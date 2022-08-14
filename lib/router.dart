import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_firebase_mfa/home_page.dart';
import 'package:flutter_firebase_mfa/sign_in_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider((ref) {
  final router = RouterNotifier(ref);
  return GoRouter(
    debugLogDiagnostics: true,
    refreshListenable: router,
    routes: router._routes,
    redirect: router._redirectLogic,
  );
});

// ref. https://github.com/lucavenir/go_router_riverpod/blob/master/lib/router.dart
class RouterNotifier extends ChangeNotifier {
  RouterNotifier(this._ref) {
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

  static const _signInPath = '/sign_in';

  List<GoRoute> get _routes => [
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
      ];

  String? _redirectLogic(GoRouterState state) {
    final user = _ref.read(signedInProvider).valueOrNull;
    if (user == null) {
      return state.location == _signInPath ? null : _signInPath;
    }
    return null;
  }
}
