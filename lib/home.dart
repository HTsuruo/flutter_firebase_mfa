import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flutter Firebase MFA'),
      ),
      body: const Center(
        child: Text('Home Page'),
      ),
    );
  }
}

// class _ListTile extends StatelessWidget {
//   const _ListTile({
//     super.key,
//     required this.title,
//     required this.value,
//   });

//   final String title;
//   final String? value;

//   @override
//   Widget build(BuildContext context) {
//     final theme = Theme.of(context);
//     final colorScheme = theme.colorScheme;
//     return ListTile(
//       visualDensity: VisualDensity.compact,
//       title: Text(title),
//       trailing: Text(
//         value ?? '---',
//         style: theme.textTheme.bodyText2!.copyWith(
//           color: value == null ? theme.disabledColor : colorScheme.primary,
//         ),
//       ),
//     );
//   }
// }
