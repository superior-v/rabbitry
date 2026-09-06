import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../models/litter.dart';
import '../services/format_utils.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../constants/app_colors.dart';

class KitDetailScreen extends StatefulWidget {
  final Litter litter;
  final Kit kit;
  final VoidCallback? onUpdated;

  const KitDetailScreen({
    Key? key,
    required this.litter,
    required this.kit,
    this.onUpdated,
  }) : super(key: key);

  @override
  State<KitDetailScreen> createState() => _KitDetailScreenState();
}

class _KitDetailScreenState extends State<KitDetailScreen> {
  final DatabaseService _db = DatabaseService();
  final ImagePicker _imagePicker = ImagePicker();
  late Kit _kit;
  late Litter _litter;
  List<Map<String, dynamic>> _weightHistory = [];

  @override
  void initState() {
    super.initState();
    _kit = widget.kit;
    _litter = widget.litter;
    _loadWeightHistory();
  }

  Future<void> _loadWeightHistory() async {
    try {
      final db = await _db.database;
      final records = await db.query(
        'weight_records',
        where: 'rabbitId = ?',
        whereArgs: [
          '${_litter.id}-K-${_kit.id}'
        ],
        orderBy: 'date DESC',
        limit: 10,
      );
      if (mounted) {
        setState(() => _weightHistory = records);
      }
    } catch (e) {
      // Weight records table may not exist for kits
    }
  }

  // ==================== PERSISTENCE ====================

  Future<void> _saveKit() async {
    await _db.updateKit(_litter.id, _kit);
    widget.onUpdated?.call();
  }

  Future<void> _saveLitter() async {
    await _db.updateLitter(_litter);
    widget.onUpdated?.call();
  }

  // ==================== IMAGE PICKER ====================

  Future<bool> _requestPermission(ImageSource source) async {
    if (source == ImageSource.camera) {
      var status = await Permission.camera.status;
      if (!status.isGranted) status = await Permission.camera.request();
      return status.isGranted;
    } else {
      var status = await Permission.photos.status;
      if (!status.isGranted) status = await Permission.photos.request();
      return status.isGranted;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      bool hasPermission = await _requestPermission(source);
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(source == ImageSource.camera ? 'Camera permission is required' : 'Gallery permission is required'),
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
        final savedPath = await _saveKitPhoto(image.path);
        setState(() {
          _kit = _kit.copyWith(imagePath: savedPath);
        });
        await _saveKit();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile picture updated'),
            backgroundColor: Color(0xFF7B6BA0),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: const Color(0xFFD44C47),
        ),
      );
    }
  }

  Future<String> _saveKitPhoto(String sourcePath) async {
    final directory = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(directory.path, 'rabbit_photos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final extension = p.extension(sourcePath).isNotEmpty ? p.extension(sourcePath) : '.jpg';
    final fileName = 'kit_${_kit.id}_${DateTime.now().millisecondsSinceEpoch}$extension';
    final savedFile = await File(sourcePath).copy(p.join(photosDir.path, fileName));
    return savedFile.path;
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
              'Change Profile Picture',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 20),
            _buildPhotoOption(
              icon: Icons.camera_alt,
              label: 'Take Photo',
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            _buildPhotoOption(
              icon: Icons.photo_library,
              label: 'Choose from Gallery',
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            if (_kit.imagePath != null && _kit.imagePath!.isNotEmpty)
              _buildPhotoOption(
                icon: Icons.delete_outline,
                label: 'Remove Photo',
                onTap: () async {
                  Navigator.pop(context);
                  setState(() {
                    _kit = Kit(
                      id: _kit.id,
                      sex: _kit.sex,
                      color: _kit.color,
                      weight: _kit.weight,
                      status: _kit.status,
                      details: _kit.details,
                      price: _kit.price,
                      imagePath: null,
                    );
                  });
                  await _saveKit();
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Profile picture removed'),
                      backgroundColor: Color(0xFF7B6BA0),
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
            Icon(icon, color: isDestructive ? const Color(0xFFD44C47) : const Color(0xFF787774), size: 22),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                  fontSize: 15,
                  color: isDestructive ? const Color(0xFFD44C47) : Colors.black87,
                )),
          ],
        ),
      ),
    );
  }

  // ==================== EDIT DIALOGS ====================

  void _showEditWeightDialog() {
    final controller = TextEditingController(text: _kit.weight > 0 ? _kit.weight.toString() : '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Weight', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Weight (${FormatUtils.weightUnit})',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 2),
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
              final val = double.tryParse(controller.text.trim());
              if (val != null && val >= 0) {
                Navigator.pop(ctx);
                setState(() {
                  _kit = _kit.copyWith(weight: val);
                });
                await _saveKit();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B6BA0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditDobDialog() {
    showDatePicker(
      context: context,
      initialDate: _litter.dob,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF7B6BA0),
              onPrimary: Colors.white,
              onSurface: Color(0xFF37352F),
            ),
          ),
          child: child!,
        );
      },
    ).then((picked) async {
      if (picked != null && picked != _litter.dob) {
        setState(() {
          _litter = _litter.copyWith(dob: picked);
        });
        await _saveLitter();
      }
    });
  }

  void _showEditBreedDialog() {
    final controller = TextEditingController(text: _litter.breed);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Breed', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Breed',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 2),
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
              if (val.isNotEmpty) {
                Navigator.pop(ctx);
                setState(() {
                  _litter = _litter.copyWith(breed: val);
                });
                await _saveLitter();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B6BA0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditColorDialog() {
    var controller = TextEditingController(text: _kit.color);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Color', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        content: Autocomplete<String>(
          optionsBuilder: (textEditingValue) {
            final colors = SettingsService.instance.colors;
            if (textEditingValue.text.isEmpty) return colors;
            return colors.where((c) => c.toLowerCase().contains(textEditingValue.text.toLowerCase()));
          },
          initialValue: controller.value,
          fieldViewBuilder: (ctx2, textController, focusNode, onSubmitted) {
            controller = textController;
            return TextField(
              controller: textController,
              focusNode: focusNode,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Color',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 2),
                ),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF787774))),
          ),
          ElevatedButton(
            onPressed: () async {
              final val = controller.text.trim();
              if (val.isNotEmpty) {
                Navigator.pop(ctx);
                setState(() {
                  _kit = _kit.copyWith(color: val);
                });
                await _saveKit();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7B6BA0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showEditSexDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
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
            const Text('Select Sex', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _buildSexOption('M', 'Male', Icons.male, const Color(0xFF2E7BB5)),
            _buildSexOption('F', 'Female', Icons.female, kFemaleColor),
            _buildSexOption('U', 'Unknown', Icons.help_outline, const Color(0xFF787774)),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSexOption(String value, String label, IconData icon, Color color) {
    final isSelected = _kit.sex == value;
    return InkWell(
      onTap: () async {
        Navigator.pop(context);
        if (_kit.sex != value) {
          setState(() {
            _kit = _kit.copyWith(sex: value);
          });
          await _saveKit();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        color: isSelected ? color.withOpacity(0.08) : null,
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 14),
            Text(label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? color : Colors.black87,
                )),
            const Spacer(),
            if (isSelected) Icon(Icons.check_circle, color: color, size: 20),
          ],
        ),
      ),
    );
  }

  // ==================== COLORS ====================

  Color get _sexColor {
    if (_kit.sex == 'M') return const Color(0xFF2E7BB5);
    if (_kit.sex == 'F') return const Color(0xFF9C6ADE);
    return const Color(0xFF787774);
  }

  Color get _sexBgColor {
    if (_kit.sex == 'M') return const Color(0xFFEBF8FF);
    if (_kit.sex == 'F') return const Color(0xFFF3E8FF);
    return const Color(0xFFF7F7F5);
  }

  String get _sexLabel {
    if (_kit.sex == 'M') return 'Male';
    if (_kit.sex == 'F') return 'Female';
    return 'Unknown';
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Nursing':
        return const Color(0xFF2E7BB5);
      case 'Weaned':
        return const Color(0xFF9C6ADE);
      case 'GrowOut':
        return const Color(0xFF459F89);
      case 'Mature':
        return const Color(0xFF7B6BA0);
      case 'Quarantine':
        return const Color(0xFFD97706);
      case 'Sold':
        return const Color(0xFF7B6BA0);
      case 'Butchered':
        return const Color(0xFF787774);
      case 'Dead':
        return const Color(0xFF37352F);
      default:
        return const Color(0xFF787774);
    }
  }

  Color _getStatusBgColor(String status) {
    switch (status) {
      case 'Nursing':
        return const Color(0xFFEBF8FF);
      case 'Weaned':
        return const Color(0xFFF3E8FF);
      case 'GrowOut':
        return const Color(0xFFF0ECFE);
      case 'Mature':
        return const Color(0xFFF0ECFE);
      case 'Quarantine':
        return const Color(0xFFFFF8E1);
      case 'Sold':
        return const Color(0xFFF0ECFE);
      case 'Butchered':
        return const Color(0xFFF1F1EF);
      case 'Dead':
        return const Color(0xFFF1F1EF);
      default:
        return const Color(0xFFF1F1EF);
    }
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF37352F)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_litter.id}-K-${_kit.id}',
          style: const TextStyle(
            color: Color(0xFF37352F),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeroSection(),
            _buildQuickStats(),
            _buildDetailSection(),
            _buildParentSection(),
            if (_weightHistory.isNotEmpty) _buildWeightHistory(),
            if (_kit.details != null && _kit.details!.isNotEmpty) _buildNotesSection(),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  // ==================== HERO SECTION ====================

  Widget _buildHeroSection() {
    final bool hasPhoto = _kit.imagePath != null && _kit.imagePath!.isNotEmpty;
    final String? photoPath = hasPhoto ? _kit.imagePath : null;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE9E9E7))),
      ),
      child: Row(
        children: [
          // Avatar with tap to change
          GestureDetector(
            onTap: _showImagePickerOptions,
            child: Stack(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _sexBgColor,
                    border: Border.all(color: _sexColor, width: 2),
                    image: hasPhoto && photoPath != null && File(photoPath).existsSync()
                        ? DecorationImage(
                            image: FileImage(File(photoPath)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: hasPhoto && photoPath != null && File(photoPath).existsSync() ? null : Icon(Icons.pets, size: 36, color: _sexColor),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF7B6BA0), width: 2),
                    ),
                    child: const Icon(Icons.camera_alt, size: 12, color: Color(0xFF7B6BA0)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _kit.color != 'Unknown' ? _kit.color : 'Kit ${_kit.id}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF37352F),
                  ),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    Text('#${_litter.id}-K-${_kit.id}', style: const TextStyle(fontSize: 13, color: Color(0xFF787774))),
                    const Text('•', style: TextStyle(color: Color(0xFF787774))),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _kit.sex == 'F'
                              ? Icons.female
                              : _kit.sex == 'M'
                                  ? Icons.male
                                  : Icons.help_outline,
                          size: 14,
                          color: _sexColor,
                        ),
                        const SizedBox(width: 4),
                        Text(_sexLabel,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _sexColor,
                            )),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildBadge(
                      _kit.status.toUpperCase(),
                      _getStatusBgColor(_kit.status),
                      _getStatusColor(_kit.status),
                    ),
                    _buildBadge(
                      _litter.location.isNotEmpty ? _litter.location : 'Unassigned',
                      const Color(0xFFF7F7F5),
                      const Color(0xFF787774),
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

  // ==================== QUICK STATS ====================

  Widget _buildQuickStats() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFAF8),
        border: Border(bottom: BorderSide(color: Color(0xFFE9E9E7))),
      ),
      child: Row(
        children: [
          _buildStatItem(
            Icons.cake_outlined,
            'Age',
            _litter.ageDisplay,
            onTap: _showEditDobDialog,
          ),
          _buildStatDivider(),
          _buildStatItem(
            Icons.scale,
            'Weight',
            '${_kit.weight} ${FormatUtils.weightUnit}',
            onTap: _showEditWeightDialog,
          ),
          _buildStatDivider(),
          _buildStatItem(
            Icons.biotech,
            'Breed',
            _litter.breed.length > 10 ? '${_litter.breed.substring(0, 10)}...' : _litter.breed,
            onTap: _showEditBreedDialog,
          ),
          _buildStatDivider(),
          _buildStatItem(
            Icons.inventory_2_outlined,
            'Litter',
            _litter.id,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, {VoidCallback? onTap}) {
    final child = Column(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF7B6BA0)),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: onTap != null ? const Color(0xFF7B6BA0) : const Color(0xFF37352F),
            ),
            textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9B9A97)), textAlign: TextAlign.center),
      ],
    );

    return Expanded(
      child: onTap != null
          ? InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: child,
              ),
            )
          : child,
    );
  }

  Widget _buildStatDivider() {
    return Container(width: 1, height: 36, color: const Color(0xFFE9E9E7));
  }

  // ==================== DETAIL SECTION ====================

  Widget _buildDetailSection() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE9E9E7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Kit Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF37352F))),
          const SizedBox(height: 16),
          _buildDetailRow('Kit ID', '${_litter.id}-K-${_kit.id}'),
          _buildEditableDetailRow('Sex', _sexLabel, _showEditSexDialog),
          _buildEditableDetailRow('Color', _kit.color, _showEditColorDialog),
          _buildEditableDetailRow('Weight', '${_kit.weight} ${FormatUtils.weightUnit}', _showEditWeightDialog),
          _buildDetailRow('Status', _kit.status),
          _buildEditableDetailRow('Date of Birth', _formatDate(_litter.dob), _showEditDobDialog),
          _buildDetailRow('Age', '${_litter.ageDays} days (${_litter.ageDisplay})'),
          _buildDetailRow('Location', _litter.location.isNotEmpty ? _litter.location : 'Not set'),
          if (_litter.cage.isNotEmpty) _buildDetailRow('Cage', _litter.cage),
          if (_kit.price != null) _buildDetailRow('Price', '\$${_kit.price!.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF9B9A97), fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF37352F), fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  Widget _buildEditableDetailRow(String label, String value, VoidCallback onEdit) {
    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              width: 120,
              child: Text(label, style: const TextStyle(fontSize: 13, color: Color(0xFF9B9A97), fontWeight: FontWeight.w500)),
            ),
            Expanded(
              child: Text(value, style: const TextStyle(fontSize: 14, color: Color(0xFF7B6BA0), fontWeight: FontWeight.w500)),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFFBFBFBD)),
          ],
        ),
      ),
    );
  }

  // ==================== PARENT SECTION ====================

  Widget _buildParentSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE9E9E7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Parentage & Litter', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF37352F))),
          const SizedBox(height: 16),
          _buildParentRow(
            icon: Icons.female,
            label: 'Dam',
            name: _litter.dam,
            id: _litter.doeId,
            color: const Color(0xFF9C6ADE),
            bgColor: const Color(0xFFF3E8FF),
          ),
          const SizedBox(height: 12),
          _buildParentRow(
            icon: Icons.male,
            label: 'Sire',
            name: _litter.sire,
            id: _litter.buckId,
            color: const Color(0xFF2E7BB5),
            bgColor: const Color(0xFFEBF8FF),
          ),
          const SizedBox(height: 16),
          // Litter info card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAF8),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined, size: 18, color: Color(0xFF7B6BA0)),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Litter ${_litter.id}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF37352F))),
                      const SizedBox(height: 2),
                      Text(
                        '${_litter.breed} • Born ${_formatDate(_litter.dob)} • ${_litter.totalKitsCount} live kits',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF787774)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Siblings
          if (_litter.kits.length > 1) ...[
            const SizedBox(height: 16),
            Text(
              'SIBLINGS (${_litter.kits.where((k) => k.id != _kit.id && !k.isArchived).length})',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF9B9A97), letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _litter.kits
                  .where((k) => k.id != _kit.id && !k.isArchived)
                  .map((sibling) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F7F5),
                          border: Border.all(color: const Color(0xFFE9E9E7)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.pets,
                                size: 12,
                                color: sibling.sex == 'M'
                                    ? const Color(0xFF2E7BB5)
                                    : sibling.sex == 'F'
                                        ? const Color(0xFF9C6ADE)
                                        : const Color(0xFF787774)),
                            const SizedBox(width: 6),
                            Text('K-${sibling.id}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Color(0xFF37352F))),
                            const SizedBox(width: 4),
                            Text(sibling.status, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _getStatusColor(sibling.status))),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParentRow({
    required IconData icon,
    required String label,
    required String name,
    required String id,
    required Color color,
    required Color bgColor,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF9B9A97), fontWeight: FontWeight.w500)),
            Text('$name ($id)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF37352F))),
          ],
        ),
      ],
    );
  }

  // ==================== WEIGHT HISTORY ====================

  Widget _buildWeightHistory() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE9E9E7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Weight History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF37352F))),
          const SizedBox(height: 12),
          ..._weightHistory.take(5).map((record) {
            final date = record['date'] as String? ?? '';
            final weight = (record['weight'] as num?)?.toDouble() ?? 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.scale, size: 14, color: Color(0xFF7B6BA0)),
                  const SizedBox(width: 8),
                  Text(
                    '${weight.toStringAsFixed(1)} ${FormatUtils.weightUnit}',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF37352F)),
                  ),
                  const Spacer(),
                  Text(
                    date.length >= 10 ? date.substring(0, 10) : date,
                    style: const TextStyle(fontSize: 12, color: Color(0xFF9B9A97)),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ==================== NOTES SECTION ====================

  Widget _buildNotesSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE9E9E7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Notes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF37352F))),
          const SizedBox(height: 8),
          Text(_kit.details!, style: const TextStyle(fontSize: 14, color: Color(0xFF787774), height: 1.5)),
        ],
      ),
    );
  }

  // ==================== HELPERS ====================

  Widget _buildBadge(String text, Color bg, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}/${date.year}';
  }
}
