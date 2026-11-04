import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:upendo_pamoja/connect.dart';
import 'package:upendo_pamoja/domain.dart';

const _clay = Color(0xFFE72570);
const _clayDeep = Color(0xFF9C1B4E);
const _paper = Color(0xFFFFFDF8);
const _ink = Color(0xFF1C1917);
const _inkSoft = Color(0xFF44403C);
const _mute = Color(0xFFA8A29E);
const _line = Color(0xFFE7DCCB);
const _slot = Color(0xFFF0EBE3);
const _sage = Color(0xFF3F5E52);
const _gold = Color(0xFFF06A4A);

class PhotosPage extends StatefulWidget {
  const PhotosPage({super.key});

  @override
  State<PhotosPage> createState() => _PhotosPageState();
}

class _PhotosPageState extends State<PhotosPage> {
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    loadOwnGallery().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _pick(int index) async {
    if (_busy) return;
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2048, imageQuality: 95);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _busy = true);
    try {
      await saveGalleryPhoto(index, bytes);
    } catch (_) {}
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final main = ProfileDraft.gallery[0] ?? ProfileDraft.photo;
    return _Sheet(
      title: 'Photos',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          const Text(
            'A clear photo of you is shown to people you choose to connect with. It is not a public directory.',
            style: TextStyle(color: _inkSoft, fontSize: 16, height: 1.4),
          ),
          const SizedBox(height: 16),
          _MainPhoto(photo: main, busy: _busy, onEdit: () => _pick(0)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _AddSlot(photo: ProfileDraft.gallery[1], onTap: () => _pick(1))),
              const SizedBox(width: 12),
              Expanded(child: _AddSlot(photo: ProfileDraft.gallery[2], onTap: () => _pick(2))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _AddSlot(photo: ProfileDraft.gallery[3], onTap: () => _pick(3))),
              const SizedBox(width: 12),
              Expanded(child: _AddSlot(photo: ProfileDraft.gallery[4], onTap: () => _pick(4))),
            ],
          ),
        ],
      ),
    );
  }
}

class HobbiesPage extends StatefulWidget {
  const HobbiesPage({super.key});

  @override
  State<HobbiesPage> createState() => _HobbiesPageState();
}

class _HobbiesPageState extends State<HobbiesPage> {
  @override
  void initState() {
    super.initState();
    loadOwnProfileDetails().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'Edit Hobbies & Interests',
      child: ListView(
        padding: const EdgeInsets.only(top: 16, bottom: 28),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              'Share what you enjoy. These details introduce you. They are never used to hide people.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _inkSoft, fontSize: 15, height: 1.4),
            ),
          ),
          const SizedBox(height: 18),
          _AnswerRow(
            label: 'What do you do for fun / entertainment?',
            field: 'hobby_fun',
            onChanged: () => setState(() {}),
          ),
          _AnswerRow(
            label: 'What sort of food do you like?',
            field: 'hobby_food',
            onChanged: () => setState(() {}),
          ),
          _AnswerRow(
            label: 'What sort of music are you into?',
            field: 'hobby_music',
            onChanged: () => setState(() {}),
          ),
          _AnswerRow(
            label: 'What sports do you play or like to watch?',
            field: 'hobby_sports',
            onChanged: () => setState(() {}),
          ),
        ],
      ),
    );
  }
}

class PersonalityPage extends StatefulWidget {
  const PersonalityPage({super.key});

  @override
  State<PersonalityPage> createState() => _PersonalityPageState();
}

class _PersonalityPageState extends State<PersonalityPage> {
  @override
  void initState() {
    super.initState();
    loadOwnProfileDetails().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return _Sheet(
      title: 'Personality',
      child: ListView(
        padding: const EdgeInsets.only(top: 16, bottom: 28),
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 28),
            child: Text(
              'Say who you are in your own words. Health status is not a personality field.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _inkSoft, fontSize: 15, height: 1.4),
            ),
          ),
          const SizedBox(height: 18),
          _AnswerRow(
            label: 'What is your favorite movie?',
            field: 'movie',
            onChanged: () => setState(() {}),
          ),
          _AnswerRow(
            label: 'What is your favorite book?',
            field: 'book',
            onChanged: () => setState(() {}),
          ),
          _AnswerRow(
            label: 'What sort of food do you like?',
            field: 'personality_food',
            onChanged: () => setState(() {}),
          ),
          _AnswerRow(
            label: 'What sort of music do you like?',
            field: 'personality_music',
            onChanged: () => setState(() {}),
          ),
          _AnswerRow(
            label: 'How would you describe your dress sense and physical appearance?',
            field: 'dress',
            onChanged: () => setState(() {}),
          ),
          _AnswerRow(
            label: 'How would you describe your sense of humor?',
            field: 'humor',
            onChanged: () => setState(() {}),
          ),
          _AnswerRow(
            label: 'What are your hobbies and interests?',
            field: 'personality_hobbies',
            onChanged: () => setState(() {}),
          ),
          _AnswerRow(
            label: 'Where have you traveled or would like to travel to?',
            field: 'travel',
            onChanged: () => setState(() {}),
          ),
          _AnswerRow(
            label: 'How adaptive are you to having a partner from a different culture to your own?',
            field: 'culture',
            onChanged: () => setState(() {}),
          ),
          _AnswerRow(
            label: 'How would you spend a perfect romantic weekend?',
            field: 'weekend',
            onChanged: () => setState(() {}),
          ),
        ],
      ),
    );
  }
}

class VerifyPhotosPage extends StatefulWidget {
  const VerifyPhotosPage({super.key});

  @override
  State<VerifyPhotosPage> createState() => _VerifyPhotosPageState();
}

class _VerifyPhotosPageState extends State<VerifyPhotosPage> {
  bool _busy = false;
  String? _message;

  Future<void> _send() async {
    if (_busy) return;
    XFile? file;
    try {
      file = await ImagePicker().pickImage(source: ImageSource.camera, maxWidth: 2048, imageQuality: 95);
    } catch (_) {}
    file ??= await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2048, imageQuality: 95);
    if (file == null) return;
    await _store(await file.readAsBytes());
  }

  Future<void> _store(Uint8List bytes) async {
    if (!mounted) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    final problem = await saveVerifyPhoto(bytes);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _message = problem ??
          'Saved privately for review. A check appears after staff approve it. This is not a health badge.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final sent = ProfileDraft.photoVerifyRequestedAt != null;
    final pending = ProfileDraft.photoVerifyPending;
    return _Sheet(
      title: 'Verify Photos',
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
              children: [
                Icon(
                  ProfileDraft.photoVerified
                      ? Icons.verified
                      : pending
                          ? Icons.hourglass_top
                          : Icons.verified_user,
                  color: _sage,
                  size: 52,
                ),
                const SizedBox(height: 12),
                Text(
                  ProfileDraft.photoVerified
                      ? 'Photo check complete'
                      : pending
                          ? 'Waiting for review'
                          : 'Verify Photos',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _ink, fontSize: 22, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  ProfileDraft.photoVerified
                      ? 'Your profile can show a check. It is not a health badge, and it is not used to rank people.'
                      : pending
                          ? 'Your confirmation photo is private and waiting for staff. You can send another if needed.'
                          : 'A photo check helps people trust that the photos are of you.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _inkSoft, fontSize: 14, height: 1.35),
                ),
                const SizedBox(height: 22),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _paper,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _line),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(16, 18, 16, 10),
                    child: Column(
                      children: [
                        _VerifyPoint(
                          icon: Icons.check_circle,
                          color: _sage,
                          title: 'Photo check',
                          body: 'A check shows the photos are of you. Wendo does not put a health badge on a photo.',
                        ),
                        _VerifyPoint(
                          icon: Icons.search,
                          color: _gold,
                          title: 'Your profile stays yours',
                          body: 'A check is not a ranking. Nothing here is ordered by health or by who paid.',
                        ),
                        _VerifyPoint(
                          icon: Icons.chat_bubble_outline,
                          color: _clay,
                          title: 'Connect with care',
                          body: 'Meet first in a public place. A photo check is not a promise that someone is safe.',
                        ),
                        _VerifyPoint(
                          icon: Icons.lock_outline,
                          color: _inkSoft,
                          title: 'Private and separate',
                          body: 'The confirmation photo is used only to confirm it is you. It is never shown on your profile or shared with other people.',
                        ),
                      ],
                    ),
                  ),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Text(_message!, textAlign: TextAlign.center, style: const TextStyle(color: _inkSoft, height: 1.4)),
                ],
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(24, 8, 24, 16 + MediaQuery.paddingOf(context).bottom),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _send,
                style: FilledButton.styleFrom(
                  backgroundColor: _clay,
                  foregroundColor: _paper,
                  disabledBackgroundColor: _line,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  sent ? 'Send another confirmation photo' : 'Send a confirmation photo',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sheet extends StatelessWidget {
  const _Sheet({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: _paper,
      body: Column(
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
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.arrow_back, color: _paper),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _paper, fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _MainPhoto extends StatelessWidget {
  const _MainPhoto({required this.photo, required this.busy, required this.onEdit});

  final Uint8List? photo;
  final bool busy;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.15,
      child: Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: photo == null
                ? Material(
                    color: _slot,
                    child: InkWell(
                      onTap: busy ? null : onEdit,
                      child: const Center(child: Icon(Icons.add, size: 48, color: _mute)),
                    ),
                  )
                : Image.memory(photo!, fit: BoxFit.cover, filterQuality: FilterQuality.high),
          ),
          if (photo != null)
            Positioned(
              right: 12,
              bottom: 12,
              child: Material(
                color: _paper,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: busy ? null : onEdit,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _paper,
                      border: Border.all(color: const Color(0xFFC4B8A8), width: 2),
                    ),
                    child: const Icon(Icons.edit_outlined, color: _inkSoft, size: 22),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AddSlot extends StatelessWidget {
  const _AddSlot({required this.photo, required this.onTap});

  final Uint8List? photo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Material(
        color: _slot,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: photo == null
              ? const Center(child: Icon(Icons.add, size: 42, color: _mute))
              : ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.memory(photo!, fit: BoxFit.cover, filterQuality: FilterQuality.high),
                ),
        ),
      ),
    );
  }
}

class _AnswerRow extends StatelessWidget {
  const _AnswerRow({required this.label, required this.field, required this.onChanged});

  final String label;
  final String field;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final value = ProfileDraft.aboutAnswers[field] ?? '';
    return InkWell(
      onTap: () async {
        await _editAnswer(context, label: label, field: field);
        onChanged();
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: _ink, fontSize: 16, height: 1.35)),
                  if (value.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(value, style: const TextStyle(color: _mute, fontSize: 15, height: 1.3)),
                    ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(top: 2, left: 8),
              child: Icon(Icons.edit_outlined, color: _inkSoft, size: 20),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _editAnswer(BuildContext context, {required String label, required String field}) async {
  final controller = TextEditingController(text: ProfileDraft.aboutAnswers[field] ?? '');
  final next = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: _paper,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (context) {
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: const TextStyle(color: _ink, fontSize: 17, fontWeight: FontWeight.w700, height: 1.3)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              autofocus: true,
              maxLength: 280,
              minLines: 2,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (text) => Navigator.pop(context, text.trim()),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Save'),
            ),
          ],
        ),
      );
    },
  );
  controller.dispose();
  if (next == null) return;
  if (next.isEmpty) {
    ProfileDraft.aboutAnswers.remove(field);
  } else {
    ProfileDraft.aboutAnswers[field] = next;
  }
  await saveAboutAnswers();
}

class _VerifyPoint extends StatelessWidget {
  const _VerifyPoint({required this.icon, required this.color, required this.title, required this.body});

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: _ink, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(body, style: const TextStyle(color: _inkSoft, fontSize: 14, height: 1.35)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
