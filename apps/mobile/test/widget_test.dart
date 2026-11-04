import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:upendo_pamoja/domain.dart';
import 'package:upendo_pamoja/main.dart';
import 'package:upendo_pamoja/places.dart';
import 'package:upendo_pamoja/screens/discover_screen.dart';
import 'package:upendo_pamoja/screens/gate_screens.dart';
import 'package:upendo_pamoja/screens/member_screens.dart';
import 'package:upendo_pamoja/screens/setup_screen.dart';

void main() {
  testWidgets('welcome screen names the product', (tester) async {
    tester.view.physicalSize = const Size(430, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const UpendoApp());
    await tester.pump();
    expect(find.text('Create Account'), findsNothing);
    await tester.pump(const Duration(seconds: 15));
    await tester.pump();
    expect(find.text('Create Account'), findsOneWidget);
    expect(find.text('I Already Have an Account'), findsOneWidget);
    expect(find.text('Love with dignity. Always.'), findsOneWidget);
  });

  testWidgets('profile setup walks the twelve questions', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    ProfileDraft.photo = Uint8List.fromList(const [
      137, 80, 78, 71, 13, 10, 26, 10, 0, 0, 0, 13, 73, 72, 68, 82, 0, 0, 0, 1, 0, 0, 0, 1, 8, 6, 0, 0, 0, 31, 21, 196,
      137, 0, 0, 0, 10, 73, 68, 65, 84, 120, 156, 99, 0, 1, 0, 0, 5, 0, 1, 13, 10, 45, 180, 0, 0, 0, 0, 73, 69, 78, 68,
      174, 66, 96, 130,
    ]);
    addTearDown(() => ProfileDraft.photo = null);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(path: '/', builder: (context, state) => const SetupScreen()),
            GoRoute(path: '/app', builder: (context, state) => const Scaffold(body: Text('Discover home'))),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add your best photo'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    expect(find.text('What age range feels right for the people you hope to meet?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    expect(find.text('Where would you like to meet someone?'), findsOneWidget);
    expect(find.text('Open to connecting'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();
    expect(find.text('What kind of relationship are you looking for?'), findsOneWidget);
    await tester.tap(find.text('Marriage'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await tester.pumpAndSettle();

    const later = [
      'Which language do you use most?',
      'Which of the following best describes your beliefs?',
      'Do you drink alcohol?',
      'Are you a smoker?',
      'Would you like to have children?',
      "What's your current marital status?",
      'What matters most to you in a connection?',
      'How do you want to get to know someone?',
    ];
    for (final question in later) {
      expect(find.text(question), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Discover home'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile gear opens settings', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    JoinDraft.displayName = 'Amina';
    addTearDown(() => JoinDraft.displayName = '');

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: GoRouter(
          initialLocation: '/app/profile',
          routes: [
            ShellRoute(
              builder: (context, state, child) => MemberShell(child: child),
              routes: [
                GoRoute(path: '/app/profile', builder: (context, state) => const ProfileScreen()),
                GoRoute(path: '/app/settings', builder: (context, state) => const SettingsScreen()),
                GoRoute(path: '/', builder: (context, state) => const SizedBox()),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('My Profile'), findsOneWidget);
    expect(find.text('Amina'), findsOneWidget);
    expect(find.text('Hobbies & Interests'), findsOneWidget);
    expect(find.text('Your profile stays in your hands'), findsOneWidget);
    await tester.tap(find.byIcon(Icons.settings));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Email address'), findsOneWidget);
    expect(find.text('Block list'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
    expect(find.text('Switch off profile'), findsOneWidget);
    await tester.tap(find.text('Email address'));
    await tester.pumpAndSettle();
    expect(find.text('Change Email Address'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Password'));
    await tester.pumpAndSettle();
    expect(find.text('Change Password'), findsOneWidget);
    expect(find.text('Forgot password'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    expect(find.text('A mutual match'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Profile settings'));
    await tester.pumpAndSettle();
    expect(find.text('Hide my profile'), findsWidgets);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();
    expect(find.text('Their favorite'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Block list'));
    await tester.pumpAndSettle();
    expect(find.text('Your blocks'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login uses the member sign-in layout', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(path: '/', builder: (context, state) => const LoginScreen()),
            GoRoute(path: '/join', builder: (context, state) => const Scaffold(body: Text('Join screen'))),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Log in to Wendo'), findsOneWidget);
    expect(find.text('Forgot password'), findsOneWidget);
    expect(find.text('Log in with Google'), findsOneWidget);
    expect(find.text('Join'), findsOneWidget);
    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();
    expect(find.text('Join screen'), findsOneWidget);
    final error = tester.takeException();
    expect(error, isNull, reason: error is FlutterError ? error.message : '$error');
  });

  testWidgets('home shows member cards and matching preferences', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            ShellRoute(
              builder: (context, state, child) => MemberShell(child: child),
              routes: [
                GoRoute(path: '/', builder: (context, state) => const DiscoverScreen()),
              ],
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Wendo'), findsOneWidget);
    expect(find.text('For you'), findsOneWidget);
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Age'), findsOneWidget);
    expect(find.byTooltip('Open the website'), findsOneWidget);
    await tester.tap(find.byTooltip('Matching preferences'));
    await tester.pumpAndSettle();
    expect(find.text('Matching preferences'), findsOneWidget);
    expect(find.text('Living in'), findsOneWidget);
    expect(find.text('County'), findsOneWidget);
    expect(find.text('Kilimani'), findsWidgets);
    await tester.scrollUntilVisible(
      find.text('Hoping for'),
      250,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.pumpAndSettle();
    expect(find.text('Hoping for'), findsOneWidget);
    expect(find.text('Mutual matches'), findsOneWidget);
    expect(find.text('250 km'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('matches and messages explain mutual chat', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MatchesScreen())),
    );
    await tester.pump();
    expect(find.text('Matches'), findsOneWidget);
    expect(find.textContaining('not in the app'), findsOneWidget);

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MessagesScreen())),
    );
    await tester.pump();
    expect(find.text('Messages'), findsOneWidget);
    expect(find.textContaining('notification'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('last seen line names online and minutes ago', () {
    final now = DateTime(2026, 10, 30, 13, 40);
    expect(
      lastSeenLabel(lastSeen: now.subtract(const Duration(seconds: 20)), online: true, now: now),
      'Online',
    );
    expect(
      lastSeenLabel(lastSeen: now.subtract(const Duration(minutes: 39)), online: false, now: now),
      '39 minutes ago',
    );
    expect(
      lastSeenLabel(lastSeen: now.subtract(const Duration(minutes: 10)), online: false, now: now),
      '10 minutes ago',
    );
  });

  test('location narrows from country to county to area', () {
    expect(Places.countries.length, greaterThan(200));
    expect(Places.countries.first, 'Kenya');
    final counties = Places.regions('Kenya');
    expect(counties, hasLength(47));
    expect(counties, containsAll(['Nairobi', 'Mombasa', 'Kisumu', 'Garissa', 'Turkana']));
    final nairobi = Places.areas('Kenya', 'Nairobi');
    expect(nairobi.length, greaterThan(70));
    expect(nairobi, contains('Kilimani'));
    expect(Places.areas('Kenya', 'Mombasa'), containsAll(['Likoni', 'Kongowea']));
    final uganda = Places.resolve(country: 'Uganda');
    expect(uganda.country, 'Uganda');
    expect(Places.regions('Uganda'), isNotEmpty);
    expect(Places.areas(uganda.country, uganda.region), isNotEmpty);
  });
}
