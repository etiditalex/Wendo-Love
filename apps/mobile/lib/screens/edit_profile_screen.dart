import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:upendo_pamoja/backend.dart';
import 'package:upendo_pamoja/connect.dart';
import 'package:upendo_pamoja/domain.dart';
import 'package:upendo_pamoja/place_picker.dart';
import 'package:upendo_pamoja/places.dart';

const _clayDeep = Color(0xFF9C1B4E);
const _paper = Color(0xFFFFFDF8);
const _ink = Color(0xFF1C1917);
const _inkSoft = Color(0xFF44403C);
const _mute = Color(0xFFA8A29E);
const _line = Color(0xFFE7DCCB);

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  bool _savingPhoto = false;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    await loadOwnProfileDetails();
    if (mounted) setState(() {});
  }

  Future<void> _commit() async {
    setState(() {});
    await saveOwnProfileDetails();
  }

  Future<void> _pickPhoto() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 2048, imageQuality: 95);
    if (file == null) return;
    ProfileDraft.photo = await file.readAsBytes();
    notifyProfilePhotoChanged();
    if (!mounted) return;
    setState(() => _savingPhoto = true);
    try {
      await saveProfilePhoto();
    } catch (_) {}
    if (mounted) setState(() => _savingPhoto = false);
  }

  Future<void> _editText({
    required String title,
    required String value,
    required ValueChanged<String> onSave,
    int maxLength = 40,
  }) async {
    final controller = TextEditingController(text: value);
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
              Text(title, style: const TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                maxLength: maxLength,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(counterText: ''),
                onSubmitted: (text) => Navigator.pop(context, text.trim()),
              ),
              const SizedBox(height: 16),
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
    onSave(next);
    await _commit();
  }

  Future<void> _editChoice({
    required String title,
    required String? value,
    required List<String> options,
    required ValueChanged<String> onSave,
  }) async {
    final picked = await showPlacePicker(context, title: title, options: options, selected: value ?? '');
    if (picked == null) return;
    onSave(picked);
    await _commit();
  }

  String _genderSelfLabel(String? id) {
    return switch (id) {
      'woman' => 'A woman',
      'man' => 'A man',
      'nonbinary' => 'Nonbinary',
      _ => '',
    };
  }

  String _educationLabel(String? id) {
    if (id == null || id.isEmpty) return '';
    for (final option in educationOptions) {
      if (option.id == id) return option.label;
    }
    return id;
  }

  String get _seekingLabel {
    if (ProfileDraft.seekingGenders.isEmpty) return '';
    return [
      for (final id in ProfileDraft.seekingGenders)
        if (genderLabel(id).isNotEmpty) genderLabel(id),
    ].join(', ');
  }

  Future<void> _editSeeking() async {
    final selected = {...ProfileDraft.seekingGenders};
    final saved = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: _paper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheet) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('I hope to meet', style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  for (final option in genders)
                    CheckboxListTile(
                      value: selected.contains(option.id),
                      title: Text(option.label),
                      activeColor: _clayDeep,
                      contentPadding: EdgeInsets.zero,
                      onChanged: (on) {
                        setSheet(() {
                          if (on == true) {
                            selected.add(option.id);
                          } else {
                            selected.remove(option.id);
                          }
                        });
                      },
                    ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Save'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (saved != true) return;
    ProfileDraft.seekingGenders = selected.toList();
    await _commit();
  }

  Future<void> _editPlace() async {
    var country = ProfileDraft.country;
    var region = ProfileDraft.region;
    var area = ProfileDraft.city;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _paper,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 18, 20, 18 + MediaQuery.viewInsetsOf(context).bottom),
          child: StatefulBuilder(
            builder: (context, setSheet) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Lives in', style: TextStyle(color: _ink, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  const Text(
                    'City or broad area only. A precise address is never collected.',
                    style: TextStyle(color: _mute, fontSize: 13, height: 1.35),
                  ),
                  const SizedBox(height: 14),
                  PlaceField(
                    label: 'Country',
                    value: country,
                    options: Places.countries,
                    onChanged: (value) {
                      final place = Places.resolve(country: value);
                      setSheet(() {
                        country = place.country;
                        region = place.region;
                        area = place.area;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  PlaceField(
                    label: Places.regionLabel(country),
                    value: region,
                    options: Places.regions(country),
                    onChanged: (value) {
                      final place = Places.resolve(country: country, region: value);
                      setSheet(() {
                        region = place.region;
                        area = place.area;
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  PlaceField(
                    label: 'Area',
                    value: area,
                    options: Places.areas(country, region),
                    onChanged: (value) => setSheet(() => area = value),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    if (saved != true) return;
    ProfileDraft.country = country;
    ProfileDraft.region = region;
    ProfileDraft.city = area;
    JoinDraft.city = area;
    await _commit();
  }

  String get _name {
    final stored = supabase?.auth.currentUser?.userMetadata?['display_name'];
    if (JoinDraft.displayName.trim().isNotEmpty) return JoinDraft.displayName.trim();
    if (stored is String && stored.trim().isNotEmpty) return stored.trim();
    return '';
  }

  String get _livesIn {
    final parts = [
      if (ProfileDraft.country.trim().isNotEmpty) ProfileDraft.country.trim(),
      if (ProfileDraft.region.trim().isNotEmpty) ProfileDraft.region.trim(),
      if (ProfileDraft.city.trim().isNotEmpty) ProfileDraft.city.trim(),
    ];
    return parts.join(', ');
  }

  String get _lookingFor {
    final ids = ProfileDraft.chosenIntentIds.isEmpty
        ? <String>[JoinDraft.relationshipIntent]
        : ProfileDraft.chosenIntentIds;
    return [for (final id in ids) _intentLabel(id)].join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final width = MediaQuery.sizeOf(context).width;
    final photo = ProfileDraft.photo;
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
                    const Expanded(
                      child: Text(
                        'Edit Profile',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _paper, fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(builder: (context) => const _ViewOwnProfilePage()),
                        );
                      },
                      child: const Text(
                        'View',
                        style: TextStyle(color: _paper, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                SizedBox(
                  height: 168,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      const Column(
                        children: [
                          SizedBox(height: 78, child: ColoredBox(color: _clayDeep, child: SizedBox.expand())),
                          Expanded(child: ColoredBox(color: _paper)),
                        ],
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 48,
                        child: Container(
                          height: 78,
                          decoration: BoxDecoration(
                            color: _paper,
                            borderRadius: BorderRadius.vertical(top: Radius.elliptical(width / 2, 52)),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 28,
                        child: GestureDetector(
                          onTap: _savingPhoto ? null : _pickPhoto,
                          child: CircleAvatar(
                            radius: 54,
                            backgroundColor: _paper,
                            child: CircleAvatar(
                              radius: 50,
                              backgroundColor: _line,
                              backgroundImage: photo == null ? null : MemoryImage(photo),
                              child: photo == null ? const Icon(Icons.person, size: 52, color: _inkSoft) : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const _EditSection('Your Basics'),
                _EditRow(
                  label: 'First Name',
                  value: _name,
                  onTap: () => _editText(
                    title: 'First Name',
                    value: _name,
                    onSave: (value) {
                      if (value.length >= 2) JoinDraft.displayName = value;
                    },
                  ),
                ),
                _EditRow(label: 'Lives in:', value: _livesIn, onTap: _editPlace),
                const _EditSection('Match criteria'),
                _EditRow(
                  label: 'I am:',
                  value: _genderSelfLabel(ProfileDraft.gender),
                  onTap: () => _editChoice(
                    title: 'I am',
                    value: _genderSelfLabel(ProfileDraft.gender),
                    options: const ['A woman', 'A man', 'Nonbinary', 'Prefer not to say yet'],
                    onSave: (value) {
                      ProfileDraft.gender = switch (value) {
                        'A woman' => 'woman',
                        'A man' => 'man',
                        'Nonbinary' => 'nonbinary',
                        _ => null,
                      };
                    },
                  ),
                ),
                _EditRow(
                  label: 'I hope to meet:',
                  value: _seekingLabel,
                  onTap: _editSeeking,
                ),
                _EditRow(
                  label: 'Education:',
                  value: _educationLabel(ProfileDraft.education),
                  onTap: () => _editChoice(
                    title: 'Education',
                    value: _educationLabel(ProfileDraft.education),
                    options: [
                      'Prefer not to say',
                      ...educationOptions.map((o) => o.label),
                    ],
                    onSave: (value) {
                      String? next;
                      for (final option in educationOptions) {
                        if (option.label == value) next = option.id;
                      }
                      ProfileDraft.education = next;
                    },
                  ),
                ),
                const _EditSection('Appearance'),
                _EditRow(
                  label: 'Hair color:',
                  value: ProfileDraft.hairColor ?? '',
                  onTap: () => _editChoice(
                    title: 'Hair color',
                    value: ProfileDraft.hairColor,
                    options: _hair,
                    onSave: (value) => ProfileDraft.hairColor = value,
                  ),
                ),
                _EditRow(
                  label: 'Eye color:',
                  value: ProfileDraft.eyeColor ?? '',
                  onTap: () => _editChoice(
                    title: 'Eye color',
                    value: ProfileDraft.eyeColor,
                    options: _eyes,
                    onSave: (value) => ProfileDraft.eyeColor = value,
                  ),
                ),
                _EditRow(
                  label: 'Height:',
                  value: ProfileDraft.heightLabel ?? '',
                  onTap: () => _editChoice(
                    title: 'Height',
                    value: ProfileDraft.heightLabel,
                    options: _heights,
                    onSave: (value) => ProfileDraft.heightLabel = value,
                  ),
                ),
                _EditRow(
                  label: 'Weight:',
                  value: ProfileDraft.weightLabel ?? '',
                  onTap: () => _editChoice(
                    title: 'Weight',
                    value: ProfileDraft.weightLabel,
                    options: _weights,
                    onSave: (value) => ProfileDraft.weightLabel = value,
                  ),
                ),
                _EditRow(
                  label: 'Body type:',
                  value: ProfileDraft.bodyType ?? '',
                  onTap: () => _editChoice(
                    title: 'Body type',
                    value: ProfileDraft.bodyType,
                    options: _bodies,
                    onSave: (value) => ProfileDraft.bodyType = value,
                  ),
                ),
                _EditRow(
                  label: 'Your ethnicity is mostly:',
                  value: ProfileDraft.ethnicity ?? '',
                  onTap: () => _editChoice(
                    title: 'Ethnicity',
                    value: ProfileDraft.ethnicity,
                    options: _ethnicity,
                    onSave: (value) => ProfileDraft.ethnicity = value,
                  ),
                ),
                _EditRow(
                  label: 'Number of children:',
                  value: ProfileDraft.childrenCount ?? '',
                  onTap: () => _editChoice(
                    title: 'Number of children',
                    value: ProfileDraft.childrenCount,
                    options: _childCounts,
                    onSave: (value) => ProfileDraft.childrenCount = value,
                  ),
                ),
                _EditRow(
                  label: 'Oldest child:',
                  value: ProfileDraft.oldestChild ?? '',
                  onTap: () => _editChoice(
                    title: 'Oldest child',
                    value: ProfileDraft.oldestChild,
                    options: _childAges,
                    onSave: (value) => ProfileDraft.oldestChild = value,
                  ),
                ),
                _EditRow(
                  label: 'Youngest child:',
                  value: ProfileDraft.youngestChild ?? '',
                  onTap: () => _editChoice(
                    title: 'Youngest child',
                    value: ProfileDraft.youngestChild,
                    options: _childAges,
                    onSave: (value) => ProfileDraft.youngestChild = value,
                  ),
                ),
                _EditRow(
                  label: 'Do you want (more) children?',
                  value: ProfileDraft.children ?? '',
                  onTap: () => _editChoice(
                    title: 'Children',
                    value: ProfileDraft.children,
                    options: _wantChildren,
                    onSave: (value) => ProfileDraft.children = value,
                  ),
                ),
                _EditRow(
                  label: 'Do you have pets?',
                  value: ProfileDraft.hasPets ?? '',
                  onTap: () => _editChoice(
                    title: 'Pets',
                    value: ProfileDraft.hasPets,
                    options: _pets,
                    onSave: (value) => ProfileDraft.hasPets = value,
                  ),
                ),
                _EditRow(
                  label: 'Occupation:',
                  value: ProfileDraft.occupation ?? '',
                  onTap: () => _editText(
                    title: 'Occupation',
                    value: ProfileDraft.occupation ?? '',
                    maxLength: 60,
                    onSave: (value) => ProfileDraft.occupation = value.isEmpty ? null : value,
                  ),
                ),
                _EditRow(
                  label: 'Employment status:',
                  value: ProfileDraft.employmentStatus ?? '',
                  onTap: () => _editChoice(
                    title: 'Employment status',
                    value: ProfileDraft.employmentStatus,
                    options: _employment,
                    onSave: (value) => ProfileDraft.employmentStatus = value,
                  ),
                ),
                _EditRow(
                  label: 'Income:',
                  value: ProfileDraft.incomeRange ?? '',
                  onTap: () => _editChoice(
                    title: 'Income',
                    value: ProfileDraft.incomeRange,
                    options: _income,
                    onSave: (value) => ProfileDraft.incomeRange = value,
                  ),
                ),
                _EditRow(
                  label: 'Living situation:',
                  value: ProfileDraft.livingSituation ?? '',
                  onTap: () => _editChoice(
                    title: 'Living situation',
                    value: ProfileDraft.livingSituation,
                    options: _living,
                    onSave: (value) => ProfileDraft.livingSituation = value,
                  ),
                ),
                _EditRow(
                  label: "Relationship you're looking for:",
                  value: _lookingFor,
                  onTap: () => _editChoice(
                    title: 'Relationship',
                    value: _lookingFor,
                    options: [for (final item in relationshipIntents) item.label],
                    onSave: (value) {
                      final match = relationshipIntents.where((item) => item.label == value);
                      if (match.isEmpty) return;
                      JoinDraft.relationshipIntent = match.first.id;
                      ProfileDraft.chosenIntentIds = [match.first.id];
                    },
                  ),
                ),
                const _EditSection('Background / Cultural Values'),
                _EditRow(
                  label: 'Beliefs:',
                  value: ProfileDraft.belief ?? '',
                  onTap: () => _editChoice(
                    title: 'Beliefs',
                    value: ProfileDraft.belief,
                    options: _beliefs,
                    onSave: (value) => ProfileDraft.belief = value,
                  ),
                ),
                _EditRow(
                  label: 'Language:',
                  value: ProfileDraft.language ?? '',
                  onTap: () => _editChoice(
                    title: 'Language',
                    value: ProfileDraft.language,
                    options: _languages,
                    onSave: (value) => ProfileDraft.language = value,
                  ),
                ),
                _EditRow(
                  label: 'Marital status:',
                  value: ProfileDraft.maritalStatus ?? '',
                  onTap: () => _editChoice(
                    title: 'Marital status',
                    value: ProfileDraft.maritalStatus,
                    options: _marital,
                    onSave: (value) => ProfileDraft.maritalStatus = value,
                  ),
                ),
                _EditRow(
                  label: 'What matters most:',
                  value: ProfileDraft.whatMatters ?? '',
                  onTap: () => _editChoice(
                    title: 'What matters most',
                    value: ProfileDraft.whatMatters,
                    options: _matters,
                    onSave: (value) => ProfileDraft.whatMatters = value,
                  ),
                ),
                _EditRow(
                  label: 'How you want to meet:',
                  value: ProfileDraft.howToMeet ?? '',
                  onTap: () => _editChoice(
                    title: 'How you want to meet',
                    value: ProfileDraft.howToMeet,
                    options: _meet,
                    onSave: (value) => ProfileDraft.howToMeet = value,
                  ),
                ),
                _EditRow(
                  label: 'Alcohol:',
                  value: ProfileDraft.alcohol ?? '',
                  onTap: () => _editChoice(
                    title: 'Alcohol',
                    value: ProfileDraft.alcohol,
                    options: _alcohol,
                    onSave: (value) => ProfileDraft.alcohol = value,
                  ),
                ),
                _EditRow(
                  label: 'Smoking:',
                  value: ProfileDraft.smoking ?? '',
                  onTap: () => _editChoice(
                    title: 'Smoking',
                    value: ProfileDraft.smoking,
                    options: _smoking,
                    onSave: (value) => ProfileDraft.smoking = value,
                  ),
                ),
                SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EditSection extends StatelessWidget {
  const _EditSection(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: _ink, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Divider(height: 1, thickness: 1, color: Color(0xFFD6D3D1)),
        ],
      ),
    );
  }
}

class _EditRow extends StatelessWidget {
  const _EditRow({required this.label, required this.value, required this.onTap});

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: _ink, fontSize: 16, height: 1.3)),
                  if (value.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        value,
                        style: const TextStyle(color: _mute, fontSize: 15, height: 1.3),
                      ),
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

class _ViewOwnProfilePage extends StatelessWidget {
  const _ViewOwnProfilePage();

  int? get _age {
    final dob = JoinDraft.dateOfBirth;
    if (dob == null) return null;
    final now = DateTime.now();
    var age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) age -= 1;
    return age;
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final photo = ProfileDraft.photo;
    final name = JoinDraft.displayName.trim().isEmpty ? 'Member' : JoinDraft.displayName.trim();
    final age = _age;
    final lives = [
      if (ProfileDraft.city.trim().isNotEmpty) ProfileDraft.city.trim(),
      if (ProfileDraft.region.trim().isNotEmpty) ProfileDraft.region.trim(),
      if (ProfileDraft.country.trim().isNotEmpty) ProfileDraft.country.trim(),
    ].join(', ');
    final rows = <(String, String)>[
      ('Lives in', lives),
      ('Hair color', ProfileDraft.hairColor ?? ''),
      ('Eye color', ProfileDraft.eyeColor ?? ''),
      ('Height', ProfileDraft.heightLabel ?? ''),
      ('Weight', ProfileDraft.weightLabel ?? ''),
      ('Body type', ProfileDraft.bodyType ?? ''),
      ('Ethnicity', ProfileDraft.ethnicity ?? ''),
      ('Children', ProfileDraft.childrenCount ?? ''),
      ('Wants children', ProfileDraft.children ?? ''),
      ('Pets', ProfileDraft.hasPets ?? ''),
      ('Occupation', ProfileDraft.occupation ?? ''),
      ('Employment', ProfileDraft.employmentStatus ?? ''),
      ('Living situation', ProfileDraft.livingSituation ?? ''),
      ('Looking for', _intentLabel(JoinDraft.relationshipIntent)),
      ('Beliefs', ProfileDraft.belief ?? ''),
      ('Language', ProfileDraft.language ?? ''),
      ('Marital status', ProfileDraft.maritalStatus ?? ''),
    ].where((row) => row.$2.trim().isNotEmpty).toList();
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
                    const Expanded(
                      child: Text(
                        'View',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: _paper, fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              children: [
                Center(
                  child: CircleAvatar(
                    radius: 64,
                    backgroundColor: _line,
                    backgroundImage: photo == null ? null : MemoryImage(photo),
                    child: photo == null ? const Icon(Icons.person, size: 64, color: _inkSoft) : null,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  age == null ? name : '$name, $age',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: _ink, fontSize: 26, fontWeight: FontWeight.w700),
                ),
                if (lives.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    lives,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: _inkSoft, fontSize: 16),
                  ),
                ],
                const SizedBox(height: 20),
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row.$1, style: const TextStyle(color: _mute, fontSize: 13)),
                        const SizedBox(height: 2),
                        Text(row.$2, style: const TextStyle(color: _ink, fontSize: 16)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _intentLabel(String id) {
  for (final item in relationshipIntents) {
    if (item.id == id) return item.label;
  }
  return id;
}

const _hair = ['Black', 'Dark brown', 'Brown', 'Grey', 'Other', 'Prefer not to say'];
const _eyes = ['Brown', 'Dark brown', 'Black', 'Hazel', 'Other', 'Prefer not to say'];
const _bodies = ['Slim', 'Average', 'Athletic', 'Curvy', 'Prefer not to say'];
const _ethnicity = ['Prefer not to say', 'African', 'Asian', 'Mixed', 'Other'];
const _childCounts = ['None', '1', '2', '3', '4', '5 or more', 'Prefer not to say'];
const _childAges = [
  'Not applicable',
  'Under 5',
  '5 to 12',
  '13 to 17',
  '18 or older',
  'Prefer not to say',
];
const _wantChildren = ['Yes', 'Not sure', 'No', 'Prefer not to say'];
const _pets = ['Yes', 'No', 'Prefer not to say'];
const _employment = ['Employed', 'Self-employed', 'Student', 'Looking for work', 'Prefer not to say'];
const _income = ['Prefer not to say', 'Student / starting out', 'Steady work', 'Comfortable'];
const _living = ['Live on my own', 'With family', 'With housemates', 'Prefer not to say'];
const _beliefs = ['Christian', 'Islam', 'Hindu', 'Traditional beliefs', 'Other', 'Prefer not to say'];
const _languages = [
  'English',
  'Kiswahili',
  'Sheng',
  'Kikuyu',
  'Luo',
  'Kalenjin',
  'Kamba',
  'Luhya',
  'Another language',
  'Prefer not to say',
];
const _marital = ['Single', 'Separated', 'Widowed', 'Divorced', 'Prefer not to say'];
const _matters = ['Kindness', 'Honesty', 'Shared faith', 'Family', 'Everyday companionship', 'Prefer not to say'];
const _meet = ['Messages first', 'Take time before meeting', 'Meet when it feels safe', 'Prefer not to say'];
const _alcohol = ['I drink regularly', 'Occasionally drink', "Don't drink", 'Prefer not to say'];
const _smoking = [
  'Yes, I smoke regularly',
  'Yes, but only occasionally or socially',
  "Don't smoke",
  'Prefer not to say',
];

final _heights = [
  for (var cm = 140; cm <= 210; cm++) '$cm cm',
  'Prefer not to say',
];

final _weights = [
  for (var kg = 40; kg <= 150; kg++) '$kg kg',
  'Prefer not to say',
];
