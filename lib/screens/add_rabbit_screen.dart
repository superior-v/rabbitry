import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import '../models/rabbit.dart';
import '../models/breed.dart';
import '../models/barn.dart';
import '../services/database_service.dart';
import '../services/format_utils.dart';

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

  RabbitType _selectedType = RabbitType.doe;
  RabbitStatus _selectedStatus = RabbitStatus.open;
  String? _selectedLocation;
  String? _selectedCage;
  DateTime? _dateOfBirth;
  String? _profileImagePath;
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
    // Parse weight into pounds and ounces if using lbs
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
      // Fallback to timestamp-based ID
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
      final bucks = await _db.getRabbitsByType(RabbitType.buck);
      final does = await _db.getRabbitsByType(RabbitType.doe);
      if (mounted) {
        setState(() {
          _availableBucks = bucks;
          _availableDoes = does;
          // Set parent names if editing
          if (_selectedSireId != null) {
            final sire = bucks.where((b) => b.id == _selectedSireId).toList();
            if (sire.isNotEmpty) _selectedSireName = sire.first.name;
          }
          if (_selectedDamId != null) {
            final dam = does.where((d) => d.id == _selectedDamId).toList();
            if (dam.isNotEmpty) _selectedDamName = dam.first.name;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _isEditing ? 'Edit Rabbit' : 'Add New Rabbit',
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w700, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveRabbit,
            child: Text(
              'SAVE',
              style: TextStyle(
                color: _isSaving ? Colors.grey : const Color(0xFF8B5E3C),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Picture Section
            _buildProfilePictureSection(),
            const SizedBox(height: 24),

            // Rabbit Type (Buck / Doe)
            const Text(
              'Rabbit Type',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFFB0AFA8)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTypeButton(
                    type: RabbitType.buck,
                    label: 'Buck',
                    icon: Icons.male,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTypeButton(
                    type: RabbitType.doe,
                    label: 'Doe',
                    icon: Icons.female,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Ear Number
            _buildTextField(
              controller: _earNumberController,
              label: 'Ear Number',
              icon: Icons.hearing,
              hint: 'Enter ear number',
            ),
            const SizedBox(height: 16),

            // Breed
            const Text(
              'Breed *',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFFB0AFA8)),
            ),
            const SizedBox(height: 8),
            _buildBreedSelector(),
            const SizedBox(height: 16),

            // Select Genotype (expandable)
            _buildGenotypeSection(),
            const SizedBox(height: 24),

            // === Optional Fields Section ===
            const Text(
              'Optional Fields',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFFB0AFA8)),
            ),
            const SizedBox(height: 16),

            // Other Breed
            _buildTextField(
              controller: _otherBreedController,
              label: 'Other Breed',
              icon: Icons.category_outlined,
              hint: 'Secondary breed (if mixed)',
            ),
            const SizedBox(height: 16),

            // Color
            _buildTextField(
              controller: _colorController,
              label: 'Color',
              icon: Icons.palette,
              hint: 'e.g., White, Black',
            ),
            const SizedBox(height: 16),

            // Other Color
            _buildTextField(
              controller: _otherColorController,
              label: 'Other Color',
              icon: Icons.palette_outlined,
              hint: 'Secondary color',
            ),
            const SizedBox(height: 16),

            // Broken / Vienna Marked / Vienna Carrier toggles
            Row(
              children: [
                Expanded(
                  child: _buildToggleRow('Broken', _broken, (val) => setState(() => _broken = val)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildToggleRow('Vienna Marked', _viennaMarked, (val) => setState(() => _viennaMarked = val)),
                ),
              ],
            ),
            const SizedBox(height: 4),
            _buildToggleRow('Vienna Carrier', _viennaCarrier, (val) => setState(() => _viennaCarrier = val)),
            const SizedBox(height: 16),

            // Date of Birth
            _buildDateField(),
            const SizedBox(height: 16),

            // Breeder Prefix
            _buildTextField(
              controller: _breederPrefixController,
              label: 'Breeder Prefix',
              icon: Icons.badge_outlined,
              hint: 'Breeder prefix',
              inputFormatters: [
                _UpperCaseTextFormatter()
              ],
            ),
            const SizedBox(height: 16),

            // Name
            _buildTextField(
              controller: _nameController,
              label: 'Name *',
              icon: Icons.pets,
              hint: 'Enter rabbit name',
            ),
            const SizedBox(height: 16),

            // Sire (Select / Clear)
            _buildParentSelector('Sire', _selectedSireId, _selectedSireName, _availableBucks, (id, name) {
              setState(() {
                _selectedSireId = id;
                _selectedSireName = name;
              });
            }),
            const SizedBox(height: 16),

            // Dam (Select / Clear)
            _buildParentSelector('Dam', _selectedDamId, _selectedDamName, _availableDoes, (id, name) {
              setState(() {
                _selectedDamId = id;
                _selectedDamName = name;
              });
            }),
            const SizedBox(height: 16),

            // Weight (pounds / ounces)
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _weightPoundsController,
                    label: 'pounds',
                    icon: Icons.monitor_weight,
                    hint: '0',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTextField(
                    controller: _weightOuncesController,
                    label: 'ounces',
                    icon: Icons.monitor_weight_outlined,
                    hint: '0',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Registration Number
            _buildTextField(
              controller: _registrationNumberController,
              label: 'Registration Number',
              icon: Icons.card_membership,
              hint: 'Registration #',
            ),
            const SizedBox(height: 16),

            // Grand Champion Number
            _buildTextField(
              controller: _grandChampionNumberController,
              label: 'Grand Champion Number',
              icon: Icons.emoji_events,
              hint: 'GC Number',
            ),
            const SizedBox(height: 16),

            // Grand Champion Legs
            _buildTextField(
              controller: _grandChampionLegsController,
              label: 'Grand Champion Legs',
              icon: Icons.emoji_events_outlined,
              hint: '0',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            // Active in Rabbitry toggle
            _buildToggleRow('Active in Rabbitry', _activeInRabbitry, (val) => setState(() => _activeInRabbitry = val)),
            const SizedBox(height: 16),

            // Status
            const Text(
              'Status',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFFB0AFA8)),
            ),
            const SizedBox(height: 8),
            _buildStatusDropdown(),
            const SizedBox(height: 16),

            // Location
            const Text(
              'Location',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFFB0AFA8)),
            ),
            const SizedBox(height: 8),
            _buildLocationDropdown(),
            const SizedBox(height: 16),

            // Cage
            const Text(
              'Cage',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFFB0AFA8)),
            ),
            const SizedBox(height: 8),
            _buildCageDropdown(),
            const SizedBox(height: 16),

            // Rabbit ID (auto-generated or locked in edit mode)
            _buildTextField(
              controller: _idController,
              label: 'Rabbit ID',
              icon: Icons.tag,
              readOnly: true,
            ),
            const SizedBox(height: 16),

            // Notes
            const Text(
              'Notes',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFFB0AFA8)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText: 'Add any notes...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF8B5E3C), width: 2),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ✅ ADD THIS METHOD: Profile Picture Section
  Widget _buildProfilePictureSection() {
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
                      color: _selectedType == RabbitType.doe ? const Color(0xFF9C6ADE) : const Color(0xFF2E7BB5),
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
                          color: _selectedType == RabbitType.doe ? const Color(0xFF9C6ADE) : const Color(0xFF2E7BB5),
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
                      color: _selectedType == RabbitType.doe ? const Color(0xFF9C6ADE) : const Color(0xFF2E7BB5),
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
          const SizedBox(height: 8),
          TextButton(
            onPressed: _showImagePickerOptions,
            child: Text(
              _profileImagePath == null ? 'Add Photo' : 'Change Photo',
              style: const TextStyle(
                color: Color(0xFF8B5E3C),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ ADD THIS METHOD: Show Image Picker Options
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
              'Add Profile Picture',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
                  setState(() => _profileImagePath = null);
                },
                isDestructive: true,
              ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ✅ ADD THIS METHOD: Photo Option Widget
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

  // ✅ ADD THIS METHOD: Pick Image
  Future<void> _pickImage(ImageSource source) async {
    try {
      // Request permission
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
        setState(() {
          _profileImagePath = image.path;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo added successfully'),
            backgroundColor: Color(0xFF8B5E3C),
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

  // ✅ ADD THIS METHOD: Request Permission
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

  Widget _buildTypeButton({
    required RabbitType type,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedType == type;
    final color = type == RabbitType.doe ? const Color(0xFF9C6ADE) : const Color(0xFF2E7BB5);

    return InkWell(
      onTap: _isEditing ? null : () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          border: Border.all(color: isSelected ? color : const Color(0xFFE9E9E7)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : color,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBreedSelector() {
    return Autocomplete<String>(
      optionsBuilder: (TextEditingValue textEditingValue) {
        final breedNames = _availableBreeds.map((b) => b.name).toList();
        if (textEditingValue.text.isEmpty) return breedNames;
        return breedNames.where(
          (name) => name.toLowerCase().contains(textEditingValue.text.toLowerCase()),
        );
      },
      initialValue: TextEditingValue(text: _breedController.text),
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        // Keep _breedController in sync
        controller.addListener(() {
          _breedController.text = controller.text;
        });
        return TextField(
          controller: controller,
          focusNode: focusNode,
          decoration: InputDecoration(
            hintText: 'e.g., New Zealand White',
            hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFCCCBC8)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF8B5E3C), width: 2),
            ),
          ),
        );
      },
      onSelected: (String breedName) {
        _breedController.text = breedName;
        // Auto-fill genetics from matched breed
        final matched = _availableBreeds.where((b) => b.name == breedName);
        if (matched.isNotEmpty) {
          final geneticsStr = matched.first.genetics.join(', ');
          setState(() {
            _autoGenetics = geneticsStr;
            _parseGeneticsToMap(geneticsStr);
          });
        }
      },
    );
  }

  // === Genotype Methods ===

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
        // "Select Genotype" header row
        InkWell(
          onTap: () => setState(() => _genotypeExpanded = !_genotypeExpanded),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0xFFE9E9E7))),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Genotype',
                  style: TextStyle(
                    fontSize: 16,
                    color: _genotypeExpanded ? const Color(0xFF8B5E3C) : Colors.black54,
                    fontWeight: FontWeight.w400,
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
        // Expanded genotype grid
        if (_genotypeExpanded) ...[
          const SizedBox(height: 16),
          // Row 1: A, B, C, D, E, En
          Row(
            children: _locusKeys.sublist(0, 6).map((key) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: _buildLocusDropdown(key),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 8),
          // Row 2: V, W
          Row(
            children: [
              ..._locusKeys.sublist(6).map((key) {
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _buildLocusDropdown(key),
                  ),
                );
              }),
              // Spacers to keep alignment
              const Expanded(child: SizedBox()),
              const Expanded(child: SizedBox()),
              const Expanded(child: SizedBox()),
              const Expanded(child: SizedBox()),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildLocusDropdown(String locus) {
    final alleles = _getAllelesForLocus(locus);
    final current = _genotypeMap[locus] ?? '--';
    // Ensure current value is in the alleles list
    final value = alleles.contains(current) ? current : '--';
    return Column(
      children: [
        Text(
          locus,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: Color(0xFF787774),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 36,
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: Color(0xFFE9E9E7))),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.arrow_drop_down, size: 16),
              style: const TextStyle(fontSize: 12, color: Color(0xFF37352F), fontFamily: 'monospace'),
              items: alleles.map((a) => DropdownMenuItem(value: a, child: Text(a, style: const TextStyle(fontSize: 12)))).toList(),
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

  Widget _buildGenotypeCheckbox(String label, bool value, ValueChanged<bool> onChanged) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              border: Border.all(
                color: value ? const Color(0xFF8B5E3C) : const Color(0xFFD1D5DB),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(4),
              color: value ? const Color(0xFF8B5E3C) : Colors.transparent,
            ),
            child: value ? const Icon(Icons.check, size: 14, color: Colors.white) : null,
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF37352F),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    String? hint,
    bool readOnly = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontSize: 11, color: Color(0xFFBBB9B2)),
        hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFCCCBC8)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8B5E3C), width: 2),
        ),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<RabbitStatus>(
      value: _selectedStatus,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
        ),
      ),
      items: (_isEditing
              ? [
                  RabbitStatus.open,
                  RabbitStatus.growout,
                  RabbitStatus.resting,
                  RabbitStatus.quarantine
                ]
              : [
                  RabbitStatus.open,
                  RabbitStatus.growout
                ])
          .map((status) {
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
          child: Text(label),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedStatus = value!),
    );
  }

  Widget _buildLocationDropdown() {
    // Build location list from actual barns in database
    final locationNames = _barns.map((b) => b.name).toList();

    // Reset selection if it no longer exists in the list
    if (_selectedLocation != null && !locationNames.contains(_selectedLocation)) {
      _selectedLocation = null;
    }

    return DropdownButtonFormField<String>(
      value: _selectedLocation,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
        ),
      ),
      hint: Text(locationNames.isEmpty ? 'No barns added yet' : 'Select Location'),
      items: locationNames.map((location) {
        return DropdownMenuItem(value: location, child: Text(location));
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedLocation = value;
          _selectedCage = null; // Reset cage when location changes
        });
      },
    );
  }

  Widget _buildCageDropdown() {
    // Get cages from the selected barn's rows
    List<String> cageNames = [];
    if (_selectedLocation != null) {
      final matchingBarn = _barns.where((b) => b.name == _selectedLocation).toList();
      if (matchingBarn.isNotEmpty) {
        for (final row in matchingBarn.first.rows) {
          cageNames.addAll(row.cages);
        }
      }
    }

    // Reset selection if it no longer exists in the list
    if (_selectedCage != null && !cageNames.contains(_selectedCage)) {
      _selectedCage = null;
    }

    return DropdownButtonFormField<String>(
      key: ValueKey(_selectedLocation), // Rebuild when location changes
      value: _selectedCage,
      decoration: InputDecoration(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
        ),
      ),
      hint: Text(_selectedLocation == null
          ? 'Select a location first'
          : cageNames.isEmpty
              ? 'No cages in this barn'
              : 'Select Cage'),
      items: cageNames.map((cage) {
        return DropdownMenuItem(value: cage, child: Text(cage));
      }).toList(),
      onChanged: (value) => setState(() => _selectedCage = value),
    );
  }

  Widget _buildDateField() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _dateOfBirth ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime.now(),
              );
              if (date != null) {
                setState(() => _dateOfBirth = date);
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE9E9E7)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Date Born',
                          style: TextStyle(fontSize: 11, color: Color(0xFFBBB9B2)),
                        ),
                        Text(
                          _dateOfBirth != null ? FormatUtils.formatDate(_dateOfBirth!) : 'Not set',
                          style: const TextStyle(fontSize: 15, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_dateOfBirth != null) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: () => setState(() => _dateOfBirth = null),
            child: const Text('Clear', style: TextStyle(color: Color(0xFF2E7BB5), fontWeight: FontWeight.w600)),
          ),
        ],
      ],
    );
  }

  Widget _buildToggleRow(String label, bool value, ValueChanged<bool> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF8B5E3C),
        ),
      ],
    );
  }

  Widget _buildParentSelector(String label, String? selectedId, String? selectedName, List<Rabbit> options, void Function(String?, String?) onSelect) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87),
        ),
        const SizedBox(width: 12),
        if (selectedId != null && selectedName != null) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF7EDE3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF8B5E3C).withOpacity(0.3)),
              ),
              child: Text(
                selectedName,
                style: const TextStyle(fontSize: 14, color: Color(0xFF8B5E3C), fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
        if (selectedId == null) const Expanded(child: SizedBox()),
        TextButton(
          onPressed: () {
            _showParentPickerDialog(label, options, (id, name) {
              onSelect(id, name);
            });
          },
          child: const Text('Select', style: TextStyle(color: Color(0xFF2E7BB5), fontWeight: FontWeight.w600)),
        ),
        if (selectedId != null)
          TextButton(
            onPressed: () => onSelect(null, null),
            child: const Text('Clear', style: TextStyle(color: Color(0xFF2E7BB5), fontWeight: FontWeight.w600)),
          ),
      ],
    );
  }

  void _showParentPickerDialog(String label, List<Rabbit> options, void Function(String, String) onSelect) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select $label'),
        content: SizedBox(
          width: double.maxFinite,
          child: options.isEmpty
              ? const Text('No rabbits available')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final rabbit = options[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFF7EDE3),
                        child: Text(rabbit.name.isNotEmpty ? rabbit.name[0] : '?'),
                      ),
                      title: Text(rabbit.name),
                      subtitle: Text('${rabbit.breed} • ${rabbit.id}'),
                      onTap: () {
                        Navigator.pop(context);
                        onSelect(rabbit.id, rabbit.name);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
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

  Future<void> _saveRabbit() async {
    // Validation
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name'), backgroundColor: Color(0xFFD44C47)),
      );
      return;
    }

    if (_breedController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a breed'), backgroundColor: Color(0xFFD44C47)),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final rabbitId = _idController.text.isNotEmpty ? _idController.text : DateTime.now().millisecondsSinceEpoch.toString();

      final newPhotos = _profileImagePath != null
          ? [
              _profileImagePath!
            ]
          : null;

      final computedWeight = _computeWeight();

      if (_isEditing) {
        final updated = widget.editRabbit!.copyWith(
          name: _nameController.text,
          status: _selectedStatus,
          breed: _breedController.text,
          location: _selectedLocation,
          cage: _selectedCage,
          dateOfBirth: _dateOfBirth,
          color: _colorController.text.isEmpty ? null : _colorController.text,
          weight: computedWeight,
          genetics: _autoGenetics,
          photos: newPhotos ?? widget.editRabbit!.photos,
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
        );
        await _db.updateRabbit(updated);

        // Sync broken/vienna toggles to genetics card SharedPreferences
        await _syncGeneticsCheckboxes(updated.id);

        if (updated.location != null && updated.location!.isNotEmpty && updated.cage != null && updated.cage!.isNotEmpty) {
          await _db.syncCageToBarn(updated.location!, updated.cage!);
        }

        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context, true);
          messenger.showSnackBar(
            SnackBar(
              content: Text('${updated.name} updated successfully'),
              backgroundColor: const Color(0xFF8B5E3C),
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
        );

        await _db.insertRabbit(rabbit);

        // Sync broken/vienna toggles to genetics card SharedPreferences
        await _syncGeneticsCheckboxes(rabbit.id);

        if (rabbit.location != null && rabbit.location!.isNotEmpty && rabbit.cage != null && rabbit.cage!.isNotEmpty) {
          await _db.syncCageToBarn(rabbit.location!, rabbit.cage!);
        }

        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context, true);
          messenger.showSnackBar(
            SnackBar(
              content: Text('${rabbit.name} added successfully'),
              backgroundColor: const Color(0xFF8B5E3C),
            ),
          );
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFD44C47)),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }
}
