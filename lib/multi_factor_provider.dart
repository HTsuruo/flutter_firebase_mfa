import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_firebase_mfa/logger.dart';
import 'package:flutter_firebase_mfa/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tsuruo_kit/tsuruo_kit.dart';

final multiFactorProvider = Provider(MultiFactorService.new);

class MultiFactorService {
  const MultiFactorService(this._ref);
  final Ref _ref;

  NavigatorState get _navigator => _ref.read(routerProvider).navigator!;

  // MFAを有効化する
  Future<void> enroll({required User user}) async {
    final session = await user.multiFactor.getSession();
    const phoneNumber = '+818012341234';
    await FirebaseAuth.instance.verifyPhoneNumber(
      multiFactorSession: session,
      phoneNumber: phoneNumber,
      verificationCompleted: (_) {},
      verificationFailed: (_) {},
      codeAutoRetrievalTimeout: (_) {},
      codeSent: (verificationId, resendToken) async {
        final smsCode = await _getSmsCodeFromUser();
        if (smsCode != null) {
          final credential = PhoneAuthProvider.credential(
            verificationId: verificationId,
            smsCode: smsCode,
          );

          try {
            await user.multiFactor.enroll(
              PhoneMultiFactorGenerator.getAssertion(credential),
            );
            // 成功すると`idTokenChanges()`に変更が流れるはず
            //  Notifying id token listeners about user ( xxx ).
          } on FirebaseAuthException catch (e) {
            logger.warning(e);
          }
        }
      },
    );
  }

  // MFAを解除する
  // センシティブリクエスト扱いなので再認証が必要:
  // E/flutter (21453): [ERROR:flutter/lib/ui/ui_dart_state.cc(198)] Unhandled Exception: PlatformException(FirebaseAuthRecentLoginRequiredException, com.google.firebase.auth.FirebaseAuthRecentLoginRequiredException: This operation is sensitive and requires recent authentication. Log in again before retrying this request., Cause: null, Stacktrace: com.google.firebase.auth.FirebaseAuthRecentLoginRequiredException: This operation is sensitive and requires recent authentication. Log in again before retrying this request.
  Future<void> unenroll({
    required User user,
    required MultiFactorInfo multiFactorInfo,
  }) async {
    await _ref.read(progressController).executeWithProgress<void>(
          () => user.multiFactor.unenroll(
            // `multiFactorInfo`か`factorUid`のどちらかを指定すれば良い
            multiFactorInfo: multiFactorInfo,
          ),
        );
  }

  // See `firebase_auth` example app for a method of retrieving user's sms code:
  // ref. https://github.com/firebase/flutterfire/blob/master/packages/firebase_auth/firebase_auth/example/lib/auth.dart#L591
  Future<String?> _getSmsCodeFromUser() async {
    String? smsCode;

    await showDialog<String>(
      context: _navigator.context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('SMS code:'),
          actions: [
            ElevatedButton(
              onPressed: () {
                _navigator.pop();
              },
              child: const Text('Enroll'),
            ),
            OutlinedButton(
              onPressed: () {
                smsCode = null;
                _navigator.pop();
              },
              child: const Text('Cancel'),
            ),
          ],
          content: Container(
            padding: const EdgeInsets.all(20),
            child: TextField(
              onChanged: (value) {
                smsCode = value;
              },
              textAlign: TextAlign.center,
              autofocus: true,
            ),
          ),
        );
      },
    );

    return smsCode;
  }
}
