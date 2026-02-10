import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../models/rabbit.dart';
import '../models/breed.dart';
import '../services/database_service.dart';

class AddRabbitScreen extends StatefulWidget {
  const AddRabbitScreen({Key? key}) : super(key: key);

  @override
  State<AddRabbitScreen> createState() => _AddRabbitScreenState();
}

class _AddRabbitScreenState extends State<AddRabbitScreen> {
  final DatabaseService _db = DatabaseService();
  final ImagePicker _imagePicker = ImagePicker();

  // Form controllers
  final TextEditingController _idController = TextEditingController(text: 'D-117');
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _breedController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();

  RabbitType _selectedType = RabbitType.doe;
  RabbitStatus _selectedStatus = RabbitStatus.open;
  String? _selectedLocation;
  String? _selectedCage;
  DateTime? _dateOfBirth;
  String? _profileImagePath; // ✅ ADD THIS
  bool _isSaving = false;
  List<Breed> _availableBreeds = [];
  String? _autoGenetics;

  @override
  void initState() {
    super.initState();
    _loadBreeds();
  }

  Future<void> _loadBreeds() async {
    final breeds = await _db.getAllBreeds();
    if (mounted) {
      setState(() => _availableBreeds = breeds);
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _breedController.dispose();
    _colorController.dispose();
    _weightController.dispose();
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
        title: const Text(
          'Add New Rabbit',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w700),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveRabbit,
            child: Text(
              'SAVE',
              style: TextStyle(
                color: _isSaving ? Colors.grey : const Color(0xFF0F7B6C),
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
            // ✅ ADD THIS: Profile Picture Section
            _buildProfilePictureSection(),
            const SizedBox(height: 24),

            // Rabbit Type
            const Text(
              'Rabbit Type',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildTypeButton(
                    type: RabbitType.doe,
                    label: 'Doe',
                    icon: Icons.female,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTypeButton(
                    type: RabbitType.buck,
                    label: 'Buck',
                    icon: Icons.male,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Rabbit ID
            _buildTextField(
              controller: _idController,
              label: 'Rabbit ID',
              icon: Icons.tag,
              readOnly: false,
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

            // Breed - Dropdown from DB with fallback to free text
            const Text(
              'Breed *',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildBreedSelector(),
            // Show auto-filled genetics if available
            if (_autoGenetics != null && _autoGenetics!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F7F6),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF0F7B6C).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.science_outlined, size: 16, color: Color(0xFF0F7B6C)),
                    const SizedBox(width: 8),
                    Text(
                      'Genotype: $_autoGenetics',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF0F7B6C),
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // Status
            const Text(
              'Status',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildStatusDropdown(),
            const SizedBox(height: 16),

            // Location
            const Text(
              'Location',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildLocationDropdown(),
            const SizedBox(height: 16),

            // Cage
            const Text(
              'Cage',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildCageDropdown(),
            const SizedBox(height: 16),

            // Date of Birth
            _buildDateField(),
            const SizedBox(height: 16),

            // Color
            _buildTextField(
              controller: _colorController,
              label: 'Color',
              icon: Icons.palette,
              hint: 'e.g., White, Black',
            ),
            const SizedBox(height: 16),

            // Weight
            _buildTextField(
              controller: _weightController,
              label: 'Weight (lbs)',
              icon: Icons.monitor_weight,
              hint: '0.0',
              keyboardType: TextInputType.number,
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
                      color: const Color(0xFF0F7B6C),
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
                      color: const Color(0xFF0F7B6C),
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
                color: Color(0xFF0F7B6C),
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
      onTap: () => setState(() => _selectedType = type),
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
                fontSize: 15,
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
            prefixIcon: const Icon(Icons.category, color: Color(0xFF787774)),
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
              borderSide: const BorderSide(color: Color(0xFF0F7B6C), width: 2),
            ),
          ),
        );
      },
      onSelected: (String breedName) {
        _breedController.text = breedName;
        // Auto-fill genetics from matched breed
        final matched = _availableBreeds.where((b) => b.name == breedName);
        if (matched.isNotEmpty) {
          setState(() => _autoGenetics = matched.first.genetics.join(', '));
        }
      },
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool readOnly = false,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF787774)),
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
          borderSide: const BorderSide(color: Color(0xFF0F7B6C), width: 2),
        ),
      ),
    );
  }

  Widget _buildStatusDropdown() {
    return DropdownButtonFormField<RabbitStatus>(
      value: _selectedStatus,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.info_outline, color: Color(0xFF787774)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
        ),
      ),
      items: [
        RabbitStatus.open,
        RabbitStatus.growout,
      ].map((status) {
        return DropdownMenuItem(
          value: status,
          child: Text(status == RabbitStatus.open ? 'Open' : 'Growout'),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedStatus = value!),
    );
  }

  Widget _buildLocationDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedLocation,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.location_on, color: Color(0xFF787774)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
        ),
      ),
      hint: const Text('Select Location'),
      items: [
        'Barn A',
        'Barn B',
        'Quarantine'
      ].map((location) {
        return DropdownMenuItem(value: location, child: Text(location));
      }).toList(),
      onChanged: (value) => setState(() => _selectedLocation = value),
    );
  }

  Widget _buildCageDropdown() {
    return DropdownButtonFormField<String>(
      value: _selectedCage,
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.home, color: Color(0xFF787774)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE9E9E7)),
        ),
      ),
      hint: const Text('Select Cage'),
      items: [
        'Cage 1',
        'Cage 2',
        'Cage 3'
      ].map((cage) {
        return DropdownMenuItem(value: cage, child: Text(cage));
      }).toList(),
      onChanged: (value) => setState(() => _selectedCage = value),
    );
  }

  Widget _buildDateField() {
    return InkWell(
      onTap: () async {
        final date = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
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
            const Icon(Icons.cake, color: Color(0xFF787774)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Date of Birth',
                    style: TextStyle(fontSize: 12, color: Color(0xFF787774)),
                  ),
                  Text(
                    _dateOfBirth != null ? '${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}' : 'Not set',
                    style: const TextStyle(fontSize: 15, color: Colors.black87),
                  ),
                ],
              ),
            ),
            const Icon(Icons.calendar_today, color: Color(0xFF787774), size: 20),
          ],
        ),
      ),
    );
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
      final rabbit = Rabbit(
        id: _idController.text,
        name: _nameController.text,
        type: _selectedType,
        status: _selectedStatus,
        breed: _breedController.text,
        location: _selectedLocation,
        cage: _selectedCage,
        dateOfBirth: _dateOfBirth,
        color: _colorController.text.isEmpty ? null : _colorController.text,
        weight: _weightController.text.isEmpty ? null : double.tryParse(_weightController.text),
        genetics: _autoGenetics,
        photos: _profileImagePath != null
            ? [
                _profileImagePath!
              ]
            : null, // ✅ ADD THIS
      );

      await _db.insertRabbit(rabbit);

      Navigator.pop(context, true);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${rabbit.name} added successfully'),
          backgroundColor: const Color(0xFF0F7B6C),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: const Color(0xFFD44C47)),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }
}
