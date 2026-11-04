import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:upendo_pamoja/backend.dart';
import 'package:upendo_pamoja/connect.dart';
import 'package:upendo_pamoja/domain.dart';
import 'package:upendo_pamoja/place_picker.dart';
import 'package:upendo_pamoja/places.dart';
import 'package:upendo_pamoja/privacy_media.dart';
import 'package:upendo_pamoja/screens/connect_screens.dart';
import 'package:upendo_pamoja/safety_actions.dart';

const _clay = Color(0xFFE72570);
const _cream = Color(0xFFF6F1E8);
const _paper = Color(0xFFFFFDF8);
const _ink = Color(0xFF1C1917);
const _inkSoft = Color(0xFF44403C);
const _line = Color(0xFFE7DCCB);
const _mute = Color(0xFFA8A29E);

enum DiscoverMode { forYou, online, newest, latestPhotos, inThisArea, mutual }

/// Home top surface: normal browse, or Video (see + tap to call).
enum HomeSurface { browse, video }

const _modeLabels = {
  DiscoverMode.forYou: 'For you',
  DiscoverMode.online: 'Online',
  DiscoverMode.newest: 'Newest',
  DiscoverMode.latestPhotos: 'Latest photos',
  DiscoverMode.inThisArea: 'In this area',
  DiscoverMode.mutual: 'Mutual matches',
};

const _chipModes = [
  DiscoverMode.forYou,
  DiscoverMode.online,
  DiscoverMode.newest,
  DiscoverMode.inThisArea,
];

/// Tapping the home icon asks the open Home screen to load profiles again.
final ValueNotifier<int> discoverReload = ValueNotifier<int>(0);

class DiscoverPerson {
  DiscoverPerson({
    required this.userId,
    required this.name,
    required this.age,
    required this.city,
    required this.presence,
    required this.intent,
    required this.intents,
    required this.photoPath,
    this.lastSeen,
    this.online = false,
    this.photoVerified = false,
  });

  final String userId;
  final String name;
  final int? age;
  final String city;
  final String presence;
  final String intent;
  final List<String> intents;
  String? photoPath;
  final DateTime? lastSeen;
  final bool online;
  final bool photoVerified;
  bool likedYou = false;
  Uint8List? photo;
}

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> with TickerProviderStateMixin {
  final Map<String, Uint8List> _photoBytes = {};
  DiscoverMode _mode = DiscoverMode.forYou;
  HomeSurface _surface = HomeSurface.browse;
  List<DiscoverPerson> _people = [];
  List<ReceivedLike> _likes = [];
  Set<String> _liked = {};
  Set<String> _likedYou = {};
  Set<String> _mutual = {};
  Set<String> _passed = {};
  Map<String, String> _matchIds = {};
  bool _loading = true;
  String? _note;
  int _page = 0;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
    discoverReload.addListener(_load);
    Future<void>.microtask(_load);
  }

  @override
  void dispose() {
    _pulse.dispose();
    discoverReload.removeListener(_load);
    super.dispose();
  }

  List<DiscoverPerson> get _videoPeople {
    final list = [..._visible];
    list.sort((a, b) {
      final am = _mutual.contains(a.userId) ? 0 : 1;
      final bm = _mutual.contains(b.userId) ? 0 : 1;
      if (am != bm) return am.compareTo(bm);
      final ao = a.online ? 0 : 1;
      final bo = b.online ? 0 : 1;
      if (ao != bo) return ao.compareTo(bo);
      return a.name.compareTo(b.name);
    });
    return list;
  }

  Future<void> _load() async {
    final client = supabase;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      setState(() {
        _loading = false;
        _people = [];
        _note = null;
      });
      return;
    }
    try {
      try {
        await ensureDiscoverableProfile();
      } catch (_) {}
      List<DiscoverPerson> fromCards = [];
      try {
        fromCards = _peopleFrom(await client.rpc('discovery_cards'));
      } catch (_) {}
      List<DiscoverPerson> people;
      try {
        people = await _loadFinishedProfiles(client, user.id);
      } catch (_) {
        people = fromCards;
      }
      if (people.isEmpty) people = fromCards;
      final cardsById = {for (final person in fromCards) person.userId: person};
      people = [
        for (final person in people)
          DiscoverPerson(
            userId: person.userId,
            name: person.name,
            age: cardsById[person.userId]?.age ?? person.age,
            city: person.city,
            presence: person.presence.isNotEmpty ? person.presence : (cardsById[person.userId]?.presence ?? ''),
            intent: person.intent,
            intents: person.intents.isNotEmpty ? person.intents : (cardsById[person.userId]?.intents ?? const []),
            photoPath: cardsById[person.userId]?.photoPath ?? person.photoPath,
            lastSeen: person.lastSeen ?? cardsById[person.userId]?.lastSeen,
            online: person.online || (cardsById[person.userId]?.online ?? false),
            photoVerified: person.photoVerified || (cardsById[person.userId]?.photoVerified ?? false),
          ),
      ];
      final liked = <String>{};
      final likedYou = <String>{};
      final mutual = <String>{};
      final matchIds = <String, String>{};
      final passed = await loadPassedIds();
      people = [for (final person in people) if (!passed.contains(person.userId)) person];
      try {
        final likes = await client.from('likes').select('to_user').eq('from_user', user.id);
        for (final row in likes) {
          if (row['to_user'] is String) liked.add(row['to_user'] as String);
        }
        final received = await client.from('likes').select('from_user').eq('to_user', user.id);
        for (final row in received) {
          if (row['from_user'] is String) likedYou.add(row['from_user'] as String);
        }
        List<dynamic> matchRows = [];
        try {
          matchRows = await client.from('matches').select('id, user_a, user_b, is_mutual').isFilter('unmatched_at', null);
        } catch (_) {
          matchRows = await client.from('matches').select('id, user_a, user_b').isFilter('unmatched_at', null);
        }
        for (final row in matchRows) {
          final a = row['user_a'];
          final b = row['user_b'];
          final id = row['id'];
          if (id is! String) continue;
          String? other;
          if (a == user.id && b is String) other = b;
          if (b == user.id && a is String) other = a;
          if (other == null) continue;
          matchIds[other] = id;
          if (row['is_mutual'] == true) mutual.add(other);
        }
      } catch (_) {}
      if (!mounted) return;
      for (final person in people) {
        person.likedYou = likedYou.contains(person.userId);
        if (liked.contains(person.userId) && person.likedYou) mutual.add(person.userId);
        person.photoPath = (person.photoPath != null && person.photoPath!.isNotEmpty)
            ? person.photoPath
            : '${person.userId}/profile.jpg';
        person.photo = cachedProfilePhoto(person.userId) ?? _photoBytes[person.userId];
      }
      setState(() {
        _people = people;
        _liked = liked;
        _likedYou = likedYou;
        _mutual = mutual;
        _passed = passed;
        _matchIds = matchIds;
        _loading = false;
        _note = null;
        _page = 0;
      });
      await Future.wait([
        _fillPhotos(people),
        _loadLikes(),
      ]);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _note = null;
      });
    }
  }

  Future<void> _fillPhotos(List<DiscoverPerson> people) async {
    final paths = <String, String>{
      for (final person in people)
        person.userId: (person.photoPath != null && person.photoPath!.isNotEmpty)
            ? person.photoPath!
            : '${person.userId}/profile.jpg',
    };
    await loadProfilePhotos(people.map((person) => person.userId), paths: paths);
    if (!mounted) return;
    var changed = false;
    for (final person in people) {
      final bytes = cachedProfilePhoto(person.userId);
      if (bytes == null) continue;
      _photoBytes[person.userId] = bytes;
      person.photo = bytes;
      changed = true;
    }
    if (changed) setState(() {});
    final storedPaths = await loadProfilePhotoPaths();
    if (!mounted || storedPaths.isEmpty) return;
    final missing = [
      for (final person in people)
        if (cachedProfilePhoto(person.userId) == null) person.userId,
    ];
    if (missing.isEmpty) return;
    await loadProfilePhotos(missing, paths: storedPaths);
    if (!mounted) return;
    for (final person in people) {
      final bytes = cachedProfilePhoto(person.userId);
      if (bytes == null) continue;
      _photoBytes[person.userId] = bytes;
      person.photo = bytes;
    }
    setState(() {});
  }

  Future<void> _loadLikes() async {
    try {
      final likes = await loadReceivedLikes();
      if (!mounted) return;
      setState(() => _likes = likes);
      await loadProfilePhotos(likes.map((like) => like.userId));
      if (!mounted) return;
      for (final like in likes) {
        like.photo = cachedProfilePhoto(like.userId);
      }
      setState(() {});
    } catch (_) {}
  }

  List<DiscoverPerson> _peopleFrom(dynamic rows) {
    final people = <DiscoverPerson>[];
    if (rows is List) {
      for (final row in rows) {
        if (row is Map) people.add(_personFrom(row));
      }
    }
    return people;
  }

  Future<List<DiscoverPerson>> _loadFinishedProfiles(dynamic client, String userId) async {
    const detailed = 'user_id, display_name, city, relationship_intent, relationship_intents, presence';
    try {
      final rows = await client
          .from('profiles')
          .select('$detailed, is_online, last_seen_at, photo_verified_at')
          .neq('user_id', userId)
          .eq('onboarding_completed', true)
          .eq('account_paused', false);
      return _peopleFrom(rows);
    } catch (_) {}
    try {
      final rows = await client
          .from('profiles')
          .select('$detailed, is_online, last_seen_at')
          .neq('user_id', userId)
          .eq('onboarding_completed', true)
          .eq('account_paused', false);
      return _peopleFrom(rows);
    } catch (_) {}
    try {
      final rows = await client
          .from('profiles')
          .select(detailed)
          .neq('user_id', userId)
          .eq('onboarding_completed', true)
          .eq('account_paused', false);
      return _peopleFrom(rows);
    } catch (_) {
      final rows = await client
          .from('profiles')
          .select('user_id, display_name, city, relationship_intent')
          .neq('user_id', userId)
          .eq('onboarding_completed', true)
          .eq('account_paused', false);
      return _peopleFrom(rows);
    }
  }

  DiscoverPerson _personFrom(Map row) {
    final intents = <String>[];
    final rawIntents = row['relationship_intents'];
    if (rawIntents is List) {
      for (final item in rawIntents) {
        if (item is String) intents.add(item);
      }
    }
    final age = row['age_years'];
    final photo = row['photo_path'];
    final seen = row['last_seen_at'];
    final verifiedAt = row['photo_verified_at'];
    return DiscoverPerson(
      userId: '${row['user_id']}',
      name: (row['display_name'] as String?)?.trim().isNotEmpty == true ? row['display_name'] as String : 'Member',
      age: age is int ? age : (age is num ? age.toInt() : null),
      city: (row['city'] as String?) ?? '',
      presence: (row['presence'] as String?) ?? '',
      intent: (row['relationship_intent'] as String?) ?? '',
      intents: intents,
      photoPath: photo is String ? photo : null,
      lastSeen: seen is String ? DateTime.tryParse(seen) : null,
      online: row['is_online'] == true,
      photoVerified: row['photo_verified'] == true || verifiedAt != null,
    );
  }

  List<DiscoverPerson> get _visible {
    final city = ProfileDraft.city.trim().toLowerCase();
    final list = _people.where((person) {
      if (_passed.contains(person.userId)) return false;
      if (_mode == DiscoverMode.online && lastSeenLabel(lastSeen: person.lastSeen, online: person.online) != 'Online') {
        return false;
      }
      if (_mode == DiscoverMode.inThisArea && city.isNotEmpty && !person.city.toLowerCase().contains(city)) {
        return false;
      }
      if (_mode == DiscoverMode.mutual && !_mutual.contains(person.userId)) return false;
      if (person.age != null && (person.age! < ProfileDraft.ageFrom || person.age! > ProfileDraft.ageTo)) {
        return false;
      }
      return true;
    }).toList();
    if (_mode == DiscoverMode.latestPhotos) {
      list.sort((a, b) {
        if (a.photoPath != null && b.photoPath == null) return -1;
        if (a.photoPath == null && b.photoPath != null) return 1;
        return 0;
      });
    }
    return list;
  }

  Future<void> _openWeb() async {
    final opened = await launchUrl(Uri.parse(webAppUrl), mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('The website could not be opened from this phone.')),
      );
    }
  }

  Future<void> _openPreferences({bool focusAge = false}) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _PreferencesSheet(
          mode: _mode,
          focusAge: focusAge,
          onApply: (mode, ageFrom, ageTo, reach, intentId) {
            setState(() {
              _mode = mode;
              ProfileDraft.ageFrom = ageFrom;
              ProfileDraft.ageTo = ageTo;
              ProfileDraft.reach = reach;
              ProfileDraft.chosenIntentIds = [intentId];
              JoinDraft.relationshipIntent = intentId;
              _page = 0;
            });
            _savePreferences();
          },
        );
      },
    );
  }

  Future<void> _savePreferences() async {
    final client = supabase;
    final user = client?.auth.currentUser;
    if (client == null || user == null) return;
    try {
      await client.from('profiles').update({
        'age_preference_min': ProfileDraft.ageFrom,
        'age_preference_max': ProfileDraft.ageTo,
        'connection_reach': ProfileDraft.reach,
        'city': ProfileDraft.city,
        'home_country': ProfileDraft.country,
        'home_region': ProfileDraft.region,
        'home_area': ProfileDraft.city,
        'pref_country': ProfileDraft.country,
        'pref_region': ProfileDraft.region,
        'pref_city': ProfileDraft.city,
      }).eq('user_id', user.id);
    } catch (_) {}
  }

  Future<void> _like(DiscoverPerson person) async {
    final client = supabase;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      _say('Sign in before you like someone.');
      return;
    }
    if (_liked.contains(person.userId)) return;
    setState(() => _liked.add(person.userId));
    try {
      await client.from('likes').insert({'from_user': user.id, 'to_user': person.userId});
      final first = user.id.compareTo(person.userId) < 0 ? user.id : person.userId;
      final second = user.id.compareTo(person.userId) < 0 ? person.userId : user.id;
      Map<String, dynamic>? mutual;
      try {
        mutual = await client
            .from('matches')
            .select('id, is_mutual')
            .eq('user_a', first)
            .eq('user_b', second)
            .isFilter('unmatched_at', null)
            .maybeSingle();
      } catch (_) {
        mutual = await client
            .from('matches')
            .select('id')
            .eq('user_a', first)
            .eq('user_b', second)
            .isFilter('unmatched_at', null)
            .maybeSingle();
      }
      final bothLiked = _likedYou.contains(person.userId) || mutual?['is_mutual'] == true;
      if (mounted) {
        setState(() {
          if (bothLiked) _mutual.add(person.userId);
          final matchId = mutual?['id'];
          if (matchId is String) _matchIds[person.userId] = matchId;
        });
      }
      _say(
        bothLiked
            ? 'You both chose each other. Photos clear, and chat stays open.'
            : 'Your like was saved. They can see it.',
      );
    } catch (_) {
      if (mounted) setState(() => _liked.remove(person.userId));
      _say('The like could not be saved just now.');
    }
  }

  Future<void> _pass(DiscoverPerson person) async {
    final client = supabase;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      _say('Sign in before you pass.');
      return;
    }
    setState(() {
      _passed.add(person.userId);
      _people.removeWhere((item) => item.userId == person.userId);
    });
    final problem = await passPerson(person.userId);
    if (!mounted) return;
    if (problem != null) {
      setState(() => _passed.remove(person.userId));
      _say(problem);
      return;
    }
    _say('Passed. They will not show on Home for you.');
  }

  Future<void> _report(DiscoverPerson person) async {
    final sent = await showReportPersonSheet(context, otherUserId: person.userId, otherName: person.name);
    if (!mounted || !sent) return;
    _say('Report received. Thank you.');
  }

  Future<void> _message(DiscoverPerson person) async {
    final client = supabase;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      _say('Sign in to send a message. They can read it when they return.');
      return;
    }
    try {
      final matchId = await openConversation(person.userId);
      if (!mounted || matchId == null) {
        _say('The conversation could not be opened just now.');
        return;
      }
      final mutual = _mutual.contains(person.userId);
      setState(() => _matchIds[person.userId] = matchId);
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (context) => ChatPage(
            matchId: matchId,
            title: person.name,
            otherUserId: person.userId,
            photo: person.photo ?? cachedProfilePhoto(person.userId),
            lastSeen: person.lastSeen,
            online: person.online,
            mutual: mutual,
            photoVerified: person.photoVerified,
          ),
        ),
      );
    } catch (_) {
      _say('The conversation could not be opened just now. They do not need to be in the app.');
    }
  }

  /// Home Video: open shared room + post invite in the conversation.
  Future<void> _videoCall(DiscoverPerson person) async {
    final client = supabase;
    final user = client?.auth.currentUser;
    if (client == null || user == null) {
      _say('Sign in before starting a video call.');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Video with ${person.name}?'),
        content: const Text(
          'Optional video opens a private room outside Wendo. A join link is sent in chat so you both use the same room. Camera and mic are set in the browser.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Call')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      var matchId = _matchIds[person.userId];
      matchId ??= await openConversation(person.userId);
      if (!mounted || matchId == null) {
        _say('The conversation could not be opened for video.');
        return;
      }
      setState(() => _matchIds[person.userId] = matchId!);
      final url = videoRoomUrlForMatch(matchId);
      await sendMessage(matchId, 'Video call invite: $url', otherUserId: person.userId);
      final opened = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!opened && mounted) _say('Could not open the video room. Check your browser.');
    } catch (_) {
      _say('Video could not start just now.');
    }
  }

  void _say(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _openProfile(DiscoverPerson person) {
    final people = [..._visible];
    var index = people.indexWhere((item) => item.userId == person.userId);
    if (index < 0) {
      people.insert(0, person);
      index = 0;
    }
    recordProfileView(person.userId);
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (context) => _ProfileFeedPage(
          people: people,
          initialIndex: index,
          likes: _likes,
          liked: _liked,
          mutual: _mutual,
          onLike: _like,
          onPass: _pass,
          onReport: _report,
          onMessage: _message,
          onOpenLike: (like) => _personFromLike(like),
        ),
      ),
    ).then((_) {
      if (mounted) setState(() {});
    });
  }

  DiscoverPerson _personFromLike(ReceivedLike like) {
    for (final person in _people) {
      if (person.userId == like.userId) return person;
    }
    return DiscoverPerson(
      userId: like.userId,
      name: like.name,
      age: null,
      city: like.city,
      presence: '',
      intent: '',
      intents: const [],
      photoPath: '${like.userId}/profile.jpg',
    )
      ..photo = like.photo ?? cachedProfilePhoto(like.userId)
      ..likedYou = true;
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final people = _visible;
    final videoPeople = _videoPeople;
    final videoMode = _surface == HomeSurface.video;
    return ColoredBox(
      color: _cream,
      child: ListView(
        padding: EdgeInsets.only(top: top + 8, bottom: 12),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.favorite, color: _clay, size: 28),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Wendo',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ),
                _RoundButton(icon: Icons.public, tooltip: 'Open the website', onPressed: _openWeb),
                const SizedBox(width: 8),
                _RoundButton(icon: Icons.tune, tooltip: 'Matching preferences', onPressed: _openPreferences),
              ],
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 88,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _HomeFeatureTile(
                  label: 'Video',
                  subtitle: 'Tap to call',
                  icon: Icons.videocam_rounded,
                  selected: videoMode,
                  accent: const Color(0xFF3F5E52),
                  onTap: () => setState(() => _surface = HomeSurface.video),
                ),
                const SizedBox(width: 10),
                _HomeFeatureTile(
                  label: 'Matches',
                  subtitle: 'Browse',
                  icon: Icons.favorite_rounded,
                  selected: !videoMode,
                  accent: _clay,
                  onTap: () => setState(() => _surface = HomeSurface.browse),
                ),
                const SizedBox(width: 10),
                _HomeFeatureTile(
                  label: 'Online',
                  subtitle: 'Active now',
                  icon: Icons.circle,
                  selected: !videoMode && _mode == DiscoverMode.online,
                  accent: const Color(0xFF9C1B4E),
                  onTap: () => setState(() {
                    _surface = HomeSurface.browse;
                    _mode = DiscoverMode.online;
                    _page = 0;
                  }),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: videoMode
                ? KeyedSubtree(
                    key: const ValueKey('video-surface'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                          child: Text(
                            'Video',
                            style: TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Text(
                            _loading
                                ? 'Loading people…'
                                : videoPeople.isEmpty
                                    ? 'No one to call yet. Finish profiles and likes first.'
                                    : 'See someone, then tap Call. Mutual matches appear first. Video stays optional.',
                            style: const TextStyle(color: _inkSoft, fontSize: 14, height: 1.35),
                          ),
                        ),
                        if (_loading)
                          const Padding(
                            padding: EdgeInsets.all(32),
                            child: Center(child: CircularProgressIndicator(color: _clay)),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: videoPeople.length,
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                mainAxisSpacing: 10,
                                crossAxisSpacing: 10,
                                childAspectRatio: 0.72,
                              ),
                              itemBuilder: (context, index) {
                                final person = videoPeople[index];
                                return _VideoCallCard(
                                  person: person,
                                  revealed: _mutual.contains(person.userId),
                                  mutual: _mutual.contains(person.userId),
                                  pulse: _pulse,
                                  onOpen: () => _openProfile(person),
                                  onCall: () => _videoCall(person),
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  )
                : KeyedSubtree(
                    key: const ValueKey('browse-surface'),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 40,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _chipModes.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final mode = _chipModes[index];
                              return _SortChip(
                                label: _modeLabels[mode]!,
                                selected: _mode == mode,
                                onTap: () => setState(() {
                                  _mode = mode;
                                  _page = 0;
                                }),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 10),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                          child: Material(
                            color: _paper,
                            borderRadius: BorderRadius.circular(18),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => _openPreferences(focusAge: true),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                                child: Row(
                                  children: [
                                    const Icon(Icons.cake_outlined, color: _clay),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Age range', style: TextStyle(color: _inkSoft, fontSize: 13, fontWeight: FontWeight.w600)),
                                          Text(
                                            '${ProfileDraft.ageFrom} – ${ProfileDraft.ageTo} years',
                                            style: const TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w700),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const Icon(Icons.tune, color: _clay),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 42,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Row(
                              children: [
                                _FilterChip(label: ProfileDraft.language ?? 'Language', onTap: _openPreferences),
                                const SizedBox(width: 8),
                                _FilterChip(label: ProfileDraft.howToMeet ?? 'Meet', onTap: _openPreferences),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_likes.isNotEmpty) ...[
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 6, 16, 10),
                            child: Text(
                              'People who liked you',
                              style: TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w700),
                            ),
                          ),
                          SizedBox(
                            height: 74,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: _likes.length,
                              separatorBuilder: (context, index) => const SizedBox(width: 10),
                              itemBuilder: (context, index) {
                                final like = _likes[index];
                                return _LikeAvatar(
                                  photo: like.photo ?? cachedProfilePhoto(like.userId),
                                  revealed: _mutual.contains(like.userId),
                                  onTap: () => _openProfile(_personFromLike(like)),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        for (var i = 0; i < people.length; i++)
                          _ProfileRow(
                            person: people[i],
                            revealed: _mutual.contains(people[i].userId),
                            onOpen: () => _openProfile(people[i]),
                            onHi: () => _message(people[i]),
                            onVideo: () => _videoCall(people[i]),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

String _intentLabelFor(String intentId) {
  for (final option in relationshipIntents) {
    if (option.id == intentId) return option.label;
  }
  return intentId;
}

class _ProfileFeedPage extends StatefulWidget {
  const _ProfileFeedPage({
    required this.people,
    required this.initialIndex,
    required this.likes,
    required this.liked,
    required this.mutual,
    required this.onLike,
    required this.onPass,
    required this.onReport,
    required this.onMessage,
    required this.onOpenLike,
  });

  final List<DiscoverPerson> people;
  final int initialIndex;
  final List<ReceivedLike> likes;
  final Set<String> liked;
  final Set<String> mutual;
  final ValueChanged<DiscoverPerson> onLike;
  final ValueChanged<DiscoverPerson> onPass;
  final ValueChanged<DiscoverPerson> onReport;
  final ValueChanged<DiscoverPerson> onMessage;
  final DiscoverPerson Function(ReceivedLike like) onOpenLike;

  @override
  State<_ProfileFeedPage> createState() => _ProfileFeedPageState();
}

class _ProfileFeedPageState extends State<_ProfileFeedPage> {
  late final PageController _controller;
  late int _page;

  @override
  void initState() {
    super.initState();
    _page = widget.initialIndex.clamp(0, widget.people.isEmpty ? 0 : widget.people.length - 1);
    _controller = PageController(initialPage: _page, viewportFraction: 0.92);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _jumpTo(DiscoverPerson person) {
    final index = widget.people.indexWhere((item) => item.userId == person.userId);
    if (index < 0) return;
    _controller.animateToPage(index, duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: _cream,
      body: Column(
        children: [
          SizedBox(height: top + 4),
          SizedBox(
            height: 72,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: _ink),
                ),
                Expanded(
                  child: widget.likes.isEmpty
                      ? const SizedBox.shrink()
                      : ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.only(right: 16),
                          itemCount: widget.likes.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 10),
                          itemBuilder: (context, index) {
                            final like = widget.likes[index];
                            return _LikeAvatar(
                              photo: like.photo ?? cachedProfilePhoto(like.userId),
                              revealed: widget.mutual.contains(like.userId),
                              onTap: () => _jumpTo(widget.onOpenLike(like)),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          Expanded(
            child: PageView.builder(
              controller: _controller,
              scrollDirection: Axis.vertical,
              itemCount: widget.people.length,
              onPageChanged: (value) {
                _page = value;
                if (value >= 0 && value < widget.people.length) {
                  recordProfileView(widget.people[value].userId);
                }
              },
              itemBuilder: (context, index) {
                final person = widget.people[index];
                return Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
                  child: _ProfileCard(
                    loading: false,
                    note: null,
                    people: [person],
                    page: 0,
                    liked: widget.liked,
                    revealed: widget.mutual.contains(person.userId),
                    tall: true,
                    onPage: (_) {},
                    onLike: (item) {
                      widget.onLike(item);
                      setState(() {});
                    },
                    onPass: (item) {
                      widget.onPass(item);
                      if (context.mounted) Navigator.of(context).pop();
                    },
                    onReport: widget.onReport,
                    onMessage: widget.onMessage,
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

class _HomeFeatureTile extends StatefulWidget {
  const _HomeFeatureTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_HomeFeatureTile> createState() => _HomeFeatureTileState();
}

class _HomeFeatureTileState extends State<_HomeFeatureTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final selected = widget.selected;
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 128,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: selected ? widget.accent : _paper,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: selected ? widget.accent : _line),
            boxShadow: const [
              BoxShadow(color: Color(0x14000000), blurRadius: 8, offset: Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(widget.icon, color: selected ? _paper : widget.accent, size: 22),
              const Spacer(),
              Text(
                widget.label,
                style: TextStyle(color: selected ? _paper : _ink, fontSize: 16, fontWeight: FontWeight.w800),
              ),
              Text(
                widget.subtitle,
                style: TextStyle(
                  color: selected ? _paper.withValues(alpha: 0.85) : _inkSoft,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VideoCallCard extends StatelessWidget {
  const _VideoCallCard({
    required this.person,
    required this.revealed,
    required this.mutual,
    required this.pulse,
    required this.onOpen,
    required this.onCall,
  });

  final DiscoverPerson person;
  final bool revealed;
  final bool mutual;
  final Animation<double> pulse;
  final VoidCallback onOpen;
  final VoidCallback onCall;

  @override
  Widget build(BuildContext context) {
    final presence = lastSeenLabel(lastSeen: person.lastSeen, online: person.online);
    return Material(
      color: _paper,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  PrivacyPhoto(
                    bytes: person.photo,
                    revealed: revealed,
                    placeholder: const ColoredBox(
                      color: _line,
                      child: Icon(Icons.person, color: _inkSoft, size: 40),
                    ),
                  ),
                  if (person.online || presence == 'Online')
                    const Positioned(
                      top: 8,
                      right: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Color(0xFF3F5E52),
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text('Online', style: TextStyle(color: _paper, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  if (mutual)
                    const Positioned(
                      top: 8,
                      left: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: _clay,
                          borderRadius: BorderRadius.all(Radius.circular(20)),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text('Match', style: TextStyle(color: _paper, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                      ),
                    ),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: AnimatedBuilder(
                      animation: pulse,
                      builder: (context, child) {
                        final t = 0.92 + (pulse.value * 0.08);
                        return Transform.scale(scale: t, child: child);
                      },
                      child: Material(
                        color: _clay,
                        shape: const CircleBorder(),
                        elevation: 3,
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: onCall,
                          child: const SizedBox(
                            width: 48,
                            height: 48,
                            child: Icon(Icons.videocam_rounded, color: _paper),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _ink, fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    [
                      if (person.age != null) '${person.age}',
                      if (person.city.isNotEmpty) person.city,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _inkSoft, fontSize: 12),
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

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.person,
    required this.revealed,
    required this.onOpen,
    required this.onHi,
    this.onVideo,
  });

  final DiscoverPerson person;
  final bool revealed;
  final VoidCallback onOpen;
  final VoidCallback onHi;
  final VoidCallback? onVideo;

  @override
  Widget build(BuildContext context) {
    final online = lastSeenLabel(lastSeen: person.lastSeen, online: person.online) == 'Online';
    final meta = <String>[
      if (person.city.isNotEmpty) person.city,
      if (person.intent.isNotEmpty) _intentLabelFor(person.intent),
      if (person.likedYou) 'Liked you',
    ].join(' · ');
    return Material(
      color: _cream,
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: PrivacyPhoto(
                        bytes: person.photo,
                        revealed: revealed,
                        placeholder: const ColoredBox(
                          color: _line,
                          child: Icon(Icons.person, color: _inkSoft, size: 32),
                        ),
                      ),
                    ),
                  ),
                  if (online)
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF3F5E52),
                          shape: BoxShape.circle,
                          border: Border.all(color: _cream, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    if (person.age != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${person.age} years old',
                          style: const TextStyle(color: _inkSoft, fontSize: 14),
                        ),
                      ),
                    if (meta.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: person.likedYou ? _clay : _mute,
                            fontSize: 13,
                            fontWeight: person.likedYou ? FontWeight.w600 : FontWeight.w400,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (onVideo != null) ...[
                          IconButton(
                            tooltip: 'Video call',
                            onPressed: onVideo,
                            icon: const Icon(Icons.videocam_outlined, color: _clay),
                            visualDensity: VisualDensity.compact,
                          ),
                          const SizedBox(width: 2),
                        ],
                        OutlinedButton(
                          onPressed: onHi,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _clay,
                            side: const BorderSide(color: _clay, width: 1.4),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            shape: const StadiumBorder(),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.favorite, size: 16),
                              SizedBox(width: 4),
                              Text('Hi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LikeAvatar extends StatelessWidget {
  const _LikeAvatar({required this.photo, required this.revealed, required this.onTap});

  final Uint8List? photo;
  final bool revealed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: 62,
        height: 62,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _paper, width: 3),
          ),
          child: ClipOval(
            child: PrivacyPhoto(
              bytes: photo,
              revealed: revealed,
              placeholder: const ColoredBox(
                color: _line,
                child: Icon(Icons.person, color: _inkSoft, size: 28),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.loading,
    required this.note,
    required this.people,
    required this.page,
    required this.liked,
    required this.onPage,
    required this.onLike,
    required this.onMessage,
    this.onPass,
    this.onReport,
    this.revealed = false,
    this.tall = false,
  });

  final bool loading;
  final String? note;
  final List<DiscoverPerson> people;
  final int page;
  final Set<String> liked;
  final bool revealed;
  final bool tall;
  final ValueChanged<int> onPage;
  final ValueChanged<DiscoverPerson> onLike;
  final ValueChanged<DiscoverPerson> onMessage;
  final ValueChanged<DiscoverPerson>? onPass;
  final ValueChanged<DiscoverPerson>? onReport;

  @override
  Widget build(BuildContext context) {
    final person = people.isEmpty ? null : people[page];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: tall
                  ? (MediaQuery.sizeOf(context).height * 0.48).clamp(240.0, 480.0)
                  : (MediaQuery.sizeOf(context).height * 0.38).clamp(220.0, 360.0),
              child: person == null
                  ? const SizedBox.shrink()
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        PrivacyPhoto(
                          bytes: person.photo,
                          revealed: revealed,
                          placeholder: const ColoredBox(
                            color: Color(0xFFE7DCCB),
                            child: Icon(Icons.person, size: 96, color: _inkSoft),
                          ),
                        ),
                        if (onReport != null)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              tooltip: 'Report',
                              onPressed: () => onReport!(person),
                              icon: const Icon(Icons.flag_outlined, color: _paper),
                            ),
                          ),
                        if (people.length > 1)
                          Positioned(
                            top: 12,
                            left: 24,
                            right: 24,
                            child: Row(
                              children: [
                                for (var i = 0; i < people.length && i < 8; i++)
                                  Expanded(
                                    child: Container(
                                      height: 4,
                                      margin: const EdgeInsets.symmetric(horizontal: 3),
                                      decoration: BoxDecoration(
                                        color: i == page ? _paper : const Color(0x66FFFDF8),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        Positioned(
                          right: 14,
                          bottom: 14,
                          child: Row(
                            children: [
                              if (onPass != null) ...[
                                _RoundButton(
                                  icon: Icons.close,
                                  tooltip: 'Pass',
                                  onPressed: () => onPass!(person),
                                ),
                                const SizedBox(width: 10),
                              ],
                              _RoundButton(
                                icon: liked.contains(person.userId) ? Icons.favorite : Icons.favorite_border,
                                tooltip: 'Like',
                                onPressed: () => onLike(person),
                              ),
                              const SizedBox(width: 10),
                              _RoundButton(
                                icon: Icons.chat_bubble_outline,
                                tooltip: 'Message',
                                onPressed: () => onMessage(person),
                              ),
                            ],
                          ),
                        ),
                        if (people.length > 1) ...[
                          Positioned(
                            left: 0,
                            top: 0,
                            bottom: 0,
                            child: IconButton(
                              onPressed: page == 0 ? null : () => onPage(page - 1),
                              icon: const Icon(Icons.chevron_left, color: _paper),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            bottom: 48,
                            child: IconButton(
                              onPressed: page >= people.length - 1 ? null : () => onPage(page + 1),
                              icon: const Icon(Icons.chevron_right, color: _paper),
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
            if (person != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            person.age == null ? person.name : '${person.name}, ${person.age}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _ink, fontSize: 26, fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (person.photoVerified)
                          const Padding(
                            padding: EdgeInsets.only(left: 6),
                            child: Icon(Icons.verified, color: Color(0xFF3F5E52), size: 22),
                          ),
                      ],
                    ),
                    if (person.city.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          person.city,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _inkSoft, fontSize: 16),
                        ),
                      ),
                    if (lastSeenLabel(lastSeen: person.lastSeen, online: person.online) case final seen?)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Row(
                          children: [
                            if (seen == 'Online') ...[
                              const DecoratedBox(
                                decoration: BoxDecoration(color: Color(0xFF3F5E52), shape: BoxShape.circle),
                                child: SizedBox(width: 8, height: 8),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Text(
                              seen,
                              style: TextStyle(
                                color: seen == 'Online' ? const Color(0xFF3F5E52) : _inkSoft,
                                fontSize: 16,
                                fontWeight: seen == 'Online' ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (person.likedYou)
                      const Padding(
                        padding: EdgeInsets.only(top: 4),
                        child: Text('Liked you', style: TextStyle(color: _clay, fontSize: 16, fontWeight: FontWeight.w700)),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        revealed
                            ? 'Matched: photos are clear. You can keep messaging.'
                            : 'Message can wait for them. Photos clear only after you both like each other.',
                        style: const TextStyle(color: _mute, fontSize: 13, height: 1.35),
                      ),
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

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _paper,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: const Color(0x33000000),
      child: IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, color: _clay),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? _paper : Colors.transparent,
      borderRadius: BorderRadius.circular(22),
      elevation: selected ? 1 : 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            children: [
              Text(
                label,
                style: TextStyle(color: selected ? _clay : _ink, fontWeight: FontWeight.w600, fontSize: 15),
              ),
              if (selected) ...[
                const SizedBox(width: 4),
                const Icon(Icons.check, size: 16, color: _clay),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.onTap, this.highlighted = false});

  final String label;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _paper,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: highlighted ? _clay : _line),
          ),
          child: Row(
            children: [
              Text(label, style: const TextStyle(color: _ink, fontWeight: FontWeight.w600)),
              const Icon(Icons.keyboard_arrow_down, color: _ink, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreferencesSheet extends StatefulWidget {
  const _PreferencesSheet({required this.mode, required this.onApply, this.focusAge = false});

  final DiscoverMode mode;
  final bool focusAge;
  final void Function(DiscoverMode mode, int ageFrom, int ageTo, String reach, String intentId) onApply;

  @override
  State<_PreferencesSheet> createState() => _PreferencesSheetState();
}

class _PreferencesSheetState extends State<_PreferencesSheet> {
  late DiscoverMode _mode;
  late RangeValues _age;
  late String _reach;
  late String _intentId;
  late String _country;
  late String _region;
  late String _area;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    _age = RangeValues(ProfileDraft.ageFrom.toDouble(), ProfileDraft.ageTo.toDouble());
    _reach = ProfileDraft.reach;
    _intentId = ProfileDraft.chosenIntentIds.isNotEmpty ? ProfileDraft.chosenIntentIds.first : JoinDraft.relationshipIntent;
    final place = Places.resolve(country: ProfileDraft.country, region: ProfileDraft.region, area: ProfileDraft.city);
    _country = place.country;
    _region = place.region;
    _area = place.area;
  }

  void _apply() {
    ProfileDraft.country = _country;
    ProfileDraft.region = _region;
    ProfileDraft.city = _area;
    widget.onApply(_mode, _age.start.round(), _age.end.round(), _reach, _intentId);
  }

  Future<void> _pickReach() async {
    const options = [
      'This area',
      'This city',
      'Anywhere in Kenya',
      'Anywhere in this country',
      'Neighbouring countries',
    ];
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _paper,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text('Open to connecting', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _ink)),
              ),
              for (final option in options)
                ListTile(
                  title: Text(option),
                  trailing: option == _reach ? const Icon(Icons.check, color: _clay) : null,
                  onTap: () => Navigator.pop(context, option),
                ),
            ],
          ),
        );
      },
    );
    if (picked == null) return;
    setState(() => _reach = picked);
    _apply();
  }

  Future<void> _pickIntent() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _paper,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text('Hoping for', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _ink)),
              ),
              for (final option in relationshipIntents)
                ListTile(
                  title: Text(option.label),
                  trailing: option.id == _intentId ? const Icon(Icons.check, color: _clay) : null,
                  onTap: () => Navigator.pop(context, option.id),
                ),
            ],
          ),
        );
      },
    );
    if (picked == null) return;
    setState(() => _intentId = picked);
    _apply();
  }

  String get _intentLabel {
    for (final option in relationshipIntents) {
      if (option.id == _intentId) return option.label;
    }
    return 'Marriage';
  }

  @override
  Widget build(BuildContext context) {
    final height = (MediaQuery.sizeOf(context).height * 0.92).clamp(420.0, 900.0);
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        height: height,
        decoration: const BoxDecoration(
          color: _paper,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(color: _line, borderRadius: BorderRadius.circular(4)),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Matching preferences', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: _ink)),
            const SizedBox(height: 14),
            _SheetCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.cake_outlined, color: _clay),
                      const SizedBox(width: 8),
                      const Text('Age range', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _ink)),
                      const Spacer(),
                      Text(
                        '${_age.start.round()} – ${_age.end.round()}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: _clay),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Show people in this age range on Home.',
                    style: TextStyle(color: _inkSoft, fontSize: 14),
                  ),
                  RangeSlider(
                    values: _age,
                    min: 18,
                    max: 80,
                    divisions: 62,
                    labels: RangeLabels('${_age.start.round()}', '${_age.end.round()}'),
                    activeColor: _clay,
                    inactiveColor: _line,
                    onChanged: (values) {
                      setState(() => _age = values);
                      _apply();
                    },
                  ),
                ],
              ),
            ),
            if (!widget.focusAge) ...[
              const SizedBox(height: 16),
              for (final mode in DiscoverMode.values) ...[
                InkWell(
                  onTap: () {
                    setState(() => _mode = mode);
                    _apply();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        Icon(
                          _mode == mode ? Icons.radio_button_checked : Icons.radio_button_off,
                          color: _mode == mode ? _clay : _mute,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _modeLabels[mode]!,
                            style: TextStyle(
                              fontSize: 17,
                              color: _mode == mode ? _clay : _ink,
                              fontWeight: _mode == mode ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Divider(height: 1, color: _line),
              ],
            ],
            const SizedBox(height: 12),
            _SheetCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Living in', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
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
                      _apply();
                    },
                  ),
                  const SizedBox(height: 10),
                  PlaceField(
                    label: Places.regionLabel(_country),
                    value: _region,
                    options: Places.regions(_country),
                    onChanged: (value) {
                      final place = Places.resolve(country: _country, region: value);
                      setState(() {
                        _region = place.region;
                        _area = place.area;
                      });
                      _apply();
                    },
                  ),
                  const SizedBox(height: 10),
                  PlaceField(
                    label: 'Area',
                    value: _area,
                    options: Places.areas(_country, _region),
                    onChanged: (value) {
                      setState(() => _area = value);
                      _apply();
                    },
                  ),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _pickReach,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Expanded(child: Text(_reach, style: const TextStyle(color: _inkSoft, fontSize: 15))),
                          const Icon(Icons.chevron_right, color: _mute),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _SheetCard(
              onTap: _pickIntent,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hoping for', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _ink)),
                        const SizedBox(height: 4),
                        Text(_intentLabel, style: const TextStyle(color: _inkSoft, fontSize: 15)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: _mute),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetCard extends StatelessWidget {
  const _SheetCard({required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _cream,
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.fromLTRB(16, 14, 12, 14), child: child),
      ),
    );
  }
}
