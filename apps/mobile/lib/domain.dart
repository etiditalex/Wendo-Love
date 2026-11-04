import 'dart:typed_data';

class RelationshipIntent {
  const RelationshipIntent(this.id, this.label);
  final String id;
  final String label;
}

const genders = [
  RelationshipIntent('woman', 'Women'),
  RelationshipIntent('man', 'Men'),
  RelationshipIntent('nonbinary', 'Nonbinary people'),
];

const educationOptions = [
  RelationshipIntent('secondary', 'Secondary'),
  RelationshipIntent('diploma', 'Diploma'),
  RelationshipIntent('degree', 'Degree'),
  RelationshipIntent('postgraduate', 'Postgraduate'),
];

const relationshipIntents = [
  RelationshipIntent('marriage', 'Marriage'),
  RelationshipIntent('long_term', 'Long-term partnership'),
  RelationshipIntent('companionship', 'Companionship'),
  RelationshipIntent('friendship', 'Friendship'),
  RelationshipIntent('unsure', 'Still deciding'),
];

String genderLabel(String? id) {
  if (id == null || id.isEmpty) return '';
  for (final option in genders) {
    if (option.id == id) return option.label;
  }
  return id;
}

String seekingLine({
  required List<String> seekingGenders,
  required int ageFrom,
  required int ageTo,
  required String intent,
}) {
  final people = [
    for (final id in seekingGenders)
      if (genderLabel(id).isNotEmpty) genderLabel(id),
  ];
  final ages = '$ageFrom–$ageTo';
  if (people.isNotEmpty) return '${people.join(', ')}, $ages';
  final intentLabel = () {
    for (final option in relationshipIntents) {
      if (option.id == intent) return option.label;
    }
    return intent.isEmpty ? 'Open to connection' : intent;
  }();
  return '$intentLabel, $ages';
}

const hivStatusOptions = [
  RelationshipIntent('living_with_hiv', 'Living with HIV'),
  RelationshipIntent('hiv_negative', 'HIV-negative'),
  RelationshipIntent('prefer_not_to_say', 'Prefer not to say'),
  RelationshipIntent('not_sure', 'Not sure'),
];

const disclosurePreferences = [
  RelationshipIntent('never', 'Do not offer sharing'),
  RelationshipIntent('when_i_choose', 'Only when I choose, with a mutual match'),
];

const consentVersion = '2026-10';

class JoinDraft {
  static String displayName = '';
  static String email = '';
  static DateTime? dateOfBirth;
  static String city = '';
  static String relationshipIntent = 'marriage';
}

class ProfileDraft {
  static Uint8List? photo;
  static int ageFrom = 25;
  static int ageTo = 40;
  static String country = 'Kenya';
  static String region = 'Nairobi';
  static String city = 'Kilimani';
  static String reach = 'This city';
  static List<String> chosenIntentIds = [];
  static String? language;
  static String? belief;
  static String? alcohol;
  static String? smoking;
  static String? children;
  static String? maritalStatus;
  static String? whatMatters;
  static String? howToMeet;
  static bool visible = true;
  static String presence = 'online';
  static bool emailMessages = true;
  static bool emailMatch = true;
  static bool emailReply = true;
  static bool mobileMessages = true;
  static bool mobileMatch = true;
  static bool realtimeMessages = true;
  static String? occupation;
  static String? hairColor;
  static String? eyeColor;
  static String? heightLabel;
  static String? weightLabel;
  static String? bodyType;
  static String? gender;
  static List<String> seekingGenders = [];
  static String? education;
  static DateTime? premiumUntil;
  static String? ethnicity;
  static String? childrenCount;
  static String? oldestChild;
  static String? youngestChild;
  static String? hasPets;
  static String? employmentStatus;
  static String? incomeRange;
  static String? livingSituation;
  static final List<Uint8List?> gallery = List<Uint8List?>.filled(5, null);
  static final Map<String, String> aboutAnswers = {};
  static DateTime? photoVerifyRequestedAt;
  static DateTime? photoVerifiedAt;
  static bool blurUntilMutual = false;

  static bool get photoVerified => photoVerifiedAt != null;
  static bool get photoVerifyPending =>
      photoVerifyRequestedAt != null && photoVerifiedAt == null;

  static bool get hasPlus {
    final until = premiumUntil;
    return until != null && until.isAfter(DateTime.now().toUtc());
  }

  static bool get matchCriteriaComplete =>
      city.trim().isNotEmpty &&
      (gender?.isNotEmpty ?? false) &&
      seekingGenders.isNotEmpty &&
      photo != null;
}

/// Online while the member's app is open. Otherwise a line such as "39 minutes ago".
String? lastSeenLabel({required DateTime? lastSeen, required bool online, DateTime? now}) {
  final current = now ?? DateTime.now();
  if (lastSeen != null && online) {
    final age = current.difference(lastSeen.toLocal());
    if (!age.isNegative && age.inMinutes < 3) return 'Online';
  }
  if (lastSeen == null) return null;
  var age = current.difference(lastSeen.toLocal());
  if (age.isNegative) age = Duration.zero;
  if (age.inMinutes < 1) return 'Just now';
  if (age.inMinutes < 60) {
    final minutes = age.inMinutes;
    return minutes == 1 ? '1 minute ago' : '$minutes minutes ago';
  }
  if (age.inHours < 24) {
    final hours = age.inHours;
    return hours == 1 ? '1 hour ago' : '$hours hours ago';
  }
  final days = age.inDays;
  return days == 1 ? '1 day ago' : '$days days ago';
}

bool isAdult(DateTime dob) {
  final today = DateTime.now();
  final cutoff = DateTime(today.year - 18, today.month, today.day);
  final birth = DateTime(dob.year, dob.month, dob.day);
  return !birth.isAfter(cutoff);
}
