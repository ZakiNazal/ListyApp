import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/repositories/auth_repository.dart';
import '../../features/about/about_screen.dart';
import '../../features/auth/language_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/otp_screen.dart';
import '../../features/friends/invited_friends_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/lists/edit_list_screen.dart';
import '../../features/lists/item_lists_screen.dart';
import '../../features/lists/list_detail_screen.dart';
import '../../features/lists/upcoming_lists_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/request/request_screen.dart';
import '../../features/shell/app_shell.dart';
import '../../features/splash/splash_screen.dart';

abstract final class Routes {
  static const splash = '/';
  static const language = '/language';
  static const login = '/login';
  static const otp = '/otp';
  static const home = '/home';
  static const request = '/request';
  static const profile = '/profile';
  static const itemLists = '/lists';
  static const upcomingLists = '/upcoming';
  static const invitedFriends = '/friends';
  static const notifications = '/notifications';
  static const about = '/about';
  static const editList = '/edit-list';

  /// Detail for one list, e.g. `/lists/abc123`.
  static String listDetail(String listId) => '$itemLists/$listId';

  /// Routes that live inside the bottom-navigation shell. Navigating between
  /// these replaces the current tab (`go`); everything else is a full-screen
  /// page stacked on top (`push`).
  static const shellRoutes = <String>{home, request, profile};
}

extension AppNavigation on BuildContext {
  /// Pops if there is anything to pop, otherwise goes to [fallback].
  ///
  /// A screen like Item Lists can be reached two ways: pushed from Home (a
  /// real stack entry) or `go`-ne to from the drawer (which replaces the
  /// stack). A bare `pop()` throws "There is nothing to pop" in the second
  /// case, so every back affordance goes through this instead.
  void backOr([String fallback = Routes.home]) {
    final router = GoRouter.of(this);
    if (router.canPop()) {
      router.pop();
    } else {
      go(fallback);
    }
  }

  /// Navigates the way the destination expects: shell tabs replace, full-screen
  /// pages stack so they can be backed out of.
  void goOrPush(String route) {
    if (Routes.shellRoutes.contains(route)) {
      go(route);
    } else {
      push(route);
    }
  }
}

/// Rebuilds the router whenever auth state flips so redirects re-evaluate.
final _routerRefreshProvider = Provider<_AuthRefreshNotifier>((ref) {
  final notifier = _AuthRefreshNotifier();
  ref.listen(authStateProvider, (_, _) => notifier.ping());
  ref.onDispose(notifier.dispose);
  return notifier;
});

class _AuthRefreshNotifier extends ChangeNotifier {
  void ping() => notifyListeners();
}

/// The root navigator, exposed so code outside the widget tree can reach the
/// app's [Overlay] -- specifically [TopBanner], which has to draw above every
/// Scaffold rather than inside one.
final rootNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(_routerRefreshProvider);

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.splash,
    refreshListenable: refresh,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);

      // Hold on the splash screen until Firebase reports its first value.
      if (authState.isLoading) return null;

      // valueOrNull, not value: AsyncValue.value rethrows when the provider is
      // in an error state, and a throw inside redirect leaves the app with no
      // route at all.
      final signedIn = authState.valueOrNull != null;
      final location = state.matchedLocation;

      const authRoutes = {Routes.language, Routes.login, Routes.otp};
      final onSplash = location == Routes.splash;
      final onAuthRoute = authRoutes.contains(location);

      if (!signedIn) {
        // Let the splash animation finish, then the splash screen itself
        // routes to /language.
        if (onSplash || onAuthRoute) return null;
        return Routes.language;
      }

      // Signed in: never leave the user sitting on an auth screen.
      if (onSplash || onAuthRoute) return Routes.home;
      return null;
    },
    routes: [
      GoRoute(path: Routes.splash, builder: (_, _) => const SplashScreen()),
      GoRoute(path: Routes.language, builder: (_, _) => const LanguageScreen()),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: Routes.otp,
        builder: (_, state) {
          final args = state.extra as OtpArgs?;
          if (args == null) return const LoginScreen();
          return OtpScreen(args: args);
        },
      ),

      // Bottom-navigation shell. Home / Request / Profile keep the nav bar and
      // the Design 23 drawer mounted.
      StatefulShellRoute(
        builder: (context, state, navigationShell) =>
            AppShell(location: state.matchedLocation, child: navigationShell),
        navigatorContainerBuilder: (context, navigationShell, children) =>
            TabTransition(
              index: navigationShell.currentIndex,
              children: children,
            ),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.request,
                builder: (_, _) => const RequestScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.profile,
                builder: (_, _) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),

      // Full-screen pages pushed above the shell.
      GoRoute(
        path: Routes.itemLists,
        builder: (_, _) => const ItemListsScreen(),
        routes: [
          // Nested so `/lists/:listId` keeps Item Lists as its parent and back
          // returns there rather than to whatever pushed it.
          GoRoute(
            path: ':listId',
            builder: (_, state) =>
                ListDetailScreen(listId: state.pathParameters['listId']!),
          ),
        ],
      ),
      GoRoute(
        path: Routes.editList,
        builder: (_, state) {
          final args = state.extra as Map<String, dynamic>?;
          if (args == null) return const HomeScreen();
          return EditListScreen(
            list: args['list'],
            items: args['items'],
          );
        },
      ),
      GoRoute(
        path: Routes.upcomingLists,
        builder: (_, _) => const UpcomingListsScreen(),
      ),
      GoRoute(
        path: Routes.invitedFriends,
        builder: (_, _) => const InvitedFriendsScreen(),
      ),
      GoRoute(
        path: Routes.notifications,
        builder: (_, _) => const NotificationsScreen(),
      ),
      GoRoute(path: Routes.about, builder: (_, _) => const AboutScreen()),
    ],
  );
});
