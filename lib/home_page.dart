import 'package:collection/collection.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_firebase_mfa/multi_factor_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:tsuruo_kit/tsuruo_kit.dart';

final userProvider = StreamProvider<User?>((ref) {
  // MFAの有効/無効の変更を受けたいので`authStateChange`ではなくsupersetの`userChanges`を使う
  return FirebaseAuth.instance.userChanges();
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
          ? const SizedBox.shrink()
          : SingleChildScrollView(
              child: Column(
                children: [
                  const _BasicAuthInfo(),
                  const Divider(),
                  const _MultiFactorInfo(),
                  const Divider(),
                  const Gap(44),
                  ElevatedButton(
                    onPressed: () async {
                      await ref.read(progressController).executeWithProgress(
                            () => FirebaseAuth.instance.signOut(),
                          );
                    },
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
    );
  }
}

final _idTokenProvider = FutureProvider<String?>((ref) async {
  final user = await ref.watch(userProvider.future);
  return user?.getIdToken();
});

class _BasicAuthInfo extends ConsumerWidget {
  const _BasicAuthInfo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider).value!;
    final idToken = ref.watch(_idTokenProvider).value;
    final values = <String, String?>{
      'uid': user.uid,
      // 'displayName': user.displayName,
      'email': user.email,
      'emailVerified': user.emailVerified.toString(),
      'lastSignInTime': user.metadata.lastSignInTime.toString(),
      'providerId': user.providerData.first.providerId,
      'idToken': idToken,
    };
    return Column(
      children: values.entries
          .map(
            (e) => Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              child: _Row(
                title: e.key,
                value: e.value,
              ),
            ),
          )
          .toList(),
    );
  }
}

final _multiFactorInfoProvider = FutureProvider<MultiFactorInfo?>((ref) async {
  final user = await ref.watch(userProvider.future);
  // 現状MFAでの対応手段は電話番号（SMS）のみなので1つのみだが
  // Google Authenticatorなど他の手段が追加されたらリストで返ってくるはず。
  return (await user?.multiFactor.getEnrolledFactors())?.firstOrNull;
});

class _MultiFactorInfo extends ConsumerWidget {
  const _MultiFactorInfo();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final multiFactorInfo = ref.watch(_multiFactorInfoProvider).value;
    final multiFactorEnabled = multiFactorInfo != null;
    final values = <String, String?>{
      'displayName': multiFactorInfo?.displayName,
      'factorId': multiFactorInfo?.factorId,
      'enrollmentTimestamp': multiFactorInfo?.enrollmentTimestamp.toString(),
      'uid(second factor)': multiFactorInfo?.uid,
    };
    return Column(
      children: [
        SwitchListTile(
          value: multiFactorEnabled,
          title: const Text('MFA'),
          subtitle: const Text('Enrolling a second factor'),
          onChanged: (_) async {
            multiFactorEnabled
                ? await ref.read(multiFactorProvider).unenroll(
                      multiFactorInfo: multiFactorInfo,
                    )
                : await ref.read(multiFactorProvider).enroll();
          },
        ),
        ...values.entries
            .map(
              (e) => Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: _Row(
                  title: e.key,
                  value: e.value,
                ),
              ),
            )
            .toList(),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.value,
  });

  final String title;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final nullOrEmpty = value == null || value!.isEmpty;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(title),
        ),
        Expanded(
          child: Text(
            nullOrEmpty ? '---' : value!,
            style: theme.textTheme.bodyText2!.copyWith(
              color: nullOrEmpty ? theme.disabledColor : colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.right,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
