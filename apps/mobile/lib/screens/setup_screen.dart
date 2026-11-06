import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:upendo_pamoja/connect.dart';
import 'package:upendo_pamoja/domain.dart';
import 'package:upendo_pamoja/place_picker.dart';
import 'package:upendo_pamoja/places.dart';

class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  static const _clay = Color(0xFFE72570);
  static const _clayDeep = Color(0xFF9C1B4E);
  static const _cream = Color(0xFFF6F1E8);
  static const _paper = Color(0xFFFFFDF8);
  static const _ink = Color(0xFF1C1917);
  static const _inkSoft = Color(0xFF44403C);
  static const _gold = Color(0xFFF06A4A);
  static const _line = Color(0xFFE7DCCB);
  static const _mute = Color(0xFFA8A29E);
  static const _pale = Color(0xFFE6D3A8);

  static const _questions = [
    'Add your best photo',
    'What age range feels right for the people you hope to meet?',
    'Where would you like to meet someone?',
    'What kind of relationship are you looking for?',
    'Which language do you use most?',
    'Which of the following best describes your beliefs?',
    'Do you drink alcohol?',
    'Are you a smoker?',
    'Would you like to have children?',
    "What's your current marital status?",
    'What matters most to you in a connection?',
    'How do you want to get to know someone?',
  ];

  static const _languages = [
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

  static const _beliefs = [
    'Christian',
    'Islam',
    'Hindu',
    'Traditional beliefs',
    'Other',
    'Prefer not to say',
  ];

  static const _alcohol = [
    'I drink regularly',
    'Occasionally drink',
    "Don't drink",
    'Prefer not to say',
  ];

  static const _smoking = [
    'Yes, I smoke regularly',
    'Yes, but only occasionally or socially',
    "Don't smoke",
    'Prefer not to say',
  ];

  static const _children = ['Yes', 'Not sure', 'No', 'Prefer not to say'];

  static const _marital = [
    'Single',
    'Separated',
    'Widowed',
    'Divorced',
    'Prefer not to say',
  ];

  static const _matters = [
    'Kindness',
    'Honesty',
    'Shared faith',
    'Family',
    'Everyday companionship',
    'Prefer not to say',
  ];

  static const _meet = [
    'Messages first',
    'Take time before meeting',
    'Meet when it feels safe',
    'Prefer not to say',
  ];

  int _step = 0;
  bool _picking = false;
  String? _message;
  int _ageFrom = 25;
  int _ageTo = 40;
  String _country = 'Kenya';
  String _region = 'Nairobi';
  String _city = 'Kilimani';
  int _reach = 1;
  final Set<String> _intents = {};
  final Map<int, String> _single = {};

  List<String> get _regions => Places.regions(_country);
  List<String> get _cities => Places.areas(_country, _region);

  bool get _skippable => _step >= 4;

  bool get _ready {
    switch (_step) {
      case 0:
        return ProfileDraft.photo != null;
      case 1:
        return _ageFrom >= 18 && _ageFrom <= _ageTo;
      case 2:
        return true;
      case 3:
        return _intents.isNotEmpty;
      default:
        return _single[_step] != null;
    }
  }

  String get _reachLabel {
    switch (_reach) {
      case 0:
        return 'This area';
      case 1:
        return 'This city';
      case 2:
        return _country == 'Kenya' ? 'Anywhere in Kenya' : 'Anywhere in this country';
      default:
        return 'Neighbouring countries';
    }
  }

  @override
  void initState() {
    super.initState();
    final dob = JoinDraft.dateOfBirth;
    if (dob != null) {
      var age = DateTime.now().year - dob.year;
      if (age < 18) age = 18;
      if (age > 80) age = 80;
      _ageFrom = (age - 3).clamp(18, 80);
      _ageTo = (age + 8).clamp(18, 80);
      if (_ageFrom > _ageTo) _ageFrom = _ageTo;
    }
    final place = JoinDraft.city.trim().isNotEmpty
        ? Places.find(JoinDraft.city)
        : Places.resolve(country: ProfileDraft.country, region: ProfileDraft.region, area: ProfileDraft.city);
    _country = place.country;
    _region = place.region;
    _city = place.area;
  }

  Future<void> _pickPhoto() async {
    setState(() {
      _picking = true;
      _message = null;
    });
    try {
      final file = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 2048,
        imageQuality: 95,
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() => ProfileDraft.photo = bytes);
    } catch (_) {
      if (!mounted) return;
      setState(() => _message = 'The photo could not be opened. You can try another one.');
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  void _back() {
    if (_step == 0) {
      // Stay inside the app: return to join rather than exiting the process.
      context.go('/join');
      return;
    }
    setState(() {
      _step -= 1;
      _message = null;
    });
  }

  void _skip() {
    setState(() => _single.remove(_step));
    _advance();
  }

  void _next() {
    if (!_ready) return;
    _advance();
  }

  void _advance() {
    if (_step == _questions.length - 1) {
      _finish();
      return;
    }
    setState(() {
      _step += 1;
      _message = null;
    });
  }

  Future<void> _finish() async {
    ProfileDraft.ageFrom = _ageFrom;
    ProfileDraft.ageTo = _ageTo;
    ProfileDraft.country = _country;
    ProfileDraft.region = _region;
    ProfileDraft.city = _city;
    ProfileDraft.reach = _reachLabel;
    final chosen = relationshipIntents.where((item) => _intents.contains(item.label)).toList();
    ProfileDraft.chosenIntentIds = [for (final item in chosen) item.id];
    if (chosen.isNotEmpty) JoinDraft.relationshipIntent = chosen.first.id;
    ProfileDraft.language = _single[4];
    ProfileDraft.belief = _single[5];
    ProfileDraft.alcohol = _single[6];
    ProfileDraft.smoking = _single[7];
    ProfileDraft.children = _single[8];
    ProfileDraft.maritalStatus = _single[9];
    ProfileDraft.whatMatters = _single[10];
    ProfileDraft.howToMeet = _single[11];
    final problem = await saveMemberProfile();
    if (!mounted) return;
    if (problem != null) {
      setState(() => _message = problem);
      return;
    }
    context.go('/app');
  }

  void _setCountry(String value) {
    final place = Places.resolve(country: value);
    setState(() {
      _country = place.country;
      _region = place.region;
      _city = place.area;
    });
  }

  void _setRegion(String value) {
    final place = Places.resolve(country: _country, region: value);
    setState(() {
      _region = place.region;
      _city = place.area;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: _cream,
        body: Column(
          children: [
            _header(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                children: [
                  Text(
                    '${_step + 1}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 64, height: 1, fontWeight: FontWeight.w600, color: _gold),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _questions[_step],
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 22, height: 1.25, fontWeight: FontWeight.w700, color: _ink),
                  ),
                  if (_help != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _help!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 15, height: 1.4, color: _inkSoft),
                    ),
                  ],
                  const SizedBox(height: 22),
                  ..._fields(),
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Text(_message!, textAlign: TextAlign.center, style: const TextStyle(color: _clayDeep)),
                  ],
                ],
              ),
            ),
            LinearProgressIndicator(
              value: (_step + 1) / _questions.length,
              minHeight: 3,
              backgroundColor: const Color(0xFFD6D3D1),
              color: _gold,
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 16 + bottom),
              child: _step == 0 ? Center(child: _nextButton(wide: false)) : Row(
                children: [
                  Expanded(child: _backButton()),
                  const SizedBox(width: 16),
                  Expanded(child: _nextButton(wide: true)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String? get _help {
    switch (_step) {
      case 1:
        return 'Everyone here is 18 or over. Suggestions follow the ages you choose.';
      case 2:
        return 'A city or a broad area is enough. Your phone’s location is never used.';
      case 3:
        return 'Select all that apply.';
      default:
        return null;
    }
  }

  Widget _header() {
    return ColoredBox(
      color: _clayDeep,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.favorite_border, color: _paper, size: 22),
                const SizedBox(width: 8),
                const Text(
                  'Wendo',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: _paper, decoration: TextDecoration.none),
                ),
                const Spacer(),
                if (_skippable)
                  TextButton(
                    onPressed: _skip,
                    child: const Text('Skip', style: TextStyle(color: _paper, fontSize: 16)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _backButton() {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: _ink,
        backgroundColor: _paper,
        side: const BorderSide(color: _line),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: const StadiumBorder(),
      ),
      onPressed: _back,
      child: const Text('Back', style: TextStyle(fontSize: 16)),
    );
  }

  Widget _nextButton({required bool wide}) {
    final enabled = _ready && !_picking;
    return SizedBox(
      width: wide ? null : 230,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: _clay,
          disabledBackgroundColor: _pale,
          foregroundColor: _paper,
          disabledForegroundColor: const Color(0xFF78716C),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: const StadiumBorder(),
        ),
        onPressed: enabled ? _next : null,
        child: const Text('Next', style: TextStyle(fontSize: 16)),
      ),
    );
  }

  List<Widget> _fields() {
    switch (_step) {
      case 0:
        return [_photoCard()];
      case 1:
        return [_ageRow()];
      case 2:
        return [_placeFields()];
      case 3:
        return [_choiceCard(relationshipIntents.map((item) => item.label).toList(), multi: true)];
      case 4:
        return [_choiceCard(_languages)];
      case 5:
        return [_choiceCard(_beliefs)];
      case 6:
        return [_choiceCard(_alcohol)];
      case 7:
        return [_choiceCard(_smoking)];
      case 8:
        return [_choiceCard(_children)];
      case 9:
        return [_choiceCard(_marital)];
      case 10:
        return [_choiceCard(_matters)];
      default:
        return [_choiceCard(_meet)];
    }
  }

  Widget _photoCard() {
    final photo = ProfileDraft.photo;
    return Column(
      children: [
        Center(
          child: SizedBox(
            width: 280,
            height: 280,
            child: Stack(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _paper,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: _line),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: SizedBox.expand(
                      child: photo == null
                          ? const Icon(Icons.person_outline, size: 148, color: Color(0xFF57534E))
                          : Image.memory(photo, fit: BoxFit.contain, filterQuality: FilterQuality.high),
                    ),
                  ),
                ),
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: Material(
                    color: _paper,
                    shape: const CircleBorder(),
                    elevation: 1,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _picking ? null : _pickPhoto,
                      child: const SizedBox(
                        width: 42,
                        height: 42,
                        child: Icon(Icons.add, color: _inkSoft),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Use a bright, clear, recent photo of you. It stays on your profile for people you choose to connect with. It is never placed in a public directory, and it is never used to guess your health.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.4, color: _inkSoft),
        ),
      ],
    );
  }

  Widget _ageRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(width: 132, child: _dropdown(_ageFrom, [for (var age = 18; age <= 80; age++) age], (value) {
          if (value == null) return;
          setState(() {
            _ageFrom = value;
            if (_ageTo < value) _ageTo = value;
          });
        })),
        const SizedBox(width: 18),
        SizedBox(width: 132, child: _dropdown(_ageTo, [for (var age = 18; age <= 80; age++) age], (value) {
          if (value == null) return;
          setState(() {
            _ageTo = value;
            if (_ageFrom > value) _ageFrom = value;
          });
        })),
      ],
    );
  }

  Widget _placeFields() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PlaceField(label: 'Country', value: _country, options: Places.countries, onChanged: _setCountry),
        const SizedBox(height: 12),
        PlaceField(label: Places.regionLabel(_country), value: _region, options: _regions, onChanged: _setRegion),
        const SizedBox(height: 12),
        PlaceField(
          label: 'Area',
          value: _city,
          options: _cities,
          onChanged: (value) => setState(() => _city = value),
        ),
        const SizedBox(height: 8),
        const Text(
          'Choose a country, then a region or county, then an area. A precise address is never collected.',
          style: TextStyle(fontSize: 14, height: 1.4, color: _inkSoft),
        ),
        const SizedBox(height: 22),
        const Text('Open to connecting', style: TextStyle(fontSize: 16, color: _ink)),
        const SizedBox(height: 6),
        Text(_reachLabel, style: const TextStyle(fontSize: 16, color: _inkSoft)),
        Slider(
          value: _reach.toDouble(),
          min: 0,
          max: 3,
          divisions: 3,
          activeColor: _ink,
          thumbColor: _ink,
          inactiveColor: const Color(0xFFD6D3D1),
          onChanged: (value) => setState(() => _reach = value.round()),
        ),
      ],
    );
  }

  Widget _dropdown<T>(T value, List<T> items, ValueChanged<T?> onChanged) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD6D3D1)),
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
              DropdownMenuItem(value: item, child: Text('$item', style: const TextStyle(color: _ink, fontSize: 16))),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _choiceCard(List<String> options, {bool multi = false}) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: _line),
            InkWell(
              onTap: () {
                setState(() {
                  if (multi) {
                    if (!_intents.add(options[i])) _intents.remove(options[i]);
                  } else {
                    _single[_step] = options[i];
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    Icon(
                      _marked(options[i], multi)
                          ? (multi ? Icons.check_box_outlined : Icons.radio_button_checked)
                          : (multi ? Icons.check_box_outline_blank : Icons.radio_button_off),
                      color: _marked(options[i], multi) ? _clay : _ink,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(options[i], style: const TextStyle(fontSize: 16, color: _ink)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _marked(String option, bool multi) {
    if (multi) return _intents.contains(option);
    return _single[_step] == option;
  }
}
