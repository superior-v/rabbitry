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
import '../services/settings_service.dart';
import '../constants/app_colors.dart';

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
      final bucks = await _db.getRabbitsByType(RabbitType.buck);
      final does = await _db.getRabbitsByType(RabbitType.doe);
      if (mounted) {
        setState(() {
          _availableBucks = bucks;
          _availableDoes = does;
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
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600, fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveRabbit,
            child: Text(
              'SAVE',
              style: TextStyle(
                color: _isSaving ? kNeutral400 : (_selectedType == RabbitType.doe ? kPinkDeep : kBlueDeep),
                fontWeight: FontWeight.w700,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfilePictureSection(),
            const SizedBox(height: 12),

            // a. Rabbit Type (Buck / Doe)
            const Text(
              'Rabbit Type',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Color(0xFFB0AFA8)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildTypeButton(
                    type: RabbitType.buck,
                    label: 'Buck',
                    icon: Icons.male,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTypeButton(
                    type: RabbitType.doe,
                    label: 'Doe',
                    icon: Icons.female,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // b. Breed (and Other Breed)
            const Text(
              'Breed *',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Color(0xFFB0AFA8)),
            ),
            const SizedBox(height: 8),
            _buildBreedSelector(),
            const SizedBox(height: 12),
            _buildTextField(
              controller: _otherBreedController,
              label: 'Other Breed',
              icon: Icons.category_outlined,
              hint: 'Secondary breed (if mixed)',
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // c. Breeder Prefix
            _buildTextField(
              controller: _breederPrefixController,
              label: 'Breeder Prefix',
              icon: Icons.badge_outlined,
              hint: 'Breeder prefix',
              inputFormatters: [_UpperCaseTextFormatter()],
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),

            // d. Name
            _buildTextField(
              controller: _nameController,
              label: 'Name *',
              icon: Icons.pets,
              hint: 'Enter rabbit name',
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // e. Ear Number
            _buildTextField(
              controller: _earNumberController,
              label: 'Ear Number',
              icon: Icons.hearing,
              hint: 'Enter ear number',
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),

            // f. Date of Birth
            _buildDateField(),
            const SizedBox(height: 16),

            // g. Color
            const Text(
              'Color',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Color(0xFFB0AFA8)),
            ),
            const SizedBox(height: 8),
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                final colors = SettingsService.instance.colors;
                if (textEditingValue.text.isEmpty) return colors;
                return colors.where(
                  (c) => c.toLowerCase().contains(textEditingValue.text.toLowerCase()),
                );
              },
              initialValue: TextEditingValue(text: _colorController.text),
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                controller.addListener(() {
                  _colorController.text = controller.text;
                });
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 17),
                  decoration: InputDecoration(
                    hintText: 'e.g., White, Black',
                    hintStyle: const TextStyle(fontSize: 16, color: Color(0xFFCCCBC8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                      borderSide: BorderSide(color: _selectedType == RabbitType.doe ? kPinkDeep : kBlueDeep, width: 2),
                    ),
                  ),
                );
              },
              onSelected: (String color) {
                _colorController.text = color;
              },
            ),
            const SizedBox(height: 12),
            const Text(
              'Other Color',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Color(0xFFB0AFA8)),
            ),
            const SizedBox(height: 8),
            Autocomplete<String>(
              optionsBuilder: (TextEditingValue textEditingValue) {
                final colors = SettingsService.instance.colors;
                if (textEditingValue.text.isEmpty) return colors;
                return colors.where(
                  (c) => c.toLowerCase().contains(textEditingValue.text.toLowerCase()),
                );
              },
              initialValue: TextEditingValue(text: _otherColorController.text),
              fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                controller.addListener(() {
                  _otherColorController.text = controller.text;
                });
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textCapitalization: TextCapitalization.words,
                  style: const TextStyle(fontSize: 17),
                  decoration: InputDecoration(
                    hintText: 'Secondary color',
                    hintStyle: const TextStyle(fontSize: 16, color: Color(0xFFCCCBC8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
                      borderSide: BorderSide(color: _selectedType == RabbitType.doe ? kPinkDeep : kBlueDeep, width: 2),
                    ),
                  ),
                );
              },
              onSelected: (String color) {
                _otherColorController.text = color;
              },
            ),
            const SizedBox(height: 16),

            // h. Broken / Vienna Marked / Vienna Carrier toggles
            Row(
              children: [
                Expanded(
                  child: _buildToggleRow('Broken', _broken, (val) => setState(() => _broken = val)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildToggleRow('VM', _viennaMarked, (val) => setState(() => _viennaMarked = val)),
                ),
              ],
            ),
            _buildToggleRow('Vienna Carrier (VC)', _viennaCarrier, (val) => setState(() => _viennaCarrier = val)),
            const SizedBox(height: 16),

            // i. Weight (pounds / ounces)
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _weightPoundsController,
                    label: 'Pounds',
                    icon: Icons.monitor_weight,
                    hint: '0',
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildTextField(
                    controller: _weightOuncesController,
                    label: 'Ounces',
                    icon: Icons.monitor_weight_outlined,
                    hint: '0',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // j. Dam / Sire
            _buildParentSelector('Dam', _selectedDamId, _selectedDamName, _availableDoes, (id, name) {
              setState(() {
                _selectedDamId = id;
                _selectedDamName = name;
              });
            }),
            const SizedBox(height: 12),
            _buildParentSelector('Sire', _selectedSireId, _selectedSireName, _availableBucks, (id, name) {
              setState(() {
                _selectedSireId = id;
                _selectedSireName = name;
              });
            }),
            const SizedBox(height: 16),

            // k. Genotype (expandable, updated to 4 columns to prevent cutting off text)
            _buildGenotypeSection(),
            const SizedBox(height: 16),

            // l. Registration / Grand Champion/Legs
            _buildTextField(
              controller: _registrationNumberController,
              label: 'Registration Number',
              icon: Icons.card_membership,
              hint: 'Registration #',
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildTextField(
                    controller: _grandChampionNumberController,
                    label: 'GC Number',
                    icon: Icons.emoji_events,
                    hint: 'GC Number',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 1,
                  child: _buildTextField(
                    controller: _grandChampionLegsController,
                    label: 'GC Legs',
                    icon: Icons.emoji_events_outlined,
                    hint: '0',
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // m. Active in Rabbitry etc.
            _buildToggleRow('Active in Rabbitry', _activeInRabbitry, (val) => setState(() => _activeInRabbitry = val)),
            const SizedBox(height: 16),

            const Text(
              'Status',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Color(0xFFB0AFA8)),
            ),
            const SizedBox(height: 8),
            _buildStatusDropdown(),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Location',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Color(0xFFB0AFA8)),
                      ),
                      const SizedBox(height: 8),
                      _buildLocationDropdown(),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Cage',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Color(0xFFB0AFA8)),
                      ),
                      const SizedBox(height: 8),
                      _buildCageDropdown(),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            _buildTextField(
              controller: _idController,
              label: 'Rabbit ID',
              icon: Icons.tag,
              readOnly: true,
            ),
            const SizedBox(height: 16),

            const Text(
              'Notes',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: Color(0xFFB0AFA8)),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              style: const TextStyle(fontSize: 17),
              decoration: InputDecoration(
                hintText: 'Add any notes...',
                hintStyle: const TextStyle(fontSize: 16, color: Color(0xFFCCCBC8)),
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
                  borderSide: BorderSide(color: _selectedType == RabbitType.doe ? kPinkDeep : kBlueDeep, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

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
                      color: _selectedType == RabbitType.doe ? kFemaleColor : kMaleColor,
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
                    color: _selectedType == RabbitType.doe ? kFemaleColor : kMaleColor,
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
                      color: _selectedType == RabbitType.doe ? kFemaleColor : kMaleColor,
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
              style: TextStyle(
                color: _selectedType == RabbitType.doe ? kFemaleColor : kMaleColor,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ),
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
        setState(() {
          _profileImagePath = image.path;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo added successfully'),
            backgroundColor: Color(0xFF6366F1),
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
    final color = type == RabbitType.doe ? kFemaleColor : kMaleColor;

    return InkWell(
      onTap: _isEditing ? null : () => setState(() => _selectedType = type),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
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
                fontSize: 16,
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
        controller.addListener(() {
          _breedController.text = controller.text;
        });
        return TextField(
          controller: controller,
          focusNode: focusNode,
          textCapitalization: TextCapitalization.words,
          style: const TextStyle(fontSize: 17),
          decoration: InputDecoration(
            hintText: 'e.g., New Zealand White',
            hintStyle: const TextStyle(fontSize: 16, color: Color(0xFFCCCBC8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
              borderSide: BorderSide(color: _selectedType == RabbitType.doe ? kPinkDeep : kBlueDeep, width: 2),
            ),
          ),
        );
      },
      onSelected: (String breedName) {
        _breedController.text = breedName;
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
      return ['--', 'EnEn', 'Enen', 'enen'];
    }
    return ['--', '$upper$upper', '$upper$lower', '$lower$lower'];
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
                    fontSize: 19,
                    color: _genotypeExpanded ? (_selectedType == RabbitType.doe ? kPinkDeep : kBlueDeep) : Colors.black54,
                    fontWeight: FontWeight.normal,
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
    IconData? icon,
    String? hint,
    bool readOnly = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      style: const TextStyle(fontSize: 17),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        labelStyle: const TextStyle(fontSize: 14, color: Color(0xFFBBB9B2)),
        hintStyle: const TextStyle(fontSize: 16, color: Color(0xFFCCCBC8)),
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
          borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
        ),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<RabbitStatus>(
      value: _selectedStatus,
      style: const TextStyle(fontSize: 17, color: Colors.black87),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
        ),
      ),
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
    final locationNames = _barns.map((b) => b.name).toList();

    if (_selectedLocation != null && !locationNames.contains(_selectedLocation)) {
      _selectedLocation = null;
    }

    return DropdownButtonFormField<String>(
      value: _selectedLocation,
      style: const TextStyle(fontSize: 17, color: Colors.black87),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
        ),
      ),
      hint: Text(locationNames.isEmpty ? 'No barns' : 'Location', style: const TextStyle(fontSize: 16)),
      items: locationNames.map((location) {
        return DropdownMenuItem(value: location, child: Text(location));
      }).toList(),
      onChanged: (value) {
        setState(() {
          _selectedLocation = value;
          _selectedCage = null;
        });
      },
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

    return DropdownButtonFormField<String>(
      key: ValueKey(_selectedLocation),
      value: _selectedCage,
      style: const TextStyle(fontSize: 17, color: Colors.black87),
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
        ),
      ),
      hint: Text(_selectedLocation == null
          ? 'Select Location'
          : cageNames.isEmpty
          ? 'No cages'
          : 'Cage', style: const TextStyle(fontSize: 16)),
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
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE9E9E7)),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Date Born',
                          style: TextStyle(fontSize: 14, color: Color(0xFFBBB9B2)),
                        ),
                        Text(
                          _dateOfBirth != null ? FormatUtils.formatDate(_dateOfBirth!) : 'Not set',
                          style: const TextStyle(fontSize: 18, color: Colors.black87),
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
            child: const Text('Clear', style: TextStyle(color: Color(0xFF2E7BB5), fontWeight: FontWeight.normal, fontSize: 16)),
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
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.normal, color: Colors.black87),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF6366F1),
        ),
      ],
    );
  }

  Widget _buildParentSelector(String label, String? selectedId, String? selectedName, List<Rabbit> options, void Function(String?, String?) onSelect) {
    return Row(
      children: [
        SizedBox(
          width: 50,
          child: Text(
            label,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.normal, color: Colors.black87),
          ),
        ),
        const SizedBox(width: 8),
        if (selectedId != null && selectedName != null) ...[
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: _selectedType == RabbitType.doe ? kPinkWash : kBlueWash,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: (_selectedType == RabbitType.doe ? kFemaleColor : kMaleColor).withOpacity(0.3)),
              ),
              child: Text(
                selectedName,
                style: TextStyle(fontSize: 17, color: _selectedType == RabbitType.doe ? kFemaleColor : kMaleColor, fontWeight: FontWeight.normal),
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
          child: Text('Select', style: TextStyle(color: label == 'Dam' ? kFemaleColor : kMaleColor, fontWeight: FontWeight.normal, fontSize: 16)),
        ),
        if (selectedId != null)
          TextButton(
            onPressed: () => onSelect(null, null),
            child: Text('Clear', style: TextStyle(color: label == 'Dam' ? kFemaleColor : kMaleColor, fontWeight: FontWeight.normal, fontSize: 16)),
          ),
      ],
    );
  }

  void _showParentPickerDialog(String label, List<Rabbit> options, void Function(String, String) onSelect) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select $label', style: const TextStyle(fontSize: 19)),
        content: SizedBox(
          width: double.maxFinite,
          child: options.isEmpty
              ? const Text('No rabbits available', style: TextStyle(fontSize: 17))
              : ListView.builder(
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final rabbit = options[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: label == 'Dam' ? kPinkLight : kBlueLight,
                  child: Text(rabbit.name.isNotEmpty ? rabbit.name[0] : '?', style: TextStyle(fontSize: 17, color: label == 'Dam' ? kFemaleColor : kMaleColor)),
                ),
                title: Text(rabbit.name, style: const TextStyle(fontSize: 17)),
                subtitle: Text('${rabbit.breed} • ${rabbit.id}', style: const TextStyle(fontSize: 15)),
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
            child: const Text('Cancel', style: TextStyle(fontSize: 16)),
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
        newPhotos = [_profileImagePath!];
      } else if (_photoRemoved) {
        newPhotos = [];
      } else {
        newPhotos = widget.editRabbit?.photos;
      }

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
        
        // Ensure null-clearable fields are explicitly set because copyWith uses ?? internally
        updated.breederPrefix = _breederPrefixController.text.isEmpty ? null : _breederPrefixController.text;
        updated.earNumber = _earNumberController.text.isEmpty ? null : _earNumberController.text;
        updated.otherBreed = _otherBreedController.text.isEmpty ? null : _otherBreedController.text;
        updated.otherColor = _otherColorController.text.isEmpty ? null : _otherColorController.text;
        updated.notes = _notesController.text.isEmpty ? null : _notesController.text;
        updated.color = _colorController.text.isEmpty ? null : _colorController.text;
        updated.location = _selectedLocation;
        updated.cage = _selectedCage;

        await _db.updateRabbit(updated);

        await _syncGeneticsCheckboxes(updated.id);

        if (updated.location != null && updated.location!.isNotEmpty && updated.cage != null && updated.cage!.isNotEmpty) {
          await _db.syncCageToBarn(updated.location!, updated.cage!);
        }

        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context, true);
          messenger.showSnackBar(
            SnackBar(
              content: Text('${updated.name} updated successfully', style: const TextStyle(fontSize: 16)),
              backgroundColor: const Color(0xFF6366F1),
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

        await _syncGeneticsCheckboxes(rabbit.id);

        if (rabbit.location != null && rabbit.location!.isNotEmpty && rabbit.cage != null && rabbit.cage!.isNotEmpty) {
          await _db.syncCageToBarn(rabbit.location!, rabbit.cage!);
        }

        if (mounted) {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context, true);
          messenger.showSnackBar(
            SnackBar(
              content: Text('${rabbit.name} added successfully', style: const TextStyle(fontSize: 16)),
              backgroundColor: const Color(0xFF6366F1),
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