import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/rabbit.dart';
import '../models/rabbit_document.dart';
import '../services/database_service.dart';
import '../constants/app_colors.dart';
import '../utils/toast_utils.dart';

// ─── Default folder definitions ──────────────────────────────
class _FolderDef {
  final String name;
  final Color bg;
  final Color icon;
  const _FolderDef({required this.name, required this.bg, required this.icon});
}

const _kDefaultFolders = [
  _FolderDef(name: 'Registration', bg: Color(0xFFFEF2F2), icon: Color(0xFFEF4444)),
  _FolderDef(name: 'Health',       bg: Color(0xFFFDF2F8), icon: Color(0xFFD4679A)),
  _FolderDef(name: 'Photos',       bg: Color(0xFFEFF6FF), icon: Color(0xFF3B82F6)),
  _FolderDef(name: 'Other',        bg: Color(0xFFF5F5F5), icon: Color(0xFF9CA3AF)),
];

// ─── Main widget ─────────────────────────────────────────────
class DocumentsCard extends StatefulWidget {
  final Rabbit rabbit;
  const DocumentsCard({Key? key, required this.rabbit}) : super(key: key);

  @override
  State<DocumentsCard> createState() => _DocumentsCardState();
}

class _DocumentsCardState extends State<DocumentsCard> {
  final DatabaseService _db = DatabaseService();

  List<RabbitDocument> _documents = [];
  List<String> _customFolderNames = []; // persisted via SharedPreferences
  bool _isLoading = true;

  // SharedPreferences key scoped to this rabbit
  String get _prefsKey => 'custom_folders_${widget.rabbit.id}';

  List<String> get _allFolderNames {
    final defaults = _kDefaultFolders.map((f) => f.name).toList();
    return [...defaults, ..._customFolderNames.where((c) => !defaults.contains(c))];
  }

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadDocuments(), _loadCustomFolders()]);
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _loadDocuments() async {
    final docs = await _db.getDocumentsByRabbit(widget.rabbit.id);
    if (mounted) setState(() => _documents = docs);
  }

  Future<void> _loadCustomFolders() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getStringList(_prefsKey) ?? [];
    if (mounted) setState(() => _customFolderNames = stored);
  }

  Future<void> _saveCustomFolders() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _customFolderNames);
  }

  _FolderDef _defForName(String name) {
    return _kDefaultFolders.firstWhere(
      (f) => f.name == name,
      orElse: () => _FolderDef(name: name, bg: const Color(0xFFF0F4FF), icon: kLilacDeep),
    );
  }

  Future<void> _saveFileToStorage(File sourceFile, String originalName, String folder) async {
    try {
      // Save directly to app's local documents directory
      final appDir = await getApplicationDocumentsDirectory();
      final docsDir = Directory(p.join(appDir.path, 'rabbit_documents', widget.rabbit.id, folder));
      if (!await docsDir.exists()) await docsDir.create(recursive: true);

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final ext = p.extension(originalName);
      final safeName = '${timestamp}$ext';
      final destPath = p.join(docsDir.path, safeName);

      // Use readAsBytes/writeAsBytes for more reliable cross-filesystem saving
      final bytes = await sourceFile.readAsBytes();
      await File(destPath).writeAsBytes(bytes);

      final doc = RabbitDocument(
        id: '${widget.rabbit.id}_$timestamp',
        rabbitId: widget.rabbit.id,
        name: originalName,
        filePath: destPath,
        fileType: _detectFileType(ext),
        fileSize: await File(destPath).length(),
        createdAt: DateTime.now().toIso8601String(),
        folder: folder,
      );

      if (widget.rabbit.id.trim().isEmpty) {
        if (mounted) {
          ToastUtils.showError(context, 'Error: Rabbit ID is missing. Please save the rabbit first.');
        }
        return;
      }

      await _db.insertDocument(doc);
      await _loadDocuments(); // refresh immediately

      if (mounted) {
        ToastUtils.showSuccess(context, 'Saved to $folder folder');
      }
    } catch (e) {
      print('Error saving file: $e');
      if (mounted) {
        ToastUtils.showError(context, 'Error saving file: $e');
      }
    }
  }

  String _detectFileType(String ext) {
    ext = ext.toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.webp'].contains(ext)) return 'image';
    if (ext == '.pdf') return 'pdf';
    return 'file';
  }

  Future<void> _deleteDoc(RabbitDocument doc) async {
    await _db.deleteDocument(doc.id);
    try { await File(doc.filePath).delete(); } catch (_) {}
    await _loadDocuments();
  }

  Future<void> _renameFolder(String oldName, String newName) async {
    if (newName.trim().isEmpty || newName.trim() == oldName) return;
    final trimmed = newName.trim();
    // Update all docs in that folder
    final toUpdate = _documents.where((d) => d.folder == oldName).toList();
    for (final doc in toUpdate) {
      await _db.updateDocument(doc.copyWith(folder: trimmed));
    }
    // Update custom folder name if it's a custom one
    final idx = _customFolderNames.indexOf(oldName);
    if (idx != -1) {
      setState(() => _customFolderNames[idx] = trimmed);
      await _saveCustomFolders();
    }
    await _loadDocuments();
  }

  void _openFolder(String folderName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _FolderDetailPage(
          folderName: folderName,
          folderDef: _defForName(folderName),
          rabbit: widget.rabbit,
          db: _db,
          onSaveFile: _saveFileToStorage,
          onDeleteDoc: _deleteDoc,
          onRenameFolder: (oldName, newName) async {
            await _renameFolder(oldName, newName);
          },
        ),
      ),
    ).then((_) => _loadAll()); // always refresh when coming back
  }

  void _showCreateFolderDialog() {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('New Folder', style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Folder name',
            filled: true,
            fillColor: kNeutral100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kLilacDeep,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final name = ctrl.text.trim();
              if (name.isNotEmpty && !_allFolderNames.contains(name)) {
                setState(() => _customFolderNames.add(name));
                await _saveCustomFolders();
              }
              Navigator.pop(context);
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: kPinkDeep));
    }

    final totalBytes = _documents.fold<int>(0, (sum, d) => sum + d.fileSize);
    final totalMB = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
    final allFolders = _allFolderNames;

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
          // ── Header ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(PhosphorIconsFill.folderSimple, size: 18, color: kNeutral500),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('DOCUMENTS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kNeutral500, letterSpacing: 0.6)),
                ),
                GestureDetector(
                  onTap: _showCreateFolderDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: kLilacWash, borderRadius: BorderRadius.circular(100)),
                    child: Row(
                      children: [
                        Icon(PhosphorIconsBold.folderPlus, size: 13, color: kLilacDeep),
                        const SizedBox(width: 4),
                        Text('New', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kLilacDeep)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Count row ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${_documents.length}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF1F2937), height: 1)),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text('files', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kNeutral500)),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: const Color(0xFFFDF2F8), borderRadius: BorderRadius.circular(100)),
                    child: Text('${allFolders.length} folders', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kPinkDeep)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Folder Grid – 4-column horizontal rows ────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: _buildFolderRows(allFolders),
            ),
          ),

          const SizedBox(height: 24),

          // ── Recent Files ──────────────────────────────────────
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text('Recent Files', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
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

          // ── Bottom Stats ──────────────────────────────────────
          Container(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: kNeutral100)), color: Color(0xFFFAFAFA)),
            child: Row(
              children: [
                _buildBottomStat('${allFolders.length}', 'FOLDERS'),
                _buildDivider(),
                _buildBottomStat('${_documents.length}', 'FILES'),
                _buildDivider(),
                _buildBottomStat(totalMB, 'MB TOTAL'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build rows of 4-column folder tiles
  List<Widget> _buildFolderRows(List<String> names) {
    final rows = <Widget>[];
    for (int i = 0; i < names.length; i += 4) {
      final chunk = names.sublist(i, (i + 4).clamp(0, names.length));
      rows.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              ...chunk.map((name) {
                final def = _defForName(name);
                final count = _documents.where((d) => d.folder == name).length;
                return Expanded(
                  child: _FolderTile(
                    name: name,
                    count: count,
                    bg: def.bg,
                    iconColor: def.icon,
                    onTap: () => _openFolder(name),
                  ),
                );
              }),
              // Fill remaining columns with empty space
              if (chunk.length < 4)
                ...List.generate(4 - chunk.length, (_) => const Expanded(child: SizedBox())),
            ],
          ),
        ),
      );
    }
    return rows;
  }

  Widget _buildFileListItem(RabbitDocument doc) {
    IconData iconData = PhosphorIconsFill.file;
    Color iconColor = kNeutral400;
    Color bgColor = kNeutral100;
    if (doc.fileType == 'pdf') {
      iconData = PhosphorIconsFill.filePdf; iconColor = const Color(0xFFEF4444); bgColor = const Color(0xFFFEF2F2);
    } else if (doc.fileType == 'image') {
      iconData = PhosphorIconsFill.fileImage; iconColor = const Color(0xFF3B82F6); bgColor = const Color(0xFFEFF6FF);
    }
    final date = DateTime.tryParse(doc.createdAt) ?? DateTime.now();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)), child: Icon(iconData, size: 20, color: iconColor)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text('${doc.folder} • ${doc.formattedSize} • ${DateFormat('MMM d, yyyy').format(date)}', style: TextStyle(fontSize: 12, color: kNeutral400)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomStat(String val, String label) {
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

  Widget _buildDivider() => Container(height: 30, width: 1, color: kNeutral100);
}

// ─── Folder tile (no edit icon here — edit is inside detail page) ──
class _FolderTile extends StatelessWidget {
  final String name;
  final int count;
  final Color bg;
  final Color iconColor;
  final VoidCallback onTap;

  const _FolderTile({required this.name, required this.count, required this.bg, required this.iconColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        decoration: BoxDecoration(color: bg.withOpacity(0.6), borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Icon(PhosphorIconsFill.folder, size: 28, color: iconColor),
            const SizedBox(height: 6),
            Text(
              name.length > 8 ? '${name.substring(0, 7)}.' : name,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text('($count)', style: TextStyle(fontSize: 10, color: kNeutral500, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ─── Folder Detail – Full Page ────────────────────────────────
class _FolderDetailPage extends StatefulWidget {
  final String folderName;
  final _FolderDef folderDef;
  final Rabbit rabbit;
  final DatabaseService db;
  final Future<void> Function(File, String, String) onSaveFile;
  final Future<void> Function(RabbitDocument) onDeleteDoc;
  final Future<void> Function(String, String) onRenameFolder;

  const _FolderDetailPage({
    required this.folderName,
    required this.folderDef,
    required this.rabbit,
    required this.db,
    required this.onSaveFile,
    required this.onDeleteDoc,
    required this.onRenameFolder,
  });

  @override
  State<_FolderDetailPage> createState() => _FolderDetailPageState();
}

class _FolderDetailPageState extends State<_FolderDetailPage> {
  final ImagePicker _imagePicker = ImagePicker();
  late String _folderName;
  List<RabbitDocument> _docs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _folderName = widget.folderName;
    _loadDocs();
  }

  Future<void> _loadDocs() async {
    final all = await widget.db.getDocumentsByRabbit(widget.rabbit.id);
    if (mounted) {
      setState(() {
        _docs = all.where((d) => d.folder == _folderName).toList();
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndSave(File file, String name) async {
    setState(() => _isLoading = true);
    await widget.onSaveFile(file, name, _folderName);
    await _loadDocs();
  }

  Future<void> _pickFromCamera() async {
    final XFile? photo = await _imagePicker.pickImage(source: ImageSource.camera, imageQuality: 85);
    if (photo != null) await _pickAndSave(File(photo.path), photo.name);
  }

  Future<void> _pickFromGallery() async {
    final XFile? photo = await _imagePicker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (photo != null) await _pickAndSave(File(photo.path), photo.name);
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      await _pickAndSave(File(result.files.single.path!), result.files.single.name);
    }
  }

  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 4, width: 40, margin: const EdgeInsets.only(top: 12, bottom: 8), decoration: BoxDecoration(color: kNeutral200, borderRadius: BorderRadius.circular(2))),
            ListTile(leading: Icon(PhosphorIconsBold.camera, color: kNeutral600), title: const Text('Take Photo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)), onTap: () { Navigator.pop(context); _pickFromCamera(); }),
            ListTile(leading: Icon(PhosphorIconsBold.image, color: kNeutral600), title: const Text('Choose from Gallery', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)), onTap: () { Navigator.pop(context); _pickFromGallery(); }),
            ListTile(leading: Icon(PhosphorIconsBold.file, color: kNeutral600), title: const Text('Choose File', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)), onTap: () { Navigator.pop(context); _pickFile(); }),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showRenameDialog() {
    final ctrl = TextEditingController(text: _folderName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Rename Folder', style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'New folder name',
            filled: true,
            fillColor: kNeutral100,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kLilacDeep, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
            onPressed: () async {
              final newName = ctrl.text.trim();
              Navigator.pop(context);
              if (newName.isNotEmpty && newName != _folderName) {
                await widget.onRenameFolder(_folderName, newName);
                setState(() => _folderName = newName);
                await _loadDocs();
              }
            },
            child: const Text('Rename'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final def = widget.folderDef;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(PhosphorIconsBold.arrowLeft, color: kNeutral800, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: def.bg, borderRadius: BorderRadius.circular(10)),
              child: Icon(PhosphorIconsFill.folder, size: 20, color: def.icon),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_folderName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1F2937))),
                  Text('${_docs.length} file${_docs.length == 1 ? '' : 's'}', style: TextStyle(fontSize: 12, color: kNeutral400)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // ✏️ Edit icon INSIDE the folder page header
          IconButton(
            tooltip: 'Rename folder',
            icon: Icon(PhosphorIconsBold.pencilSimple, size: 18, color: kNeutral500),
            onPressed: _showRenameDialog,
          ),
          // Upload button
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _showAddOptions,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(color: kLilacDeep, borderRadius: BorderRadius.circular(100)),
                child: Row(
                  children: [
                    const Icon(Icons.add, size: 16, color: Colors.white),
                    const SizedBox(width: 4),
                    const Text('Add File', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: kNeutral100, height: 1)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: kLilacDeep))
          : _docs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(PhosphorIconsFill.folder, size: 72, color: def.bg),
                      const SizedBox(height: 16),
                      Text('No files in $_folderName', style: const TextStyle(color: kNeutral400, fontSize: 15, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: _showAddOptions,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          decoration: BoxDecoration(color: kLilacWash, borderRadius: BorderRadius.circular(100)),
                          child: Text('Upload a File', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kLilacDeep)),
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: _docs.length,
                  itemBuilder: (_, i) => _buildDocItem(_docs[i]),
                ),
    );
  }

  Widget _buildDocItem(RabbitDocument doc) {
    IconData iconData; Color iconColor; Color bgColor;
    if (doc.fileType == 'pdf') {
      iconData = PhosphorIconsFill.filePdf; iconColor = const Color(0xFFEF4444); bgColor = const Color(0xFFFEF2F2);
    } else if (doc.fileType == 'image') {
      iconData = PhosphorIconsFill.fileImage; iconColor = const Color(0xFF3B82F6); bgColor = const Color(0xFFEFF6FF);
    } else {
      iconData = PhosphorIconsFill.file; iconColor = kNeutral400; bgColor = kNeutral100;
    }
    final date = DateTime.tryParse(doc.createdAt) ?? DateTime.now();
    final fileExists = File(doc.filePath).existsSync();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      child: Row(
        children: [
          // Image thumbnail or icon
          doc.fileType == 'image' && fileExists
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.file(File(doc.filePath), width: 48, height: 48, fit: BoxFit.cover),
                )
              : Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(10)),
                  child: Icon(iconData, size: 22, color: iconColor),
                ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doc.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1F2937)), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text('${doc.formattedSize} • ${DateFormat('MMM d, yyyy').format(date)}', style: TextStyle(fontSize: 12, color: kNeutral400)),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.more_horiz, color: kNeutral300),
            onPressed: () => _showDocOptions(doc),
          ),
        ],
      ),
    );
  }

  void _showDocOptions(RabbitDocument doc) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(height: 4, width: 40, margin: const EdgeInsets.only(top: 12, bottom: 8), decoration: BoxDecoration(color: kNeutral200, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(doc.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(PhosphorIconsBold.trash, color: Colors.red[400]),
              title: const Text('Delete', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await widget.onDeleteDoc(doc);
                setState(() => _docs.remove(doc));
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
