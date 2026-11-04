import 'dart:typed_data';

import 'package:flutter/material.dart';
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
                      return _ViewCard(
                        photo: person.photo ?? cachedProfilePhoto(person.userId),
                        name: person.name,
                        revealed: _mutual.contains(person.userId),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 8, 40, 18),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => setState(() => _mine = true),
                style: FilledButton.styleFrom(
                  backgroundColor: _clay,
                  foregroundColor: _paper,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
                child: const Text('Match to see clearly', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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

enum _LikeFilter { likedMe, myLikes, mutual }

class _MatchesScreenState extends State<MatchesScreen> {
  List<ReceivedLike> _likedMe = [];
  List<ReceivedLike> _myLikes = [];
  Set<String> _mutual = {};
  _LikeFilter _filter = _LikeFilter.likedMe;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final likedMe = await loadReceivedLikes();
      final myLikes = await loadSentLikes();
      final threads = await loadMatchThreads();
      if (!mounted) return;
      setState(() {
        _likedMe = likedMe;
        _myLikes = myLikes;
        _mutual = {
          for (final thread in threads)
            if (thread.mutual) thread.otherUserId,
        };
      });
      await loadProfilePhotos([
        ...likedMe.map((like) => like.userId),
        ...myLikes.map((like) => like.userId),
      ]);
      if (!mounted) return;
      for (final like in [...likedMe, ...myLikes]) {
        like.photo = cachedProfilePhoto(like.userId);
      }
      setState(() {});
    } catch (_) {}
  }

  List<ReceivedLike> get _people {
    switch (_filter) {
      case _LikeFilter.likedMe:
        return _likedMe;
      case _LikeFilter.myLikes:
        return _myLikes;
      case _LikeFilter.mutual:
        final mine = {for (final like in _myLikes) like.userId};
        final shown = <String, ReceivedLike>{};
        for (final like in _likedMe) {
          if (mine.contains(like.userId) || _mutual.contains(like.userId)) shown[like.userId] = like;
        }
        for (final like in _myLikes) {
          if (_mutual.contains(like.userId)) shown[like.userId] = like;
        }
        return shown.values.toList();
    }
  }

  String get _bannerTitle {
    final count = _filter == _LikeFilter.likedMe
        ? _likedMe.length
        : _filter == _LikeFilter.myLikes
            ? _myLikes.length
            : _people.length;
    if (_filter == _LikeFilter.likedMe) {
      if (count == 0) return 'No one has liked your profile yet';
      if (count == 1) return '1 person liked your profile';
      return '$count people liked your profile';
    }
    if (_filter == _LikeFilter.myLikes) {
      if (count == 0) return 'You have not liked anyone yet';
      if (count == 1) return 'You liked 1 profile';
      return 'You liked $count profiles';
    }
    if (count == 0) return 'You have no mutual likes yet';
    if (count == 1) return '1 mutual like';
    return '$count mutual likes';
  }

  Future<void> _openLike(ReceivedLike like) async {
    try {
      final matchId = await openConversation(like.userId);
      if (!mounted || matchId == null) return;
      Navigator.of(context, rootNavigator: true)
          .push(MaterialPageRoute<void>(
            builder: (context) => ChatPage(
              matchId: matchId,
              title: like.name,
              otherUserId: like.userId,
              photo: like.photo ?? cachedProfilePhoto(like.userId),
              mutual: _mutual.contains(like.userId),
            ),
          ))
          .then((_) => _load());
    } catch (_) {}
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
                child: const Row(
                  children: [
                    SizedBox(width: 48),
                    Expanded(
                      child: Text(
                        'Likes',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: _paper, fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                    ),
                    SizedBox(
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
                _ViewsTab(label: 'Liked Me', selected: _filter == _LikeFilter.likedMe, onTap: () => setState(() => _filter = _LikeFilter.likedMe)),
                _ViewsTab(label: 'My Likes', selected: _filter == _LikeFilter.myLikes, onTap: () => setState(() => _filter = _LikeFilter.myLikes)),
                _ViewsTab(label: 'Mutual Likes', selected: _filter == _LikeFilter.mutual, onTap: () => setState(() => _filter = _LikeFilter.mutual)),
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
                        onTap: () => _openLike(person),
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
                onPressed: () => setState(() => _filter = _LikeFilter.likedMe),
                style: FilledButton.styleFrom(
                  backgroundColor: _clay,
                  foregroundColor: _paper,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: const StadiumBorder(),
                ),
                child: const Text('Match to see clearly', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

enum _MessageFilter { received, sent, favorites, ended }

class _MessagesScreenState extends State<MessagesScreen> {
  List<MatchThread> _threads = [];
  _MessageFilter _filter = _MessageFilter.received;
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
                _ViewsTab(label: 'Received', selected: _filter == _MessageFilter.received, onTap: () => setState(() => _filter = _MessageFilter.received)),
                _ViewsTab(label: 'Sent', selected: _filter == _MessageFilter.sent, onTap: () => setState(() => _filter = _MessageFilter.sent)),
                _ViewsTab(label: 'Favorites', selected: _filter == _MessageFilter.favorites, onTap: () => setState(() => _filter = _MessageFilter.favorites)),
                _ViewsTab(label: 'Ended', selected: _filter == _MessageFilter.ended, onTap: () => setState(() => _filter = _MessageFilter.ended)),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
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
