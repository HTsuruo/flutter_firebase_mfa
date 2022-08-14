import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_firebase_mfa/logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:tsuruo_kit/tsuruo_kit.dart';

final userProvider = StreamProvider<User?>((ref) {
  return FirebaseAuth.instance.authStateChanges();
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
      body: user == null ? const SizedBox.shrink() : _Body(user: user),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.user});

  final User user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final values = <String, String?>{
      'uid': user.uid,
      'displayName': user.displayName,
      'email': user.email,
      'emailVerified': user.emailVerified.toString(),
      'lastSignInTime': user.metadata.lastSignInTime.toString(),
      'providerId': user.providerData.first.providerId,
    };
    return SingleChildScrollView(
      child: Column(
        children: [
          ...values.entries
              .map(
                (e) => _ListTile(
                  title: e.key,
                  value: e.value,
                ),
              )
              .toList(),
          const Divider(),
          SwitchListTile(
            value: false,
            title: const Text('MFA'),
            subtitle: const Text('Enrolling a second factor'),
            onChanged: (value) async {
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
                    } on FirebaseAuthException catch (e) {
                      logger.warning(e);
                    }
                  }
                },
              );
            },
          ),
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
    );
  }
}

class _ListTile extends StatelessWidget {
  const _ListTile({
    required this.title,
    required this.value,
  });

  final String title;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return ListTile(
      visualDensity: VisualDensity.compact,
      title: Text(title),
      trailing: Text(
        value ?? '---',
        style: theme.textTheme.bodyText2!.copyWith(
          color: value == null ? theme.disabledColor : colorScheme.primary,
        ),
      ),
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
