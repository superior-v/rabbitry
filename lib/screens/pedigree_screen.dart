import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import '../models/pedigree.dart';
import '../models/rabbit.dart';
import '../services/database_service.dart';

class PedigreeScreen extends StatefulWidget {
  final String rabbitId;

  const PedigreeScreen({required this.rabbitId});

  @override
  _PedigreeScreenState createState() => _PedigreeScreenState();
}

class _PedigreeScreenState extends State<PedigreeScreen> {
  late PedigreeRabbit _rabbit;
  bool _isEditing = false;
  bool _isLoading = true;
  final DatabaseService _db = DatabaseService();
  final ImagePicker _imagePicker = ImagePicker();

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

  @override
  void initState() {
    super.initState();
    _loadPedigreeData();
  }

  Future<void> _loadPedigreeData() async {
    setState(() => _isLoading = true);
    try {
      final tree = await _db.buildPedigreeTree(widget.rabbitId, maxGenerations: 5);
      if (mounted) {
        setState(() {
          _rabbit = tree;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading pedigree: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Pedigree Chart',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isEditing ? Icons.check : Icons.edit,
              color: _isEditing ? Color(0xFF6366F1) : Colors.black87,
            ),
            onPressed: () {
              setState(() => _isEditing = !_isEditing);
            },
          ),
          PopupMenuButton<int>(
            icon: Icon(Icons.more_vert, color: Colors.black87),
            onSelected: (value) {
              if (value == 1) _sharePedigree();
              if (value == 2) _printPedigree();
              if (value == 3) _exportPDF();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                  value: 1,
                  child: Row(children: [
                    Icon(Icons.share, size: 18),
                    SizedBox(width: 8),
                    Text('Share')
                  ])),
              PopupMenuItem(
                  value: 2,
                  child: Row(children: [
                    Icon(Icons.print, size: 18),
                    SizedBox(width: 8),
                    Text('Print')
                  ])),
              PopupMenuItem(
                  value: 3,
                  child: Row(children: [
                    Icon(Icons.picture_as_pdf, size: 18),
                    SizedBox(width: 8),
                    Text('Export PDF')
                  ])),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: Color(0xFF6366F1)))
          : Column(
              children: [
                _buildGenerationSelector(),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildSubjectCard(),
                        SizedBox(height: 24),
                        _buildPedigreeTree(),
                        SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildGenerationSelector() {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFF7F7F5),
        border: Border(bottom: BorderSide(color: Color(0xFFE9E9E7))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Generations:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF787774),
            ),
          ),
          SizedBox(width: 12),
          ...List.generate(3, (index) {
            final gen = index + 3;
            final isActive = _generations == gen;
            return GestureDetector(
              onTap: () => setState(() => _generations = gen),
              child: Container(
                margin: EdgeInsets.only(right: 8),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isActive ? Color(0xFF6366F1) : Colors.white,
                  border: Border.all(
                    color: isActive ? Color(0xFF6366F1) : Color(0xFFE9E9E7),
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  gen.toString(),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isActive ? Colors.white : Color(0xFF787774),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSubjectCard() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF6366F1),
            Color(0xFF14B8A6)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _changeProfilePicture(_rabbit),
                child: Stack(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.2),
                        border: Border.all(color: Colors.white, width: 2),
                        image: _rabbit.profileImage != null
                            ? DecorationImage(
                                image: FileImage(File(_rabbit.profileImage!)),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _rabbit.profileImage == null
                          ? Icon(
                              _rabbit.sex == 'Buck' ? Icons.male : Icons.female,
                              color: Colors.white,
                              size: 36,
                            )
                          : null,
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
                          border: Border.all(color: Color(0xFF6366F1), width: 2),
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          size: 12,
                          color: Color(0xFF6366F1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _rabbit.name,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _rabbit.id,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          Divider(color: Colors.white.withOpacity(0.3), thickness: 1),
          SizedBox(height: 16),
          _buildSubjectInfoRow('Breed', _rabbit.breed ?? '-'),
          _buildSubjectInfoRow('Color', _rabbit.color ?? '-'),
          _buildSubjectInfoRow('Weight', _rabbit.weight ?? '-'),
          if (_rabbit.registrationNumber != null) _buildSubjectInfoRow('Registration', _rabbit.registrationNumber!),
        ],
      ),
    );
  }

  Widget _buildSubjectInfoRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPedigreeTree() {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16),
      height: 650,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Icon(Icons.account_tree, color: Color(0xFF6366F1), size: 20),
                SizedBox(width: 8),
                Text(
                  'Ancestry Tree',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: _buildTreeStructure(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTreeStructure() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          height: 600,
          child: Center(
            child: _buildTreeCard(_rabbit, isSubject: true),
          ),
        ),
        _buildConnectorLine(2),
        SizedBox(
          height: 600,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildTreeCard(_rabbit.sire, label: 'SIRE', childId: _rabbit.id, isSire: true),
              _buildTreeCard(_rabbit.dam, label: 'DAM', childId: _rabbit.id, isSire: false),
            ],
          ),
        ),
        if (_generations >= 2) ...[
          _buildConnectorLine(4),
          SizedBox(
            height: 600,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTreeCard(_rabbit.sire?.sire, label: 'SIRE', childId: _rabbit.sire?.id, isSire: true),
                _buildTreeCard(_rabbit.sire?.dam, label: 'DAM', childId: _rabbit.sire?.id, isSire: false),
                _buildTreeCard(_rabbit.dam?.sire, label: 'SIRE', childId: _rabbit.dam?.id, isSire: true),
                _buildTreeCard(_rabbit.dam?.dam, label: 'DAM', childId: _rabbit.dam?.id, isSire: false),
              ],
            ),
          ),
        ],
        if (_generations >= 3) ...[
          _buildConnectorLine(8),
          SizedBox(
            height: 600,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildTreeCard(_rabbit.sire?.sire?.sire, label: 'SIRE', isCompact: true, childId: _rabbit.sire?.sire?.id, isSire: true),
                _buildTreeCard(_rabbit.sire?.sire?.dam, label: 'DAM', isCompact: true, childId: _rabbit.sire?.sire?.id, isSire: false),
                _buildTreeCard(_rabbit.sire?.dam?.sire, label: 'SIRE', isCompact: true, childId: _rabbit.sire?.dam?.id, isSire: true),
                _buildTreeCard(_rabbit.sire?.dam?.dam, label: 'DAM', isCompact: true, childId: _rabbit.sire?.dam?.id, isSire: false),
                _buildTreeCard(_rabbit.dam?.sire?.sire, label: 'SIRE', isCompact: true, childId: _rabbit.dam?.sire?.id, isSire: true),
                _buildTreeCard(_rabbit.dam?.sire?.dam, label: 'DAM', isCompact: true, childId: _rabbit.dam?.sire?.id, isSire: false),
                _buildTreeCard(_rabbit.dam?.dam?.sire, label: 'SIRE', isCompact: true, childId: _rabbit.dam?.dam?.id, isSire: true),
                _buildTreeCard(_rabbit.dam?.dam?.dam, label: 'DAM', isCompact: true, childId: _rabbit.dam?.dam?.id, isSire: false),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildConnectorLine(int connections) {
    return CustomPaint(
      size: Size(50, 600),
      painter: TreeConnectorPainter(connections: connections),
    );
  }

  Widget _buildTreeCard(PedigreeRabbit? rabbit, {String? label, bool isSubject = false, bool isCompact = false, String? childId, bool? isSire}) {
    final isEmpty = rabbit == null || rabbit.name == 'Unknown';
    final cardWidth = isCompact ? 140.0 : (isSubject ? 200.0 : 180.0);
    final cardHeight = isCompact ? 58.0 : (isSubject ? 90.0 : 82.0);

    return GestureDetector(
      onTap: _isEditing && !isSubject ? () => _editAncestor(rabbit, childId, isSire ?? true) : null,
      onLongPress: !isSubject && !isEmpty ? () => _showAncestorMenu(rabbit) : null,
      child: Container(
        width: cardWidth,
        height: cardHeight,
        margin: EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: isEmpty ? Color(0xFFF7F7F5) : Colors.white,
          borderRadius: BorderRadius.circular(isCompact ? 8 : 12),
          border: Border.all(
            color: isSubject ? Color(0xFF6366F1) : (isEmpty ? Color(0xFFE9E9E7) : Color(0xFFE9E9E7)),
            width: isSubject ? 2 : 1,
          ),
          boxShadow: isSubject
              ? [
                  BoxShadow(
                    color: Color(0xFF6366F1).withOpacity(0.2),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isCompact ? 8 : 12),
          child: Stack(
            children: [
              Padding(
                padding: EdgeInsets.all(isCompact ? 8 : 10),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _isEditing && !isEmpty ? () => _changeProfilePicture(rabbit) : null,
                      child: Stack(
                        children: [
                          Container(
                            width: isCompact ? 36 : (isSubject ? 50 : 45),
                            height: isCompact ? 36 : (isSubject ? 50 : 45),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isEmpty ? Color(0xFFE9E9E7) : (rabbit.sex == 'Buck' ? Color(0xFFEBF8FF) : Color(0xFFF3E8FF)),
                              border: Border.all(
                                color: isEmpty ? Color(0xFFE9E9E7) : (rabbit.sex == 'Buck' ? Color(0xFF2E7BB5) : Color(0xFF9C6ADE)),
                                width: 2,
                              ),
                              image: !isEmpty && rabbit.profileImage != null
                                  ? DecorationImage(
                                      image: FileImage(File(rabbit.profileImage!)),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: !isEmpty && rabbit.profileImage == null
                                ? Icon(
                                    rabbit.sex == 'Buck' ? Icons.male : Icons.female,
                                    size: isCompact ? 18 : (isSubject ? 24 : 22),
                                    color: rabbit.sex == 'Buck' ? Color(0xFF2E7BB5) : Color(0xFF9C6ADE),
                                  )
                                : null,
                          ),
                          if (_isEditing && !isEmpty)
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: Color(0xFF6366F1),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 1.5),
                                ),
                                child: Icon(
                                  Icons.camera_alt,
                                  size: 9,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (label != null && !isSubject)
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              margin: EdgeInsets.only(bottom: 2),
                              decoration: BoxDecoration(
                                color: label == 'SIRE' ? Color(0xFFEBF8FF) : Color(0xFFF3E8FF),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                label,
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w700,
                                  color: label == 'SIRE' ? Color(0xFF2E7BB5) : Color(0xFF9C6ADE),
                                  letterSpacing: 0.5,
                                  height: 1.2,
                                ),
                              ),
                            ),
                          Text(
                            isEmpty ? 'Unknown' : rabbit.name,
                            style: TextStyle(
                              fontSize: isCompact ? 11 : (isSubject ? 14 : 12),
                              fontWeight: FontWeight.w700,
                              color: isEmpty ? Color(0xFF9B9A97) : Colors.black87,
                              height: 1.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (!isEmpty) ...[
                            SizedBox(height: 1),
                            Text(
                              rabbit.id,
                              style: TextStyle(
                                fontSize: isCompact ? 9 : 10,
                                color: Color(0xFF787774),
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (!isCompact && rabbit.breed != null) ...[
                              SizedBox(height: 1),
                              Text(
                                rabbit.breed!,
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Color(0xFF9B9A97),
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (_isEditing && !isSubject)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: Color(0xFF6366F1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isEmpty ? Icons.add : Icons.edit,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _changeProfilePicture(PedigreeRabbit rabbit) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    'Change Profile Picture',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            _buildPhotoOption(
              icon: Icons.camera_alt,
              label: 'Take Photo',
              onTap: () async {
                Navigator.pop(context);
                bool hasPermission = await _requestPermission(ImageSource.camera);
                if (hasPermission) {
                  await _pickImage(ImageSource.camera, rabbit);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Camera permission is required'),
                      backgroundColor: Color(0xFFD44C47),
                      action: SnackBarAction(
                        label: 'Settings',
                        textColor: Colors.white,
                        onPressed: () => openAppSettings(),
                      ),
                    ),
                  );
                }
              },
            ),
            _buildPhotoOption(
              icon: Icons.photo_library,
              label: 'Choose from Gallery',
              onTap: () async {
                Navigator.pop(context);
                bool hasPermission = await _requestPermission(ImageSource.gallery);
                if (hasPermission) {
                  await _pickImage(ImageSource.gallery, rabbit);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Gallery permission is required'),
                      backgroundColor: Color(0xFFD44C47),
                      action: SnackBarAction(
                        label: 'Settings',
                        textColor: Colors.white,
                        onPressed: () => openAppSettings(),
                      ),
                    ),
                  );
                }
              },
            ),
            if (rabbit.profileImage != null)
              _buildPhotoOption(
                icon: Icons.delete_outline,
                label: 'Remove Photo',
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    rabbit.updateProfileImage(null);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Profile picture removed'),
                      backgroundColor: Color(0xFF6366F1),
                    ),
                  );
                },
                isDestructive: true,
              ),
            SizedBox(height: 30),
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
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF7F7F5))),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Color(0xFFD44C47) : Color(0xFF787774),
              size: 22,
            ),
            SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: isDestructive ? Color(0xFFD44C47) : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source, PedigreeRabbit rabbit) async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

    if (image != null) {
      setState(() => _isLoading = true);
      try {
        final existing = await _db.getRabbit(rabbit.id);
        if (existing != null) {
          final updated = existing.copyWith(photos: [image.path]);
          await _db.updateRabbit(updated);
          await _loadPedigreeData();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profile picture updated successfully'), backgroundColor: Color(0xFF6366F1)));
        }
      } catch (e) {
        print('Error updating photo: $e');
        setState(() => _isLoading = false);
      }
    }
  } on PlatformException catch (e) {
      print('Platform Exception: ${e.code} - ${e.message}');

      String errorMessage = 'Failed to pick image';

      if (e.code == 'camera_access_denied') {
        errorMessage = 'Camera permission denied. Please enable it in settings.';
      } else if (e.code == 'photo_access_denied') {
        errorMessage = 'Photo library permission denied. Please enable it in settings.';
      } else if (e.message?.contains('channel') ?? false) {
        errorMessage = 'Camera/Gallery not available. Please check permissions.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Color(0xFFD44C47),
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.white,
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    } catch (e) {
      print('General Exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
          backgroundColor: Color(0xFFD44C47),
        ),
      );
    }
  }

  void _updateRabbitProfileImage(PedigreeRabbit rabbit, String? imagePath) {
    setState(() {
      rabbit.updateProfileImage(imagePath);
      // Force UI rebuild
    });

    // In production, save to database here
    // Example: _saveToDatabase(rabbit);
  }

  void _editAncestor(PedigreeRabbit? current, String? childId, bool isSire) {
    if (childId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot add parent to unknown child')));
      return;
    }

    final TextEditingController nameController = TextEditingController(text: (current != null && current.name != 'Unknown') ? current.name : '');
    final TextEditingController idController = TextEditingController(text: (current != null && current.name != 'Unknown') ? current.id : '');
    final TextEditingController breedController = TextEditingController(text: (current != null && current.name != 'Unknown') ? current.breed : '');
    final TextEditingController colorController = TextEditingController(text: (current != null && current.name != 'Unknown') ? current.color : '');
    final TextEditingController regController = TextEditingController(text: (current != null && current.name != 'Unknown') ? current.registrationNumber : '');

    bool isExternal = current?.isExternal ?? true;
    Rabbit? selectedHerdRabbit;
    List<Rabbit> herdOptions = [];
    bool optionsLoaded = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          if (!optionsLoaded) {
            _db.getAllRabbits().then((all) {
              if (mounted) {
                setModalState(() {
                  herdOptions = all.where((r) => (isSire ? r.type == RabbitType.buck : r.type == RabbitType.doe) && r.id != childId).toList();
                  optionsLoaded = true;
                });
              }
            });
          }

          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isEmpty(current) ? 'Add ${isSire ? 'Sire' : 'Dam'}' : 'Edit ${isSire ? 'Sire' : 'Dam'}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Color(0xFFF7F7F5), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        _buildTabButton('Search Herd', !isExternal, () => setModalState(() => isExternal = false)),
                        _buildTabButton('Manual Entry', isExternal, () => setModalState(() => isExternal = true)),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  if (!isExternal) ...[
                    Text('Select from Herd', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF787774))),
                    SizedBox(height: 6),
                    DropdownButtonFormField<Rabbit>(
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Color(0xFFF7F7F5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      hint: Text('Choose a rabbit'),
                      value: selectedHerdRabbit,
                      items: herdOptions.map((r) => DropdownMenuItem(value: r, child: Text('${r.name} (${r.id})'))).toList(),
                      onChanged: (val) {
                        setModalState(() {
                          selectedHerdRabbit = val;
                          if (val != null) {
                            nameController.text = val.name;
                            idController.text = val.id;
                            breedController.text = val.breed;
                            colorController.text = val.color ?? '';
                          }
                        });
                      },
                    ),
                    SizedBox(height: 16),
                  ],
                  _buildTextField('Name', nameController),
                  SizedBox(height: 12),
                  if (isExternal) ...[
                    _buildTextField('ID / Ear Tag', idController),
                    SizedBox(height: 12),
                  ],
                  _buildTextField('Breed', breedController),
                  SizedBox(height: 12),
                  _buildTextField('Color', colorController),
                  SizedBox(height: 12),
                  _buildTextField('Registration #', regController),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _saveAncestorUpdate(childId, isSire, isExternal, selectedHerdRabbit, nameController.text, idController.text, breedController.text, colorController.text, regController.text),
                      style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF6366F1), padding: EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool isEmpty(PedigreeRabbit? r) => r == null || r.name == 'Unknown';

  Widget _buildTabButton(String label, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isActive ? [BoxShadow(color: Colors.black12, blurRadius: 4)] : [],
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontWeight: isActive ? FontWeight.w600 : FontWeight.w400, color: isActive ? Color(0xFF6366F1) : Color(0xFF787774))),
        ),
      ),
    );
  }

  Future<void> _saveAncestorUpdate(String childId, bool isSire, bool isExternal, Rabbit? selectedHerd, String name, String id, String breed, String color, String reg) async {
    Navigator.pop(context);
    setState(() => _isLoading = true);

    try {
      String finalParentId = id;

      if (!isExternal && selectedHerd != null) {
        finalParentId = selectedHerd.id;
      } else if (isExternal) {
        // Create an external rabbit entry if it doesn't exist
        final existing = await _db.getRabbit(id);
        if (existing == null) {
          final newPedRabbit = Rabbit(
            id: id,
            name: name,
            type: RabbitType.pedigree,
            status: RabbitStatus.active,
            breed: breed,
            color: color,
            registrationNumber: reg,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await _db.insertRabbit(newPedRabbit);
        } else {
          // Update existing external rabbit
          final updated = existing.copyWith(name: name, breed: breed, color: color, registrationNumber: reg);
          await _db.updateRabbit(updated);
        }
      }

      // Link to child
      final child = await _db.getRabbit(childId);
      if (child != null) {
        final updatedChild = isSire ? child.copyWith(sireId: finalParentId) : child.copyWith(damId: finalParentId);
        await _db.updateRabbit(updatedChild);
      }

      await _loadPedigreeData();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pedigree updated successfully'), backgroundColor: Color(0xFF6366F1)));
    } catch (e) {
      print('Error updating ancestor: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update pedigree'), backgroundColor: Color(0xFFD44C47)));
    }
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF787774),
          ),
        ),
        SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter $label',
            filled: true,
            fillColor: Color(0xFFF7F7F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFFE9E9E7)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFFE9E9E7)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  void _showAncestorMenu(PedigreeRabbit? rabbit) {
    if (rabbit == null || rabbit.name == 'Unknown') return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rabbit.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      Text(rabbit.id, style: TextStyle(fontSize: 14, color: Color(0xFF787774))),
                    ],
                  ),
                  Spacer(),
                  IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            _buildMenuOption(Icons.camera_alt, 'Change Photo', () {
              Navigator.pop(context);
              _changeProfilePicture(rabbit);
            }),
            _buildMenuOption(Icons.delete_outline, 'Remove from Pedigree', () {
              Navigator.pop(context);
              _confirmRemoveAncestor(rabbit);
            }, isDestructive: true),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemoveAncestor(PedigreeRabbit rabbit) async {
    final all = await _db.getAllRabbits();
    final children = all.where((r) => r.sireId == rabbit.id || r.damId == rabbit.id).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Ancestor'),
        content: Text('Are you sure you want to remove ${rabbit.name} from the pedigree? This only removes the link, it doesn\'t delete the record.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              for (var child in children) {
                final updated = child.sireId == rabbit.id ? child.copyWith(sireId: '') : child.copyWith(damId: '');
                await _db.updateRabbit(updated);
              }
              await _loadPedigreeData();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Removed ${rabbit.name} from pedigree')));
            },
            child: Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuOption(IconData icon, String label, VoidCallback onTap, {bool isDestructive = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF7F7F5))),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Color(0xFFD44C47) : Color(0xFF787774),
              size: 22,
            ),
            SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: isDestructive ? Color(0xFFD44C47) : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sharePedigree() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Share pedigree feature coming soon')),
    );
  }

  void _printPedigree() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Print pedigree feature coming soon')),
    );
  }

  void _exportPDF() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Export PDF feature coming soon')),
    );
  }
}

class TreeConnectorPainter extends CustomPainter {
  final int connections;

  TreeConnectorPainter({required this.connections});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0xFFD1D5DB)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final centerY = size.height / 2;

    if (connections == 2) {
      final parent1Y = size.height * 0.25;
      final parent2Y = size.height * 0.75;

      canvas.drawLine(Offset(0, centerY), Offset(size.width / 2, centerY), paint);
      canvas.drawLine(Offset(size.width / 2, parent1Y), Offset(size.width / 2, parent2Y), paint);
      canvas.drawLine(Offset(size.width / 2, parent1Y), Offset(size.width, parent1Y), paint);
      canvas.drawLine(Offset(size.width / 2, parent2Y), Offset(size.width, parent2Y), paint);
    } else if (connections == 4) {
      final positions = [
        size.height * 0.125,
        size.height * 0.375,
        size.height * 0.625,
        size.height * 0.875,
      ];

      canvas.drawLine(Offset(0, positions[0]), Offset(0, positions[3]), paint);

      canvas.drawLine(Offset(0, positions[0]), Offset(size.width / 2, positions[0]), paint);
      canvas.drawLine(Offset(0, positions[1]), Offset(size.width / 2, positions[1]), paint);
      canvas.drawLine(Offset(size.width / 2, positions[0]), Offset(size.width / 2, positions[1]), paint);

      canvas.drawLine(Offset(0, positions[2]), Offset(size.width / 2, positions[2]), paint);
      canvas.drawLine(Offset(0, positions[3]), Offset(size.width / 2, positions[3]), paint);
      canvas.drawLine(Offset(size.width / 2, positions[2]), Offset(size.width / 2, positions[3]), paint);

      for (var y in positions) {
        canvas.drawLine(Offset(size.width / 2, y), Offset(size.width, y), paint);
      }
    } else if (connections == 8) {
      final positions = List.generate(8, (i) => size.height * ((i + 0.5) / 8));

      canvas.drawLine(Offset(0, positions.first), Offset(0, positions.last), paint);

      for (int group = 0; group < 4; group++) {
        final idx1 = group * 2;
        final idx2 = group * 2 + 1;

        canvas.drawLine(Offset(0, positions[idx1]), Offset(size.width / 2, positions[idx1]), paint);
        canvas.drawLine(Offset(0, positions[idx2]), Offset(size.width / 2, positions[idx2]), paint);
        canvas.drawLine(Offset(size.width / 2, positions[idx1]), Offset(size.width / 2, positions[idx2]), paint);

        canvas.drawLine(Offset(size.width / 2, positions[idx1]), Offset(size.width, positions[idx1]), paint);
        canvas.drawLine(Offset(size.width / 2, positions[idx2]), Offset(size.width, positions[idx2]), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
