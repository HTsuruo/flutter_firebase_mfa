import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_firebase_mfa/main.dart';
import 'package:flutter_firebase_mfa/multi_factor_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:tsuruo_kit/tsuruo_kit.dart';

class LoginPage extends ConsumerWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign In')),
      body: Center(
        child: SizedBox(
          height: 44,
          child: SignInButton(
            Buttons.GoogleDark,
            onPressed: () async {
              final googleSignIn = GoogleSignIn(
                // AndroidはclientId指定が不要
                // ref. https://github.com/flutter/flutter/issues/99135#issuecomment-1064706025
                clientId:
                    Platform.isIOS ? dotenv.env[EnvKey.iosClientId] : null,
              );
              final account = await googleSignIn.signIn();
              final auth = await account?.authentication;
              if (auth == null) {
                return;
              }
              try {
                await ref.read(progressController).executeWithProgress(
                      () => FirebaseAuth.instance.signInWithCredential(
                        GoogleAuthProvider.credential(
                          idToken: auth.idToken,
                          accessToken: auth.accessToken,
                        ),
                      ),
                    );
              } on FirebaseAuthMultiFactorException catch (e) {
                await ref.read(multiFactorProvider).challenge(e);
              }
            },
          ),
        ),
      ),
    );
  }
}
