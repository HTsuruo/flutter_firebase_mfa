import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_firebase_mfa/home_page.dart';
import 'package:flutter_firebase_mfa/sign_in_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

const _signInPath = '/sign_in';

final routerProvider = Provider(
  (ref) => GoRouter(
    debugLogDiagnostics: true,
    routes: [
      GoRoute(
        name: 'home',
        path: '/',
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        name: 'signIn',
        path: _signInPath,
        builder: (context, state) => const SignInPage(),
      ),
    ],
    // redirect to the login page if the user is not logged in
    redirect: (state) {
      final signedIn = ref.read(_authRefreshListener).signedIn;
      if (!signedIn) {
        return state.subloc == _signInPath ? null : _signInPath;
      }
      return null;
    },
    // ref. https://github.com/rrousselGit/riverpod/issues/884
    refreshListenable: ref.watch(_authRefreshListener),
  ),
);

final _authRefreshListener = ChangeNotifierProvider<AuthNotifier>(
  AuthNotifier.new,
);

class AuthNotifier extends ChangeNotifier {
  AuthNotifier(this._ref) {
    _subscription = _ref.watch(signedInProvider.stream).listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  final Ref _ref;
  User? _user;
  bool get signedIn => _user != null;
  late StreamSubscription<void> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
