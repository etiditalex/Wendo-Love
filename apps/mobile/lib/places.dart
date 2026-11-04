import 'package:upendo_pamoja/places_data.dart';

class PlaceChoice {
  const PlaceChoice({required this.country, required this.region, required this.area});

  final String country;
  final String region;
  final String area;
}

/// Country, then region or Kenyan county, then a broad area.
/// Names only. This does not hold a precise address or a map coordinate.
class Places {
  static Map<String, String>? _codes;
  static Map<String, Map<String, List<String>>>? _tree;
  static List<String>? _countries;

  static void _ensure() {
    if (_tree != null) return;
    final codes = <String, String>{};
    final tree = <String, Map<String, List<String>>>{};
    Map<String, List<String>>? regions;
    String? region;
    for (final raw in placeCatalog.split('\n')) {
      final line = raw.trimRight();
      if (line.isEmpty) continue;
      if (line.startsWith('*')) {
        region = line.substring(1);
        regions![region] = <String>[];
      } else if (line.startsWith('-')) {
        regions![region]!.add(line.substring(1));
      } else {
        final bar = line.indexOf('|');
        final country = line.substring(0, bar);
        codes[country] = line.substring(bar + 1);
        regions = <String, List<String>>{};
        tree[country] = regions;
        region = null;
      }
    }
    final names = tree.keys.where((name) => name != 'Kenya').toList()..sort();
    _codes = codes;
    _tree = tree;
    _countries = [if (tree.containsKey('Kenya')) 'Kenya', ...names];
  }

  static List<String> get countries {
    _ensure();
    return _countries!;
  }

  static List<String> regions(String country) {
    _ensure();
    final found = _tree![country];
    if (found == null || found.isEmpty) return const ['Main area'];
    return found.keys.toList();
  }

  static List<String> areas(String country, String region) {
    _ensure();
    final found = _tree![country]?[region];
    if (found == null || found.isEmpty) return const ['Wider area'];
    return found;
  }

  static String code(String country) {
    _ensure();
    return _codes![country] ?? 'KE';
  }

  static String regionLabel(String country) => country == 'Kenya' ? 'County' : 'Region';

  static PlaceChoice resolve({String? country, String? region, String? area}) {
    _ensure();
    final chosenCountry = _tree!.containsKey(country) ? country! : 'Kenya';
    final regionList = regions(chosenCountry);
    final chosenRegion = regionList.contains(region) ? region! : (regionList.contains('Nairobi') ? 'Nairobi' : regionList.first);
    final areaList = areas(chosenCountry, chosenRegion);
    final chosenArea = areaList.contains(area) ? area! : _fallbackArea(chosenCountry, chosenRegion, areaList);
    return PlaceChoice(country: chosenCountry, region: chosenRegion, area: chosenArea);
  }

  static PlaceChoice find(String saved) {
    final needle = saved.trim().toLowerCase();
    if (needle.isEmpty) return resolve();
    _ensure();
    for (final country in _countries!) {
      for (final region in _tree![country]!.keys) {
        if (region.toLowerCase() == needle) {
          return resolve(country: country, region: region);
        }
        for (final area in _tree![country]![region]!) {
          final pair = '$area, $region'.toLowerCase();
          if (area.toLowerCase() == needle || pair == needle) {
            return PlaceChoice(country: country, region: region, area: area);
          }
        }
      }
    }
    return resolve();
  }

  static String _fallbackArea(String country, String region, List<String> areaList) {
    if (country == 'Kenya' && region == 'Nairobi' && areaList.contains('Kilimani')) return 'Kilimani';
    return areaList.first;
  }
}
