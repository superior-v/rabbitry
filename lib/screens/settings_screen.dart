import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/settings_service.dart'; // ✅ ADD THIS
import '../services/database_service.dart'; // ✅ ADD THIS for scheduled tasks
import '../models/breed.dart';
import 'package:image_picker/image_picker.dart'; // ✅ ADD THIS
import 'package:permission_handler/permission_handler.dart'; // ✅ ADD THIS
import 'dart:io'; // ✅ ADD THIS
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart'; // ✅ Add this
import '../services/notification_service.dart'; // ✅ Add this
import 'dart:convert';
import '../utils/toast_utils.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final SettingsService _settings = SettingsService.instance;
  final DatabaseService _db = DatabaseService(); // ✅ ADD THIS for scheduled tasks
  final ImagePicker _imagePicker = ImagePicker();
  bool _isLoading = true; // ✅ ADD THIS
  bool _isSaving = false;

  final TextEditingController _farmNameController = TextEditingController();
  final TextEditingController _ownerNameController = TextEditingController();
  final TextEditingController _farmAddressController = TextEditingController();
  final TextEditingController _farmPhoneController = TextEditingController();
  final TextEditingController _farmEmailController = TextEditingController();

  // State management
  bool meatProduction = true;
  bool showRabbitry = false;
  bool financeSales = true;
  bool palpationEnabled = true;
  bool nestBoxEnabled = true;
  bool weaningEnabled = true;
  bool growOutEnabled = true;
  bool pushNotifications = true;
  bool snowballEffect = true;
  bool kitPromotion = true;
  bool maturityPromotion = true;
  bool quarantineChecks = true;

  String weightUnit = 'lbs';
  String currency = 'usd';
  String dateFormat = 'MM/dd/yyyy';
  String digestTime = '07:00';
  String? _logoPath;
  // Pipeline settings
  int gestationDays = 31;
  int palpationDays = 14;
  int nestBoxDays = 28;
  int weanAge = 8;
  int restingDays = 14;
  int quarantineDays = 14;
  int matureAge = 16;

  // Checkboxes for automation
  List<Breed> breeds = [];

  List<Map<String, String>> healthIssues = [];
  List<String> colorDirectory = [];
  List<Map<String, String>> husbandryTasks = [];
  List<Map<String, String>> healthTasks = [];
  List<Map<String, String>> maintenanceTasks = [];

  // Task Directory (DB-backed)
  List<Map<String, dynamic>> taskDirectoryItems = [];

  List<Map<String, dynamic>> scheduledTasks = []; // ✅ CHANGED: Load from database instead of hardcoded
  List<Map<String, dynamic>> pipelineTasks = []; // Pipeline tasks (auto-generated)

  Map<String, List<Map<String, String>>> entityData = {
    'rabbit': [],
    'litter': [],
    'kit': [],
  };

  List<Map<String, dynamic>> barns = [];

  Future<void> _loadEntityData() async {
    final rabbits = await _db.getAllRabbits();
    final litters = await _db.getLitters();

    setState(() {
      entityData = {
        'rabbit': rabbits
            .map((r) => {
                  'id': r.id,
                  'name': r.name ?? r.id,
                  'code': r.cage ?? '',
                })
            .toList(),
        'litter': litters
            .map((l) => {
                  'id': l.id,
                  'name': 'Litter ${l.id}',
                  'code': '${l.kits.length} kits',
                })
            .toList(),
        'kit': [],
      };
    });
  }

  Map<String, bool> soldLogic = {
    'archive': true,
    'ledger': true,
    'pedigree': false,
  };

  Map<String, bool> harvestLogic = {
    'archive': true,
    'weight': true,
  };

  Map<String, bool> mortalityLogic = {
    'archive': true,
    'cause': true,
  };

  Map<String, bool> quarantineEntry = {
    'changeCage': true,
  };

  Map<String, bool> quarantineExit = {
    'returnCage': true,
    'endTask': true,
  };

  // Color Palette Constants
  static const Color kLilac = Color(0xFFC3B1E1);
  static const Color kLilacLight = Color(0xFFE8DFFA);
  static const Color kLilacWash = Color(0xFFF5F1FC);
  static const Color kLilacDeep = Color(0xFF7B6BA0);
  static const Color kLilacText = Color(0xFF5A4880);
  static const Color kNeutral900 = Color(0xFF2C2C2E);
  static const Color kNeutral600 = Color(0xFF8E8E93);
  static const Color kNeutral500 = Color(0xFFAEAEB2);
  static const Color kNeutral400 = Color(0xFFC7C7CC);
  static const Color kNeutral300 = Color(0xFFE5E5EA);
  static const Color kNeutral200 = Color(0xFFF2F2F7);
  static const Color kNeutral100 = Color(0xFFF8F8FA);
  static const Color kNeutral50 = Color(0xFFFAFAFA);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 8, vsync: this);
    _loadSettings();
    _loadContacts(); // ✅ ADD THIS
  }

  List<Map<String, dynamic>> _contacts = [];
  String _contactSearchQuery = '';
  String _activeContactFilter = 'all';
  Map<String, bool> _expandedContacts = {};

  Future<void> _loadContacts() async {
    final data = await _db.getAllContacts();
    setState(() {
      _contacts = data;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _farmNameController.dispose();
    _ownerNameController.dispose();
    _farmAddressController.dispose();
    _farmPhoneController.dispose();
    _farmEmailController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      await _settings.init();
      final loadedLogo = _settings.farmLogo;

      // ✅ Load scheduled tasks from database
      final loadedTasks = await _db.getAllScheduledTasks();
      final loadedPipelineTasks = await _db.getAllPipelineTasks();

      // ✅ Load breeds from database
      var loadedBreeds = await _db.getAllBreeds();
      // Seed DB from SettingsService defaults if empty
      if (loadedBreeds.isEmpty) {
        final settingsBreeds = _settings.breeds;
        for (final sb in settingsBreeds) {
          final breed = Breed(
            id: DateTime.now().millisecondsSinceEpoch.toString() + '_${sb['name']}',
            name: sb['name'] ?? '',
            genetics: (sb['genotype'] ?? '').split(',').map((g) => g.trim()).where((g) => g.isNotEmpty).toList(),
          );
          await _db.insertBreed(breed);
        }
        loadedBreeds = await _db.getAllBreeds();
      }

      setState(() {
        // Farm Profile
        _farmNameController.text = _settings.farmName;
        _ownerNameController.text = _settings.ownerName;
        _logoPath = loadedLogo;
        _farmAddressController.text = _settings.farmAddress;
        _farmPhoneController.text = _settings.farmPhone;
        _farmEmailController.text = _settings.farmEmail;

        // Units and Formats
        weightUnit = _settings.weightUnit;
        currency = _settings.currency;
        dateFormat = _settings.dateFormat;

        // Pipeline Settings
        gestationDays = _settings.gestationDays;
        palpationDays = _settings.palpationDays;
        nestBoxDays = _settings.nestBoxDays;
        weanAge = _settings.weanAge;
        restingDays = _settings.restingDays;
        quarantineDays = _settings.quarantineDays;
        matureAge = _settings.matureAge;

        // Pipeline Toggles
        palpationEnabled = _settings.palpationEnabled;
        nestBoxEnabled = _settings.nestBoxEnabled;
        weaningEnabled = _settings.weaningEnabled;
        growOutEnabled = _settings.growOutEnabled;

        // Module Toggles
        meatProduction = _settings.meatProductionEnabled;
        showRabbitry = _settings.showRabbitryEnabled;
        financeSales = _settings.financeSalesEnabled;

        // Notifications
        pushNotifications = _settings.notificationsEnabled;
        digestTime = _settings.digestTime;

        // Task logic
        snowballEffect = _settings.snowballEffect;

        // ✅ Scheduled tasks from database
        scheduledTasks = loadedTasks;
        pipelineTasks = loadedPipelineTasks;

        // ✅ Breeds from database
        breeds = loadedBreeds;

        // ✅ Color directory from settings
        colorDirectory = _settings.colors;

        // ✅ Health issues directory from settings
        healthIssues = _settings.healthIssues;

        _isLoading = false;
      });
      // Load task directory items from database
      await _loadTaskDirectory();
      await _loadBarns();
    } catch (e) {
      print('❌ Error loading settings: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadBarns() async {
    final loadedBarns = await _db.getAllBarns();
    setState(() {
      barns = loadedBarns;
    });
  }

  Future<void> _loadTaskDirectory() async {
    final items = await _db.getAllTaskDirectoryItems();
    setState(() {
      taskDirectoryItems = items;
      husbandryTasks = items
          .where((t) => t['category'] == 'Husbandry')
          .map((t) => {
                'name': t['name'] as String,
                'id': t['id'].toString()
              })
          .toList();
      healthTasks = items
          .where((t) => t['category'] == 'Health')
          .map((t) => {
                'name': t['name'] as String,
                'id': t['id'].toString()
              })
          .toList();
      maintenanceTasks = items
          .where((t) => t['category'] == 'Maintenance')
          .map((t) => {
                'name': t['name'] as String,
                'id': t['id'].toString()
              })
          .toList();
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isSaving = true);

    try {
      // Farm Profile
      await _settings.setFarmName(_farmNameController.text);
      await _settings.setOwnerName(_ownerNameController.text);
      if (_logoPath != null) {
        await _settings.setFarmLogo(_logoPath!);
      } else {
        await _settings.removeFarmLogo();
      }
      await _settings.setFarmAddress(_farmAddressController.text);
      await _settings.setFarmPhone(_farmPhoneController.text);
      await _settings.setFarmEmail(_farmEmailController.text);

      // Units and Formats
      await _settings.setWeightUnit(weightUnit);
      await _settings.setDateFormat(dateFormat);

      // Pipeline Settings
      await _settings.setGestationDays(gestationDays);
      await _settings.setPalpationDays(palpationDays);
      await _settings.setNestBoxDays(nestBoxDays);
      await _settings.setWeanAge(weanAge);
      await _settings.setRestingDays(restingDays);
      await _settings.setQuarantineDays(quarantineDays);
      await _settings.setMatureAge(matureAge);

      // Pipeline Toggles
      await _settings.setPalpationEnabled(palpationEnabled);
      await _settings.setNestBoxEnabled(nestBoxEnabled);
      await _settings.setWeaningEnabled(weaningEnabled);
      await _settings.setGrowOutEnabled(growOutEnabled);

      // Module Toggles
      await _settings.setMeatProductionEnabled(meatProduction);
      await _settings.setShowRabbitryEnabled(showRabbitry);
      await _settings.setFinanceSalesEnabled(financeSales);

      // Notifications
      await _settings.setNotificationsEnabled(pushNotifications);
      await _settings.setDigestTime(digestTime);

      // Task Logic
      await _settings.setSnowballEffect(snowballEffect);

      setState(() => _isSaving = false);

      ToastUtils.showSuccess(context, 'Settings saved successfully');
    } catch (e) {
      setState(() => _isSaving = false);
      ToastUtils.showError(context, 'Error saving settings: $e');
    }
  }

  Future<bool> _requestPermission(ImageSource source) async {
    if (source == ImageSource.camera) {
      var status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
      }
      return status.isGranted;
    } else {
      var status = await Permission.photos.status;
      if (!status.isGranted) {
        status = await Permission.photos.request();
      }
      return status.isGranted;
    }
  }

  Future<void> _pickLogo(ImageSource source) async {
    try {
      bool hasPermission = await _requestPermission(source);
      if (!hasPermission) {
        ToastUtils.showError(context, source == ImageSource.camera ? 'Camera permission is required' : 'Gallery permission is required');
        return;
      }

      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 90,
      );

      if (image != null) {
        setState(() => _logoPath = image.path);
        ToastUtils.showSuccess(context, 'Logo added successfully. Remember to tap Save!');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: const Color(0xFFD44C47),
        ),
      );
    }
  }

  void _showLogoUploadOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Upload Logo',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            _buildPhotoOption(
              icon: Icons.camera_alt,
              label: 'Take Photo',
              onTap: () {
                Navigator.pop(context);
                _pickLogo(ImageSource.camera);
              },
            ),
            _buildPhotoOption(
              icon: Icons.photo_library,
              label: 'Choose from Gallery',
              onTap: () {
                Navigator.pop(context);
                _pickLogo(ImageSource.gallery);
              },
            ),
            if (_logoPath != null)
              _buildPhotoOption(
                icon: Icons.delete_outline,
                label: 'Remove Logo',
                onTap: () {
                  Navigator.pop(context);
                  setState(() => _logoPath = null);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Logo removed. Remember to tap Save!'),
                      backgroundColor: kLilacDeep,
                    ),
                  );
                },
                isDestructive: true,
              ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? const Color(0xFFD44C47) : const Color(0xFF787774),
              size: 22,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: isDestructive ? const Color(0xFFD44C47) : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildHeader(),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(kLilacDeep),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildHeader(),
      body: Column(
        children: [
          _buildNavContainer(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGeneralTab(),
                _buildModulesTab(),
                _buildPipelineTab(),
                _buildOperationsTab(),
                _buildAutomationTab(), // Replaces task definitions
                _buildDataTab(),
                _buildContactsTab(),
                _buildSystemTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildHeader() {
    return AppBar(
      backgroundColor: kLilacWash,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: kNeutral900),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Settings',
        style: TextStyle(
          color: kNeutral900,
          fontWeight: FontWeight.w700,
          fontSize: 20,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: GestureDetector(
              onTap: _isSaving ? null : _saveSettings,
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(kLilacDeep),
                      ),
                    )
                  : const Text(
                      'Save',
                      style: TextStyle(
                        color: kLilacDeep,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavContainer() {
    final sections = ['General', 'Modules', 'Pipeline', 'Operations', 'Automation', 'Data', 'Contacts', 'System'];
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        color: kLilacWash,
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        itemCount: sections.length,
        itemBuilder: (context, index) {
          return AnimatedBuilder(
            animation: _tabController.animation!,
            builder: (context, child) {
              final selected = _tabController.index == index;
              return GestureDetector(
                onTap: () => _tabController.animateTo(index),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? kLilacDeep : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: selected ? kLilacDeep : kNeutral300),
                  ),
                  child: Text(
                    sections[index],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected ? Colors.white : kNeutral600,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ============================================
  // GENERAL TAB
  // ============================================
  Widget _buildGeneralTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildCard(
          'Farm Profile',
          PhosphorIconsDuotone.houseLine,
          [
            _buildVerticalSetting(
              'Farm Name',
              _buildStandardTextField(
                controller: _farmNameController,
                hintText: 'e.g. Green Valley Rabbitry',
              ),
            ),
            _buildVerticalSetting(
              'Owner Name',
              _buildStandardTextField(
                controller: _ownerNameController,
                hintText: 'e.g. John Doe',
              ),
              description: 'Used for pedigree generation.',
            ),
            _buildVerticalSetting(
              'Logo',
              Row(
                children: [
                  GestureDetector(
                    onTap: _showLogoUploadOptions,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: kNeutral100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kNeutral200),
                        image: _logoPath != null && File(_logoPath!).existsSync()
                            ? DecorationImage(
                                image: FileImage(File(_logoPath!)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _logoPath == null || !File(_logoPath!).existsSync()
                          ? Icon(PhosphorIconsBold.image, size: 32, color: kNeutral400)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showLogoUploadOptions,
                      icon: Icon(
                        _logoPath == null ? PhosphorIconsBold.upload : PhosphorIconsBold.pencilSimple,
                        size: 18,
                      ),
                      label: Text(_logoPath == null ? 'Upload Logo' : 'Change Logo'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        foregroundColor: kLilacDeep,
                        side: const BorderSide(color: kLilacDeep),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
              description: 'Upload a square image for reports.',
            ),
          ],
        ),
        _buildCard(
          'Localization',
          PhosphorIconsDuotone.globe,
          [
            _buildSettingRow(
              'Weight Unit',
              _buildStandardDropdown<String>(
                value: weightUnit,
                items: [
                  const DropdownMenuItem(value: 'lbs', child: Text('Pounds (lbs)')),
                  const DropdownMenuItem(value: 'kg', child: Text('Kilograms (kg)')),
                ],
                onChanged: (value) async {
                  if (value != null && value != weightUnit) {
                    final oldUnit = weightUnit;
                    setState(() => weightUnit = value);
                    await _settings.setWeightUnit(value);
                    await _db.convertAllWeightValues(oldUnit, value);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('All weights converted from $oldUnit to $value'),
                          backgroundColor: kLilacDeep,
                        ),
                      );
                    }
                  }
                },
              ),
            ),
            _buildSettingRow(
              'Currency',
              _buildStandardDropdown<String>(
                value: currency,
                items: const [
                  DropdownMenuItem(value: 'usd', child: Text('\$ - USD')),
                  DropdownMenuItem(value: 'cad', child: Text('C\$ - CAD')),
                  DropdownMenuItem(value: 'eur', child: Text('€ - EUR')),
                  DropdownMenuItem(value: 'gbp', child: Text('£ - GBP')),
                  DropdownMenuItem(value: 'inr', child: Text('₹ - INR')),
                  DropdownMenuItem(value: 'aud', child: Text('A\$ - AUD')),
                  DropdownMenuItem(value: 'cny', child: Text('¥ - CNY')),
                ],
                onChanged: (value) async {
                  if (value != null && value != currency) {
                    final oldCurrency = currency;
                    setState(() => currency = value);
                    await _settings.setCurrency(value);
                    await _db.convertAllCurrencyValues(oldCurrency, value);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('All monetary values converted from ${oldCurrency.toUpperCase()} to ${value.toUpperCase()}'),
                          backgroundColor: kLilacDeep,
                        ),
                      );
                    }
                  }
                },
              ),
            ),
            _buildSettingRow(
              'Date Format',
              _buildStandardDropdown<String>(
                value: dateFormat,
                items: const [
                  DropdownMenuItem(value: 'MM/dd/yyyy', child: Text('MM/DD/YYYY')),
                  DropdownMenuItem(value: 'dd/MM/yyyy', child: Text('DD/MM/YYYY')),
                  DropdownMenuItem(value: 'yyyy-MM-dd', child: Text('YYYY-MM-DD')),
                ],
                onChanged: (value) {
                  setState(() => dateFormat = value!);
                  _settings.setDateFormat(value!);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStandardTextField({required TextEditingController controller, required String hintText, TextInputType? keyboardType, int maxLines = 1}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kNeutral900),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: const TextStyle(color: kNeutral400, fontWeight: FontWeight.w500),
        filled: true,
        fillColor: kNeutral50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kNeutral200)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kNeutral200)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacDeep, width: 2)),
      ),
    );
  }

  Widget _buildStandardDropdown<T>({required T value, required List<DropdownMenuItem<T>> items, required ValueChanged<T?> onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: kNeutral50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kNeutral200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kNeutral900),
          icon: const Icon(PhosphorIconsBold.caretDown, size: 14, color: kNeutral500),
          dropdownColor: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  // ============================================
  // MODULES TAB
  // ============================================
  Widget _buildModulesTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildCard(
          'App Features',
          PhosphorIconsDuotone.squaresFour,
          [
            _buildSwitchRow(
              'Meat Production',
              'Enables harvest logs, butcher dates, and yield reports.',
              meatProduction,
              (val) => setState(() => meatProduction = val),
            ),
            _buildSwitchRow(
              'Show Rabbitry',
              'Enables GC legs, show wins, and registration numbers.',
              showRabbitry,
              (val) => setState(() => showRabbitry = val),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================
  // PIPELINE TAB
  // ============================================
  // Find this section in _buildPipelineTab() and REPLACE IT:

  Widget _buildPipelineTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Breeding Timeline',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kNeutral900, letterSpacing: -0.5),
              ),
              SizedBox(height: 6),
              Text(
                'Configure your standard reproductive cycle and actions.',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kNeutral600),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: kLilacLight),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: kLilacDeep.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            children: [
              _buildPipelineStep('Breeding', dayLabel: 'DAY 0'),
              _buildPipelineStep(
                'Palpation Check',
                hasToggle: true,
                toggleValue: palpationEnabled,
                onToggle: (val) => setState(() => palpationEnabled = val),
                dayValue: palpationDays,
                onDayChanged: (val) => setState(() => palpationDays = val),
                autoTask: true,
                actions: const [
                  {'tag': 'Positive', 'desc': 'Move to Bred'},
                  {'tag': 'Negative', 'desc': 'Move to Open'},
                ],
              ),
              _buildPipelineStep(
                'Nest Box',
                hasToggle: true,
                toggleValue: nestBoxEnabled,
                onToggle: (val) => setState(() => nestBoxEnabled = val),
                dayValue: nestBoxDays,
                onDayChanged: (val) => setState(() => nestBoxDays = val),
                autoTask: true,
                actions: [
                  {'tag': 'Action', 'desc': 'Create Check Kits (Day $gestationDays)'},
                ],
              ),
              _buildPipelineStep(
                'Kindle (Birth)',
                dayLabel: 'DAY $gestationDays',
                dayValue: gestationDays,
                onDayChanged: (val) => setState(() => gestationDays = val),
                showScheduleDay: true,
                actions: const [
                  {'tag': 'Action', 'desc': 'Log Litter Count'},
                ],
              ),
              _buildPipelineStep(
                'Weaning',
                hasToggle: true,
                toggleValue: weaningEnabled,
                onToggle: (val) => setState(() => weaningEnabled = val),
                dayValue: weanAge,
                onDayChanged: (val) => setState(() => weanAge = val),
                dayUnit: 'weeks',
                autoTask: true,
                actions: const [
                  {'tag': 'Action', 'desc': 'Separate Kits & Doe'},
                  {'tag': 'Action', 'desc': 'Promote to Grow-out'},
                ],
              ),
              _buildPipelineStep(
                'Sexual Maturity',
                dayLabel: '$matureAge WK',
                dayValue: matureAge,
                onDayChanged: (val) => setState(() => matureAge = val),
                dayUnit: 'weeks',
                showScheduleDay: true,
                actions: const [
                  {'tag': 'Action', 'desc': 'Promote to Active Breeder'},
                ],
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================
  // OPERATIONS TAB
  // ============================================
  Widget _buildOperationsTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildCard(
          'Infrastructure',
          PhosphorIconsDuotone.houseLine,
          [
            _buildSubsectionHeader('BARNS & LOCATIONS'),
            if (barns.isEmpty)
              const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No locations defined.')))
            else
              ...barns.map((b) => _buildSimpleTaskItem(
                    b['name'] as String,
                    () => _deleteLocationItem(b['id'] as String),
                    onTap: () => _showCages(b),
                  )),
            _buildAddListItem(_addLocation),
          ],
        ),
        _buildCard(
          'Genetics & Breeds',
          PhosphorIconsDuotone.dna,
          [
            _buildSubsectionHeader('BREED LIBRARY'),
            ...breeds.map((b) => _buildBreedItemWithInput(b)),
            _buildAddListItem(_addBreed),
            _buildSubsectionHeader('COLOR DIRECTORY'),
            ...colorDirectory.map((c) => _buildColorItem(c)),
            _buildAddListItem(_addColor),
          ],
        ),
        _buildCard(
          'Health Standards',
          PhosphorIconsDuotone.firstAid,
          [
            _buildSubsectionHeader('ISSUES & TREATMENTS'),
            ...healthIssues.map((issue) => _buildHealthIssueItemWithInput(issue['name']!, issue['treatment']!)),
            _buildAddListItem(_addHealthIssue),
          ],
        ),
        _buildCard(
          'Task Management',
          PhosphorIconsDuotone.calendarCheck,
          [
            _buildSubsectionHeader('SCHEDULED TASKS'),
            if (scheduledTasks.isEmpty)
              const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("No schedules defined")))
            else
              ...scheduledTasks.map((s) => _buildScheduledTaskItem(s)),
            _buildAddListItem(_openScheduleModal),
            _buildSubsectionHeader('ACTIVE PIPELINE'),
            if (pipelineTasks.isEmpty)
              const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("No pipeline tasks")))
            else
              ...pipelineTasks.map((t) => _buildPipelineTaskItem(t)),
          ],
        ),
      ],
    );
  }

  // ============================================
  // DATA TAB
  // ============================================
  Widget _buildDataTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildCard(
          'Export Data',
          PhosphorIconsDuotone.downloadSimple,
          [
            _buildExportButton(PhosphorIconsBold.fileCsv, 'Export Herd Inventory (CSV)', kLilacDeep, _exportHerdData),
            _buildExportButton(PhosphorIconsBold.fileCsv, 'Export Financial Ledger (CSV)', kLilacDeep, _exportLedgerData),
            _buildExportButton(PhosphorIconsBold.addressBook, 'Export Contact CRM (CSV)', kLilacDeep, () {}),
          ],
        ),
        _buildCard(
          'Privacy & Security',
          PhosphorIconsDuotone.shieldCheck,
          [
            _buildSwitchRow(
              'Biometric Lock',
              'Require fingerprint or face ID to open the app.',
              false,
              (val) {},
            ),
            _buildDangerRow(),
          ],
        ),
      ],
    );
  }

  // ============================================
  // SYSTEM TAB
  // ============================================
  Widget _buildSystemTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildCard(
          'Notifications',
          PhosphorIconsDuotone.bell,
          [
            _buildSwitchRow(
              'Push Notifications',
              'Allow app to send important reminders.',
              pushNotifications,
              (val) => setState(() => pushNotifications = val),
            ),
            _buildSettingRow(
              'Daily Digest Time',
              GestureDetector(
                onTap: () async {
                  final parts = digestTime.split(':');
                  final initialTime = TimeOfDay(hour: int.tryParse(parts[0]) ?? 7, minute: int.tryParse(parts[1]) ?? 0);
                  final picked = await showTimePicker(context: context, initialTime: initialTime);
                  if (picked != null) {
                    setState(() => digestTime = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: kNeutral100, border: Border.all(color: kNeutral200), borderRadius: BorderRadius.circular(8)),
                  child: Text(digestTime, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kNeutral900)),
                ),
              ),
              description: 'When to send task summary.',
            ),
          ],
        ),
        _buildCard(
          'About Rabbitry Manager',
          PhosphorIconsDuotone.info,
          [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Version 2.4.0 (Build 82)\nPremium Edition\n\n© 2026 Rabbitry Intelligence Systems.',
                style: TextStyle(fontSize: 13, height: 1.6, fontWeight: FontWeight.w500, color: kNeutral600),
              ),
            ),
            _buildSettingRow(
              'User Agreement',
              Icon(PhosphorIconsBold.caretRight, size: 16, color: kNeutral400),
            ),
            _buildSettingRow(
              'Privacy Policy',
              Icon(PhosphorIconsBold.caretRight, size: 16, color: kNeutral400),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _exportHerdData() async {
    try {
      final rabbits = await DatabaseService().getAllRabbits();
      final archived = await DatabaseService().getArchivedRabbits();
      final allRabbits = [
        ...rabbits,
        ...archived
      ];

      if (allRabbits.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No rabbit data to export'), backgroundColor: Color(0xFFD44C47)),
          );
        }
        return;
      }

      final buffer = StringBuffer();
      buffer.writeln('ID,Name,Type,Status,Breed,Location,Cage,DOB,Color,Weight,Origin,Sire ID,Dam ID');
      for (final r in allRabbits) {
        buffer.writeln(
          '${_csvEscape(r.id)},${_csvEscape(r.name)},${r.type.toString().split('.').last},${r.status.toString().split('.').last},'
          '${_csvEscape(r.breed)},${_csvEscape(r.location ?? '')},${_csvEscape(r.cage ?? '')},'
          '${r.dateOfBirth ?? ''},${_csvEscape(r.color ?? '')},${r.weight ?? ''},'
          '${_csvEscape(r.origin ?? '')},${_csvEscape(r.sireId ?? '')},${_csvEscape(r.damId ?? '')}',
        );
      }

      final directory = await _getExportDirectory();
      if (directory == null) return;
      final file = File('${directory.path}/herd_export_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buffer.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${allRabbits.length} rabbits to ${file.path.split('/').last}'),
            backgroundColor: kLilacDeep,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'OPEN',
              textColor: Colors.white,
              onPressed: () => OpenFilex.open(file.path),
            ),
          ),
        );

        // ✅ Show system notification
        await NotificationService.instance.showFileNotification(
          title: 'Herd Data Exported',
          body: 'Tap to open herd_export.csv',
          filePath: file.path,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: const Color(0xFFD44C47)),
        );
      }
    }
  }

  Future<void> _exportLedgerData() async {
    try {
      final transactions = await DatabaseService().getAllTransactions();

      if (transactions.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No ledger data to export'), backgroundColor: Color(0xFFD44C47)),
          );
        }
        return;
      }

      final buffer = StringBuffer();
      buffer.writeln('ID,Type,Category,Amount,Description,Date,Rabbit ID');
      for (final t in transactions) {
        buffer.writeln(
          '${_csvEscape(t.id)},${t.type.name},${t.category.name},'
          '${t.amount},${_csvEscape(t.description ?? '')},${t.date.toIso8601String()},${_csvEscape(t.rabbitId ?? '')}',
        );
      }

      final directory = await _getExportDirectory();
      if (directory == null) return;
      final file = File('${directory.path}/ledger_export_${DateTime.now().millisecondsSinceEpoch}.csv');
      await file.writeAsString(buffer.toString());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Exported ${transactions.length} transactions to ${file.path.split('/').last}'),
            backgroundColor: kLilacDeep,
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'OPEN',
              textColor: Colors.white,
              onPressed: () => OpenFilex.open(file.path),
            ),
          ),
        );

        // ✅ Show system notification
        await NotificationService.instance.showFileNotification(
          title: 'Ledger Data Exported',
          body: 'Tap to open ledger_export.csv',
          filePath: file.path,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: const Color(0xFFD44C47)),
        );
      }
    }
  }

  Future<Directory?> _getExportDirectory() async {
    if (Platform.isAndroid) {
      // For Android 13+, Permission.storage is split into media permissions.
      // For general file access, Permission.manageExternalStorage or specialized approaches are needed.
      // However, writing to Downloads often works with simple permissions or via MediaStore.
      
      var status = await Permission.storage.request();
      
      if (!status.isGranted) {
        // If storage permission is denied, try manageExternalStorage (Android 11+)
        var manageStatus = await Permission.manageExternalStorage.request();
        
        if (!manageStatus.isGranted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Storage permission required to export CSV'),
                backgroundColor: const Color(0xFFD44C47),
                action: SnackBarAction(
                  label: 'Settings',
                  textColor: Colors.white,
                  onPressed: () => openAppSettings(),
                ),
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return null;
        }
      }

      // Try multiple potential download paths
      final List<String> potentialPaths = [
        '/storage/emulated/0/Download',
        '/storage/emulated/0/Downloads',
        '/sdcard/Download',
      ];

      for (String path in potentialPaths) {
        final dir = Directory(path);
        try {
          if (await dir.exists()) {
            return dir;
          } else {
            // Try creating it if it doesn't exist (less likely for Download, but possible for subdirs)
            await dir.create(recursive: true);
            return dir;
          }
        } catch (_) {
          continue;
        }
      }

      // Fallback to app documents if all else fails
      return await getApplicationDocumentsDirectory();
    } else {
      // For iOS/other platforms, use temp or documents
      return await getApplicationDocumentsDirectory();
    }
  }

  String _csvEscape(dynamic val) {
    if (val == null) return '';
    final String value = val.toString();
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Widget _buildExportButton(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: kNeutral100)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // TAB BUILDERS
  // ============================================

  Widget _buildAutomationTab() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildCard(
          'Auto-Tasks',
          PhosphorIconsDuotone.sparkle,
          [
            _buildSubsectionHeader('OPERATIONS'),
            ...husbandryTasks.map((t) => _buildSimpleTaskItem(t['name'] as String, () => _deleteTaskDirectoryItem(t['id'] as int))),
            _buildAddListItem(() => _showAddTaskDirectoryDialog('Operations')),
            _buildSubsectionHeader('HEALTH'),
            ...healthTasks.map((t) => _buildSimpleTaskItem(t['name'] as String, () => _deleteTaskDirectoryItem(t['id'] as int))),
            _buildAddListItem(() => _showAddTaskDirectoryDialog('Health')),
            _buildSubsectionHeader('MAINTENANCE'),
            ...maintenanceTasks.map((t) => _buildSimpleTaskItem(t['name'] as String, () => _deleteTaskDirectoryItem(t['id'] as int))),
            _buildAddListItem(() => _showAddTaskDirectoryDialog('Maintenance')),
          ],
        ),
        _buildCard(
          'Smart Automation',
          PhosphorIconsDuotone.robot,
          [
            _buildSwitchRow(
              'Snowball Effect',
              'Overdue tasks are carried forward to today.',
              snowballEffect,
              (val) => setState(() => snowballEffect = val),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildContactsTab() {
    return Column(
      children: [
        // CRM Header Stats
        _buildContactStatsHeader(),
        // Search and Filter
        _buildContactControls(),
        // Contact List
        Expanded(
          child: _buildContactList(),
        ),
      ],
    );
  }

  Widget _buildContactStatsHeader() {
    // Calculate stats
    final total = _contacts.length;
    final totalBought = _contacts.fold<int>(0, (sum, c) => sum + (c['totalBought'] as int? ?? 0));
    final totalRevenue = _contacts.fold<double>(0.0, (sum, c) => sum + (c['totalRevenue'] as double? ?? 0.0));

    return Container(
      padding: const EdgeInsets.all(20),
      color: kLilacWash,
      child: Row(
        children: [
          _buildStatItem('Total', total.toString(), PhosphorIconsBold.users),
          const SizedBox(width: 12),
          _buildStatItem('Rabbits', totalBought.toString(), PhosphorIconsBold.rabbit),
          const SizedBox(width: 12),
          _buildStatItem('Revenue', '\$${totalRevenue.toStringAsFixed(0)}', PhosphorIconsBold.currencyDollar),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kLilacLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 14, color: kLilacDeep),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kNeutral900)),
            Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kNeutral600)),
          ],
        ),
      ),
    );
  }

  Widget _buildContactControls() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: kNeutral200)),
      ),
      child: Column(
        children: [
          // Search Bar
          TextField(
            onChanged: (val) => setState(() => _contactSearchQuery = val.toLowerCase()),
            decoration: InputDecoration(
              hintText: 'Search contacts...',
              prefixIcon: Icon(PhosphorIconsBold.magnifyingGlass, size: 18, color: kNeutral500),
              filled: true,
              fillColor: kNeutral100,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 12),
          // Filter Chips + Add Button
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildContactFilterChip('All', 'all'),
                      _buildContactFilterChip('Breeder', 'Breeder'),
                      _buildContactFilterChip('Buyer', 'Buyer'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _showAddEditContactDialog(),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(color: kLilacDeep, shape: BoxShape.circle),
                  child: Icon(PhosphorIconsBold.plus, size: 18, color: Colors.white),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactFilterChip(String label, String value) {
    final active = _activeContactFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _activeContactFilter = value),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? kLilacDeep : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? kLilacDeep : kNeutral300),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? Colors.white : kNeutral600),
        ),
      ),
    );
  }

  Widget _buildContactList() {
    final filtered = _contacts.where((c) {
      final name = (c['name'] ?? '').toString().toLowerCase();
      final type = (c['type'] ?? 'Buyer').toString();
      final phone = (c['phone'] ?? '').toString();
      final email = (c['email'] ?? '').toString().toLowerCase();

      final matchesQuery = name.contains(_contactSearchQuery) || phone.contains(_contactSearchQuery) || email.contains(_contactSearchQuery);
      final matchesFilter = _activeContactFilter == 'all' || type == _activeContactFilter;

      return matchesQuery && matchesFilter;
    }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(PhosphorIconsDuotone.addressBook, size: 64, color: kLilacDeep.withOpacity(0.3)),
            const SizedBox(height: 16),
            const Text('No contacts found', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kNeutral600)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final contact = filtered[index];
        final id = contact['id'].toString();
        final expanded = _expandedContacts[id] ?? false;

        return _buildContactCard(contact, expanded);
      },
    );
  }

  Widget _buildContactCard(Map<String, dynamic> contact, bool expanded) {
    final id = contact['id'].toString();
    final initials = contact['name'].toString().isNotEmpty ? contact['name'].toString().substring(0, 1).toUpperCase() : '?';
    final type = contact['type'] ?? 'Buyer';
    final typeColor = type == 'Breeder' ? const Color(0xFF6366F1) : const Color(0xFF10B981);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kNeutral200),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Header
          GestureDetector(
            onTap: () => setState(() => _expandedContacts[id] = !expanded),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: typeColor.withOpacity(0.1), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(initials, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: typeColor)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(contact['name'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: kNeutral900)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(color: typeColor, borderRadius: BorderRadius.circular(4)),
                              child: Text(type.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Colors.white)),
                            ),
                            if (contact['phone'] != null && contact['phone'].isNotEmpty) ...[
                              const SizedBox(width: 8),
                              const Icon(PhosphorIconsBold.phone, size: 10, color: kNeutral500),
                              const SizedBox(width: 4),
                              Text(contact['phone'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kNeutral600)),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(expanded ? PhosphorIconsBold.caretUp : PhosphorIconsBold.caretDown, size: 16, color: kNeutral400),
                ],
              ),
            ),
          ),
          // Detail View
          if (expanded)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: kNeutral50,
                border: Border(top: BorderSide(color: kNeutral200)),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (contact['email'] != null && contact['email'].isNotEmpty) _buildContactDetailRow(PhosphorIconsBold.envelope, contact['email']),
                  if (contact['farmName'] != null && contact['farmName'].isNotEmpty) _buildContactDetailRow(PhosphorIconsBold.houseLine, contact['farmName']),
                  if (contact['notes'] != null && contact['notes'].isNotEmpty) _buildContactDetailRow(PhosphorIconsBold.note, contact['notes'], isItalic: true),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showAddEditContactDialog(contact),
                          icon: const Icon(PhosphorIconsBold.pencilSimple, size: 16),
                          label: const Text('Edit'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kLilacDeep,
                            side: const BorderSide(color: kLilacDeep),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _confirmDeleteContact(id, contact['name']),
                          icon: const Icon(PhosphorIconsBold.trash, size: 16),
                          label: const Text('Delete'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(color: Colors.redAccent),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                        ),
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

  Widget _buildContactDetailRow(IconData icon, String text, {bool isItalic = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: kNeutral500),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: kNeutral900,
                fontStyle: isItalic ? FontStyle.italic : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteContact(String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Contact?'),
        content: Text('Are you sure you want to delete "$name"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              await _db.deleteContact(id);
              await _loadContacts();
              if (mounted) Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact deleted')));
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _showAddEditContactDialog([Map<String, dynamic>? contact]) {
    final isEdit = contact != null;
    final nameController = TextEditingController(text: contact?['name'] ?? '');
    final phoneController = TextEditingController(text: contact?['phone'] ?? '');
    final emailController = TextEditingController(text: contact?['email'] ?? '');
    final farmController = TextEditingController(text: contact?['farmName'] ?? '');
    final notesController = TextEditingController(text: contact?['notes'] ?? '');
    String typeSelection = contact?['type'] ?? 'Buyer';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: kNeutral300, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(isEdit ? 'Edit Contact' : 'Add Contact', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kNeutral900)),
                    IconButton(onPressed: () => Navigator.pop(context), icon: Icon(PhosphorIconsBold.x, size: 20)),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDialogField('Full Name *', nameController, PhosphorIconsBold.user),
                      const SizedBox(height: 16),
                      const Text('Contact Type', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kNeutral600)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildTypeOption('Buyer', typeSelection == 'Buyer', () => setModalState(() => typeSelection = 'Buyer')),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTypeOption('Breeder', typeSelection == 'Breeder', () => setModalState(() => typeSelection = 'Breeder')),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(child: _buildDialogField('Phone', phoneController, PhosphorIconsBold.phone, keyboardType: TextInputType.phone)),
                          const SizedBox(width: 12),
                          Expanded(child: _buildDialogField('Email', emailController, PhosphorIconsBold.envelope, keyboardType: TextInputType.emailAddress)),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildDialogField('Farm Name', farmController, PhosphorIconsBold.houseLine),
                      const SizedBox(height: 16),
                      _buildDialogField('Notes', notesController, PhosphorIconsBold.note, maxLines: 3),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (nameController.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Name is required')));
                              return;
                            }
                            try {
                              final data = {
                                'id': contact?['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
                                'name': nameController.text,
                                'type': typeSelection,
                                'phone': phoneController.text,
                                'email': emailController.text,
                                'farmName': farmController.text,
                                'notes': notesController.text,
                                'totalBought': contact?['totalBought'] ?? 0,
                                'totalRevenue': contact?['totalRevenue'] ?? 0.0,
                                'createdAt': contact?['createdAt'] ?? DateTime.now().toIso8601String(),
                              };
                              if (isEdit) {
                                await _db.updateContact(data);
                              } else {
                                await _db.insertContact(data);
                              }
                              await _loadContacts();
                              if (mounted) Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isEdit ? 'Contact updated' : 'Contact added')));
                            } catch (e) {
                              print('Error saving contact: $e');
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Failed to save contact: $e'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kLilacDeep,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text(isEdit ? 'Update Contact' : 'Save Contact', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeOption(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: active ? kLilacDeep : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? kLilacDeep : kNeutral300),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: active ? Colors.white : kNeutral600),
        ),
      ),
    );
  }

  Widget _buildDialogField(String label, TextEditingController controller, IconData icon, {TextInputType? keyboardType, int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kNeutral600)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: kNeutral500),
            filled: true,
            fillColor: kNeutral50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kNeutral200)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kNeutral200)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: kLilacDeep, width: 2)),
          ),
        ),
      ],
    );
  }

  // ============================================
  // HELPER WIDGETS
  // ============================================

  Widget _buildCard(String title, IconData icon, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: kLilacLight),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kLilacDeep.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              color: kNeutral50,
              border: Border(bottom: BorderSide(color: kNeutral200)),
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                Icon(icon, color: kLilacDeep, size: 20),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: kNeutral900,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSettingRow(String label, Widget trailing, {String? description}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kNeutral100)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kNeutral900,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: kNeutral600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }

  Widget _buildSwitchRow(String label, String? description, bool value, Function(bool) onChanged) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kNeutral100)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kNeutral900,
                  ),
                ),
                if (description != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: kNeutral600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: kLilacDeep,
            activeTrackColor: kLilacLight,
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalSetting(String label, Widget child, {String? description}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kNeutral100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kNeutral900,
            ),
          ),
          const SizedBox(height: 10),
          child,
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(
              description,
              style: const TextStyle(
                fontSize: 12,
                color: kNeutral600,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPipelineStep(
    String title, {
    String? dayLabel,
    bool hasToggle = false,
    bool? toggleValue,
    Function(bool)? onToggle,
    int? dayValue,
    Function(int)? onDayChanged,
    String dayUnit = 'days',
    bool autoTask = false,
    bool showScheduleDay = false,
    List<Map<String, String>>? actions,
    Map<String, dynamic>? extraToggle,
    bool isLast = false,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            margin: EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: kLilacDeep,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    if (dayLabel != null && !hasToggle)
                      Text(
                        dayLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      )
                    else if (hasToggle && toggleValue != null && onToggle != null)
                      Transform.scale(
                        scale: 0.85,
                        child: Switch(
                          value: toggleValue,
                          onChanged: onToggle,
                          activeColor: kLilacDeep,
                          activeTrackColor: kLilacWash,
                        ),
                      ),
                  ],
                ),
                if (title == 'Breeding')
                  Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      'The start of the cycle. Always enabled.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                if (dayValue != null || autoTask || extraToggle != null) ...[
                  SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kNeutral100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        if (showScheduleDay || (dayValue != null && hasToggle))
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Schedule Day',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: kNeutral900,
                                ),
                              ),
                              Row(
                                children: [
                                  Container(
                                    width: 70,
                                    height: 36,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border.all(color: kNeutral200),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: onDayChanged != null
                                        ? Focus(
                                            onFocusChange: (hasFocus) {
                                              if (!hasFocus) {
                                                // Sync value on focus loss if needed
                                              }
                                            },
                                            child: TextField(
                                              key: ValueKey('${title}_$dayValue'),
                                              controller: TextEditingController()
                                                ..text = dayValue.toString()
                                                ..selection = TextSelection.fromPosition(
                                                  TextPosition(offset: dayValue.toString().length),
                                                ),
                                              textAlign: TextAlign.center,
                                              keyboardType: TextInputType.number,
                                              inputFormatters: [
                                                FilteringTextInputFormatter.digitsOnly,
                                                LengthLimitingTextInputFormatter(2),
                                              ],
                                              decoration: const InputDecoration(
                                                border: InputBorder.none,
                                                contentPadding: EdgeInsets.symmetric(vertical: 8),
                                                isDense: true,
                                              ),
                                              style: const TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: kNeutral900,
                                              ),
                                              onChanged: (val) {
                                                if (val.isNotEmpty) {
                                                  final parsed = int.tryParse(val);
                                                  if (parsed != null && parsed > 0 && parsed <= 31) {
                                                    onDayChanged(parsed);
                                                  }
                                                }
                                              },
                                            ),
                                          )
                                        : Text(
                                            dayValue.toString(),
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: kNeutral900,
                                            ),
                                          ),
                                  ),
                                  if (dayUnit != 'days') ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      dayUnit,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: kNeutral600,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        if (autoTask) ...[
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Auto-create Task',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: kNeutral900,
                                ),
                              ),
                              Transform.scale(
                                scale: 0.85,
                                child: Switch(
                                  value: true,
                                  onChanged: (val) {},
                                  activeColor: kLilacDeep,
                                  activeTrackColor: kLilacWash,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (extraToggle != null) ...[
                          if (autoTask) const SizedBox(height: 12) else const SizedBox.shrink(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                extraToggle['label'],
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: kNeutral900,
                                ),
                              ),
                              Transform.scale(
                                scale: 0.85,
                                child: Switch(
                                  value: extraToggle['value'],
                                  onChanged: (val) {},
                                  activeColor: kLilacDeep,
                                  activeTrackColor: kLilacWash,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
                if (actions != null && actions.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ON COMPLETION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: kNeutral500,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...actions.map((action) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: kNeutral200),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    action['tag']!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: kNeutral900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(Icons.arrow_forward, size: 14, color: kNeutral400),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    action['desc']!,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: kNeutral600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubsectionHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: kNeutral50,
      ),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: kNeutral500,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildAddListItem(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(PhosphorIconsBold.plusCircle, size: 18, color: kLilacDeep),
            SizedBox(width: 8),
            Text(
              'Add New',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kLilacDeep,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleTaskItem(String title, VoidCallback onDelete, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: kNeutral100)),
          color: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kNeutral900,
              ),
            ),
            IconButton(
              icon: Icon(PhosphorIconsBold.trash, size: 18, color: kNeutral400),
              onPressed: onDelete,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataItem(String title, String subtitle) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Icon(Icons.edit_outlined, size: 18, color: Color(0xFF94A3B8)),
              SizedBox(width: 12),
              Icon(Icons.delete_outline, size: 18, color: Color(0xFF94A3B8)),
            ],
          ),
        ],
      ),
    );
  }


// ✅ NEW: Widget to render the fancy task row
// ✅ UPDATED: Widget to render the task row with correct colors
  Widget _buildScheduledTaskItem(Map<String, dynamic> schedule) {
    String linkType = schedule['linkType'];
    Map<String, Color> colors = _getLinkColor(linkType);

    IconData badgeIcon;
    if (linkType == 'rabbit')
      badgeIcon = PhosphorIconsBold.rabbit;
    else if (linkType == 'litter')
      badgeIcon = PhosphorIconsBold.baby;
    else if (linkType == 'kit')
      badgeIcon = PhosphorIconsBold.pawPrint;
    else
      badgeIcon = PhosphorIconsBold.linkBreak;

    return InkWell(
      onTap: () => _showScheduleDetails(schedule),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: kNeutral100)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: colors['bg']!.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(badgeIcon, size: 16, color: colors['text']),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(schedule['task'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kNeutral900)),
                  const SizedBox(height: 2),
                  Text(schedule['frequency'], style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kNeutral500)),
                ],
              ),
            ),
            Icon(PhosphorIconsBold.caretRight, size: 14, color: kNeutral300),
          ],
        ),
      ),
    );
  }

  Widget _buildPipelineTaskItem(Map<String, dynamic> task) {
    String taskName = task['task'] ?? 'Task';
    String entityName = task['rabbitName'] ?? task['litterName'] ?? '';
    String category = task['category'] ?? 'Pipeline';
    String dueDateDisplay = '';
    Color dueDateColor = kNeutral500;
    IconData taskIcon = PhosphorIconsDuotone.gitBranch;

    if (task['dueDate'] != null) {
      try {
        DateTime due = DateTime.parse(task['dueDate']);
        DateTime now = DateTime.now();
        DateTime today = DateTime(now.year, now.month, now.day);
        DateTime dueDay = DateTime(due.year, due.month, due.day);
        int diff = dueDay.difference(today).inDays;

        if (diff == 0) {
          dueDateDisplay = 'Today';
          dueDateColor = Colors.orange;
        } else if (diff < 0) {
          dueDateDisplay = '${-diff} day${-diff == 1 ? '' : 's'} overdue';
          dueDateColor = Colors.red;
        } else {
          dueDateDisplay = 'In $diff day${diff == 1 ? '' : 's'}';
          dueDateColor = kNeutral500;
        }
      } catch (_) {
        dueDateDisplay = task['dueDate'];
      }
    }

    // Task type icon refinement
    switch (task['taskType']) {
      case 'palpation':
        taskIcon = PhosphorIconsDuotone.handPalm;
        break;
      case 'nestbox':
        taskIcon = PhosphorIconsDuotone.house;
        break;
      case 'kindle':
        taskIcon = PhosphorIconsDuotone.baby;
        break;
      case 'wean':
        taskIcon = PhosphorIconsDuotone.arrowsOutLineVertical;
        break;
      case 'open_breeding':
        taskIcon = PhosphorIconsDuotone.heartHalf;
        break;
      case 'quarantine_end':
        taskIcon = PhosphorIconsDuotone.shieldCheck;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kNeutral100)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(color: kLilacWash, shape: BoxShape.circle),
            child: Icon(taskIcon, size: 16, color: kLilacDeep),
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
                        taskName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: kNeutral900),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: kLilacWash, borderRadius: BorderRadius.circular(4)),
                      child: const Text('PIPELINE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kLilacDeep)),
                    ),
                  ],
                ),
                if (entityName.isNotEmpty || dueDateDisplay.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (entityName.isNotEmpty) ...[
                        Icon(PhosphorIconsRegular.rabbit, size: 12, color: kNeutral400),
                        const SizedBox(width: 4),
                        Text(entityName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kNeutral600)),
                        const SizedBox(width: 8),
                      ],
                      if (dueDateDisplay.isNotEmpty) ...[
                        Icon(PhosphorIconsBold.calendar, size: 12, color: dueDateColor),
                        const SizedBox(width: 4),
                        Text(dueDateDisplay, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: dueDateColor)),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(color: kNeutral100, borderRadius: BorderRadius.circular(4)),
            child: Text(category.toUpperCase(), style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kNeutral600)),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleItem(String title, String subtitle, VoidCallback onEdit, VoidCallback onDelete) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  PhosphorIconsRegular.pencilSimple,
                  size: 20,
                  color: Color(0xFF94A3B8),
                ),
                onPressed: onEdit, // ⬅️ Now actually edits
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
              SizedBox(width: 16),
              IconButton(
                icon: Icon(
                  PhosphorIconsRegular.trash,
                  size: 20,
                  color: Color(0xFF94A3B8),
                ),
                onPressed: onDelete, // ⬅️ Now actually deletes
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(String label, VoidCallback onPressed) {
    return InkWell(
      onTap: onPressed, // ⬅️ Now calls the provided callback
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              PhosphorIconsBold.plus,
              color: Color(0xFF6366F1),
              size: 16,
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6366F1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChecklistSetting(String title, String? description, List<Map<String, String>> items, Map<String, bool> state, {bool isCompact = false}) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCompact) ...[
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
              ),
            ),
            if (description != null) ...[
              SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
            SizedBox(height: 8),
          ] else ...[
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
              ),
            ),
            SizedBox(height: 4),
          ],
          ...items.map((item) {
            bool isChecked = state[item['key']] ?? false;
            return GestureDetector(
              onTap: () {
                setState(() {
                  state[item['key']!] = !isChecked;
                });
              },
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: isChecked ? Color(0xFF6366F1) : Colors.transparent,
                        border: Border.all(
                          color: isChecked ? Color(0xFF6366F1) : Color(0xFFE2E8F0),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: isChecked ? Icon(Icons.check, size: 12, color: Colors.white) : null,
                    ),
                    SizedBox(width: 10),
                    Text(
                      item['label']!,
                      style: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildSettingRowWithInput(String label, String description, int value, String unit) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Container(
                width: 60,
                child: TextField(
                  controller: TextEditingController(text: value.toString()),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  style: TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Text(
                unit,
                style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthIssueItemWithInput(String name, String treatment) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ),
              IconButton(
                icon: Icon(
                  PhosphorIconsRegular.trash,
                  size: 20,
                  color: Color(0xFF94A3B8),
                ),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: const Text('Remove Issue'),
                      content: Text('Remove "$name" from the registry?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel', style: TextStyle(color: Color(0xFF787774))),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            await _settings.removeHealthIssue(name);
                            setState(() {
                              healthIssues = _settings.healthIssues;
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD44C47),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Remove', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  );
                },
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ],
          ),
          if (treatment.isNotEmpty) ...[
            SizedBox(height: 8),
            Row(
              children: [
                Icon(PhosphorIconsRegular.firstAid, size: 14, color: Color(0xFF94A3B8)),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    treatment,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBreedItemWithInput(Breed breed) {
    final genotypeController = TextEditingController(text: breed.genetics.join(', '));
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                breed.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E293B),
                ),
              ),
              IconButton(
                icon: Icon(
                  PhosphorIconsRegular.trash,
                  size: 20,
                  color: Color(0xFF94A3B8),
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text('Delete Breed'),
                      content: Text('Remove "${breed.name}" from breed library?'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text('Delete', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await _db.deleteBreed(breed.id);
                    await _settings.removeBreed(breed.name);
                    final refreshed = await _db.getAllBreeds();
                    setState(() => breeds = refreshed);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${breed.name} removed'),
                          backgroundColor: Color(0xFF6366F1),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                },
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Genotype Template:',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Container(
                  height: 36,
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: TextField(
                    controller: genotypeController,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                      fontFamily: 'monospace',
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 8),
                      hintText: 'e.g. aa B- C- D- E-',
                    ),
                    onSubmitted: (value) async {
                      final updatedBreed = Breed(
                        id: breed.id,
                        name: breed.name,
                        genetics: value.split(',').map((g) => g.trim()).where((g) => g.isNotEmpty).toList(),
                      );
                      await _db.updateBreed(updatedBreed);
                      // Also update genetics on all rabbits with this breed
                      await _db.updateGeneticsForBreed(breed.name, value.trim());
                      // Sync to SettingsService
                      await _syncBreedsToSettings();
                      final refreshed = await _db.getAllBreeds();
                      setState(() => breeds = refreshed);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Genotype updated for ${breed.name}'),
                            backgroundColor: Color(0xFF6366F1),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHealthIssueItem(String name, String treatment) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Default Treatment: $treatment',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.delete_outline, size: 18, color: Color(0xFF94A3B8)),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, Color color) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$label - Coming soon'),
            backgroundColor: Color(0xFF6366F1),
            behavior: SnackBarBehavior.floating,
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDangerRow() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Color(0xFFEF4444)),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Factory Reset',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFEF4444),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Permanently delete all data',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text('Confirm Reset'),
                  content: Text('Are you sure you want to delete all data? This cannot be undone.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          await DatabaseService().factoryReset();
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.clear();
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('All data has been deleted. Restarting...'),
                                backgroundColor: Color(0xFFEF4444),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Reset failed: $e'),
                                backgroundColor: const Color(0xFFEF4444),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                      child: Text('Reset', style: TextStyle(color: Color(0xFFEF4444))),
                    ),
                  ],
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Color(0xFFEF4444),
              side: BorderSide(color: Color(0xFFE2E8F0)),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Reset',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  void _deleteTask(String category, int index) {
    setState(() {
      if (category == 'husbandry') {
        husbandryTasks.removeAt(index);
      } else if (category == 'health') {
        healthTasks.removeAt(index);
      } else if (category == 'maintenance') {
        maintenanceTasks.removeAt(index);
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Task deleted'),
        backgroundColor: Color(0xFF6366F1),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _addTask(String category) {
    _addTaskDirectory(category[0].toUpperCase() + category.substring(1));
  }

  void _deleteTaskDirectory(int id) async {
    await _db.deleteTaskDirectoryItem(id);
    await _loadTaskDirectory();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Task removed from directory'),
        backgroundColor: Color(0xFF6366F1),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _addTaskDirectory(String category) {
    TextEditingController controller = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Define New $category Task'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter task name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
            ),
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          TextButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                await _db.insertTaskDirectoryItem(controller.text.trim(), category);
                await _loadTaskDirectory();
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Task added to $category directory'),
                    backgroundColor: Color(0xFF6366F1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text('Add', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  // ✅ NEW: The robust "New Schedule" Modal
  void _openScheduleModal() async {
    // Modal State
    await _loadEntityData();
    await _loadTaskDirectory(); // Ensure latest task directory is loaded
    String selectedCategory = 'Operations';
    String? selectedTask;
    String selectedFrequency = 'Weekly';
    String selectedLinkType = 'unlinked'; // unlinked, rabbit, litter, kit
    bool isCustomTask = false;
    TextEditingController customTaskController = TextEditingController();
    List<Map<String, String>> linkedEntities = [];

    BoxDecoration inputDeco() {
      return BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
      );
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Task Options Logic: use task directory items, fallback to defaults
            List<String> directoryTasks = taskDirectoryItems.where((t) => (t['category'] as String).toLowerCase() == selectedCategory.toLowerCase()).map((t) => t['name'] as String).toList();

            List<String> currentTaskOptions;
            if (directoryTasks.isNotEmpty) {
              currentTaskOptions = directoryTasks;
            } else {
              if (selectedCategory == 'Operations')
                currentTaskOptions = [
                  'Clean Trays',
                  'Top Off Feed',
                  'Check Water',
                  'Deep Clean'
                ];
              else if (selectedCategory == 'Health')
                currentTaskOptions = [
                  'Nail Trim',
                  'Health Check',
                  'Weighing',
                  'Ear Check'
                ];
              else if (selectedCategory == 'Butchering')
                currentTaskOptions = [
                  'Schedule Butcher',
                  'Prep Equipment',
                  'Process'
                ];
              else if (selectedCategory == 'Pregnancy')
                currentTaskOptions = [
                  'Palpation',
                  'Add Nest Box',
                  'Check for Kindle'
                ];
              else
                currentTaskOptions = [
                  'Inventory Check',
                  'General Maintenance'
                ];
            }

            // Helper to build a Radio Chip
            Widget buildRadioChip(String label, String value) {
              final bool isSelected = selectedLinkType == value;
              return GestureDetector(
                onTap: () {
                  setDialogState(() {
                    selectedLinkType = value;
                    linkedEntities.clear();
                  });
                },
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? Color(0xFFF0ECFE) : Colors.white,
                    border: Border.all(color: isSelected ? Color(0xFF6366F1) : Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 16,
                        height: 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: isSelected ? Color(0xFF6366F1) : Color(0xFFE2E8F0), width: 1.5),
                        ),
                        child: isSelected ? Center(child: Container(width: 8, height: 8, decoration: BoxDecoration(color: Color(0xFF6366F1), shape: BoxShape.circle))) : null,
                      ),
                      SizedBox(width: 8),
                      Text(label, style: TextStyle(fontSize: 13, color: Color(0xFF1E293B), fontWeight: FontWeight.w500)),
                    ],
                  ),
                ),
              );
            }

            return Dialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: EdgeInsets.all(16),
              child: Container(
                width: double.infinity,
                constraints: BoxConstraints(maxWidth: 400, maxHeight: MediaQuery.of(context).size.height * 0.9),
                padding: EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Header ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'New Schedule',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pop(dialogContext),
                            child: Container(
                              padding: EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Color(0xFFF5F7FA),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.close, size: 20, color: Color(0xFF64748B)),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24),

                      // --- Category ---
                      _buildModalLabel('Category'),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: inputDeco(),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedCategory,
                            isExpanded: true,
                            icon: Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                            items: [
                              'Operations',
                              'Health',
                              if (SettingsService.instance.meatProductionEnabled) 'Butchering',
                              'Pregnancy',
                              'Other'
                            ].map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 14)))).toList(),
                            onChanged: (val) {
                              setDialogState(() {
                                selectedCategory = val!;
                                selectedTask = null;
                                isCustomTask = false;
                              });
                            },
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // --- Task ---
                      _buildModalLabel('Task'),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: inputDeco(),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: isCustomTask ? 'custom' : selectedTask,
                            hint: Text('Select a task...', style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
                            isExpanded: true,
                            icon: Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                            items: [
                              ...currentTaskOptions.map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 14)))),
                              DropdownMenuItem(value: 'custom', child: Text('+ Custom...', style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic, color: Color(0xFF6366F1)))),
                            ],
                            onChanged: (val) {
                              setDialogState(() {
                                if (val == 'custom') {
                                  isCustomTask = true;
                                  selectedTask = null;
                                } else {
                                  isCustomTask = false;
                                  selectedTask = val;
                                }
                              });
                            },
                          ),
                        ),
                      ),
                      // Custom Task Input
                      if (isCustomTask) ...[
                        SizedBox(height: 8),
                        TextField(
                          controller: customTaskController,
                          decoration: InputDecoration(
                            hintText: 'Enter custom task name...',
                            hintStyle: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Color(0xFFE2E8F0))),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Color(0xFF6366F1))),
                          ),
                        ),
                      ],
                      SizedBox(height: 16),

                      // --- Frequency ---
                      _buildModalLabel('Frequency'),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: inputDeco(),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedFrequency,
                            isExpanded: true,
                            icon: Icon(Icons.keyboard_arrow_down, color: Color(0xFF64748B)),
                            items: [
                              'Daily',
                              'Weekly',
                              'Bi-Weekly',
                              'Monthly',
                              'Once'
                            ].map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(fontSize: 14)))).toList(),
                            onChanged: (val) => setDialogState(() => selectedFrequency = val!),
                          ),
                        ),
                      ),
                      SizedBox(height: 16),

                      // --- Link To (Radio Chips) ---
                      _buildModalLabel('Link To'),
                      Text('Choose what this task applies to', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          buildRadioChip('Unlinked', 'unlinked'),
                          buildRadioChip('Rabbit', 'rabbit'),
                          buildRadioChip('Litter', 'litter'),
                          buildRadioChip('Kits (Mixed)', 'kit'),
                        ],
                      ),

                      // --- Dynamic Multi-Select for Linked Entities ---
                      if (selectedLinkType != 'unlinked') ...[
                        SizedBox(height: 16),
                        _buildModalLabel('Select ${selectedLinkType == 'rabbit' ? 'Rabbits' : selectedLinkType == 'litter' ? 'Litters' : 'Kits'}'),
                        Container(
                          width: double.infinity,
                          decoration: inputDeco(),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Selected Chips Area
                              Padding(
                                padding: EdgeInsets.all(8),
                                child: Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    if (linkedEntities.isEmpty)
                                      Padding(
                                        padding: EdgeInsets.only(top: 4, left: 4, bottom: 4),
                                        child: Text('Select...', style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
                                      ),
                                    ...linkedEntities.map((e) => Container(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Color(0xFFF5F7FA),
                                            border: Border.all(color: Color(0xFFE2E8F0)),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(e['name']!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                              SizedBox(width: 4),
                                              GestureDetector(
                                                onTap: () {
                                                  setDialogState(() {
                                                    linkedEntities.removeWhere((item) => item['id'] == e['id']);
                                                  });
                                                },
                                                child: Icon(Icons.close, size: 14, color: Color(0xFF64748B)),
                                              )
                                            ],
                                          ),
                                        ))
                                  ],
                                ),
                              ),
                              Divider(height: 1, color: Color(0xFFE2E8F0)),
                              // Scrollable list of options
                              Container(
                                height: 150,
                                child: ListView(
                                  padding: EdgeInsets.zero,
                                  shrinkWrap: true,
                                  children: (entityData[selectedLinkType] ?? []).map((entity) {
                                    final isSelected = linkedEntities.any((e) => e['id'] == entity['id']);
                                    return InkWell(
                                      onTap: () {
                                        setDialogState(() {
                                          if (isSelected) {
                                            linkedEntities.removeWhere((e) => e['id'] == entity['id']);
                                          } else {
                                            linkedEntities.add(entity);
                                          }
                                        });
                                      },
                                      child: Container(
                                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        color: isSelected ? Color(0xFFF5F7FA) : Colors.transparent,
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 18,
                                              height: 18,
                                              decoration: BoxDecoration(
                                                color: isSelected ? Color(0xFF6366F1) : Colors.transparent,
                                                border: Border.all(color: isSelected ? Color(0xFF6366F1) : Color(0xFF64748B), width: 1.5),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: isSelected ? Icon(Icons.check, size: 14, color: Colors.white) : null,
                                            ),
                                            SizedBox(width: 10),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(entity['name']!, style: TextStyle(fontSize: 14, color: Color(0xFF1E293B))),
                                                if (entity.containsKey('code')) Text(entity['code']!, style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                              ],
                                            )
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              )
                            ],
                          ),
                        ),
                      ],

                      SizedBox(height: 24),

                      // --- Save Button ---
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            String finalTaskName = isCustomTask ? customTaskController.text : (selectedTask ?? 'Unknown');

                            if (finalTaskName.isEmpty || finalTaskName == 'Unknown') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Please select or enter a task name'), backgroundColor: Color(0xFFD44C47)),
                              );
                              return;
                            }

                            try {
                              await _db.insertScheduledTask({
                                'name': finalTaskName,
                                'category': selectedCategory,
                                'frequency': selectedFrequency,
                                'linkType': selectedLinkType,
                                'linkedEntities': List.from(linkedEntities),
                              });

                              final updatedTasks = await _db.getAllScheduledTasks();
                              setState(() {
                                scheduledTasks = updatedTasks;
                              });

                              Navigator.pop(dialogContext);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Schedule Saved'), backgroundColor: Color(0xFF6366F1)),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error saving schedule: $e'), backgroundColor: Color(0xFFD44C47)),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF6366F1),
                            padding: EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text('Save Schedule', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                        ),
                      ),

                      // --- Cancel Button ---
                      SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(dialogContext),
                          child: Text('Cancel', style: TextStyle(fontSize: 14, color: Color(0xFF64748B))),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Helpers for the modal
  Widget _buildModalLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF1E293B))),
    );
  }

  Widget _buildModalDropdown({required String value, required List<String> items, required Function(String?) onChanged}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFE9E9E7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: value,
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  // ✅ UPDATED: Radio Chip Style for Modal
  Widget _buildLinkChip(String label, String value, String currentValue, Function(String) onSelect) {
    bool isSelected = currentValue == value;
    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFFFDF3E8) : Colors.white, // Very light teal background if selected
          border: Border.all(
            color: isSelected ? Color(0xFF6366F1) : Color(0xFFE2E8F0), // Teal border if selected
            width: isSelected ? 1.5 : 1.0,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Radio Circle
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: isSelected ? Color(0xFF6366F1) : Color(0xFFCBD5E1), width: isSelected ? 5 : 1.5 // Thicker border simulates the "dot" inside
                    ),
                color: Colors.white,
              ),
            ),
            SizedBox(width: 10),
            Text(label, style: TextStyle(fontSize: 14, color: Color(0xFF1E293B), fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  void _addBreed() {
    final nameController = TextEditingController();
    final genotypeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text('Add Breed', style: TextStyle(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Breed Name',
                hintText: 'e.g. Holland Lop',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: genotypeController,
              decoration: InputDecoration(
                labelText: 'Genotype Template',
                hintText: 'e.g. aa B- C- D- E-',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              style: TextStyle(fontFamily: 'monospace'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.trim().isEmpty) return;
              final newBreed = Breed(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameController.text.trim(),
                genetics: genotypeController.text.split(',').map((g) => g.trim()).where((g) => g.isNotEmpty).toList(),
              );
              await _db.insertBreed(newBreed);
              // Also sync to SettingsService for quick_info_card compatibility
              await _settings.addBreed(newBreed.name, genotypeController.text.trim());
              final refreshed = await _db.getAllBreeds();
              setState(() => breeds = refreshed);
              Navigator.pop(ctx);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${newBreed.name} added to breed library'),
                    backgroundColor: Color(0xFF6366F1),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF6366F1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Sync all DB breeds to SettingsService so quick_info_card can access them
  Future<void> _syncBreedsToSettings() async {
    final allBreeds = await _db.getAllBreeds();
    final breedMaps = allBreeds
        .map((b) => {
              'name': b.name,
              'genotype': b.genetics.join(', ')
            })
        .toList();
    await _settings.setBreeds(breedMaps);
  }

  void _addHealthIssue() {
    final nameController = TextEditingController();
    final treatmentController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Health Issue', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Issue / Condition',
                hintText: 'e.g. Snuffles, GI Stasis...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: treatmentController,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Default Treatment (optional)',
                hintText: 'e.g. Antibiotics, fluids...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF787774))),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                await _settings.addHealthIssue(name, treatmentController.text.trim());
                setState(() {
                  healthIssues = _settings.healthIssues;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kLilacDeep,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ==================== COLOR DIRECTORY ====================

  void _addColor() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Color', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Color Name',
            hintText: 'e.g. Castor, Blue Otter...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF787774))),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = controller.text.trim();
              if (val.isNotEmpty && !colorDirectory.contains(val)) {
                Navigator.pop(ctx);
                await _settings.addColor(val);
                setState(() {
                  colorDirectory = _settings.colors;
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kLilacDeep,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Add', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _removeColorItem(String color) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Color'),
        content: Text('Remove "$color" from the directory?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF787774))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _settings.removeColor(color);
              setState(() {
                colorDirectory = _settings.colors;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD44C47),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Remove', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildColorItem(String color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F5),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE9E9E7)),
            ),
            child: const Icon(Icons.circle, size: 14, color: Color(0xFF6366F1)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              color,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          IconButton(
            icon: Icon(
              PhosphorIconsRegular.trash,
              size: 20,
              color: Color(0xFF94A3B8),
            ),
            onPressed: () => _removeColorItem(color),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  // ✅ 1. View Schedule Details Modal
  void _showScheduleDetails(Map<String, dynamic> schedule) {
    String linkType = schedule['linkType'];
    List linkedEntities = schedule['linkedEntities'] ?? [];
    Map<String, Color> colors = _getLinkColor(linkType);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Schedule Details',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Task Title
            Text(
              schedule['task'],
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF6366F1)),
            ),
            const SizedBox(height: 16),

            // Meta Tags Row
            Row(
              children: [
                _buildDetailBadge((schedule['category'] as String).toUpperCase(), const Color(0xFFF1F5F9), const Color(0xFF64748B)),
                const SizedBox(width: 8),
                _buildDetailBadge(schedule['frequency'], const Color(0xFFF1F5F9), const Color(0xFF64748B)),
                const SizedBox(width: 8),
                // Link Type Badge
                if (linkType != 'unlinked') _buildDetailBadge(linkType[0].toUpperCase() + linkType.substring(1), colors['bg']!, colors['text']!),
              ],
            ),
            const SizedBox(height: 24),

            // Linked Entities Section
            if (linkedEntities.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LINKED ${linkType.toUpperCase()}S',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8)),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: linkedEntities.map<Widget>((e) {
                        String label = e['code'] != null ? '${e['name']} (${e['code']})' : e['name'];
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(PhosphorIconsBold.link, size: 12, color: const Color(0xFF6366F1)),
                              const SizedBox(width: 6),
                              Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF334155), fontWeight: FontWeight.w500)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Edit feature coming soon')));
                    },
                    icon: const Icon(PhosphorIconsBold.pencilSimple, size: 18),
                    label: const Text('Edit'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      foregroundColor: const Color(0xFF6366F1),
                      side: const BorderSide(color: Color(0xFF6366F1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      _deleteScheduledTask(schedule['id']);
                      Navigator.pop(context);
                    },
                    icon: Icon(PhosphorIconsBold.trash, size: 18, color: Colors.white),
                    label: const Text('Delete'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      backgroundColor: const Color(0xFFEF4444),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: MediaQuery.of(context).viewInsets.bottom + 20),
          ],
        ),
      ),
    );
  }

  // ✅ 2. Delete Logic - Now uses database
  void _deleteScheduledTask(int id) async {
    try {
      // Delete from database
      await _db.deleteScheduledTask(id);

      // Reload tasks from database
      final updatedTasks = await _db.getAllScheduledTasks();
      setState(() {
        scheduledTasks = updatedTasks;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule deleted'), backgroundColor: Color(0xFF6366F1)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting schedule: $e'), backgroundColor: Color(0xFFD44C47)),
      );
    }
  }

  // ✅ 3. Helper for Colors (Pastel Style)
  Map<String, Color> _getLinkColor(String type) {
    if (type == 'rabbit') {
      return {
        'bg': const Color(0xFFFEF9C3), // Softer Yellow background
        'text': const Color(0xFFCA8A04), // Golden/Orange text
        'border': const Color(0xFFFEF08A), // Light yellow border
      };
    }
    if (type == 'litter') {
      return {
        'bg': const Color(0xFFDBEAFE), // Light Blue
        'text': const Color(0xFF2563EB), // Blue Text
        'border': const Color(0xFFBFDBFE), // Blue Border
      };
    }
    if (type == 'kit') {
      return {
        'bg': const Color(0xFFFCE7F3), // Light Pink
        'text': const Color(0xFFDB2777), // Pink Text
        'border': const Color(0xFFFBCFE8), // Pink Border
      };
    }
    // Unlinked / Default
    return {
      'bg': const Color(0xFFF1F5F9), // Light Slate
      'text': const Color(0xFF64748B), // Slate Text
      'border': const Color(0xFFE2E8F0), // Slate Border
    };
  }

  // ✅ 4. Helper for Badges (Used in Details Modal)
  Widget _buildDetailBadge(String text, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
    );
  }

  // ==================== OPERATIONS METHODS ====================

  void _addLocation() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Add Barn / Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kNeutral900)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Location Name',
            hintText: 'e.g. Main Barn, Quonset Hut...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kLilacDeep, width: 2),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: kNeutral600, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(ctx);
                await _db.insertBarn({
                  'id': DateTime.now().millisecondsSinceEpoch.toString(),
                  'name': name,
                  'rows': '[]',
                  'createdAt': DateTime.now().toIso8601String(),
                });
                await _loadBarns();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kLilacDeep,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _deleteLocationItem(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Location'),
        content: const Text('Are you sure? This will remove the location entry.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await _db.deleteBarn(id);
      await _loadBarns();
    }
  }

  void _showCages(Map<String, dynamic> barn) {
    // Show a dialog to view cages in this barn (simplified)
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        final List rows = jsonDecode(barn['rows'] ?? '[]') as List;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${barn['name']} Cages',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: kNeutral900),
              ),
              const SizedBox(height: 16),
              if (rows.isEmpty)
                const Center(child: Padding(padding: EdgeInsets.all(20), child: Text('No cages defined in this location.'))),
              ...rows.map((row) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(row['name'] as String, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          children: (row['cages'] as List).map((cage) => Chip(label: Text(cage as String))).toList(),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  // ==================== AUTOMATION METHODS ====================

  void _deleteTaskDirectoryItem(int id) async {
    await _db.deleteTaskDirectoryItem(id);
    await _loadTaskDirectory();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task removed'), backgroundColor: kLilacDeep),
      );
    }
  }

  void _showAddTaskDirectoryDialog(String category) {
    _addTaskDirectory(category);
  }
}
