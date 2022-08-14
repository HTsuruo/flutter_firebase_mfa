import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_firebase_mfa/home_page.dart';
import 'package:flutter_firebase_mfa/login_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tsuruo_kit/tsuruo_kit.dart';

final routerProvider = Provider((ref) {
  final router = RouterNotifier(ref);
  return GoRouter(
    debugLogDiagnostics: true,
    refreshListenable: router,
    routes: router._routes,
    redirect: router._redirectLogic,
    navigatorBuilder: (context, state, child) => ProgressHUD(child: child),
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

  static const _home = '/';
  static const _login = '/login';

  List<GoRoute> get _routes => [
        GoRoute(
          name: 'home',
          path: _home,
          builder: (context, state) => const HomePage(),
        ),
        GoRoute(
          name: 'login',
          path: _login,
          builder: (context, state) => const LoginPage(),
        ),
      ];

  String? _redirectLogic(GoRouterState state) {
    final user = _ref.read(signedInProvider).valueOrNull;
    // 未認証時は`/login`へリダイレクト
    if (user == null) {
      return state.location == _login ? null : _login;
    }

    // 認証時で`/login`のままだったら`/home`へリダイレクト
    if (state.location == _login) {
      return _home;
    }
    return null;
  }
}
