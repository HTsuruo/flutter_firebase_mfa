import 'package:adaptive_dialog/adaptive_dialog.dart';
import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_firebase_mfa/home_page.dart';
import 'package:flutter_firebase_mfa/logger.dart';
import 'package:flutter_firebase_mfa/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsuruo_kit/tsuruo_kit.dart';

final multiFactorProvider = Provider(MultiFactorService.new);

class MultiFactorService {
  const MultiFactorService(this._ref);
  final Ref _ref;

  NavigatorState get _navigator => _ref.read(routerProvider).navigator!;

  // サインイン時や再認証時のMFA Challenge
  // MEMO(tsuruoka): 本来は`signInWithXXX`の一貫でやるべきだが、今回はわかり易さのために切り離した。
  Future<void> challenge(FirebaseAuthMultiFactorException e) async {
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
        final smsCode = await _getSmsCodeFromUser(
          usecase: _MultiFactorUse.signIn,
        );
        if (smsCode == null) {
          return;
        }
        final credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: smsCode,
        );

        try {
          await e.resolver.resolveSignIn(
            PhoneMultiFactorGenerator.getAssertion(credential),
          );
        } on FirebaseAuthException catch (e) {
          logger.warning(e);
        }
      },
    );
  }

  // MFAを有効化する
  Future<void> enroll() async {
    final user = _ref.read(userProvider).value!;
    final session = await user.multiFactor.getSession();
    const phoneNumber = '+818012341234';
    await FirebaseAuth.instance.verifyPhoneNumber(
      multiFactorSession: session,
      phoneNumber: phoneNumber,
      verificationCompleted: (_) {},
      verificationFailed: (_) {},
      codeAutoRetrievalTimeout: (_) {},
      codeSent: (verificationId, resendToken) async {
        final smsCode = await _getSmsCodeFromUser(
          usecase: _MultiFactorUse.enroll,
        );
        if (smsCode == null) {
          return;
        }
        final credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: smsCode,
        );
        try {
          // 成功すると`idTokenChanges()`に変更が流れるはず
          //  Notifying id token listeners about user ( xxx ).
          await user.multiFactor.enroll(
            PhoneMultiFactorGenerator.getAssertion(credential),
            // second factorの表示名を設定することも可能（どこで使うのかは不明）
            // displayName: 'xxx'
          );
        } on FirebaseAuthException catch (e) {
          logger.warning(e);
        }
      },
    );
  }

  // MFAを解除する
  // MEMO(tsuruoka): センシティブリクエストの扱いなので本来なら再認証やその案内が必要
  // E/flutter (21453): [ERROR:flutter/lib/ui/ui_dart_state.cc(198)] Unhandled Exception: PlatformException(FirebaseAuthRecentLoginRequiredException, com.google.firebase.auth.FirebaseAuthRecentLoginRequiredException: This operation is sensitive and requires recent authentication. Log in again before retrying this request., Cause: null, Stacktrace: com.google.firebase.auth.FirebaseAuthRecentLoginRequiredException: This operation is sensitive and requires recent authentication. Log in again before retrying this request.
  Future<void> unenroll({
    required MultiFactorInfo multiFactorInfo,
  }) async {
    final user = _ref.read(userProvider).value!;
    await _ref.read(progressController).executeWithProgress(
          () => user.multiFactor.unenroll(
            // `multiFactorInfo`か`factorUid`のどちらかを指定すれば良い
            multiFactorInfo: multiFactorInfo,
          ),
        );
  }

  Future<String?> _getSmsCodeFromUser({
    required _MultiFactorUse usecase,
  }) async {
    final inputs = await showTextInputDialog(
      title: 'SMS Code',
      message: 'Please enter the SMS code sent to your phone.',
      barrierDismissible: false,
      context: _navigator.context,
      okLabel: usecase.label,
      textFields: [
        const DialogTextField(),
      ],
    );
    return inputs?.firstOrNull;
  }
}

enum _MultiFactorUse {
  enroll(label: 'Enroll'),
  signIn(label: 'Sign In'),
  ;

  const _MultiFactorUse({required this.label});
  final String label;
}
