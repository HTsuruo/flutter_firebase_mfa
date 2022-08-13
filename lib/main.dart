import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_firebase_mfa/home.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:simple_logger/simple_logger.dart';

import 'logger.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  logger.setLevel(
    kReleaseMode ? Level.SEVERE : Level.FINEST,
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

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Firebase MFA',
      theme: ThemeData.from(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      ),
      home: const HomePage(),
    );
  }
}
