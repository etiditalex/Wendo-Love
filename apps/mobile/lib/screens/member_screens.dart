import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:upendo_pamoja/backend.dart';
import 'package:upendo_pamoja/connect.dart';
import 'package:upendo_pamoja/domain.dart';
import 'package:upendo_pamoja/i18n.dart';
import 'package:upendo_pamoja/screens/connect_screens.dart';
import 'package:upendo_pamoja/screens/discover_screen.dart';
import 'package:upendo_pamoja/screens/edit_profile_screen.dart';
import 'package:upendo_pamoja/screens/profile_about_screens.dart';
import 'package:upendo_pamoja/app_lock.dart';
import 'package:upendo_pamoja/phone_alerts.dart';
import 'package:upendo_pamoja/screens/settings_pages.dart';

export 'connect_screens.dart' show MatchesScreen, MessagesScreen, ViewsScreen, MemberProfileScreen;

class MemberShell extends StatefulWidget {
  const MemberShell({super.key, required this.child});

  final Widget child;

  @override
  State<MemberShell> createState() => _MemberShellState();
}

class _MemberShellState extends State<MemberShell> with WidgetsBindingObserver {
  RealtimeChannel? _inbox;
  RealtimeChannel? _likes;
  IncomingMessage? _popup;
  Timer? _presence;
  Timer? _popupHide;
  int _likeCount = 0;
  int _messageCount = 0;
  int _viewCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    inboxChanged.addListener(_refreshCounts);
    _inbox = watchIncomingMessages((message) {
      _refreshCounts();
      if (!mounted || message.matchId == activeChatMatchId) return;
      if (ProfileDraft.mobileMessages || ProfileDraft.realtimeMessages) {
        PhoneAlerts.showMessage(matchId: message.matchId);
      }
      _showPopup(IncomingMessage(
        matchId: message.matchId,
        senderId: message.senderId,
        title: 'Wendo',
        body: 'You have an update.',
      ));
    });
    _likes = watchIncomingLikes((fromUserId) async {
      _refreshCounts();
      if (!mounted) return;
      if (ProfileDraft.mobileMatch) {
        PhoneAlerts.showLike(fromUserId: fromUserId);
      }
      _showPopup(IncomingMessage(
        matchId: '',
        senderId: fromUserId,
        title: 'Wendo',
        body: 'You have an update.',
      ));
    });
    _showWaitingMessage();
    _refreshCounts();
    profilePhotoChanged.addListener(_onProfilePhotoChanged);
    ensureOwnProfilePhoto();
    PhoneAlerts.requestPermission();
    registerDevicePushToken(platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android');
    if (supabase?.auth.currentUser != null) {
      markPresence(online: true);
      _presence = Timer.periodic(const Duration(seconds: 45), (_) {
        markPresence(online: true);
        discoverReload.value++;
        _refreshCounts();
        ensureOwnProfilePhoto();
      });
    }
  }

  void _onProfilePhotoChanged() {
    if (mounted) setState(() {});
  }

  void _showPopup(IncomingMessage message) {
    _popupHide?.cancel();
    setState(() => _popup = message);
    _popupHide = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      setState(() => _popup = null);
    });
  }

  @override
  void dispose() {
    _presence?.cancel();
    _popupHide?.cancel();
    profilePhotoChanged.removeListener(_onProfilePhotoChanged);
    inboxChanged.removeListener(_refreshCounts);
    WidgetsBinding.instance.removeObserver(this);
    final inbox = _inbox;
    if (inbox != null) supabase?.removeChannel(inbox);
    final likes = _likes;
    if (likes != null) supabase?.removeChannel(likes);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (supabase?.auth.currentUser == null) return;
    if (state == AppLifecycleState.resumed) {
      markPresence(online: true);
      discoverReload.value++;
      _showWaitingMessage();
      _refreshCounts();
      ensureOwnProfilePhoto();
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached || state == AppLifecycleState.hidden) {
      markPresence(online: false);
    }
  }

  Future<void> _refreshCounts() async {
    final counts = await loadInboxCounts();
    if (!mounted) return;
    setState(() {
      _likeCount = counts.likes;
      _messageCount = counts.messages;
      _viewCount = counts.views;
    });
  }

  Future<void> _showWaitingMessage() async {
    final message = await loadUnseenMessage();
    if (!mounted || message == null || message.matchId == activeChatMatchId) return;
    if (ProfileDraft.mobileMessages || ProfileDraft.realtimeMessages) {
      PhoneAlerts.showMessage(matchId: message.matchId);
    }
    _showPopup(IncomingMessage(
      matchId: message.matchId,
      senderId: message.senderId,
      title: 'Wendo',
      body: 'You have an update.',
    ));
  }

  int _barIndex(String location) {
    if (location.startsWith('/app/profile')) return 4;
    if (location.startsWith('/app/messages')) return 3;
    if (location.startsWith('/app/matches')) return 2;
    if (location.startsWith('/app/people')) return 0;
    if (location == '/app') return 0;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    final settings = location.startsWith('/app/settings');
    final edgeToEdge = settings ||
        location == '/app' ||
        location.startsWith('/app/discover') ||
        location.startsWith('/app/matches') ||
        location.startsWith('/app/people') ||
        location.startsWith('/app/messages') ||
        location.startsWith('/app/profile');
    final popup = _popup;
    final preview = popup == null
        ? ''
        : (popup.body.length > 120 ? '${popup.body.substring(0, 120)}…' : popup.body);
    return Scaffold(
      backgroundColor: const Color(0xFFF6F1E8),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: [
              Expanded(child: edgeToEdge ? widget.child : SafeArea(child: widget.child)),
              if (!settings)
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                    child: _MemberBar(
                      index: _barIndex(location),
                      likeCount: _likeCount,
                      messageCount: _messageCount,
                      viewCount: _viewCount,
                      onSelected: (value) {
                        const paths = ['/app', '/app/discover', '/app/matches', '/app/messages', '/app/profile'];
                        if (value == 0) discoverReload.value++;
                        context.go(paths[value]);
                      },
                    ),
                  ),
                ),
            ],
          ),
          if (popup != null)
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              left: 16,
              right: 16,
              child: Material(
                color: const Color(0xFF9C1B4E),
                borderRadius: BorderRadius.circular(18),
                elevation: 6,
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    final message = popup;
                    setState(() => _popup = null);
                    if (message.matchId.isEmpty) {
                      context.go('/app/matches');
                      return;
                    }
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute<void>(
                        builder: (context) => ChatPage(
                          matchId: message.matchId,
                          title: 'Message',
                          otherUserId: message.senderId,
                          photo: cachedProfilePhoto(message.senderId),
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_none, color: Color(0xFFFFFDF8)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                popup.title,
                                style: const TextStyle(color: Color(0xFFFFFDF8), fontWeight: FontWeight.w700, fontSize: 16),
                              ),
                              const SizedBox(height: 2),
                              Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFF6F1E8))),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _popup = null),
                          icon: const Icon(Icons.close, color: Color(0xFFFFFDF8)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MemberBar extends StatelessWidget {
  const _MemberBar({
    required this.index,
    required this.onSelected,
    this.likeCount = 0,
    this.messageCount = 0,
    this.viewCount = 0,
  });

  final int index;
  final int likeCount;
  final int messageCount;
  final int viewCount;
  final ValueChanged<int> onSelected;

  static const _ink = Color(0xFF1C1917);
  static const _mute = Color(0xFFA8A29E);
  static const _paper = Color(0xFFFFFDF8);
  static const _gold = Color(0xFFF06A4A);
  static const _clay = Color(0xFFE72570);

  @override
  Widget build(BuildContext context) {
    final userId = supabase?.auth.currentUser?.id;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(36),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: SizedBox(
        height: 62,
        child: Row(
          children: [
            Expanded(child: _icon(Icons.home_outlined, 0, selectedIcon: Icons.home)),
            Expanded(child: _icon(Icons.visibility_outlined, 1, badge: viewCount)),
            Expanded(child: _icon(Icons.favorite_border, 2, badge: likeCount)),
            Expanded(child: _icon(Icons.chat_bubble_outline, 3, badge: messageCount)),
            Expanded(
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => onSelected(4),
                child: Center(
                  child: ValueListenableBuilder<int>(
                    valueListenable: profilePhotoChanged,
                    builder: (context, _, child) {
                      final photo = ProfileDraft.photo ??
                          (userId == null ? null : cachedProfilePhoto(userId));
                      return CircleAvatar(
                        radius: 16,
                        backgroundColor: index == 4 ? _gold : _mute,
                        child: CircleAvatar(
                          radius: 14,
                          backgroundColor: const Color(0xFFE7DCCB),
                          backgroundImage: photo == null ? null : MemoryImage(photo),
                          child: photo == null ? const Icon(Icons.person, size: 16, color: _ink) : null,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _icon(IconData icon, int value, {IconData? selectedIcon, int badge = 0}) {
    final selected = index == value;
    final label = badge > 99 ? '99+' : '$badge';
    return IconButton(
      onPressed: () => onSelected(value),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      visualDensity: VisualDensity.compact,
      icon: Badge(
        isLabelVisible: badge > 0,
        backgroundColor: _clay,
        textColor: _paper,
        label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        child: Icon(selected ? (selectedIcon ?? icon) : icon, color: selected ? _clay : _mute, size: 26),
      ),
    );
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _clay = Color(0xFFE72570);
  static const _clayDeep = Color(0xFF9C1B4E);
  static const _cream = Color(0xFFF6F1E8);
  static const _paper = Color(0xFFFFFDF8);
  static const _ink = Color(0xFF1C1917);
  static const _inkSoft = Color(0xFF44403C);
  static const _mute = Color(0xFFA8A29E);

  @override
  void initState() {
    super.initState();
    loadOwnProfileDetails().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final storedName = supabase?.auth.currentUser?.userMetadata?['display_name'];
    final name = JoinDraft.displayName.trim().isNotEmpty
        ? JoinDraft.displayName.trim()
        : (storedName is String && storedName.trim().isNotEmpty ? storedName.trim() : 'Member');
    final width = MediaQuery.sizeOf(context).width;
    final top = MediaQuery.paddingOf(context).top;
    const titleHeight = 56.0;
    final avatarTop = top + titleHeight + 6;
    const avatarRadius = 50.0;
    final curveTop = avatarTop + 36;
    final stackHeight = avatarTop + (avatarRadius * 2) + 28;
    return ColoredBox(
      color: _cream,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          SizedBox(
            height: stackHeight,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Column(
                  children: [
                    Container(
                      height: curveTop + 8,
                      color: _clayDeep,
                      padding: EdgeInsets.only(top: top),
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        height: titleHeight,
                        child: Row(
                          children: [
                            const SizedBox(width: 48),
                            const Expanded(
                              child: Text(
                                'My Profile',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: _paper, fontSize: 20, fontWeight: FontWeight.w600),
                              ),
                            ),
                            IconButton(
                              onPressed: () => context.go('/app/settings'),
                              icon: const Icon(Icons.settings, color: _paper),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Expanded(child: ColoredBox(color: _cream)),
                  ],
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: curveTop,
                  child: Container(
                    height: 78,
                    decoration: BoxDecoration(
                      color: _cream,
                      borderRadius: BorderRadius.vertical(top: Radius.elliptical(width / 2, 52)),
                    ),
                  ),
                ),
                Positioned(
                  top: avatarTop,
                  child: const _ProfilePhotoButton(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: _ink),
                  ),
                ),
                if (ProfileDraft.photoVerified) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.verified, color: Color(0xFF3F5E52), size: 22),
                ],
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ID: ${_memberId(name)}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: _inkSoft),
          ),
          const SizedBox(height: 18),
          _row(context, Icons.person_outline, 'Edit profile & match criteria', const EditProfilePage(), fullScreen: true),
          InkWell(
            onTap: () => context.go('/app/more'),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              child: Row(
                children: [
                  Icon(Icons.menu, color: _inkSoft, size: 28),
                  SizedBox(width: 18),
                  Expanded(child: Text('More', style: TextStyle(fontSize: 17, color: _ink))),
                  Icon(Icons.chevron_right, color: _mute),
                ],
              ),
            ),
          ),
          _row(context, Icons.photo_camera_outlined, 'Photos', const PhotosPage(), fullScreen: true),
          _row(context, Icons.favorite_border, 'Hobbies & Interests', const HobbiesPage(), fullScreen: true),
          _row(context, Icons.psychology_outlined, 'Personality', const PersonalityPage(), fullScreen: true),
          _row(context, Icons.verified_user_outlined, 'Verify Photos', const VerifyPhotosPage(), fullScreen: true),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: DecoratedBox(
              decoration: BoxDecoration(color: _clay, borderRadius: BorderRadius.circular(22)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                child: Column(
                  children: [
                    const Icon(Icons.trending_up, color: _paper, size: 34),
                    const SizedBox(height: 8),
                    const Text(
                      'Your profile stays in your hands',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _paper, fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Essentials are free: your profile, messages with a mutual match, and reporting. Nothing here is ranked by health.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _paper, fontSize: 14, height: 1.35),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _paper,
                        foregroundColor: _clay,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () => context.go('/app/settings'),
                      child: const Text('Review privacy', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, IconData icon, String label, Widget page, {bool fullScreen = false}) {
    return InkWell(
      onTap: () async {
        await Navigator.of(context, rootNavigator: fullScreen).push(MaterialPageRoute(builder: (context) => page));
        if (mounted) setState(() {});
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: _inkSoft, size: 28),
            const SizedBox(width: 18),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 17, color: _ink))),
            const Icon(Icons.chevron_right, color: _mute),
          ],
        ),
      ),
    );
  }
}

class _ProfilePhotoButton extends StatefulWidget {
  const _ProfilePhotoButton();

  @override
  State<_ProfilePhotoButton> createState() => _ProfilePhotoButtonState();
}

class _ProfilePhotoButtonState extends State<_ProfilePhotoButton> {
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadStored();
  }

  Future<void> _loadStored() async {
    await ensureOwnProfilePhoto();
    if (mounted) setState(() {});
  }

  Future<void> _pick() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2048, imageQuality: 95);
    if (file == null) return;
    ProfileDraft.photo = await file.readAsBytes();
    notifyProfilePhotoChanged();
    if (!mounted) return;
    setState(() => _saving = true);
    try {
      await saveProfilePhoto();
    } catch (_) {}
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final userId = supabase?.auth.currentUser?.id;
    return ValueListenableBuilder<int>(
      valueListenable: profilePhotoChanged,
      builder: (context, _, child) {
        final photo = ProfileDraft.photo ?? (userId == null ? null : cachedProfilePhoto(userId));
        return GestureDetector(
          onTap: _saving ? null : _pick,
          child: CircleAvatar(
            radius: 54,
            backgroundColor: const Color(0xFFFFFDF8),
            child: CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFFE7DCCB),
              backgroundImage: photo == null ? null : MemoryImage(photo),
              child: photo == null ? const Icon(Icons.person, size: 52, color: Color(0xFF44403C)) : null,
            ),
          ),
        );
      },
    );
  }
}

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('More', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        for (final item in const [
          ('Meet safely', '/app/meet'),
          ('Learn', '/app/learn'),
          ('Support', '/app/support'),
          ('Settings', '/app/settings'),
          ('Back to welcome', '/'),
        ])
          ListTile(
            title: Text(item.$1),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.go(item.$2),
          ),
      ],
    );
  }
}

class MeetScreen extends StatefulWidget {
  const MeetScreen({super.key});

  @override
  State<MeetScreen> createState() => _MeetScreenState();
}

class _MeetScreenState extends State<MeetScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _place = TextEditingController();
  List<Map<String, dynamic>> _contacts = const [];
  List<Map<String, dynamic>> _checkins = const [];
  String? _message;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _place.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    final contacts = await loadTrustedContacts();
    final checkins = await loadMeetingCheckins();
    if (!mounted) return;
    setState(() {
      _contacts = contacts;
      _checkins = checkins;
    });
  }

  Future<void> _addContact() async {
    setState(() => _busy = true);
    final problem = await saveTrustedContact(name: _name.text, phone: _phone.text);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = problem ?? 'Trusted contact saved. Only you can see this.';
      if (problem == null) {
        _name.clear();
        _phone.clear();
      }
    });
    await _reload();
  }

  Future<void> _startCheckin() async {
    setState(() => _busy = true);
    final problem = await saveMeetingCheckin(placeNote: _place.text, plannedAt: DateTime.now(), status: 'started');
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = problem ?? 'Check-in started. Mark yourself safe when you are done.';
      if (problem == null) _place.clear();
    });
    await _reload();
  }

  Future<void> _openVideo() async {
    final userId = supabase?.auth.currentUser?.id ?? 'guest';
    final uri = Uri.parse(videoRoomUrlForUser(userId));
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Meet safely', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        const Text(
          'Meet first in a public place. Trusted contacts and check-ins stay private to you. Video calls are optional. If you are in immediate danger, contact local emergency services.',
          style: TextStyle(height: 1.4),
        ),
        const SizedBox(height: 24),
        const Text('Trusted contact', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
          controller: _name,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'Phone'),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _busy ? null : _addContact, child: const Text('Save trusted contact')),
        const SizedBox(height: 12),
        for (final contact in _contacts)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${contact['display_name']}'),
            subtitle: Text('${contact['phone']}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await deleteTrustedContact('${contact['id']}');
                await _reload();
              },
            ),
          ),
        const SizedBox(height: 24),
        const Text('Meeting check-in', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        TextField(
          controller: _place,
          decoration: const InputDecoration(labelText: 'Public place note (optional)'),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _busy ? null : _startCheckin, child: const Text('I am heading out')),
        const SizedBox(height: 12),
        for (final row in _checkins.take(5))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(row['place_note']?.toString().isNotEmpty == true ? '${row['place_note']}' : 'Check-in'),
            subtitle: Text('${row['status']}'),
            trailing: row['status'] == 'safe' || row['status'] == 'cancelled'
                ? null
                : TextButton(
                    onPressed: () async {
                      await updateMeetingCheckinStatus('${row['id']}', 'safe');
                      await _reload();
                    },
                    child: const Text('I am safe'),
                  ),
          ),
        const SizedBox(height: 24),
        const Text('Optional video call', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text(
          'Opens a private Jitsi room outside Wendo. Share the link only with someone you trust.',
          style: TextStyle(height: 1.4),
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: _openVideo, child: const Text('Open video room')),
        if (_message != null) ...[
          const SizedBox(height: 16),
          Text(_message!, style: const TextStyle(color: Color(0xFF9C1B4E))),
        ],
      ],
    );
  }
}

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _Page(
      title: 'Learn',
      body:
          'The World Health Organization explains that a person on antiretroviral therapy who maintains an undetectable viral load does not transmit HIV sexually. This app teaches that fact. It does not diagnose, certify a test, or replace a clinician.',
    );
  }
}

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  List<Map<String, dynamic>> _partners = const [];
  String? _message;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    loadPartnerResources().then((rows) {
      if (mounted) setState(() => _partners = rows);
    });
  }

  Future<void> _openUrl(String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _premium() async {
    setState(() => _busy = true);
    final problem = await registerPremiumInterest();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = problem ?? 'Interest saved. Billing is not live in this pilot.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Support', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        const Text(
          'Partner links open outside Wendo. A clinic should never hand over a patient list, and this app will not track clinic visits.',
          style: TextStyle(height: 1.4),
        ),
        const SizedBox(height: 20),
        if (_partners.isEmpty)
          const Text('Partner resources will appear here once loaded.')
        else
          for (final item in _partners)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFFFFDF8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD6D3D1)),
                ),
                child: ListTile(
                  title: Text('${item['title']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${item['summary']}', style: const TextStyle(height: 1.35)),
                  trailing: item['url'] == null ? null : const Icon(Icons.open_in_new),
                  onTap: item['url'] == null ? null : () => _openUrl('${item['url']}'),
                ),
              ),
            ),
        const SizedBox(height: 16),
        const Text('Wendo Plus interest', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        const Text(
          'Essentials stay free. Register interest for paid boosts later. No payment is taken here.',
          style: TextStyle(height: 1.4),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: _busy ? null : _premium, child: const Text('Register interest')),
        if (_message != null) ...[
          const SizedBox(height: 12),
          Text(_message!, style: const TextStyle(color: Color(0xFF9C1B4E))),
        ],
      ],
    );
  }
}

class UpgradeScreen extends StatefulWidget {
  const UpgradeScreen({super.key});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  @override
  Widget build(BuildContext context) {
    final complete = ProfileDraft.matchCriteriaComplete;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(t('upgrade'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: const Color(0xFF9C1B4E))),
        const SizedBox(height: 12),
        Text(t('plusInactive'), style: const TextStyle(height: 1.45, color: Color(0xFF44403C))),
        const SizedBox(height: 12),
        Text(t('lockedFilters'), style: const TextStyle(height: 1.45, color: Color(0xFF44403C))),
        const SizedBox(height: 16),
        const Text(
          'Match criteria (free unlock for Mutual and Reverse):',
          style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF1C1917)),
        ),
        const SizedBox(height: 8),
        Text(
          [
            '• City / area${ProfileDraft.city.trim().isNotEmpty ? ' ✓' : ''}',
            '• I am (gender)${(ProfileDraft.gender?.isNotEmpty ?? false) ? ' ✓' : ''}',
            '• I hope to meet${ProfileDraft.seekingGenders.isNotEmpty ? ' ✓' : ''}',
            '• Profile photo${ProfileDraft.photo != null ? ' ✓' : ''}',
          ].join('\n'),
          style: const TextStyle(height: 1.5, color: Color(0xFF44403C)),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: () => context.go('/app/profile'),
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE72570)),
          child: Text(complete ? 'Open profile' : t('completeProfile')),
        ),
      ],
    );
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const _clayDeep = Color(0xFF9C1B4E);
  static const _paper = Color(0xFFFFFDF8);
  static const _ink = Color(0xFF1C1917);
  static const _inkSoft = Color(0xFF44403C);
  static const _mute = Color(0xFFA8A29E);

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => page));
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: _paper,
      child: Column(
        children: [
          ColoredBox(
            color: _clayDeep,
            child: Padding(
              padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
              child: SizedBox(
                height: 56,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Text(
                      'Settings',
                      style: TextStyle(color: _paper, fontSize: 20, fontWeight: FontWeight.w600),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => context.go('/app/profile'),
                        icon: const Icon(Icons.arrow_back, color: _paper),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 24),
              children: [
                _settingsRow(Icons.mail_outline, 'Email address', const ChangeEmailPage()),
                _settingsRow(Icons.lock_outline, 'Password', const ChangePasswordPage()),
                _settingsRow(Icons.pin_outlined, 'PIN lock', const PinSettingsPage()),
                ListTile(
                  leading: const Icon(Icons.language, color: _ink),
                  title: Text(appLang.value == AppLang.sw ? t('english') : t('swahili'), style: const TextStyle(color: _ink, fontWeight: FontWeight.w600)),
                  subtitle: Text(appLang.value == AppLang.sw ? 'Kiswahili' : 'English', style: const TextStyle(color: _inkSoft)),
                  trailing: const Icon(Icons.chevron_right, color: _mute),
                  onTap: () async {
                    await setAppLang(appLang.value == AppLang.sw ? AppLang.en : AppLang.sw);
                    if (mounted) setState(() {});
                  },
                ),
                const Divider(height: 1),
                _settingsRow(Icons.shield_outlined, 'Privacy', const PrivacyChoices()),
                _settingsRow(Icons.policy_outlined, 'Privacy policy', const PrivacyPolicyPage()),
                _settingsRow(Icons.notifications_none, 'Notifications', const NotificationsPage()),
                _settingsRow(Icons.person_outline, 'Profile settings', const ProfileSettingsPage()),
                _settingsRow(Icons.workspace_premium_outlined, t('upgrade'), const UpgradeScreen()),
                _settingsRow(Icons.star_border, 'Favorites', const FavoritesPage()),
                _settingsRow(Icons.block, 'Block list', const BlocksPage()),
                _settingsRow(Icons.download_outlined, 'Export my data', const ExportDataPage()),
                _settingsRow(Icons.gavel_outlined, 'Moderation', const ModerationPage()),
                _settingsRow(Icons.help_outline, 'Help', const _AboutPage(
                  title: 'Help',
                  body: 'Meet first in a public place. If you are in immediate danger, contact local emergency services. This pilot does not promise a staffed 24/7 crisis line.',
                )),
                const SizedBox(height: 28),
                Center(
                  child: SizedBox(
                    width: 220,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: _ink,
                        foregroundColor: _paper,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: const StadiumBorder(),
                      ),
                      onPressed: () async {
                        clearMemberDraft();
                        AppLock.lockSession();
                        await markPresence(online: false);
                        await supabase?.auth.signOut();
                        if (context.mounted) context.go('/');
                      },
                      child: const Text('Logout', style: TextStyle(fontSize: 16)),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Center(
                  child: TextButton(
                    onPressed: () => setState(() => ProfileDraft.visible = !ProfileDraft.visible),
                    child: Text(
                      ProfileDraft.visible ? 'Switch off profile' : 'Switch on profile',
                      style: const TextStyle(
                        color: _ink,
                        fontSize: 16,
                        decoration: TextDecoration.underline,
                        decorationColor: _ink,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => _open(const DeleteAccountPage()),
                    child: const Text(
                      'Delete account',
                      style: TextStyle(color: Color(0xFF9C1B4E), fontSize: 16, decoration: TextDecoration.underline),
                    ),
                  ),
                ),
                const Center(child: Text('1.0.0', style: TextStyle(color: _mute, fontSize: 13))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingsRow(IconData icon, String label, Widget page) {
    return InkWell(
      onTap: () => _open(page),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Icon(icon, color: _inkSoft, size: 26),
            const SizedBox(width: 18),
            Expanded(child: Text(label, style: const TextStyle(fontSize: 17, color: _ink))),
            const Icon(Icons.chevron_right, color: _mute),
          ],
        ),
      ),
    );
  }
}

class PrivacyChoices extends StatefulWidget {
  const PrivacyChoices({super.key});

  @override
  State<PrivacyChoices> createState() => _PrivacyChoicesState();
}

class _PrivacyChoicesState extends State<PrivacyChoices> {
  String? _status;
  String _disclosure = 'never';
  bool _consent = false;
  bool _blur = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _blur = ProfileDraft.blurUntilMutual;
  }

  Future<void> _saveHealth() async {
    if (!_consent || _status == null) {
      setState(() => _message = 'Choose a status and give separate consent, or leave this unset.');
      return;
    }
    final client = supabase;
    final user = client?.auth.currentSession?.user;
    if (client == null || user == null) {
      setState(() => _message = 'Saved as your choice on this device. Connect Supabase before it is stored for your account.');
      return;
    }
    try {
      await client.from('health_profiles').upsert({
        'user_id': user.id,
        'self_described_status': _status,
        'disclosure_preference': _disclosure,
        'consent_version': consentVersion,
      });
      setState(() => _message = 'Saved privately. This does not appear on discovery.');
    } catch (error) {
      setState(() => _message = error.toString());
    }
  }

  Future<void> _saveBlur(bool value) async {
    setState(() => _blur = value);
    final problem = await saveBlurUntilMutual(value);
    if (!mounted) return;
    setState(() => _message = problem ?? (value ? 'Photos blur until you match.' : 'Photos show clearly before a match.'));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F1E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF9C1B4E),
        foregroundColor: const Color(0xFFFFFDF8),
        title: const Text('Privacy'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Optional HIV status is self-described, stored apart from your profile, and never used to rank people. Leave it unset if you prefer. The app will not infer a status.',
            style: TextStyle(fontSize: 16, height: 1.4),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: [
              for (final option in hivStatusOptions)
                DropdownMenuItem(value: option.id, child: Text(option.label)),
            ],
            onChanged: (value) => setState(() => _status = value),
          ),
          DropdownButtonFormField<String>(
            initialValue: _disclosure,
            decoration: const InputDecoration(labelText: 'Sharing'),
            items: [
              for (final option in disclosurePreferences)
                DropdownMenuItem(value: option.id, child: Text(option.label)),
            ],
            onChanged: (value) => setState(() => _disclosure = value ?? 'never'),
          ),
          CheckboxListTile(
            value: _consent,
            onChanged: (value) => setState(() => _consent = value ?? false),
            title: const Text('I consent to storing this optional health information separately from my profile.'),
          ),
          FilledButton(onPressed: _saveHealth, child: const Text('Save private status')),
          const SizedBox(height: 24),
          SwitchListTile(
            value: _blur,
            onChanged: _saveBlur,
            title: const Text('Blur photos until mutual match'),
            subtitle: const Text('Off by default for this pilot. Turn on to keep photos soft until both of you like each other.'),
          ),
          const SizedBox(height: 16),
          const Text(
            'Data in transit uses HTTPS. Account rows live in a private database with access limited to your signed-in session. Open Privacy policy for the full notice, or Delete account to erase this account.',
            style: TextStyle(height: 1.4),
          ),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!),
          ],
        ],
      ),
    );
  }
}

class ExportDataPage extends StatefulWidget {
  const ExportDataPage({super.key});

  @override
  State<ExportDataPage> createState() => _ExportDataPageState();
}

class _ExportDataPageState extends State<ExportDataPage> {
  String? _json;
  String? _message;
  bool _busy = false;

  Future<void> _export() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final data = await exportOwnAccount();
    if (!mounted) return;
    if (data == null) {
      setState(() {
        _busy = false;
        _message = 'Export could not run. Sign in and apply the latest migrations.';
      });
      return;
    }
    final encoded = const JsonEncoder.withIndent('  ').convert(data);
    setState(() {
      _busy = false;
      _json = encoded;
      _message = 'Copy below. Health and messages are included for your account only.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F1E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF9C1B4E),
        foregroundColor: const Color(0xFFFFFDF8),
        title: const Text('Export my data'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Download a JSON copy of your account data. This stays on your device after you copy it.',
            style: TextStyle(height: 1.4),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _export, child: Text(_busy ? 'Preparing…' : 'Prepare export')),
          if (_message != null) ...[
            const SizedBox(height: 12),
            Text(_message!),
          ],
          if (_json != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: _json!));
                if (!mounted) return;
                setState(() => _message = 'Copied to clipboard.');
              },
              child: const Text('Copy JSON'),
            ),
            const SizedBox(height: 12),
            SelectableText(_json!, style: const TextStyle(fontSize: 12, height: 1.35)),
          ],
        ],
      ),
    );
  }
}

class ModerationPage extends StatefulWidget {
  const ModerationPage({super.key});

  @override
  State<ModerationPage> createState() => _ModerationPageState();
}

class _ModerationPageState extends State<ModerationPage> {
  bool _staff = false;
  List<Map<String, dynamic>> _reports = const [];
  List<Map<String, dynamic>> _verifies = const [];
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final staff = await isStaffMember();
    final reports = staff ? await loadModerationQueue() : const <Map<String, dynamic>>[];
    final verifies = staff ? await loadPhotoVerifyQueue() : const <Map<String, dynamic>>[];
    if (!mounted) return;
    setState(() {
      _staff = staff;
      _reports = reports;
      _verifies = verifies;
      _message = staff ? null : 'Staff only. Ask an admin to add your user id to staff_roles.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F1E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF9C1B4E),
        foregroundColor: const Color(0xFFFFFDF8),
        title: const Text('Moderation'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (_message != null) Text(_message!),
          if (_staff) ...[
            const Text('Open reports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (_reports.isEmpty) const Text('No reports in the queue.'),
            for (final row in _reports)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${row['reported_name']} · ${row['reason']}'),
                subtitle: Text('${row['status']} · ${row['details'] ?? ''}'),
                trailing: PopupMenuButton<String>(
                  onSelected: (value) async {
                    await setReportStatus('${row['id']}', value);
                    await _load();
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'reviewing', child: Text('Reviewing')),
                    PopupMenuItem(value: 'closed', child: Text('Closed')),
                    PopupMenuItem(value: 'open', child: Text('Reopen')),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            const Text('Photo verify queue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (_verifies.isEmpty) const Text('No pending photo checks.'),
            for (final row in _verifies)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${row['display_name']}'),
                subtitle: Text('Requested ${row['requested_at']}'),
                trailing: TextButton(
                  onPressed: () async {
                    await approvePhotoVerify('${row['user_id']}');
                    await _load();
                  },
                  child: const Text('Approve'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AboutPage extends StatelessWidget {
  const _AboutPage({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F1E8),
      appBar: AppBar(
        backgroundColor: const Color(0xFF9C1B4E),
        foregroundColor: const Color(0xFFFFFDF8),
        title: Text(title),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(body, style: const TextStyle(fontSize: 16, height: 1.4, color: Color(0xFF1C1917))),
        ],
      ),
    );
  }
}

class _Page extends StatelessWidget {
  const _Page({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        Text(body),
      ],
    );
  }
}

String _memberId(String name) {
  var hash = 0;
  for (final unit in name.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return (100000 + (hash % 900000)).toString();
}
