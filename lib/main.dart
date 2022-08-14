import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_firebase_mfa/firebase_options.dart';
import 'package:flutter_firebase_mfa/router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:simple_logger/simple_logger.dart';
import 'package:tsuruo_kit/providers/providers.dart';

import 'logger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ),
    dotenv.load(),
  ]);
  assert(
    dotenv.isEveryDefined([EnvKey.iosClientId]),
    'Please set your `CLIENT_ID` for google_sign_in in `.env`',
  );

  logger.setLevel(
    Level.FINEST,
    includeCallerInfo: kDebugMode,
  );

  // Webブラウザ表示時のURLから`#`を取り除く
  GoRouter.setUrlPathStrategy(UrlPathStrategy.path);
  runApp(
    const ProviderScope(
      child: App(),
    ),
  );
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      scaffoldMessengerKey: ref.watch(scaffoldMessengerKey),
      title: 'Flutter Firebase MFA',
      theme: ThemeData.from(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ).copyWith(
        appBarTheme: const AppBarTheme(
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
        ),
      ),
      routeInformationProvider: router.routeInformationProvider,
      routeInformationParser: router.routeInformationParser,
      routerDelegate: router.routerDelegate,
    );
  }
}

class EnvKey {
  static const iosClientId = 'IOS_CLIENT_ID';
}
