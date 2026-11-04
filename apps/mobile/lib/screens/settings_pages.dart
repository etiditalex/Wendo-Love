import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:upendo_pamoja/app_lock.dart';
import 'package:upendo_pamoja/backend.dart';
import 'package:upendo_pamoja/connect.dart';
import 'package:upendo_pamoja/domain.dart';
import 'package:upendo_pamoja/phone_alerts.dart';

const _clay = Color(0xFFE72570);
const _clayDeep = Color(0xFF9C1B4E);
const _cream = Color(0xFFF6F1E8);
const _paper = Color(0xFFFFFDF8);
const _ink = Color(0xFF1C1917);
const _inkSoft = Color(0xFF44403C);
const _mute = Color(0xFFA8A29E);
const _line = Color(0xFFD6D3D1);
const _pale = Color(0xFFE6D3A8);

class ChangeEmailPage extends StatefulWidget {
  const ChangeEmailPage({super.key});

  @override
  State<ChangeEmailPage> createState() => _ChangeEmailPageState();
}

class _ChangeEmailPageState extends State<ChangeEmailPage> {
  late final TextEditingController _email;
  String? _message;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: JoinDraft.email);
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final next = _email.text.trim();
    if (!next.contains('@') || !next.contains('.')) {
      setState(() => _message = 'Enter the email address you want to use.');
      return;
    }
    JoinDraft.email = next;
    final client = supabase;
    final user = client?.auth.currentUser;
    if (client != null && user != null) {
      try {
        await client.auth.updateUser(UserAttributes(email: next));
      } catch (error) {
        if (!mounted) return;
        setState(() => _message = error.toString());
        return;
      }
    }
    if (!mounted) return;
    setState(() => _message = 'Email address saved. It is not shown on your profile.');
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsScaffold(
      title: 'Change Email Address',
      children: [
        const Text(
          'Update your email if it has changed, so a note about a mutual match can still reach you.',
          style: TextStyle(fontSize: 16, height: 1.4, color: _ink),
        ),
        const SizedBox(height: 22),
        const Text('Email address', style: TextStyle(fontSize: 16, color: _ink)),
        const SizedBox(height: 8),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          decoration: _boxDecoration(),
        ),
        const SizedBox(height: 22),
        _saveButton(onPressed: _save),
        if (_message != null) ...[
          const SizedBox(height: 16),
          Text(_message!, style: const TextStyle(color: _clayDeep)),
        ],
      ],
    );
  }
}

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _showCurrent = false;
  bool _showNext = false;
  String? _message;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_next.text.length < 8) {
      setState(() => _message = 'Use a new password of at least 8 characters.');
      return;
    }
    final client = supabase;
    final email = JoinDraft.email;
    if (client == null || email.isEmpty) {
      setState(() => _message = 'A password change is saved with your account once sign-in is connected.');
      return;
    }
    try {
      await client.auth.signInWithPassword(email: email, password: _current.text);
      await client.auth.updateUser(UserAttributes(password: _next.text));
      if (!mounted) return;
      setState(() => _message = 'Password saved.');
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = 'The current password was not accepted.');
    }
  }

  Future<void> _forgot() async {
    final email = JoinDraft.email;
    final client = supabase;
    if (client == null || email.isEmpty) {
      setState(() => _message = 'Add the email on your account first. A reset link can then be sent there.');
      return;
    }
    try {
      await client.auth.resetPasswordForEmail(email);
      if (!mounted) return;
      setState(() => _message = 'If that email is on an account, a reset link is on its way.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsScaffold(
      title: 'Change Password',
      children: [
        const Text(
          'A longer password keeps your account to yourself. Health information is never part of this password.',
          style: TextStyle(fontSize: 16, height: 1.4, color: _ink),
        ),
        const SizedBox(height: 22),
        const Text('Current password', style: TextStyle(fontSize: 16, color: _ink)),
        const SizedBox(height: 8),
        TextField(
          controller: _current,
          obscureText: !_showCurrent,
          decoration: _boxDecoration(hint: 'At least 8 characters').copyWith(
            suffixIcon: IconButton(
              onPressed: () => setState(() => _showCurrent = !_showCurrent),
              icon: Icon(_showCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _mute),
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text('New password', style: TextStyle(fontSize: 16, color: _ink)),
        const SizedBox(height: 8),
        TextField(
          controller: _next,
          obscureText: !_showNext,
          decoration: _boxDecoration(hint: 'At least 8 characters').copyWith(
            suffixIcon: IconButton(
              onPressed: () => setState(() => _showNext = !_showNext),
              icon: Icon(_showNext ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: _mute),
            ),
          ),
        ),
        const SizedBox(height: 22),
        _saveButton(onPressed: _save),
        const SizedBox(height: 12),
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            foregroundColor: _ink,
            side: const BorderSide(color: _line),
            minimumSize: const Size.fromHeight(52),
            shape: const StadiumBorder(),
          ),
          onPressed: _forgot,
          child: const Text('Forgot password', style: TextStyle(fontSize: 16)),
        ),
        if (_message != null) ...[
          const SizedBox(height: 16),
          Text(_message!, style: const TextStyle(color: _clayDeep)),
        ],
      ],
    );
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  late bool _emailMessages;
  late bool _emailMatch;
  late bool _emailReply;
  late bool _mobileMessages;
  late bool _mobileMatch;
  late bool _realtimeMessages;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _emailMessages = ProfileDraft.emailMessages;
    _emailMatch = ProfileDraft.emailMatch;
    _emailReply = ProfileDraft.emailReply;
    _mobileMessages = ProfileDraft.mobileMessages;
    _mobileMatch = ProfileDraft.mobileMatch;
    _realtimeMessages = ProfileDraft.realtimeMessages;
  }

  void _toggle(void Function() change) {
    setState(() {
      change();
      _dirty = true;
    });
  }

  void _save() {
    ProfileDraft.emailMessages = _emailMessages;
    ProfileDraft.emailMatch = _emailMatch;
    ProfileDraft.emailReply = _emailReply;
    ProfileDraft.mobileMessages = _mobileMessages;
    ProfileDraft.mobileMatch = _mobileMatch;
    ProfileDraft.realtimeMessages = _realtimeMessages;
    if (_mobileMessages || _mobileMatch) {
      PhoneAlerts.requestPermission();
    }
    setState(() => _dirty = false);
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsScaffold(
      title: 'Notifications',
      children: [
        const Text(
          'Alerts on this phone use a short, neutral line. They never include a name, a photo, a message preview, or health information, so a glance at the screen does not out you.',
          style: TextStyle(fontSize: 16, height: 1.4, color: _inkSoft),
        ),
        const SizedBox(height: 18),
        const _SectionTitle('Email notifications'),
        _switch('New messages', _emailMessages, (value) => _toggle(() => _emailMessages = value)),
        _switch('A mutual match', _emailMatch, (value) => _toggle(() => _emailMatch = value)),
        _switch('A reply in your conversation', _emailReply, (value) => _toggle(() => _emailReply = value)),
        const SizedBox(height: 12),
        const _SectionTitle('Mobile notifications'),
        _switch('New messages', _mobileMessages, (value) => _toggle(() => _mobileMessages = value)),
        _switch('A mutual match', _mobileMatch, (value) => _toggle(() => _mobileMatch = value)),
        const SizedBox(height: 12),
        const _SectionTitle('Realtime notifications'),
        _switch('New messages', _realtimeMessages, (value) => _toggle(() => _realtimeMessages = value)),
        const SizedBox(height: 22),
        _saveButton(onPressed: _dirty ? _save : null),
      ],
    );
  }
}

class ProfileSettingsPage extends StatefulWidget {
  const ProfileSettingsPage({super.key});

  @override
  State<ProfileSettingsPage> createState() => _ProfileSettingsPageState();
}

class _ProfileSettingsPageState extends State<ProfileSettingsPage> {
  late String _presence;
  late bool _visible;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _presence = ProfileDraft.presence;
    _visible = ProfileDraft.visible;
  }

  void _mark(void Function() change) {
    setState(() {
      change();
      _dirty = true;
    });
  }

  void _save() {
    ProfileDraft.presence = _presence;
    ProfileDraft.visible = _visible;
    setState(() => _dirty = false);
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsScaffold(
      title: 'Profile Settings',
      children: [
        const Text(
          'Choose how you appear. Only a city or a broad area is shown, and there is no public member directory.',
          style: TextStyle(fontSize: 16, height: 1.4, color: _inkSoft),
        ),
        const SizedBox(height: 18),
        const _SectionTitle('Online options'),
        const Text('Online status', style: TextStyle(fontSize: 16, color: _ink)),
        const SizedBox(height: 8),
        _radio('Show me as online', _presence == 'online', () => _mark(() => _presence = 'online')),
        _radio('Show me as busy', _presence == 'busy', () => _mark(() => _presence = 'busy')),
        const SizedBox(height: 16),
        const Text('Display profile', style: TextStyle(fontSize: 16, color: _ink)),
        const SizedBox(height: 8),
        _radio('Show my profile in suggestions', _visible, () => _mark(() => _visible = true)),
        _radio('Hide my profile', !_visible, () => _mark(() => _visible = false)),
        const SizedBox(height: 16),
        DecoratedBox(
          decoration: BoxDecoration(color: _clay, borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              children: [
                const Icon(Icons.visibility_off_outlined, color: _paper, size: 32),
                const SizedBox(height: 8),
                const Text(
                  'Hiding your profile is free. Suggestions pause until you show it again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _paper, fontSize: 16, height: 1.35, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _paper,
                    foregroundColor: _clay,
                    minimumSize: const Size(180, 44),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => _mark(() => _visible = false),
                  child: const Text('Hide my profile', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 22),
        _saveButton(onPressed: _dirty ? _save : null),
      ],
    );
  }
}

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  List<ReceivedLike> _mine = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await loadFavoritePeople();
    if (!mounted) return;
    setState(() {
      _mine = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: _cream,
        appBar: AppBar(
          backgroundColor: _clayDeep,
          foregroundColor: _paper,
          centerTitle: true,
          title: const Text('Favorites'),
        ),
        body: Column(
          children: [
            const Material(
              color: _cream,
              child: TabBar(
                indicatorColor: _gold,
                indicatorWeight: 3,
                labelColor: _ink,
                unselectedLabelColor: _mute,
                labelStyle: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                tabs: [
                  Tab(text: 'Their favorite'),
                  Tab(text: 'My favorites'),
                  Tab(text: 'Mutual'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  const _FavoriteEmpty(
                    title: 'No one has saved you as a favorite yet',
                    body: 'Favorites stay private. Being a favorite is not a match until you have both chosen each other.',
                  ),
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _mine.isEmpty
                          ? const _FavoriteEmpty(
                              title: 'You have not saved a favorite yet',
                              body: 'A favorite is a private note to yourself. It does not open a conversation on its own.',
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: _mine.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final person = _mine[index];
                                return ListTile(
                                  title: Text(person.name),
                                  subtitle: Text(person.city.isEmpty ? 'Favorite' : person.city),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.star),
                                    color: _gold,
                                    onPressed: () async {
                                      await removeFavorite(person.userId);
                                      await _load();
                                    },
                                  ),
                                );
                              },
                            ),
                  const _FavoriteEmpty(
                    title: 'You have no mutual favorites yet',
                    body: 'A mutual favorite means you have both chosen to remember each other. Chat still waits for a mutual match.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoriteEmpty extends StatelessWidget {
  const _FavoriteEmpty({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 48, 28, 24),
      children: [
        const Icon(Icons.star, color: _gold, size: 36),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: _gold, fontSize: 20, height: 1.3, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        Text(body, textAlign: TextAlign.center, style: const TextStyle(color: _inkSoft, fontSize: 15, height: 1.4)),
        const SizedBox(height: 22),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _clay,
            foregroundColor: _paper,
            minimumSize: const Size.fromHeight(48),
            shape: const StadiumBorder(),
          ),
          onPressed: () => context.go('/app/matches'),
          child: const Text('See mutual matches'),
        ),
      ],
    );
  }
}

class BlocksPage extends StatefulWidget {
  const BlocksPage({super.key});

  @override
  State<BlocksPage> createState() => _BlocksPageState();
}

class _BlocksPageState extends State<BlocksPage> {
  List<Map<String, dynamic>> _rows = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rows = await loadBlockedPeople();
    if (!mounted) return;
    setState(() {
      _rows = rows;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsScaffold(
      title: 'Your blocks',
      action: IconButton(
        onPressed: () {
          showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Reporting is separate'),
              content: const Text(
                'A block stops contact at once, and the other person is not told. A report is for a review. If you are in immediate danger, contact local emergency services.',
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
            ),
          );
        },
        icon: const Icon(Icons.more_horiz, color: _paper),
      ),
      children: [
        if (_loading)
          const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (_rows.isEmpty) ...[
          const Text(
            "You haven't blocked anyone yet",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _ink),
          ),
          const SizedBox(height: 8),
          const Text(
            'If a message feels unsafe or unwelcome, block that person so they cannot contact you. Blocking is private.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 15, height: 1.4, color: _inkSoft),
          ),
        ] else
          for (final row in _rows)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${row['display_name']}'),
              subtitle: Text('${row['city']}'.isEmpty ? 'Blocked' : '${row['city']}'),
              trailing: TextButton(
                onPressed: () async {
                  await unblockPerson('${row['user_id']}');
                  await _load();
                },
                child: const Text('Unblock'),
              ),
            ),
        const SizedBox(height: 18),
        DecoratedBox(
          decoration: BoxDecoration(color: _clay, borderRadius: BorderRadius.circular(18)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
            child: Column(
              children: [
                const Icon(Icons.mark_email_read_outlined, color: _paper, size: 34),
                const SizedBox(height: 8),
                const Text(
                  'Messages stay between two people',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _paper, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'A conversation opens only after you have both chosen each other. A block stops contact.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: _paper, fontSize: 15, height: 1.35),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: _paper,
                    foregroundColor: _clay,
                    minimumSize: const Size.fromHeight(46),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => context.go('/app/messages'),
                  child: const Text('Go to messages', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SettingsScaffold extends StatelessWidget {
  const _SettingsScaffold({required this.title, required this.children, this.action});

  final String title;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _paper,
      appBar: AppBar(
        backgroundColor: _clayDeep,
        foregroundColor: _paper,
        centerTitle: true,
        title: Text(title),
        actions: [?action],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: children,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Text(text, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _ink)),
    );
  }
}

InputDecoration _boxDecoration({String? hint}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: _mute),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _line)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _clay)),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _line)),
  );
}

Widget _saveButton({required VoidCallback? onPressed, String label = 'Save'}) {
  return FilledButton(
    style: FilledButton.styleFrom(
      backgroundColor: _clay,
      disabledBackgroundColor: _pale,
      foregroundColor: _paper,
      disabledForegroundColor: const Color(0xFFF3EDE3),
      minimumSize: const Size.fromHeight(52),
      shape: const StadiumBorder(),
    ),
    onPressed: onPressed,
    child: Text(label, style: const TextStyle(fontSize: 16)),
  );
}

Widget _switch(String label, bool value, ValueChanged<bool> onChanged) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 16, color: _ink))),
        Switch(
          value: value,
          onChanged: onChanged,
          thumbColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected) ? _ink : _paper;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected) ? _clay : _line;
          }),
        ),
      ],
    ),
  );
}

Widget _radio(String label, bool selected, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off, color: selected ? _clay : _ink),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 16, color: _ink))),
        ],
      ),
    ),
  );
}

class PinSettingsPage extends StatefulWidget {
  const PinSettingsPage({super.key});

  @override
  State<PinSettingsPage> createState() => _PinSettingsPageState();
}

class _PinSettingsPageState extends State<PinSettingsPage> {
  bool _enabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final on = await AppLock.isEnabled();
    if (!mounted) return;
    setState(() {
      _enabled = on;
      _loading = false;
    });
  }

  Future<void> _turnOn() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => PinLockScreen(
          setup: true,
          onUnlocked: () => Navigator.of(context).pop(),
        ),
      ),
    );
    await _load();
  }

  Future<void> _turnOff() async {
    await AppLock.clearPin();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsScaffold(
      title: 'PIN lock',
      children: [
        const Text(
          'A 4-digit PIN is asked when this app opens or returns from the background.',
          style: TextStyle(fontSize: 16, height: 1.4, color: _ink),
        ),
        const SizedBox(height: 22),
        if (_loading)
          const Center(child: CircularProgressIndicator(color: _clay))
        else if (_enabled) ...[
          const Text('PIN lock is on.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _saveButton(onPressed: _turnOn, label: 'Change PIN'),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: _ink,
              side: const BorderSide(color: _line),
              minimumSize: const Size.fromHeight(52),
              shape: const StadiumBorder(),
            ),
            onPressed: _turnOff,
            child: const Text('Turn PIN lock off'),
          ),
        ] else
          _saveButton(onPressed: _turnOn, label: 'Set a PIN'),
      ],
    );
  }
}

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return _SettingsScaffold(
      title: 'Privacy policy',
      children: const [
        Text(
          'This notice is for the Kenya-first Wendo pilot.',
          style: TextStyle(fontSize: 16, height: 1.45, color: _ink),
        ),
        SizedBox(height: 16),
        Text('What we collect', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _ink)),
        SizedBox(height: 8),
        Text(
          'An email, a password, a display name, a date of birth held only in private identity, a city or area (never a street address or GPS), a photo you upload, likes, and messages you send. Optional HIV status is stored only if you choose it, in a separate health table, never on your public card.',
          style: TextStyle(fontSize: 16, height: 1.45, color: _ink),
        ),
        SizedBox(height: 16),
        Text('How it is protected', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _ink)),
        SizedBox(height: 8),
        Text(
          'Traffic uses HTTPS. Stored account data sits in a private database with row-level access for your signed-in session. Photos stay in a private bucket. Screenshots of this app are blocked on Android where the phone allows it. A PIN can lock the app when it leaves the screen. Alerts say only “You have an update.” They never include a name, a preview, or a health detail.',
          style: TextStyle(fontSize: 16, height: 1.45, color: _ink),
        ),
        SizedBox(height: 16),
        Text('What we never collect', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _ink)),
        SizedBox(height: 8),
        Text(
          'Clinic names, ART cards, medical-record numbers, patient numbers, precise addresses, or GPS. HIV status is never inferred and never used to rank people.',
          style: TextStyle(fontSize: 16, height: 1.45, color: _ink),
        ),
        SizedBox(height: 16),
        Text('Deletion', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _ink)),
        SizedBox(height: 8),
        Text(
          'Delete account in Settings removes your auth user, profile, private identity, photos, likes, matches, and messages. That is a real erase, not a pause. You can also switch the profile off if you only want to stop appearing for a while.',
          style: TextStyle(fontSize: 16, height: 1.45, color: _ink),
        ),
      ],
    );
  }
}

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  bool _busy = false;
  String? _message;

  Future<void> _delete() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    AppLock.lockSession();
    await AppLock.clearPin();
    final error = await deleteOwnAccount();
    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _message = error;
      });
      return;
    }
    if (context.mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsScaffold(
      title: 'Delete account',
      children: [
        const Text(
          'This permanently removes your account, photos, likes, matches, and messages. It cannot be undone.',
          style: TextStyle(fontSize: 16, height: 1.45, color: _ink),
        ),
        const SizedBox(height: 22),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _clayDeep,
            foregroundColor: _paper,
            minimumSize: const Size.fromHeight(52),
            shape: const StadiumBorder(),
          ),
          onPressed: _busy ? null : _delete,
          child: Text(_busy ? 'Deleting…' : 'Delete my account'),
        ),
        if (_message != null) ...[
          const SizedBox(height: 16),
          Text(_message!, style: const TextStyle(color: _clayDeep)),
        ],
      ],
    );
  }
}

const _gold = Color(0xFFF06A4A);
