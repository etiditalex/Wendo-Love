import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:upendo_pamoja/backend.dart';
import 'package:upendo_pamoja/domain.dart';
import 'package:upendo_pamoja/places.dart';

/// Shared optional video room (Jitsi). Same match id → same room for both people.
String videoRoomUrlForMatch(String matchId) {
  final cleaned = matchId.replaceAll(RegExp(r'[^a-zA-Z0-9-]'), '');
  final room = cleaned.isEmpty ? 'wendo-room' : 'wendo-$cleaned';
  return 'https://meet.jit.si/$room';
}

String videoRoomUrlForUser(String userId) {
  final cleaned = userId.replaceAll(RegExp(r'[^a-zA-Z0-9-]'), '');
  final room = cleaned.isEmpty ? 'wendo-solo' : 'wendo-u-$cleaned';
  return 'https://meet.jit.si/$room';
}

class MatchThread {
  MatchThread({
    required this.matchId,
    required this.otherUserId,
    required this.name,
    required this.city,
    required this.preview,
    this.age,
    this.lastSeen,
    this.lastAt,
    this.lastSenderId,
    this.online = false,
    this.mutual = false,
    this.unmatched = false,
    this.favorite = false,
    this.photo,
  });

  final String matchId;
  final String otherUserId;
  final String name;
  final String city;
  final String preview;
  final int? age;
  final DateTime? lastSeen;
  final DateTime? lastAt;
  final String? lastSenderId;
  final bool online;
  final bool mutual;
  final bool unmatched;
  bool favorite;
  Uint8List? photo;
}

class ChatLine {
  const ChatLine({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.delivered = true,
    this.read = false,
  });

  final String id;
  final String senderId;
  final String body;
  final DateTime createdAt;
  final bool delivered;
  final bool read;

  ChatLine copyWith({bool? delivered, bool? read}) {
    return ChatLine(
      id: id,
      senderId: senderId,
      body: body,
      createdAt: createdAt,
      delivered: delivered ?? this.delivered,
      read: read ?? this.read,
    );
  }
}

class ChatPeer {
  const ChatPeer({
    required this.userId,
    required this.name,
    this.lastSeen,
    this.online = false,
    this.photo,
  });

  final String userId;
  final String name;
  final DateTime? lastSeen;
  final bool online;
  final Uint8List? photo;
}

class IncomingMessage {
  const IncomingMessage({
    required this.matchId,
    required this.senderId,
    this.body = 'You have an update.',
    this.title = 'Wendo',
  });

  final String matchId;
  final String senderId;
  final String body;
  final String title;
}

class ReceivedLike {
  ReceivedLike({required this.userId, required this.name, required this.city, this.photo});

  final String userId;
  final String name;
  final String city;
  Uint8List? photo;
}

class ProfileViewer {
  ProfileViewer({required this.userId, required this.name, required this.city, this.viewedAt, this.photo});

  final String userId;
  final String name;
  final String city;
  final DateTime? viewedAt;
  Uint8List? photo;
}

/// The chat screen that is open, so a popup is not shown on top of that conversation.
String? activeChatMatchId;

/// Writes the join and setup answers so this member can be suggested to others.
/// Date of birth stays in private identity. HIV status is not written here.
Future<String?> saveMemberProfile() async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null) return null;
  if (user == null) return 'Sign in to publish this profile. Other members cannot see it until you are signed in.';
  final dob = JoinDraft.dateOfBirth;
  if (dob == null || !isAdult(dob)) {
    return 'Confirm you are 18 or over before your profile can be used for matching.';
  }
  var name = JoinDraft.displayName.trim();
  if (name.length < 2) name = 'Member';
  if (name.length > 40) name = name.substring(0, 40);
  final birth =
      '${dob.year.toString().padLeft(4, '0')}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}';
  final intents = ProfileDraft.chosenIntentIds.isEmpty
      ? <String>[JoinDraft.relationshipIntent]
      : ProfileDraft.chosenIntentIds;
  try {
    await client.from('private_identity').upsert({
      'user_id': user.id,
      'date_of_birth': birth,
      'country_code': Places.code(ProfileDraft.country),
    });
    try {
      await client.from('profiles').upsert(_profileRow(user.id, name, intents, detailed: true));
    } catch (_) {
      await client.from('profiles').upsert(_profileRow(user.id, name, intents, detailed: false));
    }
    try {
      await saveProfilePhoto();
    } catch (_) {}
    return null;
  } catch (_) {
    return 'Your profile could not be saved for matching just now. You can save it again from Profile.';
  }
}

Map<String, dynamic> _profileRow(String userId, String name, List<String> intents, {required bool detailed}) {
  final row = <String, dynamic>{
    'user_id': userId,
    'display_name': name,
    'city': ProfileDraft.city,
    'relationship_intent': intents.first,
    'languages': ProfileDraft.language == null ? <String>[] : <String>[ProfileDraft.language!],
    'faith': ProfileDraft.belief,
    'alcohol_preference': ProfileDraft.alcohol,
    'smoking_preference': ProfileDraft.smoking,
    'children_preference': ProfileDraft.children,
    'age_preference_min': ProfileDraft.ageFrom,
    'age_preference_max': ProfileDraft.ageTo,
    'onboarding_completed': true,
    'account_paused': !ProfileDraft.visible,
  };
  if (!detailed) return row;
  const marital = {'Single', 'Separated', 'Widowed', 'Divorced', 'Prefer not to say'};
  const reach = {
    'This area',
    'This city',
    'Anywhere in Kenya',
    'Anywhere in this country',
    'Neighbouring countries',
  };
  row.addAll({
    'home_country': ProfileDraft.country,
    'home_region': ProfileDraft.region,
    'home_area': ProfileDraft.city,
    'pref_country': ProfileDraft.country,
    'pref_region': ProfileDraft.region,
    'pref_city': ProfileDraft.city,
    'connection_reach': reach.contains(ProfileDraft.reach) ? ProfileDraft.reach : 'This city',
    'relationship_intents': intents,
    'marital_status': marital.contains(ProfileDraft.maritalStatus) ? ProfileDraft.maritalStatus : null,
    'what_matters': ProfileDraft.whatMatters,
    'how_to_meet': ProfileDraft.howToMeet,
    'presence': ProfileDraft.presence == 'busy' ? 'busy' : 'online',
  });
  void put(String key, String? value) {
    if (value != null && value.trim().isNotEmpty) row[key] = value.trim();
  }

  put('occupation', ProfileDraft.occupation);
  put('hair_color', ProfileDraft.hairColor);
  put('eye_color', ProfileDraft.eyeColor);
  put('height_label', ProfileDraft.heightLabel);
  put('weight_label', ProfileDraft.weightLabel);
  put('body_type', ProfileDraft.bodyType);
  put('ethnicity', ProfileDraft.ethnicity);
  put('children_count', ProfileDraft.childrenCount);
  put('oldest_child', ProfileDraft.oldestChild);
  put('youngest_child', ProfileDraft.youngestChild);
  put('has_pets', ProfileDraft.hasPets);
  put('employment_status', ProfileDraft.employmentStatus);
  put('income_range', ProfileDraft.incomeRange);
  put('living_situation', ProfileDraft.livingSituation);
  return row;
}

String? _text(dynamic value) {
  if (value is String && value.trim().isNotEmpty) return value.trim();
  return null;
}

void applyOwnProfileRow(Map<String, dynamic> row) {
  final name = _text(row['display_name']);
  if (name != null) JoinDraft.displayName = name;
  final country = _text(row['home_country']);
  final region = _text(row['home_region']);
  final area = _text(row['home_area']) ?? _text(row['city']);
  if (country != null) ProfileDraft.country = country;
  if (region != null) ProfileDraft.region = region;
  if (area != null) {
    ProfileDraft.city = area;
    JoinDraft.city = area;
  }
  final intent = _text(row['relationship_intent']);
  if (intent != null) JoinDraft.relationshipIntent = intent;
  final intents = row['relationship_intents'];
  if (intents is List && intents.isNotEmpty) {
    ProfileDraft.chosenIntentIds = [for (final item in intents) if (item is String && item.isNotEmpty) item];
  }
  final languages = row['languages'];
  if (languages is List && languages.isNotEmpty) {
    final first = languages.whereType<String>().where((item) => item.trim().isNotEmpty);
    if (first.isNotEmpty) ProfileDraft.language = first.first;
  }
  ProfileDraft.belief = _text(row['faith']) ?? ProfileDraft.belief;
  ProfileDraft.alcohol = _text(row['alcohol_preference']) ?? ProfileDraft.alcohol;
  ProfileDraft.smoking = _text(row['smoking_preference']) ?? ProfileDraft.smoking;
  ProfileDraft.children = _text(row['children_preference']) ?? ProfileDraft.children;
  ProfileDraft.maritalStatus = _text(row['marital_status']) ?? ProfileDraft.maritalStatus;
  ProfileDraft.whatMatters = _text(row['what_matters']) ?? ProfileDraft.whatMatters;
  ProfileDraft.howToMeet = _text(row['how_to_meet']) ?? ProfileDraft.howToMeet;
  ProfileDraft.occupation = _text(row['occupation']) ?? ProfileDraft.occupation;
  ProfileDraft.hairColor = _text(row['hair_color']) ?? ProfileDraft.hairColor;
  ProfileDraft.eyeColor = _text(row['eye_color']) ?? ProfileDraft.eyeColor;
  ProfileDraft.heightLabel = _text(row['height_label']) ?? ProfileDraft.heightLabel;
  ProfileDraft.weightLabel = _text(row['weight_label']) ?? ProfileDraft.weightLabel;
  ProfileDraft.bodyType = _text(row['body_type']) ?? ProfileDraft.bodyType;
  ProfileDraft.ethnicity = _text(row['ethnicity']) ?? ProfileDraft.ethnicity;
  ProfileDraft.childrenCount = _text(row['children_count']) ?? ProfileDraft.childrenCount;
  ProfileDraft.oldestChild = _text(row['oldest_child']) ?? ProfileDraft.oldestChild;
  ProfileDraft.youngestChild = _text(row['youngest_child']) ?? ProfileDraft.youngestChild;
  ProfileDraft.hasPets = _text(row['has_pets']) ?? ProfileDraft.hasPets;
  ProfileDraft.employmentStatus = _text(row['employment_status']) ?? ProfileDraft.employmentStatus;
  ProfileDraft.incomeRange = _text(row['income_range']) ?? ProfileDraft.incomeRange;
  ProfileDraft.livingSituation = _text(row['living_situation']) ?? ProfileDraft.livingSituation;
  final answers = row['about_answers'];
  if (answers is Map) {
    ProfileDraft.aboutAnswers
      ..clear()
      ..addAll({
        for (final entry in answers.entries)
          if (entry.key is String && entry.value != null) entry.key as String: '${entry.value}',
      });
  }
  final requested = row['photo_verify_requested_at'];
  if (requested is String) {
    ProfileDraft.photoVerifyRequestedAt = DateTime.tryParse(requested);
  } else if (requested is DateTime) {
    ProfileDraft.photoVerifyRequestedAt = requested;
  }
  final verified = row['photo_verified_at'];
  if (verified is String) {
    ProfileDraft.photoVerifiedAt = DateTime.tryParse(verified);
  } else if (verified is DateTime) {
    ProfileDraft.photoVerifiedAt = verified;
  }
  if (row.containsKey('blur_until_mutual')) {
    ProfileDraft.blurUntilMutual = row['blur_until_mutual'] == true;
  }
}

/// Loads this member's saved profile so Edit Profile can show it.
Future<void> loadOwnProfileDetails() async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return;
  try {
    final row = await client.from('profiles').select().eq('user_id', user.id).maybeSingle();
    if (row != null) applyOwnProfileRow(row);
  } catch (_) {}
  if (JoinDraft.dateOfBirth == null) {
    try {
      final identity = await client.from('private_identity').select('date_of_birth').eq('user_id', user.id).maybeSingle();
      final birth = identity == null ? null : _text(identity['date_of_birth']);
      if (birth != null) {
        final parsed = DateTime.tryParse(birth);
        if (parsed != null) JoinDraft.dateOfBirth = parsed;
      }
    } catch (_) {}
  }
  await loadOwnGallery();
}

Map<String, dynamic> _ownProfileDetails() {
  final intents = ProfileDraft.chosenIntentIds.isEmpty
      ? <String>[JoinDraft.relationshipIntent]
      : ProfileDraft.chosenIntentIds;
  return {
    'display_name': JoinDraft.displayName.trim(),
    'city': ProfileDraft.city,
    'home_country': ProfileDraft.country,
    'home_region': ProfileDraft.region,
    'home_area': ProfileDraft.city,
    'pref_country': ProfileDraft.country,
    'pref_region': ProfileDraft.region,
    'pref_city': ProfileDraft.city,
    'occupation': ProfileDraft.occupation,
    'hair_color': ProfileDraft.hairColor,
    'eye_color': ProfileDraft.eyeColor,
    'height_label': ProfileDraft.heightLabel,
    'weight_label': ProfileDraft.weightLabel,
    'body_type': ProfileDraft.bodyType,
    'ethnicity': ProfileDraft.ethnicity,
    'children_count': ProfileDraft.childrenCount,
    'oldest_child': ProfileDraft.oldestChild,
    'youngest_child': ProfileDraft.youngestChild,
    'children_preference': ProfileDraft.children,
    'has_pets': ProfileDraft.hasPets,
    'employment_status': ProfileDraft.employmentStatus,
    'income_range': ProfileDraft.incomeRange,
    'living_situation': ProfileDraft.livingSituation,
    'relationship_intent': intents.first,
    'relationship_intents': intents,
    'faith': ProfileDraft.belief,
    'languages': ProfileDraft.language == null ? <String>[] : <String>[ProfileDraft.language!],
    'marital_status': ProfileDraft.maritalStatus,
    'what_matters': ProfileDraft.whatMatters,
    'how_to_meet': ProfileDraft.howToMeet,
    'alcohol_preference': ProfileDraft.alcohol,
    'smoking_preference': ProfileDraft.smoking,
    'about_answers': ProfileDraft.aboutAnswers,
  };
}

/// Saves Edit Profile answers. Date of birth and HIV status are not written here.
Future<void> saveOwnProfileDetails() async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return;
  var name = JoinDraft.displayName.trim();
  if (name.length < 2) name = 'Member';
  if (name.length > 40) name = name.substring(0, 40);
  JoinDraft.displayName = name;
  final row = _ownProfileDetails();
  row['display_name'] = name;
  try {
    await client.from('profiles').update(row).eq('user_id', user.id);
  } catch (_) {
    final basic = {
      'display_name': name,
      'city': ProfileDraft.city,
      'home_country': ProfileDraft.country,
      'home_region': ProfileDraft.region,
      'home_area': ProfileDraft.city,
      'occupation': ProfileDraft.occupation,
      'children_preference': ProfileDraft.children,
      'relationship_intent': JoinDraft.relationshipIntent,
      'faith': ProfileDraft.belief,
      'languages': ProfileDraft.language == null ? <String>[] : <String>[ProfileDraft.language!],
      'marital_status': ProfileDraft.maritalStatus,
      'what_matters': ProfileDraft.whatMatters,
      'how_to_meet': ProfileDraft.howToMeet,
      'alcohol_preference': ProfileDraft.alcohol,
      'smoking_preference': ProfileDraft.smoking,
    };
    try {
      await client.from('profiles').update(basic).eq('user_id', user.id);
    } catch (_) {}
  }
  try {
    await client.auth.updateUser(UserAttributes(data: {'display_name': name}));
  } catch (_) {}
}

/// Makes the signed-in member visible on Home. A profile that was only an account
/// login stays hidden from other members until this row exists.
Future<void> ensureDiscoverableProfile() async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return;
  var name = JoinDraft.displayName.trim();
  final meta = user.userMetadata?['display_name'];
  if (name.length < 2 && meta is String && meta.trim().length >= 2) {
    name = meta.trim();
    JoinDraft.displayName = name;
  }
  if (name.length < 2) {
    final local = (user.email ?? '').split('@').first.trim();
    name = local.length >= 2 ? local : 'Member';
  }
  if (name.length > 40) name = name.substring(0, 40);

  final existing = await client.from('profiles').select('onboarding_completed').eq('user_id', user.id).maybeSingle();
  if (existing != null && existing['onboarding_completed'] == true) {
    try {
      await saveProfilePhoto();
    } catch (_) {}
    return;
  }

  final dob = JoinDraft.dateOfBirth;
  if (dob != null && isAdult(dob)) {
    final birth =
        '${dob.year.toString().padLeft(4, '0')}-${dob.month.toString().padLeft(2, '0')}-${dob.day.toString().padLeft(2, '0')}';
    try {
      await client.from('private_identity').upsert({
        'user_id': user.id,
        'date_of_birth': birth,
        'country_code': Places.code(ProfileDraft.country),
      });
    } catch (_) {}
  }

  final city = JoinDraft.city.trim();
  final intent = JoinDraft.relationshipIntent.trim().isEmpty ? 'marriage' : JoinDraft.relationshipIntent;
  final row = <String, dynamic>{
    'user_id': user.id,
    'display_name': name,
    'relationship_intent': intent,
    'onboarding_completed': true,
    'account_paused': false,
  };
  if (city.length >= 2) row['city'] = city;
  try {
    await client.from('profiles').upsert(row);
  } catch (_) {
    row['relationship_intent'] = 'marriage';
    await client.from('profiles').upsert(row);
  }
  try {
    await saveProfilePhoto();
  } catch (_) {}
  await markPresence(online: true);
}

/// Records that this signed-in member has the app open, or the moment they leave.
Future<void> markPresence({required bool online}) async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return;
  try {
    await client.from('profiles').update({
      'is_online': online,
      'last_seen_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('user_id', user.id);
  } catch (_) {}
}

void clearMemberDraft() {
  JoinDraft.displayName = '';
  JoinDraft.email = '';
  JoinDraft.dateOfBirth = null;
  JoinDraft.city = '';
  JoinDraft.relationshipIntent = 'marriage';
  ProfileDraft.photo = null;
  notifyProfilePhotoChanged();
  ProfileDraft.occupation = null;
  ProfileDraft.hairColor = null;
  ProfileDraft.eyeColor = null;
  ProfileDraft.heightLabel = null;
  ProfileDraft.weightLabel = null;
  ProfileDraft.bodyType = null;
  ProfileDraft.ethnicity = null;
  ProfileDraft.childrenCount = null;
  ProfileDraft.oldestChild = null;
  ProfileDraft.youngestChild = null;
  ProfileDraft.hasPets = null;
  ProfileDraft.employmentStatus = null;
  ProfileDraft.incomeRange = null;
  ProfileDraft.livingSituation = null;
  for (var i = 0; i < ProfileDraft.gallery.length; i++) {
    ProfileDraft.gallery[i] = null;
  }
  ProfileDraft.aboutAnswers.clear();
  ProfileDraft.photoVerifyRequestedAt = null;
  ProfileDraft.photoVerifiedAt = null;
}

/// Permanently removes this signed-in account and signs out.
Future<String?> deleteOwnAccount() async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return 'Sign in before deleting this account.';
  try {
    await client.rpc('delete_own_account');
  } catch (error) {
    return error.toString();
  }
  clearMemberDraft();
  try {
    await client.auth.signOut();
  } catch (_) {}
  return null;
}

/// Stores the profile photo for this signed-in member so Home can show it to other members.
/// The bucket stays private. A street address is never part of the photo path.
Future<void> saveProfilePhoto() async {
  final client = supabase;
  final user = client?.auth.currentUser;
  final bytes = ProfileDraft.photo;
  if (client == null || user == null || bytes == null || bytes.isEmpty) return;
  final path = '${user.id}/profile.jpg';
  await client.storage.from('profile-photos').uploadBinary(
    path,
    bytes,
    fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
  );
  _photoCache[user.id] = bytes;
  ProfileDraft.gallery[0] = bytes;
  notifyProfilePhotoChanged();
  final existing = await client.from('profile_photos').select('id').eq('user_id', user.id).limit(1);
  if (existing.isEmpty) {
    await client.from('profile_photos').insert({
      'user_id': user.id,
      'storage_path': path,
      'sort_order': 0,
    });
  } else {
    final id = existing.first['id'];
    await client.from('profile_photos').update({'storage_path': path}).eq('id', id);
  }
}

final Map<String, Uint8List> _pathPhotoCache = {};

String galleryPath(String userId, int index) {
  return index <= 0 ? '$userId/profile.jpg' : '$userId/photo_$index.jpg';
}

Future<Uint8List?> loadStoredBytes(String path) async {
  final cached = _pathPhotoCache[path];
  if (cached != null) return cached;
  final client = supabase;
  if (client == null || path.isEmpty) return null;
  try {
    final bytes = await client.storage.from('profile-photos').download(path);
    if (bytes.isEmpty) return null;
    final data = Uint8List.fromList(bytes);
    _pathPhotoCache[path] = data;
    return data;
  } catch (_) {
    return null;
  }
}

/// Loads this member's main photo and up to four extra photos.
Future<void> loadOwnGallery() async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return;
  final userId = user.id;
  ProfileDraft.gallery[0] = ProfileDraft.photo ?? await loadProfilePhoto(userId);
  ProfileDraft.photo = ProfileDraft.gallery[0];
  try {
    final rows = await client.from('profile_photos').select('storage_path, sort_order').eq('user_id', userId);
    for (final row in rows) {
      final order = (row['sort_order'] as num?)?.toInt();
      final path = row['storage_path'];
      if (order == null || path is! String || order < 0 || order > 4) continue;
      final bytes = await loadStoredBytes(path);
      if (bytes == null) continue;
      ProfileDraft.gallery[order] = bytes;
      if (order == 0) {
        ProfileDraft.photo = bytes;
        _photoCache[userId] = bytes;
      }
    }
  } catch (_) {}
  for (var i = 1; i <= 4; i++) {
    if (ProfileDraft.gallery[i] != null) continue;
    final bytes = await loadStoredBytes(galleryPath(userId, i));
    if (bytes != null) ProfileDraft.gallery[i] = bytes;
  }
  notifyProfilePhotoChanged();
}

/// Stores one gallery photo. Slot 0 is the main profile photo.
Future<void> saveGalleryPhoto(int index, Uint8List bytes) async {
  if (index < 0 || index >= ProfileDraft.gallery.length) return;
  ProfileDraft.gallery[index] = bytes;
  if (index == 0) {
    ProfileDraft.photo = bytes;
    notifyProfilePhotoChanged();
  }
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return;
  final path = galleryPath(user.id, index);
  await client.storage.from('profile-photos').uploadBinary(
    path,
    bytes,
    fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
  );
  _pathPhotoCache[path] = bytes;
  if (index == 0) {
    _photoCache[user.id] = bytes;
    notifyProfilePhotoChanged();
  }
  final existing = await client
      .from('profile_photos')
      .select('id')
      .eq('user_id', user.id)
      .eq('sort_order', index)
      .limit(1);
  if (existing.isEmpty) {
    await client.from('profile_photos').insert({
      'user_id': user.id,
      'storage_path': path,
      'sort_order': index,
    });
  } else {
    await client.from('profile_photos').update({'storage_path': path}).eq('id', existing.first['id']);
  }
}

Future<void> saveAboutAnswers() async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return;
  try {
    await client.from('profiles').update({'about_answers': ProfileDraft.aboutAnswers}).eq('user_id', user.id);
  } catch (_) {}
}

/// Stores a confirmation photo privately for staff review. Not shown on the profile.
Future<String?> saveVerifyPhoto(Uint8List bytes) async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return 'Sign in before sending a confirmation photo.';
  try {
    await client.storage.from('profile-photos').uploadBinary(
      '${user.id}/verify.jpg',
      bytes,
      fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
    );
    final now = DateTime.now().toUtc();
    ProfileDraft.photoVerifyRequestedAt = now;
    // Keep any existing verified badge; a new request waits for staff again only if unset.
    try {
      await client.from('profiles').update({
        'photo_verify_requested_at': now.toIso8601String(),
        'photo_verified_at': null,
      }).eq('user_id', user.id);
      ProfileDraft.photoVerifiedAt = null;
    } catch (_) {
      try {
        await client.from('profiles').update({
          'photo_verify_requested_at': now.toIso8601String(),
        }).eq('user_id', user.id);
      } catch (_) {}
    }
    return null;
  } catch (_) {
    return 'The confirmation photo could not be stored just now.';
  }
}

Future<String?> saveBlurUntilMutual(bool value) async {
  ProfileDraft.blurUntilMutual = value;
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return null;
  try {
    await client.from('profiles').update({'blur_until_mutual': value}).eq('user_id', user.id);
    return null;
  } catch (_) {
    return 'That privacy choice could not be saved just now.';
  }
}

Future<Map<String, dynamic>?> exportOwnAccount() async {
  final client = supabase;
  if (client == null || client.auth.currentUser == null) return null;
  try {
    final data = await client.rpc('export_own_account');
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
  } catch (_) {}
  return null;
}

Future<List<Map<String, dynamic>>> loadTrustedContacts() async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return const [];
  try {
    final rows = await client
        .from('trusted_contacts')
        .select('id, display_name, phone, created_at')
        .eq('user_id', user.id)
        .order('created_at');
    return [for (final row in rows) Map<String, dynamic>.from(row)];
  } catch (_) {
    return const [];
  }
}

Future<String?> saveTrustedContact({required String name, required String phone}) async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return 'Sign in first.';
  final cleanedName = name.trim();
  final cleanedPhone = phone.trim();
  if (cleanedName.isEmpty || cleanedPhone.isEmpty) return 'Add a name and phone number.';
  try {
    await client.from('trusted_contacts').insert({
      'user_id': user.id,
      'display_name': cleanedName,
      'phone': cleanedPhone,
    });
    return null;
  } catch (_) {
    return 'That contact could not be saved just now.';
  }
}

Future<String?> deleteTrustedContact(String id) async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null || id.isEmpty) return 'Sign in first.';
  try {
    await client.from('trusted_contacts').delete().eq('id', id).eq('user_id', user.id);
    return null;
  } catch (_) {
    return 'That contact could not be removed just now.';
  }
}

Future<List<Map<String, dynamic>>> loadMeetingCheckins() async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return const [];
  try {
    final rows = await client
        .from('meeting_checkins')
        .select('id, place_note, planned_at, status, created_at, updated_at')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);
    return [for (final row in rows) Map<String, dynamic>.from(row)];
  } catch (_) {
    return const [];
  }
}

Future<String?> saveMeetingCheckin({
  required String placeNote,
  DateTime? plannedAt,
  String status = 'planned',
}) async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return 'Sign in first.';
  try {
    await client.from('meeting_checkins').insert({
      'user_id': user.id,
      'place_note': placeNote.trim().isEmpty ? null : placeNote.trim(),
      if (plannedAt != null) 'planned_at': plannedAt.toUtc().toIso8601String(),
      'status': status,
    });
    return null;
  } catch (_) {
    return 'That check-in could not be saved just now.';
  }
}

Future<String?> updateMeetingCheckinStatus(String id, String status) async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null || id.isEmpty) return 'Sign in first.';
  try {
    await client.from('meeting_checkins').update({
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id).eq('user_id', user.id);
    return null;
  } catch (_) {
    return 'That check-in could not be updated just now.';
  }
}

Future<List<Map<String, dynamic>>> loadPartnerResources() async {
  final client = supabase;
  if (client == null) return const [];
  try {
    final rows = await client
        .from('partner_resources')
        .select('id, kind, title, summary, url, region, sort_order')
        .eq('active', true)
        .order('sort_order');
    return [for (final row in rows) Map<String, dynamic>.from(row)];
  } catch (_) {
    return const [];
  }
}

Future<String?> registerPremiumInterest({String plan = 'wendo_plus', String note = ''}) async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return 'Sign in first.';
  try {
    await client.from('premium_interest').upsert({
      'user_id': user.id,
      'plan': plan,
      if (note.trim().isNotEmpty) 'note': note.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
    return null;
  } catch (_) {
    return 'Interest could not be saved just now.';
  }
}

/// Registers a device token row for future FCM/APNs delivery.
/// Until a push provider is wired, stores a stable local device id as the token.
Future<void> registerDevicePushToken({String platform = 'android'}) async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return;
  try {
    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString('wendo_device_push_token');
    if (token == null || token.isEmpty) {
      token = 'local-${user.id}-${DateTime.now().millisecondsSinceEpoch}';
      await prefs.setString('wendo_device_push_token', token);
    }
    await client.from('device_push_tokens').upsert(
      {
        'user_id': user.id,
        'token': token,
        'platform': platform,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'user_id,token',
    );
  } catch (_) {}
}

Future<bool> isStaffMember() async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return false;
  try {
    final row = await client.from('staff_roles').select('role').eq('user_id', user.id).maybeSingle();
    return row != null;
  } catch (_) {
    return false;
  }
}

Future<List<Map<String, dynamic>>> loadModerationQueue() async {
  final client = supabase;
  if (client == null) return const [];
  try {
    final rows = await client.rpc('moderation_queue');
    if (rows is! List) return const [];
    return [for (final row in rows) if (row is Map) Map<String, dynamic>.from(row)];
  } catch (_) {
    return const [];
  }
}

Future<List<Map<String, dynamic>>> loadPhotoVerifyQueue() async {
  final client = supabase;
  if (client == null) return const [];
  try {
    final rows = await client.rpc('photo_verify_queue');
    if (rows is! List) return const [];
    return [for (final row in rows) if (row is Map) Map<String, dynamic>.from(row)];
  } catch (_) {
    return const [];
  }
}

Future<String?> setReportStatus(String reportId, String status) async {
  final client = supabase;
  if (client == null) return 'Not signed in.';
  try {
    await client.rpc('set_report_status', params: {'report_id': reportId, 'next_status': status});
    return null;
  } catch (_) {
    return 'Status could not be updated.';
  }
}

Future<String?> approvePhotoVerify(String userId) async {
  final client = supabase;
  if (client == null) return 'Not signed in.';
  try {
    await client.rpc('approve_photo_verify', params: {'target_user': userId});
    return null;
  } catch (_) {
    return 'Verify could not be approved.';
  }
}

Future<List<Map<String, dynamic>>> loadBlockedPeople() async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return const [];
  try {
    final rows = await client.from('blocks').select('blocked_id, created_at').eq('blocker_id', user.id);
    final ids = <String>[
      for (final row in rows)
        if (row['blocked_id'] is String) row['blocked_id'] as String,
    ];
    if (ids.isEmpty) return const [];
    final profiles = await client.from('profiles').select('user_id, display_name, city').inFilter('user_id', ids);
    final names = <String, Map<String, dynamic>>{
      for (final row in profiles)
        if (row['user_id'] is String) row['user_id'] as String: row,
    };
    return [
      for (final id in ids)
        {
          'user_id': id,
          'display_name': (names[id]?['display_name'] as String?)?.trim().isNotEmpty == true
              ? names[id]!['display_name']
              : 'Member',
          'city': names[id]?['city'] ?? '',
        },
    ];
  } catch (_) {
    return const [];
  }
}

Future<String?> unblockPerson(String otherUserId) async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return 'Sign in first.';
  try {
    await client.from('blocks').delete().eq('blocker_id', user.id).eq('blocked_id', otherUserId);
    return null;
  } catch (_) {
    return 'That block could not be removed.';
  }
}

Future<String?> addFavorite(String otherUserId) async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return 'Sign in first.';
  try {
    await client.from('favorites').insert({'owner_id': user.id, 'favorite_id': otherUserId});
    return null;
  } catch (_) {
    return 'Favorite could not be saved.';
  }
}

Future<String?> removeFavorite(String otherUserId) async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return 'Sign in first.';
  try {
    await client.from('favorites').delete().eq('owner_id', user.id).eq('favorite_id', otherUserId);
    return null;
  } catch (_) {
    return 'Favorite could not be removed.';
  }
}

Future<List<ReceivedLike>> loadFavoritePeople() async {
  final ids = await loadFavoriteIds();
  if (ids.isEmpty) return const [];
  final client = supabase;
  if (client == null) return const [];
  try {
    final profiles = await client.from('profiles').select('user_id, display_name, city').inFilter('user_id', ids.toList());
    await loadProfilePhotos(ids.toList());
    return [
      for (final row in profiles)
        if (row['user_id'] is String)
          ReceivedLike(
            userId: row['user_id'] as String,
            name: (row['display_name'] as String?)?.trim().isNotEmpty == true
                ? row['display_name'] as String
                : 'Member',
            city: (row['city'] as String?) ?? '',
            photo: cachedProfilePhoto(row['user_id'] as String),
          ),
    ];
  } catch (_) {
    return const [];
  }
}

/// Hides this person from the passer's Home feed. The other person is not told.
Future<String?> passPerson(String otherUserId) async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return 'Sign in before you pass.';
  if (otherUserId.isEmpty || otherUserId == user.id) return 'Choose another member.';
  try {
    await client.from('passes').upsert({'from_user': user.id, 'to_user': otherUserId});
    return null;
  } catch (_) {
    return 'That pass could not be saved just now.';
  }
}

Future<Set<String>> loadPassedIds() async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return {};
  try {
    final rows = await client.from('passes').select('to_user').eq('from_user', user.id);
    return {
      for (final row in rows)
        if (row['to_user'] is String) row['to_user'] as String,
    };
  } catch (_) {
    return {};
  }
}

/// Saves a report for review. This is not a block.
Future<String?> reportPerson({
  required String otherUserId,
  required String reason,
  String details = '',
}) async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return 'Sign in before you report.';
  if (otherUserId.isEmpty || otherUserId == user.id) return 'Choose another member.';
  try {
    await client.from('reports').insert({
      'reporter_id': user.id,
      'reported_user_id': otherUserId,
      'reason': reason,
      if (details.trim().isNotEmpty) 'details': details.trim(),
    });
    return null;
  } catch (_) {
    return 'The report could not be sent just now.';
  }
}

Future<bool> isMutualWith(String otherUserId) async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null || otherUserId.isEmpty) return false;
  final first = user.id.compareTo(otherUserId) < 0 ? user.id : otherUserId;
  final second = user.id.compareTo(otherUserId) < 0 ? otherUserId : user.id;
  try {
    final row = await client
        .from('matches')
        .select('is_mutual')
        .eq('user_a', first)
        .eq('user_b', second)
        .isFilter('unmatched_at', null)
        .maybeSingle();
    return row?['is_mutual'] == true;
  } catch (_) {
    return false;
  }
}

/// Paths of photos saved with each account. The usual file is `{user id}/profile.jpg`.
Future<Map<String, String>> loadProfilePhotoPaths() async {
  final client = supabase;
  if (client == null || client.auth.currentUser == null) return const {};
  final paths = <String, String>{};
  void take(dynamic rows) {
    if (rows is! List) return;
    for (final row in rows) {
      if (row is! Map) continue;
      final id = row['user_id'];
      final path = row['storage_path'];
      if (id is String && path is String && path.isNotEmpty) paths[id] = path;
    }
  }

  try {
    take(await client.from('profile_photos').select('user_id, storage_path'));
  } catch (_) {}
  try {
    take(await client.rpc('profile_photo_paths'));
  } catch (_) {}
  return paths;
}

final Map<String, Uint8List> _photoCache = {};
final Map<String, Future<Uint8List?>> _photoLoads = {};

/// The photo saved when this account was created, from its private profile-photo file.
/// Works for people already in the app and for accounts created later.
Future<Uint8List?> loadProfilePhoto(String userId, {String? storagePath}) {
  if (userId.isEmpty) return Future<Uint8List?>.value(null);
  final cached = _photoCache[userId];
  if (cached != null) return Future<Uint8List?>.value(cached);
  return _photoLoads.putIfAbsent(userId, () => _downloadProfilePhoto(userId, storagePath));
}

Future<Uint8List?> _downloadProfilePhoto(String userId, String? storagePath) async {
  final client = supabase;
  if (client == null) {
    _photoLoads.remove(userId);
    return null;
  }
  final candidates = <String>{
    if (storagePath != null && storagePath.isNotEmpty) storagePath,
    '$userId/profile.jpg',
    '$userId/profile.jpeg',
    '$userId/profile.png',
  };
  for (final path in candidates) {
    try {
      final bytes = await client.storage.from('profile-photos').download(path);
      if (bytes.isNotEmpty) {
        final data = Uint8List.fromList(bytes);
        _photoCache[userId] = data;
        _photoLoads.remove(userId);
        return data;
      }
    } catch (_) {}
  }
  _photoLoads.remove(userId);
  return null;
}

Future<void> loadProfilePhotos(Iterable<String> userIds, {Map<String, String>? paths}) async {
  final missing = <String>[];
  for (final id in userIds) {
    if (id.isEmpty || _photoCache.containsKey(id)) continue;
    missing.add(id);
  }
  if (missing.isEmpty) return;
  for (var i = 0; i < missing.length; i += 10) {
    await Future.wait([
      for (final id in missing.skip(i).take(10)) loadProfilePhoto(id, storagePath: paths?[id]),
    ]);
  }
}

Uint8List? cachedProfilePhoto(String userId) => _photoCache[userId];

Future<List<MatchThread>> loadMatchThreads() async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return const [];
  List<dynamic> matches = [];
  try {
    matches = await client.from('matches').select('id, user_a, user_b, is_mutual, unmatched_at');
  } catch (_) {
    try {
      matches = await client.from('matches').select('id, user_a, user_b, is_mutual').isFilter('unmatched_at', null);
    } catch (_) {
      matches = await client.from('matches').select('id, user_a, user_b').isFilter('unmatched_at', null);
    }
  }
  final others = <String, String>{};
  final mutualIds = <String>{};
  final unmatchedIds = <String>{};
  for (final row in matches) {
    final id = row['id'];
    final a = row['user_a'];
    final b = row['user_b'];
    if (id is! String) continue;
    if (a == user.id && b is String) others[id] = b;
    if (b == user.id && a is String) others[id] = a;
    if (row['is_mutual'] == true) mutualIds.add(id);
    if (row['unmatched_at'] != null) unmatchedIds.add(id);
  }
  if (others.isEmpty) return const [];
  List<Map<String, dynamic>> profiles = [];
  try {
    profiles = List<Map<String, dynamic>>.from(
      await client.from('profiles').select('user_id, display_name, city, is_online, last_seen_at').inFilter('user_id', others.values.toList()),
    );
  } catch (_) {
    profiles = List<Map<String, dynamic>>.from(
      await client.from('profiles').select('user_id, display_name, city').inFilter('user_id', others.values.toList()),
    );
  }
  final names = <String, Map<String, dynamic>>{
    for (final row in profiles)
      if (row['user_id'] is String) row['user_id'] as String: row,
  };
  final messages = await client
      .from('messages')
      .select('match_id, sender_id, body, created_at')
      .inFilter('match_id', others.keys.toList())
      .order('created_at');
  final preview = <String, String>{};
  final lastAt = <String, DateTime>{};
  final lastSender = <String, String>{};
  for (final row in messages) {
    final matchId = row['match_id'];
    final body = row['body'];
    if (matchId is! String || body is! String) continue;
    preview[matchId] = body;
    lastAt[matchId] = DateTime.tryParse('${row['created_at']}')?.toLocal() ?? DateTime.now();
    if (row['sender_id'] is String) lastSender[matchId] = row['sender_id'] as String;
  }
  final ages = <String, int>{};
  try {
    final cards = await client.rpc('discovery_cards');
    if (cards is List) {
      for (final row in cards) {
        if (row is! Map) continue;
        final id = row['user_id'];
        final age = row['age_years'];
        if (id is String && age is num) ages[id] = age.toInt();
      }
    }
  } catch (_) {}
  final favoriteIds = await loadFavoriteIds();
  final threads = [
    for (final entry in others.entries)
      MatchThread(
        matchId: entry.key,
        otherUserId: entry.value,
        name: (names[entry.value]?['display_name'] as String?)?.trim().isNotEmpty == true
            ? names[entry.value]!['display_name'] as String
            : 'Member',
        city: (names[entry.value]?['city'] as String?) ?? '',
        preview: preview[entry.key] ?? '',
        age: ages[entry.value],
        lastSeen: DateTime.tryParse('${names[entry.value]?['last_seen_at']}'),
        lastAt: lastAt[entry.key],
        lastSenderId: lastSender[entry.key],
        online: names[entry.value]?['is_online'] == true,
        mutual: mutualIds.contains(entry.key),
        unmatched: unmatchedIds.contains(entry.key),
        favorite: favoriteIds.contains(entry.value),
        photo: cachedProfilePhoto(entry.value),
      ),
  ];
  threads.sort((a, b) {
    final aTime = a.lastAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final bTime = b.lastAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return bTime.compareTo(aTime);
  });
  return threads;
}

Future<Set<String>> loadFavoriteIds() async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return {};
  try {
    final rows = await client.from('favorites').select('favorite_id').eq('owner_id', user.id);
    return {
      for (final row in rows)
        if (row['favorite_id'] is String) row['favorite_id'] as String,
    };
  } catch (_) {
    return {};
  }
}

Future<DateTime?> loadThreadReadAt({required String matchId, required String userId}) async {
  final client = supabase;
  if (client == null || matchId.isEmpty || userId.isEmpty) return null;
  try {
    final row = await client
        .from('message_reads')
        .select('read_at')
        .eq('match_id', matchId)
        .eq('user_id', userId)
        .maybeSingle();
    return DateTime.tryParse('${row?['read_at']}')?.toLocal();
  } catch (_) {
    return null;
  }
}

Future<List<ChatLine>> loadMessages(String matchId, {String? otherUserId}) async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null) return const [];
  final rows = await client.from('messages').select('id, sender_id, body, created_at').eq('match_id', matchId).order('created_at');
  DateTime? otherReadAt;
  if (otherUserId != null && otherUserId.isNotEmpty) {
    otherReadAt = await loadThreadReadAt(matchId: matchId, userId: otherUserId);
  }
  final lines = <ChatLine>[];
  for (final row in rows) {
    if (row['id'] is! String || row['sender_id'] is! String || row['body'] is! String) continue;
    final createdAt = DateTime.tryParse('${row['created_at']}')?.toLocal() ?? DateTime.now();
    final mine = user != null && row['sender_id'] == user.id;
    final read = mine && otherReadAt != null && !createdAt.isAfter(otherReadAt);
    lines.add(
      ChatLine(
        id: row['id'] as String,
        senderId: row['sender_id'] as String,
        body: row['body'] as String,
        createdAt: createdAt,
        delivered: true,
        read: read,
      ),
    );
  }
  return lines;
}

Future<ChatLine?> sendMessage(String matchId, String body, {String? otherUserId}) async {
  final client = supabase;
  final user = client?.auth.currentUser;
  final text = body.trim();
  if (client == null || user == null || text.isEmpty) return null;
  final row = await client
      .from('messages')
      .insert({'match_id': matchId, 'sender_id': user.id, 'body': text})
      .select('id, sender_id, body, created_at')
      .single();
  final createdAt = DateTime.tryParse('${row['created_at']}')?.toLocal() ?? DateTime.now();
  var read = false;
  if (otherUserId != null && otherUserId.isNotEmpty) {
    final otherReadAt = await loadThreadReadAt(matchId: matchId, userId: otherUserId);
    read = otherReadAt != null && !createdAt.isAfter(otherReadAt);
  }
  return ChatLine(
    id: row['id'] as String,
    senderId: row['sender_id'] as String,
    body: row['body'] as String,
    createdAt: createdAt,
    delivered: true,
    read: read,
  );
}

Future<ChatPeer?> loadChatPeer(String userId) async {
  final client = supabase;
  if (client == null || userId.isEmpty) return null;
  Map<String, dynamic>? row;
  try {
    row = await client.from('profiles').select('user_id, display_name, is_online, last_seen_at').eq('user_id', userId).maybeSingle();
  } catch (_) {
    row = await client.from('profiles').select('user_id, display_name').eq('user_id', userId).maybeSingle();
  }
  if (row == null) return null;
  final name = (row['display_name'] as String?)?.trim().isNotEmpty == true ? row['display_name'] as String : 'Member';
  final photo = await loadProfilePhoto(userId);
  return ChatPeer(
    userId: userId,
    name: name,
    lastSeen: DateTime.tryParse('${row['last_seen_at']}'),
    online: row['is_online'] == true,
    photo: photo,
  );
}

Future<void> endMatch(String matchId) async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return;
  await client.from('matches').update({
    'unmatched_at': DateTime.now().toUtc().toIso8601String(),
    'unmatched_by': user.id,
  }).eq('id', matchId);
}

Future<void> blockPerson(String otherUserId, String matchId) async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return;
  await client.from('blocks').insert({'blocker_id': user.id, 'blocked_id': otherUserId});
  await endMatch(matchId);
}

/// Opens a conversation with another member. They do not need to be in the app.
Future<String?> openConversation(String otherUserId) async {
  final client = supabase;
  if (client == null || client.auth.currentUser == null || otherUserId.isEmpty) return null;
  final id = await client.rpc('open_conversation', params: {'other_user': otherUserId});
  return id is String ? id : null;
}

Future<List<ReceivedLike>> loadReceivedLikes() {
  return _loadLikes(column: 'from_user', match: 'to_user');
}

Future<List<ReceivedLike>> loadSentLikes() {
  return _loadLikes(column: 'to_user', match: 'from_user');
}

Future<List<ReceivedLike>> _loadLikes({required String column, required String match}) async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return const [];
  final likes = await client.from('likes').select(column).eq(match, user.id).order('created_at', ascending: false);
  final ids = <String>[
    for (final row in likes)
      if (row[column] is String) row[column] as String,
  ];
  if (ids.isEmpty) return const [];
  final profiles = await client.from('profiles').select('user_id, display_name, city').inFilter('user_id', ids);
  final names = <String, Map<String, dynamic>>{
    for (final row in profiles)
      if (row['user_id'] is String) row['user_id'] as String: row,
  };
  return [
    for (final id in ids)
      ReceivedLike(
        userId: id,
        name: (names[id]?['display_name'] as String?)?.trim().isNotEmpty == true ? names[id]!['display_name'] as String : 'Member',
        city: (names[id]?['city'] as String?) ?? '',
        photo: cachedProfilePhoto(id),
      ),
  ];
}

final inboxChanged = ValueNotifier<int>(0);

/// Bumps when this member's profile photo is loaded or changed so the nav icon refreshes.
final profilePhotoChanged = ValueNotifier<int>(0);

void notifyProfilePhotoChanged() {
  profilePhotoChanged.value++;
}

/// Loads this signed-in member's main photo into ProfileDraft and the nav icon.
Future<void> ensureOwnProfilePhoto() async {
  final userId = supabase?.auth.currentUser?.id;
  if (userId == null) return;
  if (ProfileDraft.photo != null) {
    notifyProfilePhotoChanged();
    return;
  }
  final cached = cachedProfilePhoto(userId);
  if (cached != null) {
    ProfileDraft.photo = cached;
    ProfileDraft.gallery[0] = cached;
    notifyProfilePhotoChanged();
    return;
  }
  final bytes = await loadProfilePhoto(userId);
  if (bytes == null) return;
  ProfileDraft.photo = bytes;
  ProfileDraft.gallery[0] = bytes;
  notifyProfilePhotoChanged();
}

class InboxCounts {
  const InboxCounts({required this.likes, required this.messages, this.views = 0});

  final int likes;
  final int messages;
  final int views;
}

Future<InboxCounts> loadInboxCounts() async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return const InboxCounts(likes: 0, messages: 0);
  var likes = 0;
  var views = 0;
  try {
    final rows = await client.from('likes').select('from_user').eq('to_user', user.id);
    likes = rows.length;
  } catch (_) {}
  try {
    final rows = await client.from('profile_views').select('viewer_id').eq('viewed_id', user.id);
    views = rows.length;
  } catch (_) {
    try {
      final rows = await client.rpc('list_profile_viewers');
      if (rows is List) views = rows.length;
    } catch (_) {}
  }
  final messages = (await _unseenMessages()).length;
  return InboxCounts(likes: likes, messages: messages, views: views);
}

Future<void> recordProfileView(String otherUserId) async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null || otherUserId.isEmpty || otherUserId == user.id) return;
  try {
    await client.rpc('record_profile_view', params: {'other_user': otherUserId});
    return;
  } catch (_) {}
  try {
    await client.from('profile_views').upsert({
      'viewer_id': user.id,
      'viewed_id': otherUserId,
      'viewed_at': DateTime.now().toUtc().toIso8601String(),
    });
  } catch (_) {}
}

Future<List<ProfileViewer>> loadProfileViewers() {
  return _loadProfileViews(
    rpc: 'list_profile_viewers',
    fallbackColumn: 'viewer_id',
    matchColumn: 'viewed_id',
  );
}

Future<List<ProfileViewer>> loadViewedProfiles() {
  return _loadProfileViews(
    rpc: 'list_viewed_profiles',
    fallbackColumn: 'viewed_id',
    matchColumn: 'viewer_id',
  );
}

Future<List<ProfileViewer>> _loadProfileViews({
  required String rpc,
  required String fallbackColumn,
  required String matchColumn,
}) async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return const [];
  var rows = <dynamic>[];
  try {
    final result = await client.rpc(rpc);
    if (result is List) rows = result;
  } catch (_) {
    try {
      rows = await client
          .from('profile_views')
          .select('$fallbackColumn, viewed_at')
          .eq(matchColumn, user.id)
          .order('viewed_at', ascending: false);
    } catch (_) {
      return const [];
    }
  }
  final ids = <String>[];
  final names = <String, String>{};
  final cities = <String, String>{};
  final seenAt = <String, DateTime?>{};
  for (final row in rows) {
    if (row is! Map) continue;
    final id = row['user_id'] ?? row[fallbackColumn];
    if (id is! String || ids.contains(id)) continue;
    ids.add(id);
    final name = (row['display_name'] as String?)?.trim();
    if (name != null && name.isNotEmpty) names[id] = name;
    final city = row['city'];
    if (city is String) cities[id] = city;
    seenAt[id] = DateTime.tryParse('${row['viewed_at']}');
  }
  if (ids.isEmpty) return const [];
  try {
    final found = await client.from('profiles').select('user_id, display_name, city').inFilter('user_id', ids);
    for (final row in found) {
      final id = row['user_id'];
      if (id is! String) continue;
      final name = (row['display_name'] as String?)?.trim();
      if (name != null && name.isNotEmpty) names[id] = name;
      final city = row['city'];
      if (city is String && city.isNotEmpty) cities[id] = city;
    }
  } catch (_) {}
  await loadProfilePhotos(ids);
  return [
    for (final id in ids)
      ProfileViewer(
        userId: id,
        name: names[id] ?? 'Member',
        city: cities[id] ?? '',
        viewedAt: seenAt[id],
        photo: cachedProfilePhoto(id),
      ),
  ];
}

Future<void> markThreadRead(String matchId) async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null || matchId.isEmpty) return;
  final now = DateTime.now().toUtc().toIso8601String();
  try {
    await client.from('message_reads').upsert({
      'user_id': user.id,
      'match_id': matchId,
      'read_at': now,
    });
  } catch (_) {}
  inboxChanged.value++;
}

/// Messages from other people that this member has not opened yet. Newest first.
Future<List<IncomingMessage>> _unseenMessages() async {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return const [];
  try {
    final matches = await client.from('matches').select('id, user_a, user_b').isFilter('unmatched_at', null);
    final matchIds = <String>[];
    for (final row in matches) {
      final id = row['id'];
      if (id is! String) continue;
      if (row['user_a'] == user.id || row['user_b'] == user.id) matchIds.add(id);
    }
    if (matchIds.isEmpty) return const [];
    final readAt = <String, DateTime>{};
    try {
      final reads = await client.from('message_reads').select('match_id, read_at').eq('user_id', user.id);
      for (final row in reads) {
        final id = row['match_id'];
        final at = DateTime.tryParse('${row['read_at']}');
        if (id is String && at != null) readAt[id] = at.toLocal();
      }
    } catch (_) {}
    final rows = await client
        .from('messages')
        .select('match_id, sender_id, body, created_at')
        .inFilter('match_id', matchIds)
        .neq('sender_id', user.id)
        .order('created_at', ascending: false)
        .limit(200);
    final unseen = <IncomingMessage>[];
    for (final row in rows) {
      final matchId = row['match_id'];
      final senderId = row['sender_id'];
      final body = row['body'];
      final created = DateTime.tryParse('${row['created_at']}')?.toLocal();
      if (matchId is! String || senderId is! String || body is! String || created == null) continue;
      final seen = readAt[matchId];
      if (seen != null && !created.isAfter(seen)) continue;
      unseen.add(IncomingMessage(matchId: matchId, senderId: senderId));
    }
    return unseen;
  } catch (_) {}
  return const [];
}

/// The newest message from someone else that this member has not opened yet.
Future<IncomingMessage?> loadUnseenMessage() async {
  final rows = await _unseenMessages();
  return rows.isEmpty ? null : rows.first;
}

RealtimeChannel? watchIncomingLikes(void Function(String fromUserId) onLike) {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return null;
  return client
      .channel('likes-${user.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'likes',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'to_user', value: user.id),
        callback: (payload) {
          final fromUser = payload.newRecord['from_user'];
          if (fromUser is String && fromUser != user.id) onLike(fromUser);
        },
      )
      .subscribe();
}

RealtimeChannel? watchIncomingMessages(void Function(IncomingMessage message) onMessage) {
  final client = supabase;
  final user = client?.auth.currentUser;
  if (client == null || user == null) return null;
  return client
      .channel('inbox-${user.id}')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        callback: (payload) {
          final row = payload.newRecord;
          final matchId = row['match_id'];
          final senderId = row['sender_id'];
          final body = row['body'];
          if (matchId is String && senderId is String && body is String && senderId != user.id) {
            onMessage(IncomingMessage(matchId: matchId, senderId: senderId));
          }
        },
      )
      .subscribe();
}

RealtimeChannel? watchMessages(String matchId, void Function(ChatLine line) onLine) {
  final client = supabase;
  if (client == null) return null;
  return client
      .channel('match-$matchId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'messages',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'match_id', value: matchId),
        callback: (payload) {
          final row = payload.newRecord;
          final id = row['id'];
          final senderId = row['sender_id'];
          final body = row['body'];
          if (id is String && senderId is String && body is String) {
            onLine(ChatLine(
              id: id,
              senderId: senderId,
              body: body,
              createdAt: DateTime.tryParse('${row['created_at']}')?.toLocal() ?? DateTime.now(),
              delivered: true,
            ));
          }
        },
      )
      .subscribe();
}

RealtimeChannel? watchThreadReads(String matchId, String otherUserId, void Function(DateTime readAt) onRead) {
  final client = supabase;
  if (client == null || matchId.isEmpty || otherUserId.isEmpty) return null;
  return client
      .channel('reads-$matchId-$otherUserId')
      .onPostgresChanges(
        event: PostgresChangeEvent.insert,
        schema: 'public',
        table: 'message_reads',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'match_id', value: matchId),
        callback: (payload) {
          final row = payload.newRecord;
          if (row['user_id'] != otherUserId) return;
          final at = DateTime.tryParse('${row['read_at']}')?.toLocal();
          if (at != null) onRead(at);
        },
      )
      .onPostgresChanges(
        event: PostgresChangeEvent.update,
        schema: 'public',
        table: 'message_reads',
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'match_id', value: matchId),
        callback: (payload) {
          final row = payload.newRecord;
          if (row['user_id'] != otherUserId) return;
          final at = DateTime.tryParse('${row['read_at']}')?.toLocal();
          if (at != null) onRead(at);
        },
      )
      .subscribe();
}
