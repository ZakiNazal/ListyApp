import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_strings.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/push_repository.dart';
import 'data/repositories/user_repository.dart';
import 'firebase_options.dart';
import 'widgets/top_banner.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    // Ignore duplicate-app exception when natively initialized
  }

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  runApp(const ProviderScope(child: ListyApp()));
}

final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

class ListyApp extends ConsumerWidget {
  const ListyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      scaffoldMessengerKey: scaffoldMessengerKey,
      builder: (context, child) {
        // The app ships in English only. Forcing LTR here means no screen can
        // accidentally mirror itself, regardless of the device locale.
        // The listener has to sit inside `builder` rather than wrapping
        // MaterialApp, so it is below the ScaffoldMessenger it posts into and
        // rebuilds with the router.
        return Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: _GlobalNotificationListener(
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}

class _GlobalNotificationListener extends ConsumerStatefulWidget {
  const _GlobalNotificationListener({required this.child});
  final Widget child;

  @override
  ConsumerState<_GlobalNotificationListener> createState() => _GlobalNotificationListenerState();
}

class _GlobalNotificationListenerState extends ConsumerState<_GlobalNotificationListener> {
  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authStateProvider).valueOrNull?.uid;

    // Registers this device for push and keeps its FCM token fresh. Watching it
    // here means it runs for the whole signed-in session and tears down on
    // sign-out.
    ref.watch(pushRegistrationProvider);

    if (uid != null) {
      ref.listen(userNotificationsProvider(uid), (previous, next) {
        final prevList = previous?.valueOrNull ?? [];
        final nextList = next.valueOrNull ?? [];

        for (final notification in nextList) {
          final isNew = !prevList.any((p) => p.id == notification.id);

          // Only banner things that just happened. Without this the whole
          // unread backlog would fire on every cold start.
          final createdAt = notification.createdAt;
          final isRecent =
              createdAt != null &&
              DateTime.now().difference(createdAt) < const Duration(seconds: 10);

          if (isNew && isRecent) {
            TopBanner.show(
              notification.message,
              onTap: () => ref.read(routerProvider).push(Routes.notifications),
            );
          }
        }
      });
    }

    return widget.child;
  }
}
