import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:upendo_pamoja/backend.dart';
import 'package:upendo_pamoja/connect.dart';
import 'package:upendo_pamoja/domain.dart';
import 'package:upendo_pamoja/place_picker.dart';
import 'package:upendo_pamoja/places.dart';
import 'package:upendo_pamoja/screens/settings_pages.dart';

class OpeningScreen extends StatefulWidget {
  const OpeningScreen({super.key});

  @override
  State<OpeningScreen> createState() => _OpeningScreenState();
}

class _OpeningScreenState extends State<OpeningScreen> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(seconds: 15), () {
      if (!mounted) return;
      context.go('/');
    });
  }

  @override
  Widget build(BuildContext context) {
    final width = (MediaQuery.sizeOf(context).width * 0.62).clamp(140.0, 240.0);
    return Scaffold(
      backgroundColor: const Color(0xFFA23B50),
      body: Center(
        child: Image(
          image: const AssetImage('assets/wendo_logo_white.png'),
          width: width,
          fit: BoxFit.contain,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _pink = Color(0xFFDE3268);
  static const _paper = Color(0xFFFFFFFF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFA23B50),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const Image(
            image: AssetImage('assets/wendo_couple.jpg'),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            filterQuality: FilterQuality.high,
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(28, 4, 28, 16),
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/wendo_logo_white.png',
                              height: (MediaQuery.sizeOf(context).height * 0.18).clamp(88.0, 156.0),
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                            const Text(
                              'REAL PEOPLE. MEANINGFUL LOVE.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: _paper, fontSize: 13, letterSpacing: 1.1, fontWeight: FontWeight.w600),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: _pink,
                                  foregroundColor: _paper,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: const StadiumBorder(),
                                ),
                                onPressed: () => context.go('/join'),
                                child: const Text('Create Account', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _paper,
                                  side: const BorderSide(color: Color(0xFFFFFFFF), width: 1.4),
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: const StadiumBorder(),
                                ),
                                onPressed: () => context.go('/login'),
                                child: const Text('I Already Have an Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                              ),
                            ),
                            const SizedBox(height: 18),
                            const Text('Love with dignity. Always.', style: TextStyle(color: _paper, fontSize: 16)),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});

  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  static const _clay = Color(0xFFE72570);
  static const _clayDeep = Color(0xFF9C1B4E);
  static const _cream = Color(0xFFF6F1E8);
  static const _paper = Color(0xFFFFFDF8);
  static const _ink = Color(0xFF1C1917);
  static const _line = Color(0xFFD6D3D1);
  static const _mute = Color(0xFFA8A29E);

  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _city = TextEditingController();
  DateTime? _dob;
  final String _intent = 'marriage';
  String? _message;
  bool _pending = false;
  int _step = 0;
  String? _iAm;
  String? _lookingFor;
  int? _age;
  String _country = 'Kenya';
  String _region = 'Nairobi';
  String _area = 'Kilimani';
  bool _showPassword = false;
  bool _agreed = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _name.dispose();
    _city.dispose();
    super.dispose();
  }

  void _back() {
    if (_step == 0) {
      context.go('/');
      return;
    }
    setState(() {
      _step -= 1;
      _message = null;
    });
  }

  void _next() {
    if (_step == 0) {
      if (_iAm == null || _lookingFor == null || _name.text.trim().isEmpty) {
        setState(() => _message = 'Choose who you are, who you want to meet, and a name.');
        return;
      }
      setState(() {
        _step = 1;
        _message = null;
      });
      return;
    }
    if (_step == 1) {
      if (_age == null || _age! < 18) {
        setState(() => _message = 'Wendo is for adults 18 and over.');
        return;
      }
      final today = DateTime.now();
      _dob = DateTime(today.year - _age!, today.month, today.day);
      _city.text = _area;
      ProfileDraft.country = _country;
      ProfileDraft.region = _region;
      ProfileDraft.city = _area;
      setState(() {
        _step = 2;
        _message = null;
      });
      return;
    }
    _submit();
  }

  Future<void> _submit() async {
    final dob = _dob;
    if (dob == null || !isAdult(dob)) {
      setState(() => _message = 'Wendo is for adults 18 and over.');
      return;
    }
    if (_password.text.length < 8) {
      setState(() => _message = 'Use a password of at least 8 characters.');
      return;
    }
    if (!_agreed) {
      setState(() => _message = 'Accept the terms, privacy notice, and community rules to continue.');
      return;
    }
    JoinDraft.displayName = _name.text.trim();
    JoinDraft.email = _email.text.trim();
    JoinDraft.dateOfBirth = dob;
    JoinDraft.city = _city.text.trim();
    JoinDraft.relationshipIntent = _intent;

    final client = supabase;
    if (client != null) {
      setState(() => _pending = true);
      try {
        await client.auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          data: {'display_name': JoinDraft.displayName},
        );
      } catch (error) {
        setState(() => _message = error.toString());
        return;
      } finally {
        if (mounted) setState(() => _pending = false);
      }
    }
    if (mounted) context.go('/setup');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: DecoratedBox(
                decoration: BoxDecoration(color: _cream, borderRadius: BorderRadius.circular(28)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 20, 18),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: _back,
                          icon: const Icon(Icons.arrow_back, color: _ink),
                        ),
                      ),
                      const Text(
                        'Create your free profile and start\nmeeting with dignity.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 20, height: 1.35, fontWeight: FontWeight.w500, color: _ink),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < 3; i++)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i == _step ? _ink : _line,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 24),
                children: [
                  if (_step == 0) ..._introStep(),
                  if (_step == 1) ..._detailsStep(),
                  if (_step == 2) ..._accountStep(),
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Text(_message!, textAlign: TextAlign.center, style: const TextStyle(color: _clayDeep)),
                  ],
                  const SizedBox(height: 28),
                  Center(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _clay,
                        foregroundColor: _paper,
                        padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: _pending ? null : _next,
                      child: Text(_pending ? 'Please wait…' : (_step == 2 ? 'Create your profile' : 'Next')),
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text.rich(
                    TextSpan(
                      style: const TextStyle(color: _ink, fontSize: 15),
                      children: [
                        const TextSpan(text: 'Already have an account? '),
                        WidgetSpan(
                          alignment: PlaceholderAlignment.baseline,
                          baseline: TextBaseline.alphabetic,
                          child: GestureDetector(
                            onTap: () => context.go('/login'),
                            child: const Text(
                              'Login',
                              style: TextStyle(
                                color: _clay,
                                fontSize: 15,
                                decoration: TextDecoration.underline,
                                decorationColor: _clay,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _introStep() {
    return [
      const Text("I'm a", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: _ink)),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PersonChoice(icon: Icons.man_outlined, selected: _iAm == 'man', onTap: () => setState(() => _iAm = 'man')),
          const SizedBox(width: 16),
          _PersonChoice(icon: Icons.woman_outlined, selected: _iAm == 'woman', onTap: () => setState(() => _iAm = 'woman')),
        ],
      ),
      const SizedBox(height: 28),
      const Text("I'm looking for", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: _ink)),
      const SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _PersonChoice(
            icon: Icons.man_outlined,
            selected: _lookingFor == 'man',
            onTap: () => setState(() => _lookingFor = 'man'),
          ),
          const SizedBox(width: 16),
          _PersonChoice(
            icon: Icons.woman_outlined,
            selected: _lookingFor == 'woman',
            onTap: () => setState(() => _lookingFor = 'woman'),
          ),
        ],
      ),
      const SizedBox(height: 28),
      const Text('What name do you want to use?', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: _ink)),
      const SizedBox(height: 12),
      TextField(
        controller: _name,
        textAlign: TextAlign.start,
        decoration: _fieldDecoration(),
      ),
    ];
  }

  List<String> get _regions => Places.regions(_country);

  List<String> get _areas => Places.areas(_country, _region);

  List<Widget> _detailsStep() {
    return [
      const Text('How old are you?', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: _ink)),
      const SizedBox(height: 12),
      Center(
        child: SizedBox(
          width: 168,
          child: _dropdownBox<int>(
            value: _age,
            items: [for (var age = 18; age <= 80; age++) age],
            label: (age) => '$age',
            onChanged: (value) => setState(() => _age = value),
          ),
        ),
      ),
      const SizedBox(height: 8),
      const Text(
        'Adults 18 and over. This stays in a private identity record, separate from your profile.',
        textAlign: TextAlign.center,
        style: TextStyle(color: _mute, height: 1.4),
      ),
      const SizedBox(height: 28),
      const Text('Where do you live?', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: _ink)),
      const SizedBox(height: 12),
      PlaceField(
        label: 'Country',
        value: _country,
        options: Places.countries,
        onChanged: (value) {
          final place = Places.resolve(country: value);
          setState(() {
            _country = place.country;
            _region = place.region;
            _area = place.area;
          });
        },
      ),
      const SizedBox(height: 12),
      PlaceField(
        label: Places.regionLabel(_country),
        value: _region,
        options: _regions,
        onChanged: (value) {
          final place = Places.resolve(country: _country, region: value);
          setState(() {
            _region = place.region;
            _area = place.area;
          });
        },
      ),
      const SizedBox(height: 12),
      PlaceField(
        label: 'Area',
        value: _area,
        options: _areas,
        onChanged: (value) => setState(() => _area = value),
      ),
      const SizedBox(height: 8),
      const Text(
        'Only a city or a broad area is shown. A precise address is never collected.',
        textAlign: TextAlign.center,
        style: TextStyle(color: _mute, height: 1.4),
      ),
    ];
  }

  List<Widget> _accountStep() {
    return [
      const Text("What's your email address?", textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: _ink)),
      const SizedBox(height: 12),
      TextField(
        controller: _email,
        keyboardType: TextInputType.emailAddress,
        decoration: _fieldDecoration(hint: 'email@example.com'),
      ),
      const SizedBox(height: 22),
      const Text('What password do you want to use?', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: _ink)),
      const SizedBox(height: 12),
      TextField(
        controller: _password,
        obscureText: !_showPassword,
        decoration: _fieldDecoration(hint: 'At least 8 characters').copyWith(
          suffixIcon: IconButton(
            onPressed: () => setState(() => _showPassword = !_showPassword),
            icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _mute),
          ),
        ),
      ),
      const SizedBox(height: 18),
      CheckboxListTile(
        value: _agreed,
        contentPadding: EdgeInsets.zero,
        controlAffinity: ListTileControlAffinity.leading,
        activeColor: _clay,
        onChanged: (value) => setState(() => _agreed = value ?? false),
        title: GestureDetector(
          onTap: () {
            Navigator.of(context).push(MaterialPageRoute<void>(builder: (context) => const PrivacyPolicyPage()));
          },
          child: const Text(
            'Yes, I agree to the terms of use, privacy notice, and community rules.',
            style: TextStyle(fontSize: 15, height: 1.4, color: _ink, decoration: TextDecoration.underline),
          ),
        ),
      ),
      const Text(
        'HIV status is not part of creating an account. It stays off your profile unless you later choose to share it with a mutual match.',
        textAlign: TextAlign.center,
        style: TextStyle(color: _mute, height: 1.4),
      ),
    ];
  }

  Widget _dropdownBox<T>({
    required T? value,
    required List<T> items,
    required String Function(T) label,
    required ValueChanged<T?> onChanged,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _line),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          underline: const SizedBox.shrink(),
          icon: const Icon(Icons.keyboard_arrow_down, color: _mute),
          borderRadius: BorderRadius.circular(16),
          items: [
            for (final item in items)
              DropdownMenuItem(value: item, child: Text(label(item), style: const TextStyle(color: _ink))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _clay)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _line)),
    );
  }
}

class _PersonChoice extends StatelessWidget {
  const _PersonChoice({required this.icon, required this.selected, required this.onTap});

  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const clay = Color(0xFFE72570);
    const line = Color(0xFFD6D3D1);
    const mute = Color(0xFFA8A29E);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 76,
        height: 84,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: selected ? clay : line, width: selected ? 1.6 : 1),
        ),
        child: Icon(icon, size: 40, color: selected ? clay : mute),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const _clay = Color(0xFFE72570);
  static const _clayDeep = Color(0xFF9C1B4E);
  static const _cream = Color(0xFFF6F1E8);
  static const _paper = Color(0xFFFFFDF8);
  static const _ink = Color(0xFF1C1917);
  static const _line = Color(0xFFD6D3D1);
  static const _mute = Color(0xFFA8A29E);

  final _email = TextEditingController();
  final _password = TextEditingController();
  String? _message;
  bool _pending = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final client = supabase;
    if (client == null) {
      setState(() => _message = 'Sign-in connects once the account service is set up. Your details stayed on this device.');
      return;
    }
    setState(() {
      _pending = true;
      _message = null;
    });
    try {
      await client.auth.signInWithPassword(email: _email.text.trim(), password: _password.text);
      try {
        await ensureDiscoverableProfile();
      } catch (_) {}
      if (mounted) context.go('/app');
    } catch (_) {
      if (mounted) setState(() => _message = 'That email and password were not accepted.');
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  Future<void> _forgot() async {
    final email = _email.text.trim();
    if (!email.contains('@')) {
      setState(() => _message = 'Enter your email address, then ask for a reset link.');
      return;
    }
    final client = supabase;
    if (client == null) {
      setState(() => _message = 'A reset link can be sent once the account service is set up.');
      return;
    }
    try {
      await client.auth.resetPasswordForEmail(email);
      if (mounted) setState(() => _message = 'If that email is on an account, a reset link is on its way.');
    } catch (_) {
      if (mounted) setState(() => _message = 'The reset link could not be sent.');
    }
  }

  Future<void> _google() async {
    final client = supabase;
    if (client == null) {
      setState(() => _message = 'Google sign-in connects once the account service is set up.');
      return;
    }
    setState(() {
      _pending = true;
      _message = null;
    });
    try {
      await client.auth.signInWithOAuth(OAuthProvider.google);
    } catch (_) {
      if (mounted) setState(() => _message = 'Google sign-in could not be opened.');
    } finally {
      if (mounted) setState(() => _pending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + bottom),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                onPressed: () => context.go('/'),
                icon: const Icon(Icons.arrow_back, color: _ink),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Log in to Wendo',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: _ink),
            ),
            const SizedBox(height: 36),
            const Text('Email', style: TextStyle(fontSize: 16, color: _ink)),
            const SizedBox(height: 8),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: _field(hint: 'email@example.com'),
            ),
            const SizedBox(height: 18),
            const Text('Password', style: TextStyle(fontSize: 16, color: _ink)),
            const SizedBox(height: 8),
            TextField(
              controller: _password,
              obscureText: !_showPassword,
              decoration: _field(hint: 'Password').copyWith(
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                  icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _mute),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _forgot,
                child: const Text(
                  'Forgot password',
                  style: TextStyle(color: _ink, decoration: TextDecoration.underline, decorationColor: _ink),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _clay,
                  foregroundColor: _paper,
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                ),
                onPressed: _pending ? null : _submit,
                child: Text(_pending ? 'Please wait…' : 'Log in', style: const TextStyle(fontSize: 16)),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: _paper,
                  foregroundColor: _ink,
                  side: const BorderSide(color: _line),
                  minimumSize: const Size.fromHeight(52),
                  shape: const StadiumBorder(),
                ),
                onPressed: _pending ? null : _google,
                icon: const _GoogleMark(),
                label: const Text('Log in with Google', style: TextStyle(fontSize: 16)),
              ),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(_message!, textAlign: TextAlign.center, style: const TextStyle(color: _clayDeep, height: 1.35)),
            ],
            const SizedBox(height: 28),
            Text.rich(
              TextSpan(
                style: const TextStyle(color: _ink, fontSize: 16),
                children: [
                  const TextSpan(text: 'Not a member? '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.baseline,
                    baseline: TextBaseline.alphabetic,
                    child: GestureDetector(
                      onTap: () => context.go('/join'),
                      child: const Text(
                        'Join',
                        style: TextStyle(color: _clay, fontSize: 16, decoration: TextDecoration.underline, decorationColor: _clay),
                      ),
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _field({required String hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _mute),
      filled: true,
      fillColor: _paper,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _line)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _clay)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _line)),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return const CustomPaint(size: Size(18, 18), painter: _GooglePainter());
  }
}

class _GooglePainter extends CustomPainter {
  const _GooglePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.18
      ..strokeCap = StrokeCap.butt;
    final rect = Rect.fromLTWH(1.2, 1.2, size.width - 2.4, size.height - 2.4);
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.5, 1.7, false, paint);
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 1.2, 1.15, false, paint);
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, 2.35, 0.9, false, paint);
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, 3.25, 1.1, false, paint);
    paint
      ..color = const Color(0xFF4285F4)
      ..strokeCap = StrokeCap.square;
    final mid = size.height / 2;
    canvas.drawLine(Offset(size.width / 2, mid), Offset(size.width - 1.5, mid), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
