import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:upendo_pamoja/app_lock.dart';
import 'package:upendo_pamoja/backend.dart';
import 'package:upendo_pamoja/domain.dart';
import 'package:upendo_pamoja/phone_alerts.dart';
import 'package:upendo_pamoja/screens/discover_screen.dart';
import 'package:upendo_pamoja/screens/gate_screens.dart';
import 'package:upendo_pamoja/screens/member_screens.dart';
import 'package:upendo_pamoja/screens/setup_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PhoneAlerts.init();
  const url = String.fromEnvironment('SUPABASE_URL');
  const publishableKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  if (url.isNotEmpty && publishableKey.isNotEmpty) {
    await Supabase.initialize(url: url, publishableKey: publishableKey);
    supabaseReady = true;
    _rememberAccount();
  }
  runApp(const UpendoApp());
}

void _rememberAccount() {
  final user = supabase?.auth.currentUser;
  if (user == null) return;
  final name = user.userMetadata?['display_name'];
  if (JoinDraft.displayName.isEmpty && name is String && name.trim().isNotEmpty) {
    JoinDraft.displayName = name.trim();
  }
  final email = user.email;
  if (JoinDraft.email.isEmpty && email != null && email.isNotEmpty) {
    JoinDraft.email = email;
  }
}

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh() {
    supabase?.auth.onAuthStateChange.listen((_) {
      _rememberAccount();
      notifyListeners();
    });
  }
}

final _authRefresh = _AuthRefresh();

class UpendoApp extends StatefulWidget {
  const UpendoApp({super.key});

  @override
  State<UpendoApp> createState() => _UpendoAppState();
}

class _UpendoAppState extends State<UpendoApp> with WidgetsBindingObserver {
  bool _checking = true;
  bool _needsPin = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshLock();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      AppLock.lockSession();
    } else if (state == AppLifecycleState.resumed) {
      _refreshLock();
    }
  }

  Future<void> _refreshLock() async {
    final enabled = await AppLock.isEnabled();
    if (!mounted) return;
    setState(() {
      _needsPin = enabled && !AppLock.unlockedThisSession;
      _checking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Wendo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE72570),
          primary: const Color(0xFFE72570),
          surface: const Color(0xFFFFFDF8),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F1E8),
        useMaterial3: true,
      ),
      routerConfig: appRouter,
      builder: (context, child) {
        Widget page = child ?? const SizedBox.shrink();
        if (_checking) {
          page = const ColoredBox(color: Color(0xFFF6F1E8));
        } else if (_needsPin) {
          page = PinLockScreen(
            onUnlocked: () => setState(() => _needsPin = false),
          );
        }
        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: 1.3,
          child: page,
        );
      },
    );
  }
}

final appRouter = GoRouter(
  refreshListenable: _authRefresh,
  initialLocation: '/opening',
  redirect: (context, state) {
    final path = state.uri.path;
    if (path == '/opening') return null;
    final signedIn = supabase?.auth.currentSession != null;
    if (signedIn && (path == '/' || path == '/login')) return '/app';
    return null;
  },
  routes: [
    GoRoute(path: '/opening', builder: (context, state) => const OpeningScreen()),
    GoRoute(path: '/', builder: (context, state) => const WelcomeScreen()),
    GoRoute(path: '/join', builder: (context, state) => const JoinScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/setup', builder: (context, state) => const SetupScreen()),
    ShellRoute(
      builder: (context, state, child) => MemberShell(child: child),
      routes: [
        GoRoute(path: '/app', builder: (context, state) => const DiscoverScreen()),
        GoRoute(path: '/app/discover', builder: (context, state) => const ViewsScreen()),
        GoRoute(
          path: '/app/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/app/matches',
          builder: (context, state) => const MatchesScreen(),
        ),
        GoRoute(
          path: '/app/messages',
          builder: (context, state) => const MessagesScreen(),
        ),
        GoRoute(path: '/app/more', builder: (context, state) => const MoreScreen()),
        GoRoute(path: '/app/meet', builder: (context, state) => const MeetScreen()),
        GoRoute(path: '/app/learn', builder: (context, state) => const LearnScreen()),
        GoRoute(
          path: '/app/support',
          builder: (context, state) => const SupportScreen(),
        ),
        GoRoute(
          path: '/app/settings',
          builder: (context, state) => const SettingsScreen(),
        ),
      ],
    ),
  ],
);
