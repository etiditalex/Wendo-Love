import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight EN / Kiswahili copy for Home and membership chrome.
enum AppLang { en, sw }

const _storageKey = 'wendo.lang';

final ValueNotifier<AppLang> appLang = ValueNotifier(AppLang.en);

const _en = {
  'home': 'Home',
  'video': 'Video',
  'matches': 'Matches',
  'mutual': 'Mutual Matches',
  'reverse': 'Reverse Matches',
  'online': 'Online',
  'popular': 'Popular',
  'newest': 'Newest members',
  'latestPhotos': 'Latest Photos',
  'inArea': 'In My Area',
  'bodyStyle': 'Body style',
  'education': 'Education',
  'age': 'Age',
  'seeking': 'Seeking',
  'upgrade': 'About Plus',
  'hi': 'Hi',
  'nextStep': 'Next step: complete your match criteria',
  'lockedLists':
      'Mutual and reverse matches open after you add your gender, who you hope to meet, a city, and a photo.',
  'lockedFilters':
      'Body style and education filters stay locked until an admin activates Wendo Plus for your account.',
  'plusInactive':
      'Wendo Plus is not available to buy in the app yet. An admin will activate or deactivate it later from the dashboard.',
  'completeProfile': 'Complete match criteria',
  'seeUpgrade': 'About Wendo Plus',
  'filtersSoon': 'Those filters open when an admin activates Wendo Plus.',
  'noMembers': 'No members in this view yet. Try another filter.',
  'english': 'English',
  'swahili': 'Kiswahili',
  'tapToCall': 'Tap to call',
  'browse': 'Browse',
};

const _sw = {
  'home': 'Nyumbani',
  'video': 'Video',
  'matches': 'Mechi',
  'mutual': 'Mechi za pande zote',
  'reverse': 'Mechi zilizokupenda',
  'online': 'Mtandaoni',
  'popular': 'Maarufu',
  'newest': 'Wanachama wapya',
  'latestPhotos': 'Picha mpya',
  'inArea': 'Karibu nami',
  'bodyStyle': 'Umbo',
  'education': 'Elimu',
  'age': 'Umri',
  'seeking': 'Natafuta',
  'upgrade': 'Kuhusu Plus',
  'hi': 'Habari',
  'nextStep': 'Hatua inayofuata: kamilisha vigezo vya mechi',
  'lockedLists':
      'Mechi za pande zote na zilizokupenda hufunguka ukiweka jinsia, unayemtafuta, jiji, na picha.',
  'lockedFilters':
      'Vichujio vya umbo na elimu vinabaki vikiwa vimefungwa hadi msimamizi awashe Wendo Plus.',
  'plusInactive':
      'Wendo Plus bado haipatikani kununuliwa kwenye programu. Msimamizi atawasha au kuzima baadaye kutoka dashibodi.',
  'completeProfile': 'Kamilisha vigezo',
  'seeUpgrade': 'Kuhusu Wendo Plus',
  'filtersSoon': 'Vichujio hivyo hufunguka msimamizi anapowasha Wendo Plus.',
  'noMembers': 'Hakuna wanachama katika mwonekano huu. Jaribu kichujio kingine.',
  'english': 'English',
  'swahili': 'Kiswahili',
  'tapToCall': 'Gusa kupiga',
  'browse': 'Vinjari',
};

String t(String key) {
  final table = appLang.value == AppLang.sw ? _sw : _en;
  return table[key] ?? _en[key] ?? key;
}

Future<void> loadAppLang() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_storageKey);
    if (saved == 'sw') appLang.value = AppLang.sw;
    if (saved == 'en') appLang.value = AppLang.en;
  } catch (_) {}
}

Future<void> setAppLang(AppLang lang) async {
  appLang.value = lang;
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, lang == AppLang.sw ? 'sw' : 'en');
  } catch (_) {}
}
