import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import '../models/rabbit.dart';
import '../models/rabbit_document.dart';
import '../services/database_service.dart';
import '../services/format_utils.dart';

class DocumentsCard extends StatefulWidget {
  final Rabbit rabbit;

  const DocumentsCard({Key? key, required this.rabbit}) : super(key: key);

  @override
  State<DocumentsCard> createState() => _DocumentsCardState();
}

class _DocumentsCardState extends State<DocumentsCard> {
  final DatabaseService _db = DatabaseService();
  final ImagePicker _imagePicker = ImagePicker();

  List<RabbitDocument> _documents = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    final docs = await _db.getDocumentsByRabbit(widget.rabbit.id);
    if (mounted) {
      setState(() {
        _documents = docs;
        _isLoading = false;
      });
    }
  }

  Future<String> _getDocumentsDir() async {
    final appDir = await getApplicationDocumentsDirectory();
    final docsDir = Directory(p.join(appDir.path, 'rabbit_documents', widget.rabbit.id));
    if (!await docsDir.exists()) {
      await docsDir.create(recursive: true);
    }
    return docsDir.path;
  }

  Future<void> _pickFromCamera() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
      );
      if (photo != null) {
        await _saveFile(File(photo.path), photo.name);
      }
    } catch (e) {
      _showError('Failed to take photo: $e');
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (image != null) {
        await _saveFile(File(image.path), image.name);
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles();
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        await _saveFile(file, result.files.single.name);
      }
    } catch (e) {
      _showError('Failed to pick file: $e');
    }
  }

  Future<void> _saveFile(File sourceFile, String originalName) async {
    try {
      final docsDir = await _getDocumentsDir();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeName = '${timestamp}_${originalName.replaceAll(RegExp(r'[^\w\.\-]'), '_')}';
      final destPath = p.join(docsDir, safeName);

      // Copy file to app storage
      await sourceFile.copy(destPath);

      final fileSize = await sourceFile.length();
      final ext = p.extension(originalName);
      final fileType = _detectFileType(ext);

      final doc = RabbitDocument(
        id: '${widget.rabbit.id}_$timestamp',
        rabbitId: widget.rabbit.id,
        name: originalName,
        filePath: destPath,
        fileType: fileType,
        fileSize: fileSize,
        createdAt: DateTime.now().toIso8601String(),
      );

      await _db.insertDocument(doc);
      await _loadDocuments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document uploaded successfully'),
            backgroundColor: Color(0xFF0F7B6C),
          ),
        );
      }
    } catch (e) {
      _showError('Failed to save file: $e');
    }
  }

  String _detectFileType(String ext) {
    ext = ext.toLowerCase();
    if ([
      '.jpg',
      '.jpeg',
      '.png',
      '.gif',
      '.bmp',
      '.webp',
      '.heic'
    ].contains(ext)) {
      return 'image';
    } else if (ext == '.pdf') {
      return 'pdf';
    } else {
      return 'file';
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _deleteDocument(RabbitDocument doc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Document'),
        content: Text('Are you sure you want to delete "${doc.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final file = File(doc.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}

      await _db.deleteDocument(doc.id);
      await _loadDocuments();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document deleted'),
            backgroundColor: Color(0xFF0F7B6C),
          ),
        );
      }
    }
  }

  Future<void> _renameDocument(RabbitDocument doc) async {
    final controller = TextEditingController(text: doc.name);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Rename Document'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Enter new name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text('Rename', style: TextStyle(color: Color(0xFF0F7B6C))),
          ),
        ],
      ),
    );

    if (newName != null && newName.isNotEmpty && newName != doc.name) {
      final updated = doc.copyWith(name: newName);
      await _db.updateDocument(updated);
      await _loadDocuments();
    }
  }

  void _viewDocument(RabbitDocument doc) {
    final file = File(doc.filePath);
    if (!file.existsSync()) {
      _showError('File not found');
      return;
    }

    if (doc.fileType == 'image') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _ImageViewerScreen(doc: doc),
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(doc.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Type: ${doc.fileType.toUpperCase()}'),
              SizedBox(height: 4),
              Text('Size: ${doc.formattedSize}'),
              SizedBox(height: 4),
              Text('Added: ${FormatUtils.formatDate(DateTime.parse(doc.createdAt))}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text('Close'),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _shareDocument(RabbitDocument doc) async {
    final file = File(doc.filePath);
    if (!file.existsSync()) {
      _showError('File not found');
      return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('File stored at: ${doc.filePath}'),
          backgroundColor: Color(0xFF0F7B6C),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFE9E9E7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFFF7F7F5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DOCUMENTS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF787774),
                    letterSpacing: 0.5,
                  ),
                ),
                GestureDetector(
                  onTap: () => _showUploadDialog(context),
                  child: Row(
                    children: [
                      Icon(Icons.upload_file, size: 16, color: Color(0xFF787774)),
                      SizedBox(width: 4),
                      Text(
                        'Upload',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF787774),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isLoading)
            Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF0F7B6C)),
                ),
              ),
            )
          else if (_documents.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No documents uploaded yet.\nTap Upload to add files.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF787774),
                  ),
                ),
              ),
            )
          else
            ..._documents.map((doc) => _buildDocumentItem(context, doc)),
        ],
      ),
    );
  }

  Widget _buildDocumentItem(BuildContext context, RabbitDocument doc) {
    IconData icon;
    Color color;
    switch (doc.fileType) {
      case 'image':
        icon = Icons.image;
        color = Color(0xFF0F7B6C);
        break;
      case 'pdf':
        icon = Icons.picture_as_pdf;
        color = Color(0xFFC47070);
        break;
      default:
        icon = Icons.insert_drive_file;
        color = Color(0xFF5B9BD5);
    }

    final dateStr = FormatUtils.formatDate(DateTime.parse(doc.createdAt));

    return InkWell(
      onTap: () => _viewDocument(doc),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF7F7F5))),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              clipBehavior: Clip.antiAlias,
              child: doc.fileType == 'image' && File(doc.filePath).existsSync()
                  ? Image.file(
                      File(doc.filePath),
                      fit: BoxFit.cover,
                      width: 40,
                      height: 40,
                      errorBuilder: (_, __, ___) => Icon(icon, color: color, size: 20),
                    )
                  : Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doc.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF37352F),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    '${doc.fileType.toUpperCase()} • ${doc.formattedSize}',
                    style: TextStyle(fontSize: 12, color: Color(0xFF787774)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 11, color: Color(0xFF9B9A97)),
                ),
                SizedBox(height: 4),
                GestureDetector(
                  onTap: () => _showDocumentOptions(context, doc),
                  child: Icon(Icons.more_vert, size: 16, color: Color(0xFF9B9A97)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showUploadDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Upload Document',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            _buildUploadOption(context, Icons.camera_alt, 'Take Photo', () {
              Navigator.pop(context);
              _pickFromCamera();
            }),
            _buildUploadOption(context, Icons.photo_library, 'Choose from Gallery', () {
              Navigator.pop(context);
              _pickFromGallery();
            }),
            _buildUploadOption(context, Icons.insert_drive_file, 'Choose File', () {
              Navigator.pop(context);
              _pickFile();
            }),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadOption(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: Color(0xFF787774), size: 24),
            SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(fontSize: 15, color: Color(0xFF37352F)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDocumentOptions(BuildContext context, RabbitDocument doc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      doc.name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            _buildDocOption(ctx, Icons.visibility, 'View', () => _viewDocument(doc)),
            _buildDocOption(ctx, Icons.share, 'Share', () => _shareDocument(doc)),
            _buildDocOption(ctx, Icons.edit, 'Rename', () => _renameDocument(doc)),
            Divider(),
            _buildDocOption(ctx, Icons.delete_outline, 'Delete', () => _deleteDocument(doc), isDestructive: true),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildDocOption(BuildContext context, IconData icon, String label, VoidCallback onTap, {bool isDestructive = false}) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Color(0xFFC47070) : Color(0xFF787774),
              size: 24,
            ),
            SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: isDestructive ? Color(0xFFC47070) : Color(0xFF37352F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen image viewer
class _ImageViewerScreen extends StatelessWidget {
  final RabbitDocument doc;

  const _ImageViewerScreen({required this.doc});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          doc.name,
          style: TextStyle(fontSize: 16),
        ),
      ),
      body: Center(
        child: InteractiveViewer(
          child: Image.file(
            File(doc.filePath),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.broken_image, size: 64, color: Colors.white54),
                SizedBox(height: 16),
                Text('Unable to load image', style: TextStyle(color: Colors.white54)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
