import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_firebase_mfa/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:tsuruo_kit/tsuruo_kit.dart';

final userProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.userChanges();
});

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider).value;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Firebase MFA'),
      ),
      body: user == null
          ? const SizedBox.shrink()
          : SingleChildScrollView(
              child: Column(
                children: [
                  _BasicAuthInfo(user: user),
                  const Divider(),
                  _MultiFactorInfo(user: user),
                  const Divider(),
                  const Gap(44),
                  ElevatedButton(
                    onPressed: () async {
                      await ref.read(progressController).executeWithProgress(
                            () => FirebaseAuth.instance.signOut(),
                          );
                    },
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
    );
  }
}

final _idTokenProvider = FutureProvider<String?>((ref) async {
  final user = await ref.watch(userProvider.future);
  return user?.getIdToken();
});

class _BasicAuthInfo extends ConsumerWidget {
  const _BasicAuthInfo({required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values = <String, String?>{
      'uid': user.uid,
      // 'displayName': user.displayName,
      'email': user.email,
      'emailVerified': user.emailVerified.toString(),
      'lastSignInTime': user.metadata.lastSignInTime.toString(),
      'providerId': user.providerData.first.providerId,
      'idToken': ref.watch(_idTokenProvider).valueOrNull,
    };
    return Column(
      children: values.entries
          .map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: _Row(
                title: e.key,
                value: e.value,
              ),
            ),
          )
          .toList(),
    );
  }
}

final _multiFactorInfoProvider = FutureProvider<MultiFactorInfo?>((ref) async {
  final user = await ref.watch(userProvider.future);
  // 現状MFAでの対応手段は電話番号（SMS）のみなので1つのみだが
  // Google Authenticatorなど他の手段が追加されたらリストで返ってくるはず。
  return (await user?.multiFactor.getEnrolledFactors())?.firstOrNull;
});

class _MultiFactorInfo extends ConsumerWidget {
  const _MultiFactorInfo({required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final multiFactor = ref.watch(_multiFactorInfoProvider).value;
    final multiFactorEnabled = multiFactor != null;
    final values = <String, String?>{
      'displayName': multiFactor?.displayName,
      'factorId': multiFactor?.factorId,
      'enrollmentTimestamp': multiFactor?.enrollmentTimestamp.toString(),
      'uid(second factor)': multiFactor?.uid,
    };
    return Column(
      children: [
        SwitchListTile(
          value: multiFactorEnabled,
          title: const Text('MFA'),
          subtitle: const Text('Enrolling a second factor'),
          onChanged: (_) async {
            if (multiFactorEnabled) {
              // MFAを解除する
              // センシティブリクエスト扱いなので再認証が必要:
              // E/flutter (21453): [ERROR:flutter/lib/ui/ui_dart_state.cc(198)] Unhandled Exception: PlatformException(FirebaseAuthRecentLoginRequiredException, com.google.firebase.auth.FirebaseAuthRecentLoginRequiredException: This operation is sensitive and requires recent authentication. Log in again before retrying this request., Cause: null, Stacktrace: com.google.firebase.auth.FirebaseAuthRecentLoginRequiredException: This operation is sensitive and requires recent authentication. Log in again before retrying this request.
              await ref.read(progressController).executeWithProgress(
                    () => user.multiFactor.unenroll(
                      factorUid: multiFactor.factorId,
                    ),
                  );
            } else {
              // MFAを有効化する
              final session = await user.multiFactor.getSession();
              const phoneNumber = '+818012341234';
              await FirebaseAuth.instance.verifyPhoneNumber(
                multiFactorSession: session,
                phoneNumber: phoneNumber,
                verificationCompleted: (_) {},
                verificationFailed: (_) {},
                codeAutoRetrievalTimeout: (_) {},
                codeSent: (verificationId, resendToken) async {
                  final smsCode = await getSmsCodeFromUser(context);
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
          },
        ),
        ...values.entries
            .map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: _Row(
                  title: e.key,
                  value: e.value,
                ),
              ),
            )
            .toList(),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.value,
  });

  final String title;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final nullOrEmpty = value == null || value!.isEmpty;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(title),
        ),
        Expanded(
          child: Text(
            nullOrEmpty ? '---' : value!,
            style: theme.textTheme.bodyText2!.copyWith(
              color: nullOrEmpty ? theme.disabledColor : colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

Future<String?> getSmsCodeFromUser(BuildContext context) async {
  String? smsCode;

  // Update the UI - wait for the user to enter the SMS code
  await showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return AlertDialog(
        title: const Text('SMS code:'),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Sign in'),
          ),
          OutlinedButton(
            onPressed: () {
              smsCode = null;
              Navigator.of(context).pop();
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
