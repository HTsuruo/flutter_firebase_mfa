import 'dart:io';

import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_firebase_mfa/home_page.dart';
import 'package:flutter_firebase_mfa/logger.dart';
import 'package:flutter_firebase_mfa/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tsuruo_kit/tsuruo_kit.dart';

import 'main.dart';

final authProvider = Provider(Authenticator.new);

class Authenticator {
  const Authenticator(this._ref);
  final Ref _ref;

  static const _testPhoneNumber = '+818012341234';

  NavigatorState get _navigator => _ref.read(routerProvider).navigator!;
  User get _user => _ref.read(userProvider).value!;

  Future<void> signIn() => _authenticateWithGoogle(
        f: (credential) =>
            FirebaseAuth.instance.signInWithCredential(credential),
      );

  Future<void> _reauthenticate() async {
    final credential = await _authenticateWithGoogle<UserCredential>(
      f: _user.reauthenticateWithCredential,
    );
    logger.fine('credential: ${credential?.user}');
  }

  Future<T?> _authenticateWithGoogle<T>({
    required Future<T> Function(OAuthCredential credential) f,
  }) async {
    final googleSignIn = GoogleSignIn(
      // AndroidはclientId指定が不要
      // ref. https://github.com/flutter/flutter/issues/99135#issuecomment-1064706025
      clientId: Platform.isIOS ? dotenv.env[EnvKey.iosClientId] : null,
    );
    final account = await googleSignIn.signIn();
    final auth = await account?.authentication;
    if (auth == null) {
      return null;
    }
    try {
      return await _ref.read(progressController).executeWithProgress<T>(
            () => f(
              GoogleAuthProvider.credential(
                idToken: auth.idToken,
                accessToken: auth.accessToken,
              ),
            ),
          );
    } on FirebaseAuthMultiFactorException catch (e) {
      await _challenge(e);
    } on FirebaseAuthException catch (e) {
      logger.warning(e);
      // signInWith系の時は期待通り`FirebaseAuthMultiFactorException`で返ってくるが、
      // reAuthの時は`FirebaseAuthException`で返ってきてしまうので暫定措置。
      if (e.code == 'second-factor-required') {
        // TODO(tsuruoka): 二要素認証
      }
      // ignore: avoid_catches_without_on_clauses
    } catch (e) {
      // 省略...
      logger.warning(e);
    }
    return null;
  }

  // サインイン時や再認証時のMFA Challenge
  Future<void> _challenge(FirebaseAuthMultiFactorException e) async {
    final session = e.resolver.session;
    final firstHint = e.resolver.hints.firstOrNull;
    if (firstHint == null || firstHint is! PhoneMultiFactorInfo) {
      return;
    }
    await FirebaseAuth.instance.verifyPhoneNumber(
      multiFactorSession: session,
      multiFactorInfo: firstHint,
      verificationCompleted: (_) {},
      verificationFailed: (_) {},
      codeAutoRetrievalTimeout: (_) {},
      codeSent: (verificationId, resendToken) async {
        await _verifySMSCode(
          verificationId,
          resendToken,
          f: (credential, _) async {
            await e.resolver.resolveSignIn(
              PhoneMultiFactorGenerator.getAssertion(credential),
            );
          },
        );
      },
    );
  }

  // MFAを有効化する
  Future<void> enroll() async {
    final session = await _user.multiFactor.getSession();
    await FirebaseAuth.instance.verifyPhoneNumber(
      multiFactorSession: session,
      phoneNumber: _testPhoneNumber,
      verificationCompleted: (_) {},
      verificationFailed: (_) {},
      codeAutoRetrievalTimeout: (_) {},
      codeSent: (verificationId, resendToken) async {
        await _verifySMSCode(
          verificationId,
          resendToken,
          f: (credential, displayName) async {
            await _user.multiFactor.enroll(
              PhoneMultiFactorGenerator.getAssertion(credential),
              // second factorの表示名を設定することも可能
              displayName: displayName,
            );
          },
        );
      },
    );
  }

  // MFAを解除する
  Future<void> unenroll({
    required MultiFactorInfo multiFactorInfo,
  }) async {
    try {
      await _ref.read(progressController).executeWithProgress(
            () => _user.multiFactor.unenroll(
              // `multiFactorInfo`か`factorUid`のどちらかを指定すれば良い
              multiFactorInfo: multiFactorInfo,
            ),
          );
      // FirebaseAuthExceptionではなくPlatformExceptionで返ってくる
    } on PlatformException catch (e) {
      logger.warning(e);
      // センシティブリクエストの扱いなの再認証が必要な場合
      if (e.code == 'FirebaseAuthRecentLoginRequiredException') {
        final res = await showOkCancelAlertDialog(
          context: _navigator.context,
          title: 'Required ReAuthentication',
          message: '''
This operation is sensitive and requires recent authentication. Log in again before retrying this request.''',
        );
        if (res == OkCancelResult.ok) {
          await _reauthenticate();
        }
      }
    }
  }

  // SMS認証コードを検証する処理
  // 認証時と登録時で利用するメソッドが異なる（Userクラスやリゾルバクラス）ので、
  // enroll部分の処理のみ外から受け渡し、その他共通部分はここにまとめた。
  Future<void> _verifySMSCode(
    String verificationId,
    int? forceResendingToken, {
    required PhoneCodeVerify f,
  }) async {
    final smsCode = await _getSmsCodeFromUser();
    if (smsCode == null) {
      return;
    }
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    try {
      await f.call(credential, 'MFA Tester');
    } on FirebaseAuthException catch (e) {
      logger.warning(e);
    } on PlatformException catch (e) {
      // 認証コードが誤っていた場合
      if (e.code == 'FirebaseAuthInvalidCredentialsException') {
        _ref.read(scaffoldMessengerKey).currentState!.showMessage(
              // ignore: lines_longer_than_80_chars
              'The sms verification code used to create the phone auth credential is invalid.',
            );
      }
    }
  }

  Future<String?> _getSmsCodeFromUser() async {
    final inputs = await showTextInputDialog(
      title: 'SMS Code',
      message: 'Please enter the SMS code sent to your phone.',
      barrierDismissible: false,
      context: _navigator.context,
      textFields: [
        const DialogTextField(),
      ],
    );
    return inputs?.firstOrNull;
  }
}

typedef PhoneCodeVerify = Future<void> Function(
  PhoneAuthCredential credential,
  String? displayName,
);
