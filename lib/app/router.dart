import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/auth/presentation/login_page.dart';
import '../features/auth/presentation/signup_page.dart';
import '../features/auth/presentation/welcome_page.dart';
import '../features/checkin/presentation/breathing_page.dart';
import '../features/checkin/presentation/checkin_page.dart';
import '../features/checkin/presentation/results_page.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/profile/presentation/onboarding_page.dart';
import '../features/profile/presentation/settings_page.dart';
import 'app_state.dart';
import 'shell.dart';

GoRouter buildRouter(AppState app) {
  const public = {'/welcome', '/login', '/signup'};
  Page<void> page(Widget child) => NoTransitionPage(child: child);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: app,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      if (!app.ready) return loc == '/splash' ? null : '/splash';
      if (!app.loggedIn) return public.contains(loc) ? null : '/welcome';
      final p = app.profile;
      if (p == null) return loc == '/splash' ? null : '/splash';
      if (!p.onboarded) return loc == '/onboarding' ? null : '/onboarding';
      if (public.contains(loc) || loc == '/splash' || loc == '/onboarding') return '/home';
      return null;
    },
    routes: [
      ShellRoute(
        builder: (context, state, child) => AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(path: '/splash', pageBuilder: (c, s) => page(const _Splash())),
          GoRoute(path: '/welcome', pageBuilder: (c, s) => page(const WelcomePage())),
          GoRoute(path: '/login', pageBuilder: (c, s) => page(const LoginPage())),
          GoRoute(path: '/signup', pageBuilder: (c, s) => page(const SignupPage())),
          GoRoute(path: '/onboarding', pageBuilder: (c, s) => page(const OnboardingPage())),
          GoRoute(path: '/home', pageBuilder: (c, s) => page(const DashboardPage())),
          GoRoute(path: '/checkin', pageBuilder: (c, s) => page(const CheckinPage())),
          GoRoute(path: '/results', pageBuilder: (c, s) => page(const ResultsPage())),
          GoRoute(path: '/breathe', pageBuilder: (c, s) => page(const BreathingPage())),
          GoRoute(path: '/settings', pageBuilder: (c, s) => page(const SettingsPage())),
        ],
      ),
    ],
  );
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => const Center(child: CircularProgressIndicator());
}
