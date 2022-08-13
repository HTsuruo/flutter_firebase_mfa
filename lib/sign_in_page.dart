import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tsuruo_kit/tsuruo_kit.dart';

class SignInPage extends ConsumerWidget {
  const SignInPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: Center(
        child: SizedBox(
          height: 44,
          child: SignInButton(
            Buttons.Google,
            onPressed: () async {
              final googleSignIn = GoogleSignIn(
                clientId:
                    // ignore: lines_longer_than_80_chars
                    '624229075561-i2hacdfbgvhq5aqv03dfgm9jcsbcbtml.apps.googleusercontent.com',
              );
              final account = await googleSignIn.signIn();
              final auth = await account?.authentication;
              if (auth == null) {
                return;
              }
              await ref.read(progressController).executeWithProgress(
                    () => FirebaseAuth.instance.signInWithCredential(
                      GoogleAuthProvider.credential(
                        idToken: auth.idToken,
                        accessToken: auth.accessToken,
                      ),
                    ),
                  );
            },
          ),
        ),
      ),
    );
  }
}
