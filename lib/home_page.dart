import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      body: user == null
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _Body(user: user),
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
    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: values.entries.toList().length,
          itemBuilder: (context, index) {
            final value = values.entries.toList()[index];
            return _ListTile(
              title: value.key,
              value: value.value,
            );
          },
          separatorBuilder: (context, index) => const Divider(),
        ),
        ElevatedButton(
          onPressed: () async {
            await ref.read(progressController).executeWithProgress(
                  () => FirebaseAuth.instance.signOut(),
                );
          },
          child: const Text('Sign out'),
        )
      ],
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
