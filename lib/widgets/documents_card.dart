import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/rabbit.dart';
import '../models/rabbit_document.dart';
import '../services/database_service.dart';
import '../services/format_utils.dart';
import '../constants/app_colors.dart';

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

  Future<void> _saveFile(File sourceFile, String originalName) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final docsDir = Directory(p.join(appDir.path, 'rabbit_documents', widget.rabbit.id));
      if (!await docsDir.exists()) await docsDir.create(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final safeName = '${timestamp}_${originalName.replaceAll(RegExp(r'[^\w\.\-]'), '_')}';
      final destPath = p.join(docsDir.path, safeName);

      await sourceFile.copy(destPath);

      final doc = RabbitDocument(
        id: '${widget.rabbit.id}_$timestamp',
        rabbitId: widget.rabbit.id,
        name: originalName,
        filePath: destPath,
        fileType: _detectFileType(p.extension(originalName)),
        fileSize: await sourceFile.length(),
        createdAt: DateTime.now().toIso8601String(),
      );

      await _db.insertDocument(doc);
      await _loadDocuments();
    } catch (e) {
      print(e);
    }
  }

  String _detectFileType(String ext) {
    ext = ext.toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.webp'].contains(ext)) return 'image';
    if (ext == '.pdf') return 'pdf';
    return 'file';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: kPinkDeep));
    }

    // Counts for folders
    final imgCount = _documents.where((d) => d.fileType == 'image').length;
    final pdfCount = _documents.where((d) => d.fileType == 'pdf').length;
    final otherCount = _documents.where((d) => d.fileType == 'file').length;

    // MB total
    final totalBytes = _documents.fold<int>(0, (sum, d) => sum + d.fileSize);
    final totalMB = (totalBytes / (1024 * 1024)).toStringAsFixed(1);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kNeutral200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(PhosphorIconsFill.folderSimple, size: 18, color: kNeutral500),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'DOCUMENTS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: kNeutral500,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _showUploadBottomSheet,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kNeutral100,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      children: [
                        Icon(PhosphorIconsBold.uploadSimple, size: 14, color: kNeutral600),
                        const SizedBox(width: 4),
                        const Text(
                          'Upload',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: kNeutral600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Count Overview
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_documents.length}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                    height: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    'files',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: kNeutral500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDF2F8),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: const Text(
                      '4 folders',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: kPinkDeep,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Folder Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _buildFolderItem('Regist.', '(0)', const Color(0xFFFEF2F2), const Color(0xFFEF4444)),
                const SizedBox(width: 8),
                _buildFolderItem('Health', '($pdfCount)', const Color(0xFFFDF2F8), kPinkDeep),
                const SizedBox(width: 8),
                _buildFolderItem('Photos', '($imgCount)', const Color(0xFFEFF6FF), const Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                _buildFolderItem('Other', '($otherCount)', const Color(0xFFF5F5F5), kNeutral500),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Recent Files
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Recent Files',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF374151),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_documents.isEmpty)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: Text('No files yet', style: TextStyle(color: kNeutral400))),
            )
          else
            ..._documents.take(5).map((d) => _buildFileListItem(d)),

          const SizedBox(height: 12),

          // Bottom Stats Grid
          Container(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: kNeutral100)),
              color: Color(0xFFFAFAFA),
            ),
            child: Row(
              children: [
                _buildBottomStatItem('4', 'FOLDERS'),
                _buildDivider(),
                _buildBottomStatItem('${_documents.length}', 'FILES'),
                _buildDivider(),
                _buildBottomStatItem(totalMB, 'MB TOTAL'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFolderItem(String label, String count, Color bgColor, Color iconColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: bgColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(PhosphorIconsFill.folder, size: 24, color: iconColor),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
            ),
            Text(
              count,
              style: TextStyle(fontSize: 10, color: kNeutral500, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileListItem(RabbitDocument doc) {
    IconData iconData = PhosphorIconsFill.file;
    Color iconColor = kNeutral400;
    Color bgColor = kNeutral100;

    if (doc.fileType == 'pdf') {
      iconData = PhosphorIconsFill.filePdf;
      iconColor = const Color(0xFFEF4444);
      bgColor = const Color(0xFFFEF2F2);
    } else if (doc.fileType == 'image') {
      iconData = PhosphorIconsFill.fileImage;
      iconColor = const Color(0xFF3B82F6);
      bgColor = const Color(0xFFEFF6FF);
    }

    final date = DateTime.tryParse(doc.createdAt) ?? DateTime.now();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
            child: Icon(iconData, size: 20, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${doc.formattedSize} • ${DateFormat('MMM d, yyyy').format(date)}',
                  style: TextStyle(fontSize: 12, color: kNeutral400),
                ),
              ],
            ),
          ),
          Icon(Icons.more_horiz, size: 20, color: kNeutral300),
        ],
      ),
    );
  }

  Widget _buildBottomStatItem(String val, String label) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          children: [
            Text(val, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kNeutral400, letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(height: 30, width: 1, color: kNeutral100);
  }

  void _showUploadBottomSheet() {
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
            Container(height: 4, width: 40, margin: const EdgeInsets.only(top: 12, bottom: 8), decoration: BoxDecoration(color: kNeutral200, borderRadius: BorderRadius.circular(2))),
            _buildOption(PhosphorIconsBold.camera, 'Take Photo', _pickFromCamera),
            _buildOption(PhosphorIconsBold.image, 'Choose from Gallery', _pickFromGallery),
            _buildOption(PhosphorIconsBold.file, 'Choose File', _pickFile),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: kNeutral600),
      title: Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }

  Future<void> _pickFromCamera() async {
    final XFile? photo = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (photo != null) await _saveFile(File(photo.path), photo.name);
  }

  Future<void> _pickFromGallery() async {
    final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (image != null) await _saveFile(File(image.path), image.name);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      await _saveFile(File(result.files.single.path!), result.files.single.name);
    }
  }
}
