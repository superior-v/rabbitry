import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../models/rabbit.dart';
import '../models/rabbit_document.dart';
import '../models/transaction.dart' as finance_model;
import '../models/breed.dart';
import '../models/barn.dart';
import '../services/database_service.dart';
import '../services/format_utils.dart';
import '../services/settings_service.dart';
import '../services/app_event_service.dart';
import '../constants/app_colors.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class AddRabbitScreen extends StatefulWidget {
  final Rabbit? editRabbit;

  const AddRabbitScreen({Key? key, this.editRabbit}) : super(key: key);

  @override
  State<AddRabbitScreen> createState() => _AddRabbitScreenState();
}

/// Forces all input to uppercase.
class _UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

class _AddRabbitScreenState extends State<AddRabbitScreen> {
  static const Color doePink = Color(0xFFEC4899);
  static const Color buckBlue = Color(0xFF2E7BB5);

  final DatabaseService _db = DatabaseService();
  final ImagePicker _imagePicker = ImagePicker();

  // Form controllers
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _breedController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  final TextEditingController _earNumberController = TextEditingController();
  final TextEditingController _otherBreedController = TextEditingController();
  final TextEditingController _otherColorController = TextEditingController();
  final TextEditingController _breederPrefixController = TextEditingController();
  final TextEditingController _registrationNumberController = TextEditingController();
  final TextEditingController _grandChampionNumberController = TextEditingController();
  final TextEditingController _grandChampionLegsController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _weightPoundsController = TextEditingController();
  final TextEditingController _weightOuncesController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _acquiredDateController = TextEditingController();
  final TextEditingController _sireController = TextEditingController();
  final TextEditingController _damController = TextEditingController();

  // Purchase Details controllers
  final TextEditingController _sellerController = TextEditingController();
  final TextEditingController _purchaseRabbitryController = TextEditingController();
  final TextEditingController _purchaseCostController = TextEditingController();
  final TextEditingController _purchaseDateController = TextEditingController();
  DateTime? _purchaseDate;
  bool _hasPurchaseDetails = false;
  bool _addPurchaseAsExpense = false;

  RabbitType _selectedType = RabbitType.doe;
  RabbitStatus _selectedStatus = RabbitStatus.open;
  String? _selectedLocation;
  String? _selectedCage;
  DateTime? _dateOfBirth;
  DateTime? _acquiredDate;
  String? _profileImagePath;
  bool _photoRemoved = false;
  bool _isSaving = false;
  List<Breed> _availableBreeds = [];
  String? _autoGenetics;
  List<Barn> _barns = [];

  // New fields
  bool _broken = false;
  bool _viennaMarked = false;
  bool _viennaCarrier = false;
  bool _activeInRabbitry = true;
  String? _selectedSireId;
  String? _selectedDamId;
  String? _selectedSireName;
  String? _selectedDamName;
  List<Rabbit> _availableBucks = [];
  List<Rabbit> _availableDoes = [];

  // Genotype fields
  bool _genotypeExpanded = false;
  Map<String, String> _genotypeMap = {
    'A': '--',
    'B': '--',
    'C': '--',
    'D': '--',
    'E': '--',
    'En': '--',
    'V': '--',
    'W': '--',
  };

  bool get _isEditing => widget.editRabbit != null;

  @override
  void initState() {
    super.initState();
    _loadBreeds();
    _loadBarns();
    _loadParentOptions();
    if (_isEditing) {
      _prefillFromRabbit(widget.editRabbit!);
    } else {
      _generateRabbitId();
    }
  }

  void _prefillFromRabbit(Rabbit r) {
    _idController.text = r.id;
    _nameController.text = r.name;
    _breedController.text = r.breed;
    _colorController.text = r.color ?? '';
    _weightController.text = r.weight != null ? r.weight.toString() : '';
    _earNumberController.text = r.earNumber ?? '';
    _otherBreedController.text = r.otherBreed ?? '';
    _otherColorController.text = r.otherColor ?? '';
    _breederPrefixController.text = r.breederPrefix ?? '';
    _registrationNumberController.text = r.registrationNumber ?? '';
    _grandChampionNumberController.text = r.grandChampionNumber ?? '';
    _grandChampionLegsController.text = r.grandChampionLegs?.toString() ?? '';
    _notesController.text = r.notes ?? '';
    _selectedType = r.type;
    _selectedStatus = r.status;
    _selectedLocation = r.location;
    _selectedCage = r.cage;
    _dateOfBirth = r.dateOfBirth;
    if (r.dateOfBirth != null) {
      _dobController.text = FormatUtils.formatDate(r.dateOfBirth!);
    }
    _acquiredDate = r.acquiredDate;
    if (r.acquiredDate != null) {
      _acquiredDateController.text = FormatUtils.formatDate(r.acquiredDate!);
    }
    _sellerController.text = r.seller ?? '';
    _purchaseRabbitryController.text = r.purchaseRabbitry ?? '';
    _purchaseCostController.text = r.purchaseCost != null ? r.purchaseCost!.toStringAsFixed(2) : '';
    _purchaseDate = r.purchaseDate ?? r.acquiredDate;
    if (_purchaseDate != null) {
      _purchaseDateController.text = FormatUtils.formatDate(_purchaseDate!);
    }
    if (r.hasPurchaseDetails || r.acquiredDate != null) {
      _hasPurchaseDetails = true;
    }
    _autoGenetics = r.genetics;
    _parseGeneticsToMap(r.genetics);
    _broken = r.broken ?? false;
    _viennaMarked = r.viennaMarked ?? false;
    _viennaCarrier = r.viennaCarrier ?? false;
    _activeInRabbitry = r.activeInRabbitry;
    _selectedSireId = r.sireId;
    _selectedDamId = r.damId;
    if (r.photos != null && r.photos!.isNotEmpty) {
      _profileImagePath = r.photos!.first;
    }
    if (r.weight != null) {
      final totalOz = r.weight! * 16;
      final lbs = totalOz ~/ 16;
      final oz = (totalOz % 16).round();
      _weightPoundsController.text = lbs > 0 ? lbs.toString() : '';
      _weightOuncesController.text = oz > 0 ? oz.toString() : '';
    }
  }

  Future<void> _generateRabbitId() async {
    try {
      final allRabbits = await _db.getAllRabbits();
      final archivedRabbits = await _db.getArchivedRabbits();
      final allIds = [
        ...allRabbits,
        ...archivedRabbits
      ].map((r) => r.id).toList();

      int maxNum = 0;
      for (final id in allIds) {
        final match = RegExp(r'^R-(\d+)$').firstMatch(id);
        if (match != null) {
          final num = int.tryParse(match.group(1)!) ?? 0;
          if (num > maxNum) maxNum = num;
        }
      }

      final nextId = 'R-${(maxNum + 1).toString().padLeft(4, '0')}';
      if (mounted) {
        setState(() {
          _idController.text = nextId;
        });
      }
    } catch (e) {
      _idController.text = 'R-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    }
  }

  Future<void> _loadBreeds() async {
    final breeds = await _db.getAllBreeds();
    if (mounted) {
      setState(() => _availableBreeds = breeds);
    }
  }

  Future<void> _loadBarns() async {
    try {
      final barnMaps = await _db.getAllBarns();
      if (mounted) {
        setState(() {
          _barns = barnMaps.map((m) => Barn.fromMap(m)).toList();
        });
      }
    } catch (e) {
      print('Error loading barns: $e');
    }
  }

  Future<void> _loadParentOptions() async {
    try {
      final activeBucks = await _db.getRabbitsByType(RabbitType.buck);
      final activeDoes = await _db.getRabbitsByType(RabbitType.doe);
      final archivedRabbits = await _db.getArchivedRabbits();
      final pedigreeRabbits = await _db.getRabbitsByType(RabbitType.pedigree);

      final archivedBucks = archivedRabbits.where((r) => r.type == RabbitType.buck).toList();
      final archivedDoes = archivedRabbits.where((r) => r.type == RabbitType.doe).toList();
      final pedBucks = pedigreeRabbits.where((r) => r.type == RabbitType.buck).toList();
      final pedDoes = pedigreeRabbits.where((r) => r.type == RabbitType.doe).toList();

      final allBucksMap = <String, Rabbit>{};
      for (final b in activeBucks) allBucksMap[b.id] = b;
      for (final b in archivedBucks) allBucksMap[b.id] = b;
      for (final b in pedBucks) allBucksMap[b.id] = b;

      final allDoesMap = <String, Rabbit>{};
      for (final d in activeDoes) allDoesMap[d.id] = d;
      for (final d in archivedDoes) allDoesMap[d.id] = d;
      for (final d in pedDoes) allDoesMap[d.id] = d;

      final bucks = allBucksMap.values.toList()..sort((a, b) => a.fullName.compareTo(b.fullName));
      final does = allDoesMap.values.toList()..sort((a, b) => a.fullName.compareTo(b.fullName));

      String? sireName;
      String? damName;

      if (_selectedSireId != null && _selectedSireId!.isNotEmpty) {
        final s = allBucksMap[_selectedSireId];
        if (s != null) {
          sireName = s.fullName.isNotEmpty ? s.fullName : s.name;
        } else {
          final sRabbit = await _db.getRabbit(_selectedSireId!);
          sireName = sRabbit != null ? (sRabbit.fullName.isNotEmpty ? sRabbit.fullName : sRabbit.name) : null;
        }
      }

      if (_selectedDamId != null && _selectedDamId!.isNotEmpty) {
        final d = allDoesMap[_selectedDamId];
        if (d != null) {
          damName = d.fullName.isNotEmpty ? d.fullName : d.name;
        } else {
          final dRabbit = await _db.getRabbit(_selectedDamId!);
          damName = dRabbit != null ? (dRabbit.fullName.isNotEmpty ? dRabbit.fullName : dRabbit.name) : null;
        }
      }

      if (mounted) {
        setState(() {
          _availableBucks = bucks;
          _availableDoes = does;
          if (sireName != null) {
            _selectedSireName = sireName;
            _sireController.text = sireName;
          }
          if (damName != null) {
            _selectedDamName = damName;
            _damController.text = damName;
          }
        });
      }
    } catch (e) {
      print('Error loading parent options: $e');
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _breedController.dispose();
    _colorController.dispose();
    _weightController.dispose();
    _earNumberController.dispose();
    _otherBreedController.dispose();
    _otherColorController.dispose();
    _breederPrefixController.dispose();
    _registrationNumberController.dispose();
    _grandChampionNumberController.dispose();
    _grandChampionLegsController.dispose();
    _notesController.dispose();
    _weightPoundsController.dispose();
    _weightOuncesController.dispose();
    _dobController.dispose();
    _sireController.dispose();
    _damController.dispose();
    _sellerController.dispose();
    _purchaseRabbitryController.dispose();
    _purchaseCostController.dispose();
    _purchaseDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEDAFE),
      appBar: AppBar(
        backgroundColor: const Color(0xFFE6BEFE),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIcons.x(PhosphorIconsStyle.bold), color: const Color(0xFF4A3E6D)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Edit Rabbit' : 'Add New Rabbit',
          style: const TextStyle(
            color: Color(0xFF4A3E6D),
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Rabbit Type (Buck / Doe) Toggle
            _buildTypeToggle(),
            const SizedBox(height: 16),

            // 2. Profile picture section
            _buildProfilePictureSection(),
            const SizedBox(height: 16),

            // 3. Breed Selector (with Consistency.jpg alternate colors modal)
            _buildBreedField(),
            const SizedBox(height: 14),

            // 4. Color Selector (with Consistency.jpg alternate colors modal)
            // (Other Breed and Other Color boxes REMOVED!)
            _buildColorField(),
            const SizedBox(height: 14),

            // 5. Broken, VM, VC compact toggles container
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD6CEE2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCompactToggle('Broken', _broken, (val) => setState(() => _broken = val)),
                  _buildCompactToggle('VM', _viennaMarked, (val) => setState(() => _viennaMarked = val)),
                  _buildCompactToggle('VC', _viennaCarrier, (val) => setState(() => _viennaCarrier = val)),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 6. Name text field
            _buildTextField(
              controller: _nameController,
              label: 'Name',
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 14),

            // 7. Breeder Prefix & Ear Number Row
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _breederPrefixController,
                    label: 'Breeder Prefix',
                    inputFormatters: [_UpperCaseTextFormatter()],
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTextField(
                    controller: _earNumberController,
                    label: 'Ear Number',
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 8. Purchase Details
            _buildPurchaseDetailsSection(),
            const SizedBox(height: 14),

            // 9. Date of Birth
            _buildDateField(),
            const SizedBox(height: 14),

            // 10. Pounds & Ounce Row
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _weightPoundsController,
                    label: 'Pounds',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTextField(
                    controller: _weightOuncesController,
                    label: 'Ounce',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // 11. Sire & Dam selector Row
            Row(
              children: [
                Expanded(
                  child: _buildParentSelector('Sire', _selectedSireId, _selectedSireName, _availableBucks, (id, name) {
                    setState(() {
                      _selectedSireId = id;
                      _selectedSireName = name;
                    });
                  }),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildParentSelector('Dam', _selectedDamId, _selectedDamName, _availableDoes, (id, name) {
                    setState(() {
                      _selectedDamId = id;
                      _selectedDamName = name;
                    });
                  }),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 12. Genotype Section
            _buildGenotypeSection(),
            const SizedBox(height: 16),

            // 13. Registration / Grand Champion/Legs
            _buildTextField(
              controller: _registrationNumberController,
              label: 'Registration Number',
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildTextField(
                    controller: _grandChampionNumberController,
                    label: 'GC Number',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: _buildTextField(
                    controller: _grandChampionLegsController,
                    label: 'Legs',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 14. Active in Rabbitry
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFD6CEE2)),
              ),
              child: _buildToggleRow('Active in Rabbitry', _activeInRabbitry, (val) => setState(() => _activeInRabbitry = val)),
            ),
            const SizedBox(height: 14),

            // 15. Status
            _buildStatusDropdown(),
            const SizedBox(height: 14),

            // 16. Location & Cage
            Row(
              children: [
                Expanded(child: _buildLocationDropdown()),
                const SizedBox(width: 10),
                Expanded(child: _buildCageDropdown()),
              ],
            ),
            const SizedBox(height: 14),

            // 17. Rabbit ID
            _buildTextField(
              controller: _idController,
              label: 'Rabbit ID',
              readOnly: true,
            ),
            const SizedBox(height: 14),

            // 18. Notes
            _buildNotesField(),
            const SizedBox(height: 24),

            // 19. Save Button
            _buildSaveButton(),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePictureSection() {
    final activeColor = _selectedType == RabbitType.doe ? doePink : buckBlue;
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _showImagePickerOptions,
            child: Stack(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFF7F7F5),
                    border: Border.all(
                      color: activeColor,
                      width: 3,
                    ),
                    image: _profileImagePath != null
                        ? DecorationImage(
                            image: FileImage(File(_profileImagePath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: _profileImagePath == null
                      ? Icon(
                          _selectedType == RabbitType.doe ? Icons.female : Icons.male,
                          size: 50,
                          color: activeColor,
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: activeColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_profileImagePath != null) ...[  
            const SizedBox(height: 8),
            TextButton(
              onPressed: _showImagePickerOptions,
              child: Text(
                'Change Photo',
                style: TextStyle(
                  color: activeColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _showImagePickerOptions() {
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
            const SizedBox(height: 2),
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
              'Add Profile Picture',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            _buildPhotoOption(
              icon: Icons.camera_alt,
              label: 'Take Photo',
              onTap: () async {
                Navigator.pop(context);
                await _pickImage(ImageSource.camera);
              },
            ),
            _buildPhotoOption(
              icon: Icons.photo_library,
              label: 'Choose from Gallery',
              onTap: () async {
                Navigator.pop(context);
                await _pickImage(ImageSource.gallery);
              },
            ),
            if (_profileImagePath != null)
              _buildPhotoOption(
                icon: Icons.delete_outline,
                label: 'Remove Photo',
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _profileImagePath = null;
                    _photoRemoved = true;
                  });
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
                fontSize: 17,
                color: isDestructive ? const Color(0xFFD44C47) : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
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
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        final savedPath = await _saveRabbitPhoto(image.path);
        FileImage(File(savedPath)).evict();
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
        setState(() {
          _profileImagePath = savedPath;
        });
        notifyDataChanged();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo added successfully'),
            backgroundColor: Color(0xFF7B6BA0),
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

  Future<String> _saveRabbitPhoto(String sourcePath) async {
    final directory = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(directory.path, 'rabbit_photos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final extension = p.extension(sourcePath).isNotEmpty ? p.extension(sourcePath) : '.jpg';
    final fileName = 'rabbit_${DateTime.now().millisecondsSinceEpoch}$extension';
    final savedFile = await File(sourcePath).copy(p.join(photosDir.path, fileName));
    return savedFile.path;
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

  Widget _buildTypeToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: const Color(0xFFD6CEE2)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: _isEditing ? null : () => setState(() => _selectedType = RabbitType.buck),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedType == RabbitType.buck ? const Color(0xFFE5E5EA) : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: _selectedType == RabbitType.buck
                      ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.male, size: 18, color: _selectedType == RabbitType.buck ? buckBlue : const Color(0xFF787880)),
                      const SizedBox(width: 6),
                      Text(
                        'Buck',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _selectedType == RabbitType.buck ? buckBlue : const Color(0xFF787880),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: _isEditing ? null : () => setState(() => _selectedType = RabbitType.doe),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _selectedType == RabbitType.doe ? const Color(0xFFE5E5EA) : Colors.transparent,
                  borderRadius: BorderRadius.circular(100),
                  boxShadow: _selectedType == RabbitType.doe
                      ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
                      : null,
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.female, size: 18, color: _selectedType == RabbitType.doe ? doePink : const Color(0xFF787880)),
                      const SizedBox(width: 6),
                      Text(
                        'Doe',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _selectedType == RabbitType.doe ? doePink : const Color(0xFF787880),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showBreedPickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final allBreeds = _availableBreeds.map((b) => b.name).toList();
            final filtered = searchQuery.isEmpty
                ? allBreeds
                : allBreeds.where((b) => b.toLowerCase().contains(searchQuery.toLowerCase())).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEADBFC),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select Breed',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4A3E6D),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 18, color: Color(0xFF4A3E6D)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search or enter breed...',
                        hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF787880)),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF787880), size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF7F3FB),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFD6CEE2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFD6CEE2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5),
                        ),
                      ),
                      onChanged: (val) => setModalState(() => searchQuery = val),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length + (searchQuery.isNotEmpty && !filtered.contains(searchQuery.trim()) ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < filtered.length) {
                          final breedName = filtered[index];
                          final isSelected = _breedController.text.trim().toLowerCase() == breedName.toLowerCase();
                          final isOdd = index % 2 == 1;
                          final rowBg = isOdd ? const Color(0xFFF9F5FE) : Colors.white;

                          return Material(
                            color: rowBg,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _breedController.text = breedName;
                                  final matched = _availableBreeds.where((b) => b.name == breedName);
                                  if (matched.isNotEmpty) {
                                    final geneticsStr = matched.first.genetics.join(', ');
                                    _autoGenetics = geneticsStr;
                                    _parseGeneticsToMap(geneticsStr);
                                  }
                                });
                                Navigator.pop(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      breedName,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected ? const Color(0xFF7B6BA0) : const Color(0xFF2C2C2E),
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_circle, color: Color(0xFF7B6BA0), size: 18),
                                  ],
                                ),
                              ),
                            ),
                          );
                        } else {
                          final customBreed = searchQuery.trim();
                          return Material(
                            color: Colors.white,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _breedController.text = customBreed;
                                });
                                Navigator.pop(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    const Icon(Icons.add_circle_outline, color: Color(0xFF7B6BA0), size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Use "$customBreed"',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF7B6BA0),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showColorPickerModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final colors = SettingsService.instance.colors;
            final filtered = searchQuery.isEmpty
                ? colors
                : colors.where((c) => c.toLowerCase().contains(searchQuery.toLowerCase())).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEADBFC),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Select Color',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4A3E6D),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 18, color: Color(0xFF4A3E6D)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search or enter color...',
                        hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF787880)),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF787880), size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF7F3FB),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFD6CEE2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFD6CEE2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5),
                        ),
                      ),
                      onChanged: (val) => setModalState(() => searchQuery = val),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: filtered.length + (searchQuery.isNotEmpty && !filtered.contains(searchQuery.trim()) ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index < filtered.length) {
                          final colorName = filtered[index];
                          final isSelected = _colorController.text.trim().toLowerCase() == colorName.toLowerCase();
                          final isOdd = index % 2 == 1;
                          final rowBg = isOdd ? const Color(0xFFF9F5FE) : Colors.white;

                          return Material(
                            color: rowBg,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _colorController.text = colorName;
                                });
                                Navigator.pop(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      colorName,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected ? const Color(0xFF7B6BA0) : const Color(0xFF2C2C2E),
                                      ),
                                    ),
                                    if (isSelected)
                                      const Icon(Icons.check_circle, color: Color(0xFF7B6BA0), size: 18),
                                  ],
                                ),
                              ),
                            ),
                          );
                        } else {
                          final customColor = searchQuery.trim();
                          return Material(
                            color: Colors.white,
                            child: InkWell(
                              onTap: () {
                                setState(() {
                                  _colorController.text = customColor;
                                });
                                Navigator.pop(context);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                child: Row(
                                  children: [
                                    const Icon(Icons.add_circle_outline, color: Color(0xFF7B6BA0), size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Use "$customColor"',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF7B6BA0),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBreedField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'BREED',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF4F4F56),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: _showBreedPickerModal,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFD6CEE2)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _breedController.text.isNotEmpty ? _breedController.text : 'Select Breed',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: _breedController.text.isNotEmpty ? FontWeight.w600 : FontWeight.w400,
                      color: _breedController.text.isNotEmpty ? const Color(0xFF4F4F56) : const Color(0xFF787880),
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: Color(0xFF4A3E6D)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'COLOR',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF4F4F56),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: _showColorPickerModal,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFD6CEE2)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _colorController.text.isNotEmpty ? _colorController.text : 'Select Color',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: _colorController.text.isNotEmpty ? FontWeight.w600 : FontWeight.w400,
                      color: _colorController.text.isNotEmpty ? const Color(0xFF4F4F56) : const Color(0xFF787880),
                    ),
                  ),
                ),
                const Icon(Icons.keyboard_arrow_down, color: Color(0xFF4A3E6D)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE6BEFE).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _saveRabbit,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFE6BEFE),
          foregroundColor: const Color(0xFF4A3E6D),
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: _isSaving
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A3E6D)),
                ),
              )
            : Text(
                _isEditing ? 'Update Rabbit' : 'Save Rabbit',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4A3E6D),
                  letterSpacing: -0.2,
                ),
              ),
      ),
    );
  }

  static const List<String> _locusKeys = [
    'A',
    'B',
    'C',
    'D',
    'E',
    'En',
    'V',
    'W'
  ];

  List<String> _getAllelesForLocus(String locus) {
    final key = locus.length == 1 ? locus : locus;
    final upper = key.substring(0, 1).toUpperCase();
    final lower = key.substring(0, 1).toLowerCase();
    if (key == 'En') {
      return [
        '--',
        'EnEn',
        'Enen',
        'enen'
      ];
    }
    return [
      '--',
      '$upper$upper',
      '$upper$lower',
      '$lower$lower'
    ];
  }

  void _parseGeneticsToMap(String? genetics) {
    if (genetics == null || genetics.trim().isEmpty) return;
    final parts = genetics.split(RegExp(r'[,\s]+')).where((p) => p.isNotEmpty).toList();
    final newMap = Map<String, String>.from(_genotypeMap);
    for (final part in parts) {
      final lower = part.toLowerCase();
      if (lower.startsWith('en')) {
        newMap['En'] = part;
      } else {
        for (final key in _locusKeys) {
          if (key == 'En') continue;
          if (lower.startsWith(key.toLowerCase()) && part.length <= 3) {
            newMap[key] = part;
            break;
          }
        }
      }
    }
    _genotypeMap = newMap;
  }

  String _genotypeMapToString() {
    final parts = _genotypeMap.entries.where((e) => e.value != '--').map((e) => e.value).toList();
    return parts.join(' ');
  }

  Widget _buildGenotypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _genotypeExpanded = !_genotypeExpanded),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD6CEE2)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Genotype',
                  style: TextStyle(
                    fontSize: 14,
                    color: _genotypeExpanded ? (_selectedType == RabbitType.doe ? doePink : buckBlue) : const Color(0xFF636366),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Icon(
                  _genotypeExpanded ? Icons.keyboard_arrow_down : Icons.chevron_right,
                  color: Colors.black38,
                ),
              ],
            ),
          ),
        ),
        if (_genotypeExpanded) ...[
          const SizedBox(height: 2),
          // Changed layout to 3 items per row for better visibility
          Row(
            children: _locusKeys.sublist(0, 3).map((key) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _buildLocusDropdown(key),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Row(
            children: _locusKeys.sublist(3, 6).map((key) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _buildLocusDropdown(key),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Row(
            children: _locusKeys.sublist(6, 8).map((key) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _buildLocusDropdown(key),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildLocusDropdown(String locus) {
    final alleles = _getAllelesForLocus(locus);
    final current = _genotypeMap[locus] ?? '--';
    final value = alleles.contains(current) ? current : '--';
    return Column(
      children: [
        Text(
          locus,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF787774),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 38,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE9E9E7))),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, size: 18),
              style: const TextStyle(fontSize: 15, color: Color(0xFF37352F), fontFamily: 'monospace'),
              items: alleles.map((a) => DropdownMenuItem(value: a, child: Text(a, style: const TextStyle(fontSize: 15)))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() {
                    _genotypeMap[locus] = val;
                    _autoGenetics = _genotypeMapToString();
                  });
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? prefixText,
    String? hintText,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF4F4F56),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          readOnly: readOnly,
          onTap: onTap,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4F4F56)),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF787880), fontWeight: FontWeight.w400),
            prefixText: prefixText,
            prefixStyle: const TextStyle(fontSize: 14, color: Color(0xFF4F4F56), fontWeight: FontWeight.w600),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFD6CEE2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFD6CEE2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'STATUS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF4F4F56),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<RabbitStatus>(
          value: _selectedStatus,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4F4F56)),
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF4A3E6D)),
          dropdownColor: Colors.white,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFD6CEE2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFD6CEE2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5),
            ),
          ),
          selectedItemBuilder: (context) {
            final List<RabbitStatus> allPossible = [
              RabbitStatus.open,
              RabbitStatus.growout,
              RabbitStatus.resting,
              RabbitStatus.quarantine,
              _selectedStatus,
            ];
            return allPossible.map((status) {
              String label;
              switch (status) {
                case RabbitStatus.open:
                  label = 'Open';
                  break;
                case RabbitStatus.growout:
                  label = 'Growout';
                  break;
                case RabbitStatus.resting:
                  label = 'Resting';
                  break;
                case RabbitStatus.quarantine:
                  label = 'Quarantine';
                  break;
                default:
                  label = status.toString().split('.').last;
                  break;
              }
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4F4F56)),
                ),
              );
            }).toList();
          },
          items: () {
            final List<RabbitStatus> baseItems = _isEditing
                ? [
                    RabbitStatus.open,
                    RabbitStatus.growout,
                    RabbitStatus.resting,
                    RabbitStatus.quarantine
                  ]
                : [
                    RabbitStatus.open,
                    RabbitStatus.growout
                  ];
            if (!baseItems.contains(_selectedStatus)) {
              baseItems.add(_selectedStatus);
            }
            return baseItems;
          }()
              .asMap()
              .entries
              .map((entry) {
            final idx = entry.key;
            final status = entry.value;
            final isAlt = idx % 2 == 1;
            String label;
            switch (status) {
              case RabbitStatus.open:
                label = 'Open';
                break;
              case RabbitStatus.growout:
                label = 'Growout';
                break;
              case RabbitStatus.resting:
                label = 'Resting';
                break;
              case RabbitStatus.quarantine:
                label = 'Quarantine';
                break;
              default:
                label = status.toString().split('.').last;
                break;
            }
            return DropdownMenuItem(
              value: status,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isAlt ? const Color(0xFFF9F5FE) : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4F4F56)),
                ),
              ),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedStatus = value!),
        ),
      ],
    );
  }

  Widget _buildLocationDropdown() {
    final locationNames = _barns.map((b) => b.name).toList();

    if (_selectedLocation != null && !locationNames.contains(_selectedLocation)) {
      _selectedLocation = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'LOCATION',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF4F4F56),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: _selectedLocation,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4F4F56)),
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF4A3E6D)),
          dropdownColor: Colors.white,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFD6CEE2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFD6CEE2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5),
            ),
          ),
          hint: Text(
            locationNames.isEmpty ? 'No barns' : 'Location',
            style: const TextStyle(fontSize: 14, color: Color(0xFF787880), fontWeight: FontWeight.w400),
          ),
          selectedItemBuilder: (context) {
            return locationNames.map((loc) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  loc,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4F4F56)),
                ),
              );
            }).toList();
          },
          items: locationNames.asMap().entries.map((entry) {
            final idx = entry.key;
            final location = entry.value;
            final isAlt = idx % 2 == 1;
            return DropdownMenuItem(
              value: location,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isAlt ? const Color(0xFFF9F5FE) : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  location,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4F4F56)),
                ),
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedLocation = value;
              _selectedCage = null;
            });
          },
        ),
      ],
    );
  }

  Widget _buildCageDropdown() {
    List<String> cageNames = [];
    if (_selectedLocation != null) {
      final matchingBarn = _barns.where((b) => b.name == _selectedLocation).toList();
      if (matchingBarn.isNotEmpty) {
        for (final row in matchingBarn.first.rows) {
          cageNames.addAll(row.cages);
        }
      }
    }

    if (_selectedCage != null && !cageNames.contains(_selectedCage)) {
      _selectedCage = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'CAGE',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF4F4F56),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        DropdownButtonFormField<String>(
          key: ValueKey(_selectedLocation),
          value: _selectedCage,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4F4F56)),
          icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF4A3E6D)),
          dropdownColor: Colors.white,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFD6CEE2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFD6CEE2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5),
            ),
          ),
          hint: Text(
            _selectedLocation == null
                ? 'Select Location'
                : cageNames.isEmpty
                    ? 'No cages'
                    : 'Cage',
            style: const TextStyle(fontSize: 14, color: Color(0xFF787880), fontWeight: FontWeight.w400),
          ),
          selectedItemBuilder: (context) {
            return cageNames.map((cage) {
              return Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  cage,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4F4F56)),
                ),
              );
            }).toList();
          },
          items: cageNames.asMap().entries.map((entry) {
            final idx = entry.key;
            final cage = entry.value;
            final isAlt = idx % 2 == 1;
            return DropdownMenuItem(
              value: cage,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: isAlt ? const Color(0xFFF9F5FE) : Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  cage,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4F4F56)),
                ),
              ),
            );
          }).toList(),
          onChanged: (value) => setState(() => _selectedCage = value),
        ),
      ],
    );
  }

  Widget _buildPurchaseDetailsSection() {
    final activeColor = _selectedType == RabbitType.doe ? doePink : buckBlue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Purchase Details',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4F4F56),
              ),
            ),
            _buildCompactToggle('', _hasPurchaseDetails, (val) {
              setState(() {
                _hasPurchaseDetails = val;
                if (_hasPurchaseDetails && _purchaseDate == null) {
                  _purchaseDate = _acquiredDate ?? DateTime.now();
                  _purchaseDateController.text = FormatUtils.formatDate(_purchaseDate!);
                  _acquiredDate = _purchaseDate;
                }
              });
            }),
          ],
        ),
        if (_hasPurchaseDetails) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: const Color(0xFFD6CEE2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Seller
                _buildTextField(
                  controller: _sellerController,
                  label: 'Seller',
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),

                // Rabbitry
                _buildTextField(
                  controller: _purchaseRabbitryController,
                  label: 'Rabbitry',
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 12),

                // Date of Purchase
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DATE OF PURCHASE',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4F4F56),
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _purchaseDate ?? DateTime.now(),
                          firstDate: DateTime(2010),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          setState(() {
                            _purchaseDate = date;
                            _purchaseDateController.text = FormatUtils.formatDate(date);
                            _acquiredDate = date;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFD6CEE2)),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, color: Color(0xFF4F4F56), size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _purchaseDate != null ? FormatUtils.formatDate(_purchaseDate!) : 'Select Date of Purchase',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: _purchaseDate != null ? FontWeight.w600 : FontWeight.w400,
                                  color: _purchaseDate != null ? const Color(0xFF4F4F56) : const Color(0xFF787880),
                                ),
                              ),
                            ),
                            if (_purchaseDate != null)
                              GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _purchaseDate = null;
                                    _purchaseDateController.clear();
                                  });
                                },
                                child: const Icon(Icons.clear, color: Color(0xFF787880), size: 18),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Cost
                _buildTextField(
                  controller: _purchaseCostController,
                  label: 'Cost',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  prefixText: FormatUtils.currencyPrefix,
                ),
                const SizedBox(height: 10),

                // Add as Expense Check box
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => setState(() => _addPurchaseAsExpense = !_addPurchaseAsExpense),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        SizedBox(
                          height: 24,
                          width: 24,
                          child: Checkbox(
                            value: _addPurchaseAsExpense,
                            activeColor: activeColor,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            onChanged: (val) => setState(() => _addPurchaseAsExpense = val ?? false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Add as Expense',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4F4F56),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DATE OF BIRTH',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF4F4F56),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: _dateOfBirth ?? DateTime.now(),
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
            );
            if (date != null) {
              setState(() {
                _dateOfBirth = date;
                _dobController.text = FormatUtils.formatDate(date);
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFD6CEE2)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, color: Color(0xFF4F4F56), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _dateOfBirth != null ? FormatUtils.formatDate(_dateOfBirth!) : 'Select Date of Birth',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: _dateOfBirth != null ? FontWeight.w600 : FontWeight.w400,
                      color: _dateOfBirth != null ? const Color(0xFF4F4F56) : const Color(0xFF787880),
                    ),
                  ),
                ),
                if (_dateOfBirth != null)
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _dateOfBirth = null;
                        _dobController.clear();
                      });
                    },
                    child: const Icon(Icons.clear, color: Color(0xFF787880), size: 18),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildToggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    // Herd page matching colors
    const Color doeActive = Color(0xFFEC4899);
    const Color buckActive = Color(0xFF2E7BB5);
    final Color activeColor = _selectedType == RabbitType.doe ? doeActive : buckActive;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.normal, color: Color(0xFF4F4F56)),
        ),
        // Pill-style toggle: white unselected, pink/blue selected
        GestureDetector(
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 52,
            height: 28,
            decoration: BoxDecoration(
              color: value ? activeColor : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: value ? activeColor : const Color(0xFFD1D1D6),
                width: 1.5,
              ),
            ),
            child: Stack(
              children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Color(0x29000000), blurRadius: 4, offset: Offset(0, 1))
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactToggle(String label, bool value, ValueChanged<bool> onChanged) {
    final Color activeColor = _selectedType == RabbitType.doe ? doePink : buckBlue;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4F4F56)),
          ),
          const SizedBox(width: 6),
        ],
        GestureDetector(
          onTap: () => onChanged(!value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 44,
            height: 24,
            decoration: BoxDecoration(
              color: value ? activeColor : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: value ? activeColor : const Color(0xFFC7C7CC),
                width: 1.5,
              ),
            ),
            child: Stack(
              children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 200),
                  alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1))
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParentSelector(String label, String? selectedId, String? selectedName, List<Rabbit> options, void Function(String?, String?) onSelect) {
    final hasSelection = (selectedId != null && selectedId.isNotEmpty) || (selectedName != null && selectedName.isNotEmpty);
    final color = label == 'Dam' ? doePink : buckBlue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF4F4F56),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () {
            _showParentPickerDialog(label, options, (id, name) {
              onSelect(id, name);
              setState(() {
                if (name != null) {
                  if (label == 'Sire') _sireController.text = name;
                  if (label == 'Dam') _damController.text = name;
                } else {
                  if (label == 'Sire') _sireController.clear();
                  if (label == 'Dam') _damController.clear();
                }
              });
            });
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFD6CEE2)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    hasSelection ? (selectedName ?? '') : 'Select $label',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: hasSelection ? FontWeight.w600 : FontWeight.w400,
                      color: hasSelection ? const Color(0xFF4F4F56) : const Color(0xFF787880),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasSelection)
                  GestureDetector(
                    onTap: () {
                      onSelect(null, null);
                      setState(() {
                        if (label == 'Sire') _sireController.clear();
                        if (label == 'Dam') _damController.clear();
                      });
                    },
                    child: const Icon(Icons.clear, color: Color(0xFF787880), size: 18),
                  )
                else
                  Icon(Icons.keyboard_arrow_down, color: color, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showParentPickerDialog(String label, List<Rabbit> options, void Function(String?, String?) onSelect) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        String searchQuery = '';
        return StatefulBuilder(
          builder: (context, setModalState) {
            final filtered = searchQuery.isEmpty
                ? options
                : options.where((r) {
                    final name = r.fullName.isNotEmpty ? r.fullName : r.name;
                    return name.toLowerCase().contains(searchQuery.toLowerCase()) ||
                        (r.earNumber != null && r.earNumber!.toLowerCase().contains(searchQuery.toLowerCase()));
                  }).toList();

            return Container(
              height: MediaQuery.of(context).size.height * 0.75,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEADBFC),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Select $label',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4A3E6D),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close, size: 18, color: Color(0xFF4A3E6D)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search $label by name or ear...',
                        hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF787880)),
                        prefixIcon: const Icon(Icons.search, color: Color(0xFF787880), size: 20),
                        filled: true,
                        fillColor: const Color(0xFFF7F3FB),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFD6CEE2)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFD6CEE2)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5),
                        ),
                      ),
                      onChanged: (val) => setModalState(() => searchQuery = val),
                    ),
                  ),
                  Material(
                    color: Colors.white,
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        onSelect(null, null);
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Color(0xFFE5DEEC))),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.red.shade200),
                              ),
                              child: Icon(Icons.block, color: Colors.red.shade700, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'None (Leave Blank)',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.red.shade700),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'No rabbits available',
                              style: TextStyle(fontSize: 14, color: Color(0xFF787880)),
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final rabbit = filtered[index];
                              final displayName = rabbit.fullName.isNotEmpty ? rabbit.fullName : rabbit.name;
                              final isOdd = index % 2 == 1;
                              final rowBg = isOdd ? const Color(0xFFF9F5FE) : Colors.white;

                              return Material(
                                color: rowBg,
                                child: InkWell(
                                  onTap: () {
                                    Navigator.pop(context);
                                    onSelect(rabbit.id, displayName);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 16,
                                          backgroundColor: label == 'Dam' ? kPinkLight : kBlueLight,
                                          child: Text(
                                            rabbit.name.isNotEmpty ? rabbit.name[0] : '?',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: label == 'Dam' ? doePink : buckBlue,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                displayName,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF2C2C2E),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${rabbit.breed}${rabbit.status == RabbitStatus.archived ? " • Archived" : ""} • ${rabbit.id}',
                                                style: const TextStyle(fontSize: 12, color: Color(0xFF787880)),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'NOTES',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Color(0xFF4F4F56),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: _notesController,
          maxLines: 3,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4F4F56)),
          decoration: InputDecoration(
            hintText: 'Enter notes...',
            hintStyle: const TextStyle(fontSize: 14, color: Color(0xFF787880), fontWeight: FontWeight.w400),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFD6CEE2)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFFD6CEE2)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  double? _computeWeight() {
    final lbs = double.tryParse(_weightPoundsController.text) ?? 0;
    final oz = double.tryParse(_weightOuncesController.text) ?? 0;
    final total = lbs + (oz / 16);
    return total > 0 ? total : null;
  }

  Future<void> _syncGeneticsCheckboxes(String rabbitId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('genetics_broken_$rabbitId', _broken);
    await prefs.setBool('genetics_vienna_marked_$rabbitId', _viennaMarked);
    await prefs.setBool('genetics_vienna_carrier_$rabbitId', _viennaCarrier);
  }

  /// ✅ SYNC BREED TO LIBRARY
  /// If the breed name doesn't exist in the library, add it.
  Future<void> _syncBreedToLibrary(String breedName) async {
    final name = breedName.trim();
    if (name.isEmpty) return;

    // Case-insensitive check
    final exists = _availableBreeds.any((b) => b.name.toLowerCase() == name.toLowerCase());

    if (!exists) {
      final newBreed = Breed(
        id: 'B-${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        genetics: _autoGenetics != null && name == _breedController.text.trim() ? _autoGenetics!.split(RegExp(r'[,\s]+')).where((g) => g.isNotEmpty).toList() : [],
      );
      await _db.insertBreed(newBreed);
      // Update local list to prevent double insertion if saving multiple times
      _availableBreeds.add(newBreed);
    }
  }

  Future<void> _saveRabbit() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name', style: TextStyle(fontSize: 16)), backgroundColor: Color(0xFFD44C47)),
      );
      return;
    }

    if (_breedController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a breed', style: TextStyle(fontSize: 16)), backgroundColor: Color(0xFFD44C47)),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final rabbitId = _idController.text.isNotEmpty ? _idController.text : DateTime.now().millisecondsSinceEpoch.toString();

      List<String>? newPhotos;
      if (_profileImagePath != null) {
        newPhotos = [
          _profileImagePath!
        ];
      } else if (_photoRemoved) {
        newPhotos = [];
      } else {
        newPhotos = widget.editRabbit?.photos;
      }

      final computedWeight = _computeWeight();

      final seller = _hasPurchaseDetails && _sellerController.text.trim().isNotEmpty
          ? _sellerController.text.trim()
          : null;
      final rabbitry = _hasPurchaseDetails && _purchaseRabbitryController.text.trim().isNotEmpty
          ? _purchaseRabbitryController.text.trim()
          : null;
      final cost = _hasPurchaseDetails && _purchaseCostController.text.trim().isNotEmpty
          ? double.tryParse(_purchaseCostController.text.trim())
          : null;
      final purchaseDate = _hasPurchaseDetails ? _purchaseDate : null;

      if (_hasPurchaseDetails && purchaseDate != null) {
        _acquiredDate = purchaseDate;
      }

      if (_isEditing) {
        final updated = widget.editRabbit!.copyWith(
          name: _nameController.text,
          status: _selectedStatus,
          breed: _breedController.text,
          location: _selectedLocation,
          cage: _selectedCage,
          dateOfBirth: _dateOfBirth,
          acquiredDate: _acquiredDate,
          color: _colorController.text.isEmpty ? null : _colorController.text,
          weight: computedWeight,
          genetics: _autoGenetics,
          photos: newPhotos,
          earNumber: _earNumberController.text.isEmpty ? null : _earNumberController.text,
          otherBreed: _otherBreedController.text.isEmpty ? null : _otherBreedController.text,
          otherColor: _otherColorController.text.isEmpty ? null : _otherColorController.text,
          broken: _broken,
          viennaMarked: _viennaMarked,
          viennaCarrier: _viennaCarrier,
          breederPrefix: _breederPrefixController.text.isEmpty ? null : _breederPrefixController.text,
          sireId: _selectedSireId,
          damId: _selectedDamId,
          registrationNumber: _registrationNumberController.text.isEmpty ? null : _registrationNumberController.text,
          grandChampionNumber: _grandChampionNumberController.text.isEmpty ? null : _grandChampionNumberController.text,
          grandChampionLegs: int.tryParse(_grandChampionLegsController.text),
          activeInRabbitry: _activeInRabbitry,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          seller: seller,
          purchaseRabbitry: rabbitry,
          purchaseCost: cost,
          purchaseDate: purchaseDate,
        );

        // Ensure null-clearable fields are explicitly set because copyWith uses ?? internally
        updated.acquiredDate = _acquiredDate;
        updated.breederPrefix = _breederPrefixController.text.isEmpty ? null : _breederPrefixController.text;
        updated.earNumber = _earNumberController.text.isEmpty ? null : _earNumberController.text;
        updated.otherBreed = _otherBreedController.text.isEmpty ? null : _otherBreedController.text;
        updated.otherColor = _otherColorController.text.isEmpty ? null : _otherColorController.text;
        updated.notes = _notesController.text.isEmpty ? null : _notesController.text;
        updated.color = _colorController.text.isEmpty ? null : _colorController.text;
        updated.location = _selectedLocation;
        updated.cage = _selectedCage;
        updated.sireId = _selectedSireId;
        updated.damId = _selectedDamId;
        updated.seller = seller;
        updated.purchaseRabbitry = rabbitry;
        updated.purchaseCost = cost;
        updated.purchaseDate = purchaseDate;

        await _db.updateRabbit(updated);
        notifyDataChanged();

        // ✅ SYNC BREEDS TO LIBRARY
        await _syncBreedToLibrary(_breedController.text);
        if (_otherBreedController.text.isNotEmpty) {
          await _syncBreedToLibrary(_otherBreedController.text);
        }

        await _syncGeneticsCheckboxes(updated.id);

        if (updated.location != null && updated.location!.isNotEmpty && updated.cage != null && updated.cage!.isNotEmpty) {
          await _db.syncCageToBarn(updated.location!, updated.cage!);
        }

        // Add expense transaction if requested
        if (_hasPurchaseDetails && _addPurchaseAsExpense && cost != null && cost > 0) {
          final tx = finance_model.Transaction(
            id: 'tx_purch_${DateTime.now().millisecondsSinceEpoch}',
            type: finance_model.TransactionType.expense,
            category: finance_model.TransactionCategory.otherExpense,
            amount: cost,
            date: purchaseDate ?? DateTime.now(),
            description: 'Purchased ${_nameController.text.trim().isNotEmpty ? _nameController.text.trim() : "rabbit"}',
            notes: [
              if (seller != null) 'Seller: $seller',
              if (rabbitry != null) 'Rabbitry: $rabbitry',
            ].join(', '),
            linkType: finance_model.LinkType.rabbit,
            rabbitId: updated.id,
          );
          await _db.insertTransaction(tx);
        }

        // Save purchase document in documents section
        if (_hasPurchaseDetails && (seller != null || rabbitry != null || cost != null || purchaseDate != null)) {
          try {
            final docContent = '''PURCHASE DETAILS
Rabbit: ${_nameController.text.trim()}
Seller: ${seller ?? '-'}
Rabbitry: ${rabbitry ?? '-'}
Date of Purchase: ${purchaseDate != null ? FormatUtils.formatDate(purchaseDate) : '-'}
Cost: ${cost != null ? "${FormatUtils.currencyPrefix}${cost.toStringAsFixed(2)}" : '-'}
''';
            final appDir = await getApplicationDocumentsDirectory();
            final docsDir = Directory(p.join(appDir.path, 'rabbit_documents', updated.id, 'Registration'));
            if (!await docsDir.exists()) await docsDir.create(recursive: true);
            final filePath = p.join(docsDir.path, 'purchase_details.txt');
            final file = File(filePath);
            await file.writeAsString(docContent);

            final doc = RabbitDocument(
              id: 'doc_purch_${DateTime.now().millisecondsSinceEpoch}',
              rabbitId: updated.id,
              name: 'Purchase Details.txt',
              filePath: filePath,
              fileType: 'file',
              fileSize: await file.length(),
              createdAt: DateTime.now().toIso8601String(),
              folder: 'Registration',
            );
            await _db.insertDocument(doc);
          } catch (e) {
            print('Error saving purchase document: $e');
          }
        }

        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context, true);
          messenger.showSnackBar(
            SnackBar(
              content: Text('${updated.name} updated successfully', style: const TextStyle(fontSize: 16)),
              backgroundColor: const Color(0xFF7B6BA0),
            ),
          );
        }
      } else {
        final rabbit = Rabbit(
          id: rabbitId,
          name: _nameController.text,
          type: _selectedType,
          status: _selectedStatus,
          breed: _breedController.text,
          location: _selectedLocation,
          cage: _selectedCage,
          dateOfBirth: _dateOfBirth,
          acquiredDate: _acquiredDate,
          color: _colorController.text.isEmpty ? null : _colorController.text,
          weight: computedWeight,
          genetics: _autoGenetics,
          photos: newPhotos,
          earNumber: _earNumberController.text.isEmpty ? null : _earNumberController.text,
          otherBreed: _otherBreedController.text.isEmpty ? null : _otherBreedController.text,
          otherColor: _otherColorController.text.isEmpty ? null : _otherColorController.text,
          broken: _broken,
          viennaMarked: _viennaMarked,
          viennaCarrier: _viennaCarrier,
          breederPrefix: _breederPrefixController.text.isEmpty ? null : _breederPrefixController.text,
          sireId: _selectedSireId,
          damId: _selectedDamId,
          registrationNumber: _registrationNumberController.text.isEmpty ? null : _registrationNumberController.text,
          grandChampionNumber: _grandChampionNumberController.text.isEmpty ? null : _grandChampionNumberController.text,
          grandChampionLegs: int.tryParse(_grandChampionLegsController.text),
          activeInRabbitry: _activeInRabbitry,
          notes: _notesController.text.isEmpty ? null : _notesController.text,
          seller: seller,
          purchaseRabbitry: rabbitry,
          purchaseCost: cost,
          purchaseDate: purchaseDate,
        );

        await _db.insertRabbit(rabbit);
        notifyDataChanged();

        // ✅ SYNC BREEDS TO LIBRARY
        await _syncBreedToLibrary(_breedController.text);
        if (_otherBreedController.text.isNotEmpty) {
          await _syncBreedToLibrary(_otherBreedController.text);
        }

        await _syncGeneticsCheckboxes(rabbit.id);

        if (rabbit.location != null && rabbit.location!.isNotEmpty && rabbit.cage != null && rabbit.cage!.isNotEmpty) {
          await _db.syncCageToBarn(rabbit.location!, rabbit.cage!);
        }

        // Add expense transaction if requested
        if (_hasPurchaseDetails && _addPurchaseAsExpense && cost != null && cost > 0) {
          final tx = finance_model.Transaction(
            id: 'tx_purch_${DateTime.now().millisecondsSinceEpoch}',
            type: finance_model.TransactionType.expense,
            category: finance_model.TransactionCategory.otherExpense,
            amount: cost,
            date: purchaseDate ?? DateTime.now(),
            description: 'Purchased ${_nameController.text.trim().isNotEmpty ? _nameController.text.trim() : "rabbit"}',
            notes: [
              if (seller != null) 'Seller: $seller',
              if (rabbitry != null) 'Rabbitry: $rabbitry',
            ].join(', '),
            linkType: finance_model.LinkType.rabbit,
            rabbitId: rabbit.id,
          );
          await _db.insertTransaction(tx);
        }

        // Save purchase document in documents section
        if (_hasPurchaseDetails && (seller != null || rabbitry != null || cost != null || purchaseDate != null)) {
          try {
            final docContent = '''PURCHASE DETAILS
Rabbit: ${_nameController.text.trim()}
Seller: ${seller ?? '-'}
Rabbitry: ${rabbitry ?? '-'}
Date of Purchase: ${purchaseDate != null ? FormatUtils.formatDate(purchaseDate) : '-'}
Cost: ${cost != null ? "${FormatUtils.currencyPrefix}${cost.toStringAsFixed(2)}" : '-'}
''';
            final appDir = await getApplicationDocumentsDirectory();
            final docsDir = Directory(p.join(appDir.path, 'rabbit_documents', rabbit.id, 'Registration'));
            if (!await docsDir.exists()) await docsDir.create(recursive: true);
            final filePath = p.join(docsDir.path, 'purchase_details.txt');
            final file = File(filePath);
            await file.writeAsString(docContent);

            final doc = RabbitDocument(
              id: 'doc_purch_${DateTime.now().millisecondsSinceEpoch}',
              rabbitId: rabbit.id,
              name: 'Purchase Details.txt',
              filePath: filePath,
              fileType: 'file',
              fileSize: await file.length(),
              createdAt: DateTime.now().toIso8601String(),
              folder: 'Registration',
            );
            await _db.insertDocument(doc);
          } catch (e) {
            print('Error saving purchase document: $e');
          }
        }

        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context, true);
          messenger.showSnackBar(
            SnackBar(
              content: Text('${rabbit.name} added successfully', style: const TextStyle(fontSize: 16)),
              backgroundColor: const Color(0xFF7B6BA0),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e', style: const TextStyle(fontSize: 16)), backgroundColor: const Color(0xFFD44C47)),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }
}
