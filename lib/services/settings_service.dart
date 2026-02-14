import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SettingsService {
  static final SettingsService instance = SettingsService._internal();
  SettingsService._internal();

  SharedPreferences? _prefs;
  bool _initialized = false;

  // Default breeding pipeline settings
  static const int _defaultGestationDays = 31;
  static const int _defaultPalpationDays = 14;
  static const int _defaultNestBoxDays = 28;
  static const int _defaultWeanAge = 8; // weeks
  static const int _defaultRestingDays = 14;
  static const int _defaultQuarantineDays = 14;
  static const int _defaultMatureAge = 16; // weeks

  // Getters for breeding settings
  int get gestationDays => _prefs?.getInt('gestationDays') ?? _defaultGestationDays;
  int get palpationDays => _prefs?.getInt('palpationDays') ?? _defaultPalpationDays;
  int get nestBoxDays => _prefs?.getInt('nestBoxDays') ?? _defaultNestBoxDays;
  int get weanAge => _prefs?.getInt('weanAge') ?? _defaultWeanAge;
  int get restingDays => _prefs?.getInt('restingDays') ?? _defaultRestingDays;
  int get quarantineDays => _prefs?.getInt('quarantineDays') ?? _defaultQuarantineDays;
  int get matureAge => _prefs?.getInt('matureAge') ?? _defaultMatureAge;

  // Pipeline toggle settings
  bool get palpationEnabled => _prefs?.getBool('palpationEnabled') ?? true;
  bool get nestBoxEnabled => _prefs?.getBool('nestBoxEnabled') ?? true;
  bool get weaningEnabled => _prefs?.getBool('weaningEnabled') ?? true;
  bool get growOutEnabled => _prefs?.getBool('growOutEnabled') ?? true;
  bool get trackWeightsEnabled => _prefs?.getBool('trackWeightsEnabled') ?? true;
  int get growOutDuration => _prefs?.getInt('growOutDuration') ?? 12; // weeks
  int get sexualMaturityAge => _prefs?.getInt('sexualMaturityAge') ?? 6; // months

  // Module toggles
  bool get meatProductionEnabled => _prefs?.getBool('meatProductionEnabled') ?? true;
  bool get showRabbitryEnabled => _prefs?.getBool('showRabbitryEnabled') ?? false;
  bool get financeSalesEnabled => _prefs?.getBool('financeSalesEnabled') ?? true;

  // App settings
  String get weightUnit => _prefs?.getString('weightUnit') ?? 'lbs';
  String get dateFormat => _prefs?.getString('dateFormat') ?? 'MM/dd/yyyy';
  bool get darkMode => _prefs?.getBool('darkMode') ?? false;
  bool get notificationsEnabled => _prefs?.getBool('notificationsEnabled') ?? true;

  // Farm info
  String get farmName => _prefs?.getString('farmName') ?? 'My Rabbitry';
  String get ownerName => _prefs?.getString('ownerName') ?? '';
  String? get farmLogo => _prefs?.getString('farmLogo');
  String get farmAddress => _prefs?.getString('farmAddress') ?? '';
  String get farmPhone => _prefs?.getString('farmPhone') ?? '';
  String get farmEmail => _prefs?.getString('farmEmail') ?? '';

  // Breeds - stored as JSON array
  static const List<Map<String, String>> _defaultBreeds = [
    {
      'name': 'Rex',
      'genotype': 'aa B- C- D- E-'
    },
    {
      'name': 'New Zealand White',
      'genotype': '-- -- cc -- --'
    },
    {
      'name': 'Holland Lop',
      'genotype': ''
    },
    {
      'name': 'Californian',
      'genotype': ''
    },
    {
      'name': 'Flemish Giant',
      'genotype': ''
    },
    {
      'name': 'Mini Rex',
      'genotype': ''
    },
  ];

  List<Map<String, String>> get breeds {
    final jsonStr = _prefs?.getString('breeds');
    if (jsonStr == null) return List<Map<String, String>>.from(_defaultBreeds);
    try {
      final List<dynamic> decoded = jsonDecode(jsonStr);
      return decoded.map((e) => Map<String, String>.from(e as Map)).toList();
    } catch (e) {
      return List<Map<String, String>>.from(_defaultBreeds);
    }
  }

  Future<void> setBreeds(List<Map<String, String>> breedsList) async {
    await _prefs?.setString('breeds', jsonEncode(breedsList));
  }

  Future<void> addBreed(String name, String genotype) async {
    final currentBreeds = breeds;
    currentBreeds.add({
      'name': name,
      'genotype': genotype
    });
    await setBreeds(currentBreeds);
  }

  Future<void> removeBreed(String name) async {
    final currentBreeds = breeds;
    currentBreeds.removeWhere((b) => b['name'] == name);
    await setBreeds(currentBreeds);
  }

  Future<void> init() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
    print(' SettingsService initialized');
  }

  // Setters for breeding settings
  Future<void> setGestationDays(int days) async {
    await _prefs?.setInt('gestationDays', days);
  }

  Future<void> setPalpationDays(int days) async {
    await _prefs?.setInt('palpationDays', days);
  }

  Future<void> setNestBoxDays(int days) async {
    await _prefs?.setInt('nestBoxDays', days);
  }

  Future<void> setWeanAge(int weeks) async {
    await _prefs?.setInt('weanAge', weeks);
  }

  Future<void> setRestingDays(int days) async {
    await _prefs?.setInt('restingDays', days);
  }

  Future<void> setQuarantineDays(int days) async {
    await _prefs?.setInt('quarantineDays', days);
  }

  Future<void> setMatureAge(int weeks) async {
    await _prefs?.setInt('matureAge', weeks);
  }

  // Setters for pipeline toggles
  Future<void> setPalpationEnabled(bool enabled) async {
    await _prefs?.setBool('palpationEnabled', enabled);
  }

  Future<void> setNestBoxEnabled(bool enabled) async {
    await _prefs?.setBool('nestBoxEnabled', enabled);
  }

  Future<void> setWeaningEnabled(bool enabled) async {
    await _prefs?.setBool('weaningEnabled', enabled);
  }

  Future<void> setGrowOutEnabled(bool enabled) async {
    await _prefs?.setBool('growOutEnabled', enabled);
  }

  Future<void> setTrackWeightsEnabled(bool enabled) async {
    await _prefs?.setBool('trackWeightsEnabled', enabled);
  }

  Future<void> setGrowOutDuration(int weeks) async {
    await _prefs?.setInt('growOutDuration', weeks);
  }

  Future<void> setSexualMaturityAge(int months) async {
    await _prefs?.setInt('sexualMaturityAge', months);
  }

  // Module toggle setters
  Future<void> setMeatProductionEnabled(bool enabled) async {
    await _prefs?.setBool('meatProductionEnabled', enabled);
  }

  Future<void> setShowRabbitryEnabled(bool enabled) async {
    await _prefs?.setBool('showRabbitryEnabled', enabled);
  }

  Future<void> setFinanceSalesEnabled(bool enabled) async {
    await _prefs?.setBool('financeSalesEnabled', enabled);
  }

  // Setters for app settings
  Future<void> setWeightUnit(String unit) async {
    await _prefs?.setString('weightUnit', unit);
  }

  Future<void> setDateFormat(String format) async {
    await _prefs?.setString('dateFormat', format);
  }

  Future<void> setDarkMode(bool enabled) async {
    await _prefs?.setBool('darkMode', enabled);
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs?.setBool('notificationsEnabled', enabled);
  }

  // Setters for farm info
  Future<void> setFarmName(String name) async {
    await _prefs?.setString('farmName', name);
  }

  Future<void> setOwnerName(String name) async {
    // ✅ ADD THIS
    await _prefs?.setString('ownerName', name);
  }

  Future<void> setFarmLogo(String path) async {
    // ✅ ADD THIS ENTIRE METHOD
    await _prefs?.setString('farmLogo', path);
  }

  Future<void> setFarmAddress(String address) async {
    await _prefs?.setString('farmAddress', address);
  }

  Future<void> setFarmPhone(String phone) async {
    await _prefs?.setString('farmPhone', phone);
  }

  Future<void> setFarmEmail(String email) async {
    await _prefs?.setString('farmEmail', email);
  }

  // Reset to defaults
  Future<void> resetBreedingSettings() async {
    await setGestationDays(_defaultGestationDays);
    await setPalpationDays(_defaultPalpationDays);
    await setNestBoxDays(_defaultNestBoxDays);
    await setWeanAge(_defaultWeanAge);
    await setRestingDays(_defaultRestingDays);
    await setQuarantineDays(_defaultQuarantineDays);
    await setMatureAge(_defaultMatureAge);
    // Reset pipeline toggles
    await setPalpationEnabled(true);
    await setNestBoxEnabled(true);
    await setWeaningEnabled(true);
    await setGrowOutEnabled(true);
    await setTrackWeightsEnabled(true);
    await setGrowOutDuration(12);
    await setSexualMaturityAge(6);
  }

  // Get all settings as map (for backup/export)
  Map<String, dynamic> getAllSettings() {
    return {
      'gestationDays': gestationDays,
      'palpationDays': palpationDays,
      'nestBoxDays': nestBoxDays,
      'weanAge': weanAge,
      'restingDays': restingDays,
      'quarantineDays': quarantineDays,
      'matureAge': matureAge,
      'palpationEnabled': palpationEnabled,
      'nestBoxEnabled': nestBoxEnabled,
      'weaningEnabled': weaningEnabled,
      'growOutEnabled': growOutEnabled,
      'trackWeightsEnabled': trackWeightsEnabled,
      'growOutDuration': growOutDuration,
      'sexualMaturityAge': sexualMaturityAge,
      'weightUnit': weightUnit,
      'dateFormat': dateFormat,
      'darkMode': darkMode,
      'notificationsEnabled': notificationsEnabled,
      'farmName': farmName,
      'ownerName': ownerName,
      'farmLogo': farmLogo,
      'farmAddress': farmAddress,
      'farmPhone': farmPhone,
      'farmEmail': farmEmail,
    };
  }

  // Import settings from map (for restore)
  Future<void> importSettings(Map<String, dynamic> settings) async {
    if (settings['gestationDays'] != null) await setGestationDays(settings['gestationDays']);
    if (settings['palpationDays'] != null) await setPalpationDays(settings['palpationDays']);
    if (settings['nestBoxDays'] != null) await setNestBoxDays(settings['nestBoxDays']);
    if (settings['weanAge'] != null) await setWeanAge(settings['weanAge']);
    if (settings['restingDays'] != null) await setRestingDays(settings['restingDays']);
    if (settings['quarantineDays'] != null) await setQuarantineDays(settings['quarantineDays']);
    if (settings['matureAge'] != null) await setMatureAge(settings['matureAge']);
    // Pipeline toggles
    if (settings['palpationEnabled'] != null) await setPalpationEnabled(settings['palpationEnabled']);
    if (settings['nestBoxEnabled'] != null) await setNestBoxEnabled(settings['nestBoxEnabled']);
    if (settings['weaningEnabled'] != null) await setWeaningEnabled(settings['weaningEnabled']);
    if (settings['growOutEnabled'] != null) await setGrowOutEnabled(settings['growOutEnabled']);
    if (settings['trackWeightsEnabled'] != null) await setTrackWeightsEnabled(settings['trackWeightsEnabled']);
    if (settings['growOutDuration'] != null) await setGrowOutDuration(settings['growOutDuration']);
    if (settings['sexualMaturityAge'] != null) await setSexualMaturityAge(settings['sexualMaturityAge']);
    if (settings['weightUnit'] != null) await setWeightUnit(settings['weightUnit']);
    if (settings['dateFormat'] != null) await setDateFormat(settings['dateFormat']);
    if (settings['darkMode'] != null) await setDarkMode(settings['darkMode']);
    if (settings['notificationsEnabled'] != null) await setNotificationsEnabled(settings['notificationsEnabled']);
    if (settings['farmName'] != null) await setFarmName(settings['farmName']);
    if (settings['ownerName'] != null) await setOwnerName(settings['ownerName']);
    if (settings['farmLogo'] != null) await setFarmLogo(settings['farmLogo']);
    if (settings['farmAddress'] != null) await setFarmAddress(settings['farmAddress']);
    if (settings['farmPhone'] != null) await setFarmPhone(settings['farmPhone']);
    if (settings['farmEmail'] != null) await setFarmEmail(settings['farmEmail']);
  }
}
