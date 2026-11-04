import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:upendo_pamoja/backend.dart';
import 'package:upendo_pamoja/connect.dart';
import 'package:upendo_pamoja/domain.dart';
import 'package:upendo_pamoja/privacy_media.dart';
import 'package:upendo_pamoja/safety_actions.dart';

const _clay = Color(0xFFE72570);
const _clayDeep = Color(0xFF9C1B4E);
const _cream = Color(0xFFF6F1E8);
const _paper = Color(0xFFFFFDF8);
const _ink = Color(0xFF1C1917);
const _inkSoft = Color(0xFF44403C);
const _line = Color(0xFFE7DCCB);
const _sage = Color(0xFF3F5E52);
const _gold = Color(0xFFF06A4A);

class ViewsScreen extends StatefulWidget {
  const ViewsScreen({super.key});

  @override
  State<ViewsScreen> createState() => _ViewsScreenState();
}

class _ViewsScreenState extends State<ViewsScreen> {
  List<ProfileViewer> _viewers = [];
  List<ProfileViewer> _viewed = [];
  Set<String> _mutual = {};
  bool _mine = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final viewers = await loadProfileViewers();
      final viewed = await loadViewedProfiles();
      final threads = await loadMatchThreads();
      if (!mounted) return;
      setState(() {
        _viewers = viewers;
        _viewed = viewed;
        _mutual = {
          for (final thread in threads)
            if (thread.mutual) thread.otherUserId,
        };
      });
    } catch (_) {}
  }

  List<ProfileViewer> get _people => _mine ? _viewers : _viewed;

  String get _bannerTitle {
    final count = _people.length;
    if (_mine) {
      if (count == 0) return 'No one has viewed your profile yet';
      if (count == 1) return '1 person viewed your profile';
      return '$count people viewed your profile';
    }
    if (count == 0) return 'You have not viewed a profile yet';
    if (count == 1) return 'You viewed 1 profile';
    return 'You viewed $count profiles';
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final people = _people;
    return ColoredBox(
      color: const Color(0xFFFFF7F4),
      child: Column(
        children: [
          ColoredBox(
            color: _clayDeep,
            child: SizedBox(
              height: top + 56,
              child: Padding(
                padding: EdgeInsets.only(top: top),
                child: Row(
                  children: [
                    const SizedBox(width: 48),
                    const Expanded(
                      child: Text(
                        'Profile View',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _paper, fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(
                      width: 48,
                      child: Icon(Icons.more_horiz, color: _paper),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ColoredBox(
            color: _clay,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Row(
                children: [
                  const Icon(Icons.remove_red_eye_outlined, color: _paper, size: 34),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _bannerTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _paper, fontSize: 16, fontWeight: FontWeight.w700, height: 1.25),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Photos show on each profile.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Color(0xFFFFE4EC), fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          ColoredBox(
            color: const Color(0xFFFFF7F4),
            child: Row(
              children: [
                _ViewsTab(
                  label: 'Viewed My Profile',
                  selected: _mine,
                  onTap: () => setState(() => _mine = true),
                ),
                _ViewsTab(
                  label: 'Profiles I Viewed',
                  selected: !_mine,
                  onTap: () => setState(() => _mine = false),
                ),
              ],
            ),
          ),
          Expanded(
            child: people.isEmpty
                ? const SizedBox.expand()
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    itemCount: people.length,
                    itemBuilder: (context, index) {
                      final person = people[index];
                      return GestureDetector(
                        onTap: () => context.push('/app/people/${person.userId}'),
                        child: _ViewCard(
                          photo: person.photo ?? cachedProfilePhoto(person.userId),
                          name: person.name,
                          revealed: _mutual.contains(person.userId),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 8, 40, 18),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.go('/app/matches?tab=likes'),
                style: FilledButton.styleFrom(
                  backgroundColor: _clay,
                  foregroundColor: _paper,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
                child: const Text('Open Activity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewsTab extends StatelessWidget {
  const _ViewsTab({required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? _clayDeep : const Color(0xFFB0A8A2),
                  fontSize: 15,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            Container(
              height: selected ? 3 : 1,
              color: selected ? _clayDeep : const Color(0xFFE7DCCB),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewCard extends StatelessWidget {
  const _ViewCard({required this.photo, required this.name, required this.revealed});

  final Uint8List? photo;
  final String name;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        fit: StackFit.expand,
        children: [
          PrivacyPhoto(
            bytes: photo,
            revealed: revealed,
            showLock: false,
            placeholder: const ColoredBox(
              color: Color(0xFFEDE6DC),
              child: Icon(Icons.person, color: Color(0xFF6B645E), size: 72),
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 14,
            child: revealed
                ? Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: _paper, fontSize: 15, fontWeight: FontWeight.w700),
                  )
                : const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(color: Color(0x99FFFDF8), borderRadius: BorderRadius.all(Radius.circular(8))),
                        child: SizedBox(width: 72, height: 8),
                      ),
                      SizedBox(height: 8),
                      DecoratedBox(
                        decoration: BoxDecoration(color: Color(0x66FFFDF8), borderRadius: BorderRadius.all(Radius.circular(8))),
                        child: SizedBox(width: 46, height: 8),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class MatchesScreen extends StatefulWidget {
  const MatchesScreen({super.key});

  @override
  State<MatchesScreen> createState() => _MatchesScreenState();
}

enum _ActivityTab { likes, views, favorites, mutual }

class _MatchesScreenState extends State<MatchesScreen> {
  List<ReceivedLike> _likes = [];
  List<ProfileViewer> _views = [];
  List<ReceivedLike> _favorites = [];
  List<MatchThread> _mutual = [];
  Set<String> _mutualIds = {};
  _ActivityTab _tab = _ActivityTab.likes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tab = GoRouterState.of(context).uri.queryParameters['tab'];
      if (tab == 'views') _tab = _ActivityTab.views;
      if (tab == 'favorites') _tab = _ActivityTab.favorites;
      if (tab == 'mutual') _tab = _ActivityTab.mutual;
      if (tab == 'likes') _tab = _ActivityTab.likes;
      if (mounted) setState(() {});
    });
    _load();
  }

  Future<void> _load() async {
    try {
      final likes = await loadReceivedLikes();
      final views = await loadProfileViewers();
      final favorites = await loadFavoritePeople();
      final threads = await loadMatchThreads();
      if (!mounted) return;
      final mutual = [for (final thread in threads) if (thread.mutual) thread];
      setState(() {
        _likes = likes;
        _views = views;
        _favorites = favorites;
        _mutual = mutual;
        _mutualIds = {for (final thread in mutual) thread.otherUserId};
      });
      await loadProfilePhotos([
        ...likes.map((like) => like.userId),
        ...views.map((viewer) => viewer.userId),
        ...favorites.map((person) => person.userId),
        ...mutual.map((thread) => thread.otherUserId),
      ]);
      if (!mounted) return;
      for (final like in likes) {
        like.photo = cachedProfilePhoto(like.userId);
      }
      for (final viewer in views) {
        viewer.photo = cachedProfilePhoto(viewer.userId);
      }
      for (final person in favorites) {
        person.photo = cachedProfilePhoto(person.userId);
      }
      for (final thread in mutual) {
        thread.photo = cachedProfilePhoto(thread.otherUserId);
      }
      setState(() {});
    } catch (_) {}
  }

  void _selectTab(_ActivityTab tab) {
    setState(() => _tab = tab);
    final label = switch (tab) {
      _ActivityTab.likes => 'likes',
      _ActivityTab.views => 'views',
      _ActivityTab.favorites => 'favorites',
      _ActivityTab.mutual => 'mutual',
    };
    context.go('/app/matches?tab=$label');
  }

  String get _bannerTitle {
    switch (_tab) {
      case _ActivityTab.likes:
        if (_likes.isEmpty) return 'No incoming likes yet';
        if (_likes.length == 1) return '1 person liked your profile';
        return '${_likes.length} people liked your profile';
      case _ActivityTab.views:
        if (_views.isEmpty) return 'No profile views yet';
        if (_views.length == 1) return '1 person viewed your profile';
        return '${_views.length} people viewed your profile';
      case _ActivityTab.favorites:
        if (_favorites.isEmpty) return 'No favorites yet';
        if (_favorites.length == 1) return '1 private favorite';
        return '${_favorites.length} private favorites';
      case _ActivityTab.mutual:
        if (_mutual.isEmpty) return 'No mutual matches yet';
        if (_mutual.length == 1) return '1 mutual match';
        return '${_mutual.length} mutual matches';
    }
  }

  Future<void> _likeBack(ReceivedLike like) async {
    await sendLike(like.userId);
    final matchId = await openConversation(like.userId);
    if (!mounted) return;
    if (matchId != null) {
      await Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute<void>(
          builder: (context) => ChatPage(
            matchId: matchId,
            title: like.name,
            otherUserId: like.userId,
            photo: like.photo ?? cachedProfilePhoto(like.userId),
            mutual: true,
          ),
        ),
      );
    }
    await _load();
  }

  void _openPerson(String userId) {
    context.push('/app/people/$userId').then((_) => _load());
  }

  void _openThread(MatchThread thread) {
    Navigator.of(context, rootNavigator: true)
        .push(
          MaterialPageRoute<void>(
            builder: (context) => ChatPage(
              matchId: thread.matchId,
              title: thread.name,
              otherUserId: thread.otherUserId,
              photo: thread.photo ?? cachedProfilePhoto(thread.otherUserId),
              lastSeen: thread.lastSeen,
              online: thread.online,
              mutual: thread.mutual,
            ),
          ),
        )
        .then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ColoredBox(
      color: const Color(0xFFFFF7F4),
      child: Column(
        children: [
          ColoredBox(
            color: _clayDeep,
            child: SizedBox(
              height: top + 56,
              child: Padding(
                padding: EdgeInsets.only(top: top),
                child: const Row(
                  children: [
                    SizedBox(width: 48),
                    Expanded(
                      child: Text(
                        'Activity',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _paper, fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(width: 48, child: Icon(Icons.more_horiz, color: _paper)),
                  ],
                ),
              ),
            ),
          ),
          ColoredBox(
            color: _clay,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
              child: Row(
                children: [
                  const Icon(Icons.favorite_border, color: _paper, size: 34),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _bannerTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _paper, fontSize: 16, fontWeight: FontWeight.w700, height: 1.25),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Likes, views, favorites, and mutual matches.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Color(0xFFFFE4EC), fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          ColoredBox(
            color: const Color(0xFFFFF7F4),
            child: Row(
              children: [
                _ViewsTab(
                  label: 'Liked you (${_likes.length})',
                  selected: _tab == _ActivityTab.likes,
                  onTap: () => _selectTab(_ActivityTab.likes),
                ),
                _ViewsTab(
                  label: 'Views (${_views.length})',
                  selected: _tab == _ActivityTab.views,
                  onTap: () => _selectTab(_ActivityTab.views),
                ),
                _ViewsTab(
                  label: 'Favorites (${_favorites.length})',
                  selected: _tab == _ActivityTab.favorites,
                  onTap: () => _selectTab(_ActivityTab.favorites),
                ),
                _ViewsTab(
                  label: 'Mutual (${_mutual.length})',
                  selected: _tab == _ActivityTab.mutual,
                  onTap: () => _selectTab(_ActivityTab.mutual),
                ),
              ],
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_tab) {
      case _ActivityTab.likes:
        if (_likes.isEmpty) {
          return const _ActivityEmpty(
            title: 'No incoming likes yet',
            body: 'When someone likes you in the app or on web, they show here.',
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: _likes.length,
          itemBuilder: (context, index) {
            final like = _likes[index];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openPerson(like.userId),
                    child: _ViewCard(
                      photo: like.photo ?? cachedProfilePhoto(like.userId),
                      name: like.name,
                      revealed: _mutualIds.contains(like.userId),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FilledButton(
                  onPressed: () => _likeBack(like),
                  style: FilledButton.styleFrom(
                    backgroundColor: _clay,
                    foregroundColor: _paper,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: const StadiumBorder(),
                  ),
                  child: const Text('Like back', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            );
          },
        );
      case _ActivityTab.views:
        if (_views.isEmpty) {
          return const _ActivityEmpty(
            title: 'No profile views yet',
            body: 'Members who open your profile appear here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: _views.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final viewer = _views[index];
            return _ActivityPersonTile(
              name: viewer.name,
              city: viewer.city,
              photo: viewer.photo ?? cachedProfilePhoto(viewer.userId),
              revealed: _mutualIds.contains(viewer.userId),
              onTap: () => _openPerson(viewer.userId),
            );
          },
        );
      case _ActivityTab.favorites:
        if (_favorites.isEmpty) {
          return const _ActivityEmpty(
            title: 'No favorites yet',
            body: 'Star someone from Home or a profile to keep them here privately.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: _favorites.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final person = _favorites[index];
            return _ActivityPersonTile(
              name: person.name,
              city: person.city,
              photo: person.photo ?? cachedProfilePhoto(person.userId),
              revealed: true,
              onTap: () => _openPerson(person.userId),
            );
          },
        );
      case _ActivityTab.mutual:
        if (_mutual.isEmpty) {
          return const _ActivityEmpty(
            title: 'No mutual matches yet',
            body: 'A mutual like in the app or on web opens a conversation here.',
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          itemCount: _mutual.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final thread = _mutual[index];
            return _ActivityPersonTile(
              name: thread.name,
              city: thread.preview.isNotEmpty ? thread.preview : (thread.city.isEmpty ? 'Say hello' : thread.city),
              photo: thread.photo ?? cachedProfilePhoto(thread.otherUserId),
              revealed: true,
              onTap: () => _openThread(thread),
            );
          },
        );
    }
  }
}

class _ActivityEmpty extends StatelessWidget {
  const _ActivityEmpty({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 40, 28, 24),
      child: Column(
        children: [
          Text(title, textAlign: TextAlign.center, style: const TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(body, textAlign: TextAlign.center, style: const TextStyle(color: _inkSoft, fontSize: 14, height: 1.4)),
        ],
      ),
    );
  }
}

class _ActivityPersonTile extends StatelessWidget {
  const _ActivityPersonTile({
    required this.name,
    required this.city,
    required this.photo,
    required this.revealed,
    required this.onTap,
  });

  final String name;
  final String city;
  final Uint8List? photo;
  final bool revealed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _paper,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: PrivacyPhoto(
                    bytes: photo,
                    revealed: revealed,
                    showLock: false,
                    placeholder: const ColoredBox(
                      color: Color(0xFFEDE6DC),
                      child: Icon(Icons.person, color: Color(0xFF6B645E)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w700)),
                    if (city.isNotEmpty)
                      Text(city, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _inkSoft, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

enum _MessageFilter { all, received, sent, favorites, ended }

class _MessagesScreenState extends State<MessagesScreen> {
  List<MatchThread> _threads = [];
  _MessageFilter _filter = _MessageFilter.all;
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final threads = await loadMatchThreads();
      if (!mounted) return;
      setState(() => _threads = threads);
      await loadProfilePhotos(threads.map((thread) => thread.otherUserId));
      if (!mounted) return;
      for (final thread in threads) {
        thread.photo = cachedProfilePhoto(thread.otherUserId);
      }
      setState(() {});
    } catch (_) {}
  }

  List<MatchThread> get _visible {
    final me = supabase?.auth.currentUser?.id;
    return [
      for (final thread in _threads)
        if (_keep(thread, me)) thread,
    ];
  }

  bool _keep(MatchThread thread, String? me) {
    switch (_filter) {
      case _MessageFilter.all:
        return !thread.unmatched;
      case _MessageFilter.received:
        return !thread.unmatched && thread.lastSenderId != null && thread.lastSenderId != me;
      case _MessageFilter.sent:
        return !thread.unmatched && (thread.lastSenderId == null || thread.lastSenderId == me);
      case _MessageFilter.favorites:
        return !thread.unmatched && thread.favorite;
      case _MessageFilter.ended:
        return thread.unmatched;
    }
  }

  void _open(MatchThread thread) {
    if (_editing) return;
    Navigator.of(context, rootNavigator: true)
        .push(MaterialPageRoute<void>(
          builder: (context) => ChatPage(
            matchId: thread.matchId,
            title: thread.name,
            otherUserId: thread.otherUserId,
            photo: thread.photo ?? cachedProfilePhoto(thread.otherUserId),
            lastSeen: thread.lastSeen,
            online: thread.online,
            mutual: thread.mutual,
          ),
        ))
        .then((_) => _load());
  }

  Future<void> _end(MatchThread thread) async {
    try {
      await endMatch(thread.matchId);
      if (!mounted) return;
      await _load();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final people = _visible;
    final me = supabase?.auth.currentUser?.id;
    return ColoredBox(
      color: _paper,
      child: Column(
        children: [
          ColoredBox(
            color: _clayDeep,
            child: SizedBox(
              height: top + 56,
              child: Padding(
                padding: EdgeInsets.only(top: top),
                child: Row(
                  children: [
                    const SizedBox(width: 64),
                    const Expanded(
                      child: Text(
                        'Messages',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _paper, fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _editing = !_editing),
                      child: Text(
                        _editing ? 'Done' : 'Edit',
                        style: const TextStyle(color: _paper, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ColoredBox(
            color: _clay,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 22,
                    backgroundColor: _paper,
                    child: Icon(Icons.chat_bubble_outline, color: _clay),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your conversations stay private.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: _paper, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'A message waits even if they are away.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: Color(0xFFFFE4EC), fontSize: 13, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          ColoredBox(
            color: _paper,
            child: Row(
              children: [
                _ViewsTab(label: 'All', selected: _filter == _MessageFilter.all, onTap: () => setState(() => _filter = _MessageFilter.all)),
                _ViewsTab(label: 'Received', selected: _filter == _MessageFilter.received, onTap: () => setState(() => _filter = _MessageFilter.received)),
                _ViewsTab(label: 'Sent', selected: _filter == _MessageFilter.sent, onTap: () => setState(() => _filter = _MessageFilter.sent)),
                _ViewsTab(label: 'Favorites', selected: _filter == _MessageFilter.favorites, onTap: () => setState(() => _filter = _MessageFilter.favorites)),
                _ViewsTab(label: 'Ended', selected: _filter == _MessageFilter.ended, onTap: () => setState(() => _filter = _MessageFilter.ended)),
              ],
            ),
          ),
          Expanded(
            child: people.isEmpty
                ? const Padding(
                    padding: EdgeInsets.fromLTRB(28, 40, 28, 24),
                    child: Text(
                      'No chats in this folder.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _inkSoft, fontSize: 15),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.only(top: 4, bottom: 8),
                    itemCount: people.length,
                    itemBuilder: (context, index) {
                      final thread = people[index];
                      return _MessageRow(
                        thread: thread,
                        mine: thread.lastSenderId == me,
                        editing: _editing,
                        onTap: () => _open(thread),
                        onEnd: () => _end(thread),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _MessageRow extends StatelessWidget {
  const _MessageRow({
    required this.thread,
    required this.mine,
    required this.editing,
    required this.onTap,
    required this.onEnd,
  });

  final MatchThread thread;
  final bool mine;
  final bool editing;
  final VoidCallback onTap;
  final VoidCallback onEnd;

  String get _date {
    final at = thread.lastAt;
    if (at == null) return '';
    return '${at.month}/${at.day}/${at.year}';
  }

  @override
  Widget build(BuildContext context) {
    final online = lastSeenLabel(lastSeen: thread.lastSeen, online: thread.online) == 'Online';
    final title = thread.age == null ? thread.name : '${thread.name}  •  ${thread.age}';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Row(
          children: [
            SizedBox(
              width: 58,
              height: 58,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: _PeerAvatar(
                      photo: thread.photo ?? cachedProfilePhoto(thread.otherUserId),
                      online: online,
                      radius: 29,
                      revealed: true,
                    ),
                  ),
                  if (mine)
                    const Positioned(
                      left: -2,
                      top: 16,
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: _clay,
                        child: Icon(Icons.reply, color: _paper, size: 12),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.person, size: 16, color: _gold),
                    ],
                  ),
                  if (thread.preview.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        thread.preview,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _inkSoft, fontSize: 14),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (editing && !thread.unmatched)
              IconButton(
                onPressed: onEnd,
                icon: const Icon(Icons.close, color: _inkSoft),
              )
            else
              Text(_date, style: const TextStyle(color: Color(0xFFB0A8A2), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _PersonTile extends StatelessWidget {
  const _PersonTile({
    required this.name,
    required this.subtitle,
    required this.onTap,
    this.photo,
    this.revealed = false,
  });

  final String name;
  final String subtitle;
  final VoidCallback onTap;
  final Uint8List? photo;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: _paper,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                _PeerAvatar(photo: photo, online: false, revealed: revealed),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _ink)),
                      Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: _inkSoft)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: _inkSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({required this.thread, required this.onTap, this.subtitle});

  final MatchThread thread;
  final VoidCallback onTap;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final presence = lastSeenLabel(lastSeen: thread.lastSeen, online: thread.online);
    final online = presence == 'Online';
    final detail = subtitle ?? (thread.city.isEmpty ? 'Mutual match' : thread.city);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: _paper,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                _PeerAvatar(
                  photo: thread.photo ?? cachedProfilePhoto(thread.otherUserId),
                  online: online,
                  revealed: thread.mutual,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(thread.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: _ink)),
                      Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _inkSoft),
                      ),
                      if (presence != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            presence,
                            style: TextStyle(
                              color: online ? _sage : _inkSoft,
                              fontSize: 13,
                              fontWeight: online ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: _inkSoft),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PeerAvatar extends StatelessWidget {
  const _PeerAvatar({required this.photo, required this.online, this.radius = 24, this.revealed = true});

  final Uint8List? photo;
  final bool online;
  final double radius;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(
          width: radius * 2,
          height: radius * 2,
          child: ClipOval(
            child: PrivacyPhoto(
              bytes: photo,
              revealed: revealed,
              placeholder: ColoredBox(
                color: _line,
                child: Icon(Icons.person, color: _inkSoft, size: radius),
              ),
            ),
          ),
        ),
        if (online)
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              width: radius * 0.45,
              height: radius * 0.45,
              decoration: BoxDecoration(
                color: _sage,
                shape: BoxShape.circle,
                border: Border.all(color: _paper, width: 2),
              ),
            ),
          ),
      ],
    );
  }
}

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.matchId,
    required this.title,
    this.otherUserId,
    this.photo,
    this.lastSeen,
    this.online = false,
    this.mutual = false,
    this.photoVerified = false,
  });

  final String matchId;
  final String title;
  final String? otherUserId;
  final Uint8List? photo;
  final DateTime? lastSeen;
  final bool online;
  final bool mutual;
  final bool photoVerified;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _text = TextEditingController();
  final _lines = <ChatLine>[];
  RealtimeChannel? _channel;
  RealtimeChannel? _readsChannel;
  bool _sending = false;
  String? _note;
  String _title = '';
  Uint8List? _photo;
  DateTime? _lastSeen;
  bool _online = false;
  late bool _mutual;

  @override
  void initState() {
    super.initState();
    _title = widget.title;
    _photo = widget.photo ?? (widget.otherUserId == null ? null : cachedProfilePhoto(widget.otherUserId!));
    _lastSeen = widget.lastSeen;
    _online = widget.online;
    _mutual = widget.mutual;
    activeChatMatchId = widget.matchId;
    _load();
    _loadPeer();
    _loadMutual();
    _loadPhoto();
    markThreadRead(widget.matchId);
    _channel = watchMessages(widget.matchId, (line) {
      markThreadRead(widget.matchId);
      if (!mounted || _lines.any((item) => item.id == line.id)) return;
      setState(() => _lines.add(line));
    });
    final other = widget.otherUserId;
    if (other != null) {
      _readsChannel = watchThreadReads(widget.matchId, other, (readAt) {
        if (!mounted) return;
        setState(() {
          for (var i = 0; i < _lines.length; i++) {
            final line = _lines[i];
            if (line.senderId == supabase?.auth.currentUser?.id && !line.createdAt.isAfter(readAt)) {
              _lines[i] = line.copyWith(read: true, delivered: true);
            }
          }
        });
      });
    }
  }

  @override
  void dispose() {
    if (activeChatMatchId == widget.matchId) activeChatMatchId = null;
    final channel = _channel;
    if (channel != null) supabase?.removeChannel(channel);
    final reads = _readsChannel;
    if (reads != null) supabase?.removeChannel(reads);
    _text.dispose();
    super.dispose();
  }

  Future<void> _loadPhoto() async {
    final other = widget.otherUserId;
    if (other == null) return;
    final bytes = await loadProfilePhoto(other);
    if (!mounted || bytes == null) return;
    setState(() => _photo = bytes);
  }

  Future<void> _loadPeer() async {
    final other = widget.otherUserId;
    if (other == null) return;
    try {
      final peer = await loadChatPeer(other);
      if (!mounted || peer == null) return;
      setState(() {
        _title = peer.name;
        _photo = peer.photo ?? _photo;
        _lastSeen = peer.lastSeen;
        _online = peer.online;
      });
    } catch (_) {}
  }

  Future<void> _loadMutual() async {
    final other = widget.otherUserId;
    if (other == null || _mutual) return;
    final mutual = await isMutualWith(other);
    if (!mounted || !mutual) return;
    setState(() => _mutual = true);
  }

  Future<void> _report() async {
    final other = widget.otherUserId;
    if (other == null) return;
    final sent = await showReportPersonSheet(context, otherUserId: other, otherName: _title);
    if (!mounted || !sent) return;
    setState(() => _note = 'Report received. Thank you.');
  }

  Future<void> _load() async {
    try {
      final lines = await loadMessages(widget.matchId, otherUserId: widget.otherUserId);
      if (!mounted) return;
      setState(() {
        _lines
          ..clear()
          ..addAll(lines);
        _note = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _note = 'This conversation could not be opened.');
    }
  }

  Future<void> _send() async {
    final text = _text.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final line = await sendMessage(widget.matchId, text, otherUserId: widget.otherUserId);
      if (!mounted) return;
      _text.clear();
      if (line != null && _lines.every((item) => item.id != line.id)) {
        setState(() => _lines.add(line));
      }
    } catch (_) {
      if (mounted) setState(() => _note = 'That message was not sent. Chat stays inside a mutual match.');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _end() async {
    try {
      await endMatch(widget.matchId);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _note = 'The match could not be ended just now.');
    }
  }

  Future<void> _block() async {
    final other = widget.otherUserId;
    if (other == null) return;
    try {
      await blockPerson(other, widget.matchId);
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) setState(() => _note = 'The block could not be saved just now.');
    }
  }

  Future<void> _startVideo() async {
    final url = videoRoomUrlForMatch(widget.matchId);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Start video call?'),
        content: const Text(
          'Opens a private video room outside Wendo. A join link is posted in this chat so the other person can enter the same room. Camera and mic permissions are set in the browser.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Start')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final invite = 'Video call invite: $url';
    try {
      final line = await sendMessage(widget.matchId, invite, otherUserId: widget.otherUserId);
      if (mounted && line != null && _lines.every((item) => item.id != line.id)) {
        setState(() => _lines.add(line));
      }
    } catch (_) {
      if (mounted) setState(() => _note = 'Could not post the invite. Opening the room anyway.');
    }
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      setState(() => _note = 'Could not open the video room. Check your browser.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = supabase?.auth.currentUser?.id;
    final presence = lastSeenLabel(lastSeen: _lastSeen, online: _online);
    final online = presence == 'Online';
    return Scaffold(
      backgroundColor: _cream,
      appBar: AppBar(
        backgroundColor: _clayDeep,
        foregroundColor: _paper,
        titleSpacing: 0,
        title: Row(
          children: [
            _PeerAvatar(photo: _photo, online: online, radius: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          _title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (widget.photoVerified) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, color: Color(0xFFB7D4C5), size: 16),
                      ],
                    ],
                  ),
                  if (presence != null)
                    Text(
                      presence,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: online ? const Color(0xFFB7D4C5) : const Color(0xFFE7DCCB), fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Video call',
            onPressed: _startVideo,
            icon: const Icon(Icons.videocam_outlined),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'video') _startVideo();
              if (value == 'end') _end();
              if (value == 'block') _block();
              if (value == 'report') _report();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'video', child: Text('Start video call')),
              const PopupMenuItem(value: 'end', child: Text('End this match')),
              if (widget.otherUserId != null) const PopupMenuItem(value: 'block', child: Text('Block')),
              if (widget.otherUserId != null) const PopupMenuItem(value: 'report', child: Text('Report')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          ColoredBox(
            color: _mutual ? const Color(0xFFE8F0EC) : const Color(0xFFFFF0F5),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Text(
                _mutual
                    ? 'Matched: you can both message freely. Use the video icon for an optional call.'
                    : 'You can message now. A mutual like confirms the match. Video is optional from the camera icon.',
                style: TextStyle(
                  color: _mutual ? _sage : _clayDeep,
                  fontSize: 13,
                  height: 1.35,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          if (_note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(_note!, style: const TextStyle(color: _clayDeep)),
            ),
          Expanded(
            child: _lines.isEmpty
                ? const SizedBox.expand()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _lines.length,
                    itemBuilder: (context, index) {
                      final line = _lines[index];
                      final mine = line.senderId == me;
                      return Align(
                        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.78),
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Column(
                              crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                              children: [
                                if (!mine)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: _PeerAvatar(photo: _photo, online: false, radius: 14),
                                  ),
                                Builder(
                                  builder: (context) {
                                    final isVideo = line.body.startsWith('Video call invite:');
                                    final link = isVideo
                                        ? line.body.replaceFirst(RegExp(r'^Video call invite:\s*'), '').trim()
                                        : null;
                                    return Material(
                                      color: mine ? _clay : _paper,
                                      borderRadius: BorderRadius.circular(16),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(16),
                                        onTap: link == null
                                            ? null
                                            : () async {
                                                final uri = Uri.tryParse(link);
                                                if (uri == null) return;
                                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                                              },
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                          child: Text(
                                            link == null ? line.body : 'Join video call',
                                            style: TextStyle(
                                              color: mine ? _paper : _ink,
                                              height: 1.3,
                                              decoration: link == null ? null : TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                if (mine)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4, right: 4),
                                    child: Text(
                                      line.read ? 'Read' : (line.delivered ? 'Delivered' : 'Sending…'),
                                      style: TextStyle(
                                        color: line.read ? _sage : _inkSoft,
                                        fontSize: 12,
                                        fontWeight: line.read ? FontWeight.w700 : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Message',
                        filled: true,
                        fillColor: _paper,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _line)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _line)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    style: IconButton.styleFrom(backgroundColor: _clay, foregroundColor: _paper),
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send),
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

class MemberProfileScreen extends StatefulWidget {
  const MemberProfileScreen({super.key, required this.userId});

  final String userId;

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  MemberProfile? _profile;
  bool _loading = true;
  bool _liked = false;
  bool _favorited = false;
  bool _mutual = false;
  int _photoIndex = 0;
  String? _note;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _note = null;
    });
    await recordProfileView(widget.userId);
    final profile = await loadMemberProfile(widget.userId);
    final favorites = await loadFavoriteIds();
    final threads = await loadMatchThreads();
    final likedYou = await loadReceivedLikes();
    final myLikes = await loadSentLikes();
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _favorited = favorites.contains(widget.userId);
      _mutual = threads.any((thread) => thread.otherUserId == widget.userId && thread.mutual);
      _liked = myLikes.any((like) => like.userId == widget.userId) ||
          likedYou.any((like) => like.userId == widget.userId && _mutual);
      _loading = false;
      _note = profile == null ? 'This member could not be loaded.' : null;
      _photoIndex = 0;
    });
  }

  Future<void> _like() async {
    final problem = await sendLike(widget.userId);
    if (!mounted) return;
    if (problem != null) {
      setState(() => _note = problem);
      return;
    }
    setState(() {
      _liked = true;
      _note = 'Like sent.';
    });
  }

  Future<void> _message() async {
    final matchId = await openConversation(widget.userId);
    if (!mounted) return;
    if (matchId == null) {
      setState(() => _note = 'Chat opens after you both like each other.');
      return;
    }
    final profile = _profile;
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<void>(
        builder: (context) => ChatPage(
          matchId: matchId,
          title: profile?.name ?? 'Member',
          otherUserId: widget.userId,
          photo: profile?.photos.isNotEmpty == true ? profile!.photos.first : cachedProfilePhoto(widget.userId),
          lastSeen: profile?.lastSeen,
          online: profile?.online ?? false,
          mutual: _mutual,
        ),
      ),
    );
  }

  Future<void> _favorite() async {
    if (_favorited) {
      setState(() => _note = 'Already in your private favorites.');
      return;
    }
    final problem = await addFavorite(widget.userId);
    if (!mounted) return;
    if (problem != null) {
      setState(() => _note = problem);
      return;
    }
    setState(() {
      _favorited = true;
      _note = 'Saved to your private favorites.';
    });
  }

  Future<void> _pass() async {
    final problem = await passPerson(widget.userId);
    if (!mounted) return;
    if (problem != null) {
      setState(() => _note = problem);
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/app');
    }
  }

  Future<void> _block() async {
    final problem = await blockMember(widget.userId);
    if (!mounted) return;
    if (problem != null) {
      setState(() => _note = problem);
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/app');
    }
  }

  Future<void> _report() async {
    final sent = await showReportPersonSheet(
      context,
      otherUserId: widget.userId,
      otherName: _profile?.name,
    );
    if (!mounted || !sent) return;
    setState(() => _note = 'Report sent for review.');
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final profile = _profile;
    final photos = profile?.photos ?? const <Uint8List>[];
    final revealed = _mutual || !(profile?.blurUntilMutual ?? false);
    return ColoredBox(
      color: _cream,
      child: Column(
        children: [
          ColoredBox(
            color: _clayDeep,
            child: SizedBox(
              height: top + 56,
              child: Padding(
                padding: EdgeInsets.only(top: top),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go('/app');
                        }
                      },
                      icon: const Icon(Icons.arrow_back, color: _paper),
                    ),
                    const Expanded(
                      child: Text(
                        'Member profile',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _paper, fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/app/upgrade'),
                      child: const Text('Upgrade', style: TextStyle(color: _paper, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_note != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(_note!, style: const TextStyle(color: _inkSoft, fontSize: 13)),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: _clay))
                : profile == null
                    ? const Center(child: Text('Profile unavailable', style: TextStyle(color: _inkSoft)))
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: AspectRatio(
                              aspectRatio: 0.92,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  PrivacyPhoto(
                                    bytes: photos.isEmpty ? null : photos[_photoIndex.clamp(0, photos.length - 1)],
                                    revealed: revealed,
                                    placeholder: const ColoredBox(
                                      color: Color(0xFFE7DCCB),
                                      child: Icon(Icons.person, size: 96, color: _inkSoft),
                                    ),
                                  ),
                                  if (photos.length > 1) ...[
                                    Positioned(
                                      left: 4,
                                      top: 0,
                                      bottom: 0,
                                      child: IconButton(
                                        onPressed: () => setState(() {
                                          _photoIndex = (_photoIndex - 1 + photos.length) % photos.length;
                                        }),
                                        icon: const Icon(Icons.chevron_left, color: _paper),
                                      ),
                                    ),
                                    Positioned(
                                      right: 4,
                                      top: 0,
                                      bottom: 0,
                                      child: IconButton(
                                        onPressed: () => setState(() {
                                          _photoIndex = (_photoIndex + 1) % photos.length;
                                        }),
                                        icon: const Icon(Icons.chevron_right, color: _paper),
                                      ),
                                    ),
                                    Positioned(
                                      left: 0,
                                      right: 0,
                                      bottom: 12,
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          for (var i = 0; i < photos.length; i++)
                                            Container(
                                              width: 8,
                                              height: 8,
                                              margin: const EdgeInsets.symmetric(horizontal: 3),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: i == _photoIndex ? _paper : const Color(0x66FFFDF8),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            profile.age == null ? profile.name : '${profile.name}, ${profile.age}',
                            style: const TextStyle(color: _ink, fontSize: 28, fontWeight: FontWeight.w700),
                          ),
                          if (profile.city.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(profile.city, style: const TextStyle(color: _inkSoft, fontSize: 16)),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              lastSeenLabel(lastSeen: profile.lastSeen, online: profile.online) ?? 'Last seen private',
                              style: TextStyle(
                                color: profile.online ? _sage : _inkSoft,
                                fontSize: 14,
                                fontWeight: profile.online ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text('Seeking: ${profile.seeking}', style: const TextStyle(color: _inkSoft, fontSize: 15)),
                          ),
                          if (profile.bio != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Text(profile.bio!, style: const TextStyle(color: _ink, fontSize: 15, height: 1.45)),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              [
                                if (profile.bodyType != null && profile.bodyType!.isNotEmpty) profile.bodyType!,
                                if (profile.education != null && profile.education!.isNotEmpty) profile.education!,
                                if (photos.isNotEmpty) '${photos.length} photos',
                                if (profile.photoVerified) 'Photo confirmed',
                              ].join(' · '),
                              style: const TextStyle(color: _inkSoft, fontSize: 13),
                            ),
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              FilledButton(
                                onPressed: _liked ? null : _like,
                                style: FilledButton.styleFrom(backgroundColor: _liked ? _clayDeep : _clay, foregroundColor: _paper),
                                child: Text(_liked ? 'Liked' : 'Like'),
                              ),
                              OutlinedButton(
                                onPressed: _message,
                                style: OutlinedButton.styleFrom(foregroundColor: _clayDeep),
                                child: const Text('Message'),
                              ),
                              OutlinedButton(
                                onPressed: _favorite,
                                style: OutlinedButton.styleFrom(foregroundColor: _favorited ? _clay : _ink),
                                child: Text(_favorited ? 'Favorited' : 'Favorite'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 16,
                            children: [
                              TextButton(onPressed: _pass, child: const Text('Pass')),
                              TextButton(onPressed: _block, child: const Text('Block')),
                              TextButton(
                                onPressed: _report,
                                style: TextButton.styleFrom(foregroundColor: _clayDeep),
                                child: const Text('Report'),
                              ),
                            ],
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
