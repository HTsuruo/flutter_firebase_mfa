import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_signin_button/flutter_signin_button.dart';
import 'package:google_sign_in/google_sign_in.dart';

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
              final googleSignIn = GoogleSignIn();
            },
          ),
        ),
      ),
    );
  }
}
