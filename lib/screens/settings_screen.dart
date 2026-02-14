import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/settings_service.dart'; // ✅ ADD THIS
import '../services/database_service.dart'; // ✅ ADD THIS for scheduled tasks
import '../models/breed.dart';
import 'package:image_picker/image_picker.dart'; // ✅ ADD THIS
import 'package:permission_handler/permission_handler.dart'; // ✅ ADD THIS
import 'dart:io'; // ✅ ADD THIS

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
  bool urgentAlerts = true;
  bool snowballEffect = true;
  bool kitPromotion = true;
  bool maturityPromotion = true;
  bool quarantineChecks = true;

  String weightUnit = 'lbs';
  String currency = 'usd';
  String dateFormat = 'MM/dd/yyyy';
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
  List<Map<String, String>> husbandryTasks = [];
  List<Map<String, String>> healthTasks = [];
  List<Map<String, String>> maintenanceTasks = [];

  // Task Directory (DB-backed)
  List<Map<String, dynamic>> taskDirectoryItems = [];

  List<Map<String, dynamic>> scheduledTasks = []; // ✅ CHANGED: Load from database instead of hardcoded

  // TODO: Load entity data from database
  Map<String, List<Map<String, String>>> entityData = {
    'rabbit': [],
    'litter': [],
    'kit': [],
  };
  Future<void> _loadEntityData() async {
    final rabbits = await _db.getAllRabbits();
    final litters = await _db.getLitters();

    setState(() {
      entityData = {
        'rabbit': rabbits
            .map((r) => {
                  'id': r.id,
                  'name': r.name ?? r.id,
                  'code': r.cage ?? '', // ✅ Changed from cageLocation to cage
                })
            .toList(),
        'litter': litters
            .map((l) => {
                  'id': l.id, // ✅ Changed from litterId to id
                  'name': 'Litter ${l.id}', // ✅ Changed from litterId to id
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _tabController.animation?.addListener(() {
      setState(() {});
    });
    _loadSettings();
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

        // Notifications
        pushNotifications = _settings.notificationsEnabled;

        // ✅ Scheduled tasks from database
        scheduledTasks = loadedTasks;

        // ✅ Breeds from database
        breeds = loadedBreeds;

        // ✅ Task directory items loaded below after setState

        _isLoading = false;
      });
      // Load task directory items from database
      await _loadTaskDirectory();
    } catch (e) {
      print('❌ Error loading settings: $e');
      setState(() => _isLoading = false);
    }
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
      if (_logoPath != null) await _settings.setFarmLogo(_logoPath!);
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

      // Notifications
      await _settings.setNotificationsEnabled(pushNotifications);

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(' Settings saved successfully'),
          backgroundColor: Color(0xFF0F7B6C),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('❌ Error saving settings: $e'),
          backgroundColor: const Color(0xFFD44C47),
          behavior: SnackBarBehavior.floating,
        ),
      );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              source == ImageSource.camera ? 'Camera permission is required' : 'Gallery permission is required',
            ),
            backgroundColor: const Color(0xFFD44C47),
            action: SnackBarAction(
              label: 'Settings',
              textColor: Colors.white,
              onPressed: () => openAppSettings(),
            ),
          ),
        );
        return;
      }

      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 90,
      );

      if (image != null) {
        setState(() {
          _logoPath = image.path;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logo added successfully. Remember to tap Save!'),
            backgroundColor: Color(0xFF0F7B6C),
            duration: Duration(seconds: 2),
          ),
        );
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
                      backgroundColor: Color(0xFF0F7B6C),
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
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Settings',
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w700,
              fontSize: 18,
            ),
          ),
        ),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F7B6C)),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF1E293B)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Settings',
          style: TextStyle(
            color: Color(0xFF1E293B),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveSettings,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F7B6C)),
                    ),
                  )
                : const Text(
                    'Save',
                    style: TextStyle(
                      color: Color(0xFF0F7B6C),
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGeneralTab(),
                _buildModulesTab(),
                _buildPipelineTab(),
                _buildOperationsTab(),
                _buildAutomationTab(),
                _buildDataTab(),
                _buildSystemTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildTabChip('General', 0),
            _buildTabChip('Modules', 1),
            _buildTabChip('Pipeline', 2),
            _buildTabChip('Operations', 3),
            _buildTabChip('Automation', 4),
            _buildTabChip('Data', 5),
            _buildTabChip('System', 6),
          ],
        ),
      ),
    );
  }

  Widget _buildTabChip(String label, int index) {
    bool isSelected = (_tabController.animation?.value.round() ?? _tabController.index) == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _tabController.animateTo(index);
        });
      },
      child: Container(
        margin: EdgeInsets.only(right: 8),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF1E293B) : Color(0xFFF5F7FA),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Color(0xFF1E293B) : Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? Colors.white : Color(0xFF64748B),
          ),
        ),
      ),
    );
  }

  // ============================================
  // GENERAL TAB
  // ============================================
  Widget _buildGeneralTab() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildCard(
          'Farm Profile',
          PhosphorIconsDuotone.houseLine,
          [
            _buildVerticalSetting(
              'Farm Name',
              TextField(
                controller: _farmNameController,
                decoration: InputDecoration(
                  hintText: 'Green Valley Rabbitry',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFF0F7B6C)),
                  ),
                ),
              ),
            ),
            _buildVerticalSetting(
              'Owner Name',
              TextField(
                controller: _ownerNameController,
                decoration: InputDecoration(
                  hintText: 'John Doe',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: Color(0xFF0F7B6C)),
                  ),
                ),
              ),
              description: 'Used for pedigree generation.',
            ),
            _buildVerticalSetting(
              'Logo',
              Row(
                children: [
                  // Logo Preview
                  GestureDetector(
                    onTap: _showLogoUploadOptions,
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F7FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        image: _logoPath != null && File(_logoPath!).existsSync()
                            ? DecorationImage(
                                image: FileImage(File(_logoPath!)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _logoPath == null || !File(_logoPath!).existsSync()
                          ? const Icon(
                              Icons.image_outlined,
                              size: 32,
                              color: Color(0xFF94A3B8),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Upload Button
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showLogoUploadOptions,
                      icon: Icon(
                        _logoPath == null ? Icons.upload : Icons.edit,
                        size: 18,
                        color: const Color(0xFF0F7B6C),
                      ),
                      label: Text(
                        _logoPath == null ? 'Upload Logo' : 'Change Logo',
                        style: const TextStyle(
                          color: Color(0xFF0F7B6C),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: Color(0xFF0F7B6C)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              description: 'Upload a square image for reports.',
            ),
          ],
        ),
        SizedBox(height: 20),
        _buildCard(
          'Localization',
          Icons.public_outlined,
          [
            _buildSettingRow(
              'Weight Unit',
              DropdownButton<String>(
                value: weightUnit,
                underline: SizedBox(),
                style: TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                items: [
                  DropdownMenuItem(value: 'lbs', child: Text('Pounds (lbs)')),
                  DropdownMenuItem(value: 'kg', child: Text('Kilograms (kg)')),
                ],
                onChanged: (value) {},
              ),
            ),
            _buildSettingRow(
              'Currency',
              DropdownButton<String>(
                value: 'usd',
                underline: SizedBox(),
                style: TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                items: [
                  DropdownMenuItem(value: 'usd', child: Text('\$ - USD')),
                  DropdownMenuItem(value: 'eur', child: Text('€ - EUR')),
                  DropdownMenuItem(value: 'gbp', child: Text('£ - GBP')),
                  DropdownMenuItem(value: 'inr', child: Text('₹ - INR')),
                  DropdownMenuItem(value: 'aud', child: Text('A\$ - AUD')),
                  DropdownMenuItem(value: 'cny', child: Text('¥ - CNY')),
                  DropdownMenuItem(value: 'rub', child: Text('₽ - RUB')),
                  DropdownMenuItem(value: 'mxn', child: Text('\$ - MXN')),
                  // Add more as needed
                ],
                onChanged: (value) {
                  setState(() => currency = value!);
                },
              ),
            ),
            _buildSettingRow(
              'Date Format',
              DropdownButton<String>(
                value: dateFormat,
                underline: SizedBox(),
                style: TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                items: [
                  DropdownMenuItem(value: 'MM/dd/yyyy', child: Text('MM/DD/YYYY')), // ✅ Changed
                  DropdownMenuItem(value: 'dd/MM/yyyy', child: Text('DD/MM/YYYY')), // ✅ Changed
                  DropdownMenuItem(value: 'yyyy-MM-dd', child: Text('YYYY-MM-DD')), // ✅ Added
                ],
                onChanged: (value) {
                  setState(() => dateFormat = value!);
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================
  // MODULES TAB
  // ============================================
  Widget _buildModulesTab() {
    return ListView(
      padding: EdgeInsets.all(16),
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
            _buildSwitchRow(
              'Finance & Sales',
              'Enables ledger, kit sales, and expense tracking.',
              financeSales,
              (val) => setState(() => financeSales = val),
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
      padding: EdgeInsets.all(16),
      children: [
        // ADD THIS NEW HEADER ⬇️
        Padding(
          padding: EdgeInsets.only(bottom: 16, left: 4, right: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Breeding Timeline',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Configure your standard reproductive cycle and actions.',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),

        // WRAP the pipeline steps in a white container ⬇️
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Color(0xFFE2E8F0)),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              _buildPipelineStep('Breeding', dayLabel: 'DAY 0'),
              _buildPipelineStep(
                'Palpation Check',
                hasToggle: true,
                toggleValue: palpationEnabled,
                onToggle: (val) {
                  setState(() => palpationEnabled = val);
                },
                dayValue: palpationDays,
                onDayChanged: (val) => setState(() => palpationDays = val),
                autoTask: true,
                actions: [
                  {
                    'tag': 'Positive',
                    'desc': 'Move to Pregnant'
                  },
                  {
                    'tag': 'Negative',
                    'desc': 'Move to Open'
                  },
                ],
              ),
              _buildPipelineStep(
                'Nest Box',
                hasToggle: true,
                toggleValue: nestBoxEnabled,
                onToggle: (val) {
                  setState(() => nestBoxEnabled = val);
                },
                dayValue: nestBoxDays,
                onDayChanged: (val) => setState(() => nestBoxDays = val),
                autoTask: true,
                actions: [
                  {
                    'tag': 'Action',
                    'desc': 'Create Check Kits (Day $gestationDays)'
                  },
                ],
              ),
              _buildPipelineStep(
                'Kindle (Birth)',
                dayLabel: 'DAY $gestationDays',
                dayValue: gestationDays,
                onDayChanged: (val) => setState(() => gestationDays = val),
                showScheduleDay: true,
                actions: [
                  {
                    'tag': 'Action',
                    'desc': 'Log Litter Count'
                  },
                ],
              ),
              _buildPipelineStep(
                'Weaning',
                hasToggle: true,
                toggleValue: weaningEnabled,
                onToggle: (val) {
                  setState(() => weaningEnabled = val);
                },
                dayValue: weanAge,
                onDayChanged: (val) => setState(() => weanAge = val),
                dayUnit: 'weeks',
                autoTask: true,
                actions: [
                  {
                    'tag': 'Action',
                    'desc': 'Separate Kits & Doe'
                  },
                  {
                    'tag': 'Action',
                    'desc': 'Promote to Grow-out'
                  },
                ],
              ),
              _buildPipelineStep(
                'Grow-out Phase',
                hasToggle: true,
                toggleValue: growOutEnabled,
                onToggle: (val) {
                  setState(() => growOutEnabled = val);
                },
                dayValue: 12,
                dayUnit: 'weeks',
                extraToggle: {
                  'label': 'Track Weights',
                  'value': true
                },
              ),
              _buildPipelineStep(
                'Sexual Maturity',
                dayLabel: '$matureAge WK',
                dayValue: matureAge,
                onDayChanged: (val) => setState(() => matureAge = val),
                dayUnit: 'weeks',
                showScheduleDay: true,
                actions: [
                  {
                    'tag': 'Action',
                    'desc': 'Promote to Active Breeder'
                  },
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
  // ✅ UPDATED Operations Tab
  Widget _buildOperationsTab() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        // SCHEDULED TASKS CARD
        _buildCard(
          'Scheduled Tasks',
          PhosphorIconsDuotone.calendarCheck,
          [
            if (scheduledTasks.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(child: Text("No scheduled tasks", style: TextStyle(color: Colors.grey))),
              )
            else
              ...scheduledTasks.map((schedule) {
                return _buildScheduledTaskItem(schedule);
              }).toList(),

            _buildAddButton('Add New Schedule', _openScheduleModal), // Calls new modal
          ],
        ),
        SizedBox(height: 20),

        // TASK DIRECTORY CARD (DB-backed)
        _buildCard(
          'Task Directory',
          PhosphorIconsDuotone.listChecks,
          [
            _buildSubsectionHeader('HUSBANDRY TASKS'),
            ...husbandryTasks.map((task) {
              return _buildSimpleTaskItem(
                task['name']!,
                () => _deleteTaskDirectory(int.parse(task['id']!)),
              );
            }).toList(),
            _buildAddButton('Define New Task', () => _addTaskDirectory('Husbandry')),
            SizedBox(height: 8),
            _buildSubsectionHeader('HEALTH TASKS'),
            ...healthTasks.map((task) {
              return _buildSimpleTaskItem(
                task['name']!,
                () => _deleteTaskDirectory(int.parse(task['id']!)),
              );
            }).toList(),
            _buildAddButton('Define New Task', () => _addTaskDirectory('Health')),
            SizedBox(height: 8),
            _buildSubsectionHeader('MAINTENANCE TASKS'),
            ...maintenanceTasks.map((task) {
              return _buildSimpleTaskItem(
                task['name']!,
                () => _deleteTaskDirectory(int.parse(task['id']!)),
              );
            }).toList(),
            _buildAddButton('Define New Task', () => _addTaskDirectory('Maintenance')),
          ],
        ),
        SizedBox(height: 20),

        // TASK LOGIC CARD (Kept same as before)
        _buildCard(
          'Task Logic',
          PhosphorIconsDuotone.lightbulb,
          [
            _buildSwitchRow(
              'Snowball Effect',
              'Overdue tasks carry over to the next day instead of disappearing.',
              snowballEffect,
              (val) => setState(() => snowballEffect = val),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================
  // AUTOMATION TAB
  // ============================================
  Widget _buildAutomationTab() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildCard(
          'Exit Workflows',
          Icons.logout_outlined,
          [
            _buildChecklistSetting(
              'Sold Logic',
              'When rabbit is marked "Sold":',
              [
                {
                  'label': 'Move to Archive',
                  'key': 'archive'
                },
                {
                  'label': 'Open Ledger (Income)',
                  'key': 'ledger'
                },
                {
                  'label': 'Generate Pedigree PDF',
                  'key': 'pedigree'
                },
              ],
              soldLogic,
            ),
            _buildChecklistSetting(
              'Harvest Logic',
              'When rabbit is marked "Butchered":',
              [
                {
                  'label': 'Move to Archive',
                  'key': 'archive'
                },
                {
                  'label': 'Open Weight Log',
                  'key': 'weight'
                },
              ],
              harvestLogic,
            ),
            _buildChecklistSetting(
              'Mortality Logic',
              'When rabbit is marked "Dead":',
              [
                {
                  'label': 'Move to Archive',
                  'key': 'archive'
                },
                {
                  'label': 'Log Cause of Death',
                  'key': 'cause'
                },
              ],
              mortalityLogic,
            ),
          ],
        ),
        SizedBox(height: 20),
        _buildCard(
          'Status Transitions',
          Icons.auto_awesome_outlined,
          [
            _buildSwitchRow(
              'Kit Promotion',
              'Auto-promote kits to "Grow-out" after weaning task.',
              kitPromotion,
              (val) => setState(() => kitPromotion = val),
            ),
            _buildSwitchRow(
              'Maturity Promotion',
              'Auto-promote "Grow-out" to "Active" after 6 months.',
              maturityPromotion,
              (val) => setState(() => maturityPromotion = val),
            ),
          ],
        ),
        SizedBox(height: 20),
        _buildCard(
          'Health & Quarantine',
          Icons.health_and_safety_outlined,
          [
            _buildSwitchRow(
              'Quarantine Checks',
              'Auto-add daily check tasks if rabbits are in quarantine.',
              quarantineChecks,
              (val) => setState(() => quarantineChecks = val),
            ),
            _buildSettingRowWithInput(
              'Default Duration',
              'Standard isolation period in days.',
              30,
              'days',
            ),
            _buildChecklistSetting(
              'Entry Actions',
              null,
              [
                {
                  'label': 'Prompt to change Cage',
                  'key': 'changeCage'
                },
              ],
              quarantineEntry,
              isCompact: true,
            ),
            _buildChecklistSetting(
              'Exit Actions',
              null,
              [
                {
                  'label': 'Prompt to return to original Cage',
                  'key': 'returnCage'
                },
                {
                  'label': 'Create "End Quarantine" Task',
                  'key': 'endTask'
                },
              ],
              quarantineExit,
              isCompact: true,
            ),
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
      padding: EdgeInsets.all(16),
      children: [
        _buildCard(
          'Breed Library',
          PhosphorIconsDuotone.pawPrint,
          [
            ...breeds
                .map((breed) => _buildBreedItemWithInput(
                      breed,
                    ))
                .toList(),
            _buildAddButton('Add Breed', _addBreed),
          ],
        ),
        SizedBox(height: 20),
        _buildCard(
          'Health Issues Registry',
          PhosphorIconsDuotone.firstAid,
          [
            ...healthIssues
                .map((issue) => _buildHealthIssueItemWithInput(
                      issue['name']!,
                      issue['treatment']!,
                    ))
                .toList(),
            _buildAddButton('Add Issue', _addHealthIssue),
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
      padding: EdgeInsets.all(16),
      children: [
        _buildCard(
          'Notifications',
          Icons.notifications_outlined,
          [
            _buildSwitchRow(
              'Push Notifications',
              null,
              pushNotifications,
              (val) => setState(() => pushNotifications = val),
            ),
            _buildSettingRow(
              'Daily Digest Time',
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Color(0xFFE2E8F0)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '07:00',
                  style: TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                ),
              ),
              description: 'When to send task summary.',
            ),
            _buildSwitchRow(
              'Urgent Alerts',
              'Kindle dates & mortality spikes.',
              urgentAlerts,
              (val) => setState(() => urgentAlerts = val),
            ),
          ],
        ),
        SizedBox(height: 20),
        _buildCard(
          'System Defaults',
          Icons.tune_outlined,
          [
            _buildSettingRow(
              'Fiscal Year Start',
              DropdownButton<String>(
                value: 'January',
                underline: SizedBox(),
                style: TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
                items: [
                  DropdownMenuItem(value: 'January', child: Text('January')),
                  DropdownMenuItem(value: 'April', child: Text('April')),
                ],
                onChanged: (value) {},
              ),
            ),
          ],
        ),
        SizedBox(height: 20),
        _buildCard(
          'Data & Safety',
          Icons.download_outlined,
          [
            _buildActionButton(Icons.file_download_outlined, 'Export Herd Data (CSV)', Color(0xFF0F7B6C)),
            _buildActionButton(Icons.file_download_outlined, 'Export Ledger (CSV)', Color(0xFF0F7B6C)),
            _buildDangerRow(),
          ],
        ),
      ],
    );
  }

  // ============================================
  // HELPER WIDGETS
  // ============================================

  Widget _buildCard(String title, IconData icon, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFFAFAFA),
              border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(icon, color: Color(0xFF0F7B6C), size: 20),
                SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
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
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
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
              ],
            ),
          ),
          SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }

  Widget _buildSwitchRow(String label, String? description, bool value, Function(bool) onChanged) {
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
                  label,
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
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Color(0xFF0F7B6C),
          ),
        ],
      ),
    );
  }

  Widget _buildVerticalSetting(String label, Widget child, {String? description}) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
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
          SizedBox(height: 8),
          child,
          if (description != null) ...[
            SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
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
              color: Color(0xFF0F7B6C),
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 12),
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
                          activeColor: Color(0xFF0F7B6C),
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
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        if (showScheduleDay || (dayValue != null && hasToggle))
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Schedule Day',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1E293B),
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
                                      border: Border.all(color: Color(0xFFE2E8F0)),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: onDayChanged != null
                                        ? TextField(
                                            controller: TextEditingController(text: dayValue.toString()),
                                            textAlign: TextAlign.center,
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              border: InputBorder.none,
                                              contentPadding: EdgeInsets.symmetric(vertical: 8),
                                              isDense: true,
                                            ),
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF1E293B),
                                            ),
                                            onChanged: (val) {
                                              final parsed = int.tryParse(val);
                                              if (parsed != null && parsed > 0) {
                                                onDayChanged(parsed);
                                              }
                                            },
                                          )
                                        : Text(
                                            dayValue.toString(),
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                  ),
                                  if (dayUnit != 'days') ...[
                                    SizedBox(width: 8),
                                    Text(
                                      dayUnit,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF64748B),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        if (autoTask) ...[
                          SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Auto-create Task',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              Transform.scale(
                                scale: 0.85,
                                child: Switch(
                                  value: true,
                                  onChanged: (val) {},
                                  activeColor: Color(0xFF0F7B6C),
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (extraToggle != null) ...[
                          if (autoTask) SizedBox(height: 12) else SizedBox.shrink(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                extraToggle['label'],
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF1E293B),
                                ),
                              ),
                              Transform.scale(
                                scale: 0.85,
                                child: Switch(
                                  value: extraToggle['value'],
                                  onChanged: (val) {},
                                  activeColor: Color(0xFF0F7B6C),
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
                  SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ON COMPLETION',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF94A3B8),
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 8),
                      ...actions.map((action) => Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: Color(0xFFE2E8F0)),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    action['tag']!,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward, size: 14, color: Color(0xFFCBD5E1)),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    action['desc']!,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF64748B),
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
      width: double.infinity, // ⬅️ Full width
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Color(0xFFF8FAFC), // Light gray background covering full width
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF64748B),
          letterSpacing: 0.8,
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

  Widget _buildSimpleTaskItem(String title, VoidCallback onDelete) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
        color: Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0xFF1E293B),
            ),
          ),
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
    );
  }

// ✅ NEW: Widget to render the fancy task row
// ✅ UPDATED: Widget to render the task row with correct colors
  Widget _buildScheduledTaskItem(Map<String, dynamic> schedule) {
    String linkType = schedule['linkType'];
    List linkedEntities = schedule['linkedEntities'] ?? [];
    Map<String, Color> colors = _getLinkColor(linkType);

    // Icons based on type
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
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFF1F5F9))), // Very light divider
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Row: Task Name + Link Badge
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        schedule['task'],
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      SizedBox(width: 8),
                      // Link Type Badge
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colors['bg'],
                          borderRadius: BorderRadius.circular(12), // Rounded pill shape
                          border: Border.all(color: colors['border']!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(badgeIcon, size: 12, color: colors['text']),
                            SizedBox(width: 4),
                            Text(
                              linkType == 'unlinked' ? 'Unlinked' : linkType[0].toUpperCase() + linkType.substring(1),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: colors['text'],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),

                  // Second Row: Category + Frequency
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Color(0xFFF1F5F9), // Light gray for category
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          (schedule['category'] as String).toUpperCase(),
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF64748B), letterSpacing: 0.5),
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        schedule['frequency'],
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),

                  // Third Row: Linked Entities Chips (if any)
                  if (linkedEntities.isNotEmpty) ...[
                    SizedBox(height: 10),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: linkedEntities.take(3).map<Widget>((e) {
                        String label = e['code'] != null ? '${e['name']} (${e['code']})' : e['name'];
                        return Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(badgeIcon, size: 12, color: Color(0xFF94A3B8)),
                              SizedBox(width: 6),
                              Text(label, style: TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8.0, top: 4.0),
              child: Icon(Icons.chevron_right, color: Color(0xFFCBD5E1), size: 20),
            ),
          ],
        ),
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
              color: Color(0xFF0F7B6C),
              size: 16,
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F7B6C),
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
                        color: isChecked ? Color(0xFF0F7B6C) : Colors.transparent,
                        border: Border.all(
                          color: isChecked ? Color(0xFF0F7B6C) : Color(0xFFE2E8F0),
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
              Text(
                name,
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
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Delete $name - Coming soon'),
                      backgroundColor: Color(0xFF0F7B6C),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
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
                'Default Treatment:',
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
                  alignment: Alignment.centerLeft,
                  child: Text(
                    treatment,
                    style: TextStyle(
                      fontSize: 13,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
                          backgroundColor: Color(0xFF0F7B6C),
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
                            backgroundColor: Color(0xFF0F7B6C),
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
            backgroundColor: Color(0xFF0F7B6C),
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
                      onPressed: () {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Reset cancelled'),
                            backgroundColor: Color(0xFFEF4444),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
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
        backgroundColor: Color(0xFF0F7B6C),
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
        backgroundColor: Color(0xFF0F7B6C),
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
              borderSide: BorderSide(color: Color(0xFF0F7B6C), width: 2),
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
                    backgroundColor: Color(0xFF0F7B6C),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: Text('Add', style: TextStyle(color: Color(0xFF0F7B6C), fontWeight: FontWeight.w600)),
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
    String linkType = 'unlinked'; // unlinked, rabbit, litter, kit
    bool isCustomTask = false;
    TextEditingController customTaskController = TextEditingController();
    List<Map<String, String>> selectedEntities = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Get Tasks based on Category from task directory
            List<Map<String, String>> currentCategoryTasks = taskDirectoryItems
                .where((t) => (t['category'] as String).toLowerCase() == selectedCategory.toLowerCase())
                .map((t) => {
                      'name': t['name'] as String
                    })
                .toList();

            return Dialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: EdgeInsets.all(16),
              child: Container(
                padding: EdgeInsets.all(24),
                constraints: BoxConstraints(maxWidth: 500, maxHeight: MediaQuery.of(context).size.height * 0.9),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('New Schedule', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                          IconButton(
                            icon: Icon(Icons.close, color: Color(0xFF64748B)),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                      SizedBox(height: 20),

                      // Category
                      _buildModalLabel('Category'),
                      _buildModalDropdown(
                        value: selectedCategory,
                        items: [
                          'Operations',
                          'Health',
                          'Butchering',
                          'Pregnancy',
                          'Husbandry',
                          'Maintenance'
                        ],
                        onChanged: (val) {
                          setModalState(() {
                            selectedCategory = val!;
                            selectedTask = null;
                            isCustomTask = false;
                          });
                        },
                      ),
                      SizedBox(height: 16),

                      // Task
                      _buildModalLabel('Task'),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            hint: Text('Select a task...', style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8))),
                            value: isCustomTask ? 'custom' : selectedTask,
                            items: [
                              ...currentCategoryTasks.map((t) => DropdownMenuItem(
                                    value: t['name'],
                                    child: Text(t['name']!),
                                  )),
                              DropdownMenuItem(value: 'custom', child: Text('+ Custom...', style: TextStyle(color: Color(0xFF0F7B6C), fontWeight: FontWeight.w600))),
                            ],
                            onChanged: (val) {
                              setModalState(() {
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
                      if (isCustomTask)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: TextField(
                            controller: customTaskController,
                            decoration: InputDecoration(
                              hintText: 'Enter custom task name...',
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      SizedBox(height: 16),

                      // Frequency
                      _buildModalLabel('Frequency'),
                      _buildModalDropdown(
                        value: selectedFrequency,
                        items: [
                          'Daily',
                          'Weekly',
                          'Bi-Weekly',
                          'Monthly',
                          'Once'
                        ],
                        onChanged: (val) => setModalState(() => selectedFrequency = val!),
                      ),
                      SizedBox(height: 16),

                      // Link To (Radio Chips)
                      _buildModalLabel('Link To'),
                      Text('Choose what this task applies to', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _buildLinkChip(
                              'Unlinked',
                              'unlinked',
                              linkType,
                              (val) => setModalState(() {
                                    linkType = val;
                                    selectedEntities.clear();
                                  })),
                          _buildLinkChip(
                              'Rabbit',
                              'rabbit',
                              linkType,
                              (val) => setModalState(() {
                                    linkType = val;
                                    selectedEntities.clear();
                                  })),
                          _buildLinkChip(
                              'Litter',
                              'litter',
                              linkType,
                              (val) => setModalState(() {
                                    linkType = val;
                                    selectedEntities.clear();
                                  })),
                          _buildLinkChip(
                              'Kits (Mixed)',
                              'kit',
                              linkType,
                              (val) => setModalState(() {
                                    linkType = val;
                                    selectedEntities.clear();
                                  })),
                        ],
                      ),

                      // Dynamic Multi-Select
                      if (linkType != 'unlinked') ...[
                        SizedBox(height: 16),
                        _buildModalLabel('Select ${linkType == 'rabbit' ? 'Rabbits' : linkType == 'litter' ? 'Litters' : 'Kits'}'),
                        Container(
                          decoration: BoxDecoration(
                            border: Border.all(color: Color(0xFFE2E8F0)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            children: [
                              // Selected Chips
                              if (selectedEntities.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: selectedEntities
                                        .map((e) => Chip(
                                              label: Text(e['name']!, style: TextStyle(fontSize: 12)),
                                              deleteIcon: Icon(Icons.close, size: 14),
                                              onDeleted: () {
                                                setModalState(() {
                                                  selectedEntities.removeWhere((item) => item['id'] == e['id']);
                                                });
                                              },
                                              backgroundColor: Color(0xFFF1F5F9),
                                              padding: EdgeInsets.zero,
                                              visualDensity: VisualDensity.compact,
                                            ))
                                        .toList(),
                                  ),
                                ),

                              // Dropdown List
                              Container(
                                height: 150,
                                decoration: BoxDecoration(
                                  border: Border(top: BorderSide(color: Color(0xFFE2E8F0))),
                                ),
                                child: ListView(
                                  shrinkWrap: true,
                                  children: (entityData[linkType] ?? []).map((entity) {
                                    bool isSelected = selectedEntities.any((e) => e['id'] == entity['id']);
                                    return CheckboxListTile(
                                      value: isSelected,
                                      title: Text(entity['name']!, style: TextStyle(fontSize: 14)),
                                      subtitle: entity['code'] != null ? Text(entity['code']!, style: TextStyle(fontSize: 12)) : null,
                                      dense: true,
                                      activeColor: Color(0xFF0F7B6C),
                                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                                      onChanged: (bool? checked) {
                                        setModalState(() {
                                          if (checked == true) {
                                            selectedEntities.add(entity);
                                          } else {
                                            selectedEntities.removeWhere((e) => e['id'] == entity['id']);
                                          }
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF0F7B6C),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () async {
                            // SAVE LOGIC - Save to database
                            String finalTaskName = isCustomTask ? customTaskController.text : (selectedTask ?? 'Unknown');

                            if (finalTaskName.isEmpty || finalTaskName == 'Unknown') {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Please select or enter a task name'), backgroundColor: Color(0xFFD44C47)),
                              );
                              return;
                            }

                            try {
                              // Save to database
                              await _db.insertScheduledTask({
                                'name': finalTaskName,
                                'category': selectedCategory,
                                'frequency': selectedFrequency,
                                'linkType': linkType,
                                'linkedEntities': List.from(selectedEntities),
                              });

                              // Reload tasks from database to get updated list
                              final updatedTasks = await _db.getAllScheduledTasks();
                              setState(() {
                                scheduledTasks = updatedTasks;
                              });

                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Schedule Saved'), backgroundColor: Color(0xFF0F7B6C)),
                              );
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error saving schedule: $e'), backgroundColor: Color(0xFFD44C47)),
                              );
                            }
                          },
                          child: Text('Save Schedule', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
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
        border: Border.all(color: Color(0xFFE2E8F0)),
        borderRadius: BorderRadius.circular(8),
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
          color: isSelected ? Color(0xFFF0FDFA) : Colors.white, // Very light teal background if selected
          border: Border.all(
            color: isSelected ? Color(0xFF0F7B6C) : Color(0xFFE2E8F0), // Teal border if selected
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
                border: Border.all(color: isSelected ? Color(0xFF0F7B6C) : Color(0xFFCBD5E1), width: isSelected ? 5 : 1.5 // Thicker border simulates the "dot" inside
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
                    backgroundColor: Color(0xFF0F7B6C),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF0F7B6C),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Add health issue - Coming soon'),
        backgroundColor: Color(0xFF0F7B6C),
        behavior: SnackBarBehavior.floating,
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
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: Color(0xFF0F7B6C)),
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
                              Icon(PhosphorIconsBold.link, size: 12, color: const Color(0xFF0F7B6C)),
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
                      foregroundColor: const Color(0xFF0F7B6C),
                      side: const BorderSide(color: Color(0xFF0F7B6C)),
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
                    icon: const Icon(PhosphorIconsBold.trash, size: 18, color: Colors.white),
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
        const SnackBar(content: Text('Schedule deleted'), backgroundColor: Color(0xFF0F7B6C)),
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
}
