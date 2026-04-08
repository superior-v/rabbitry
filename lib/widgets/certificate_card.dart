import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'dart:io';
import '../models/rabbit.dart';
import '../services/database_service.dart';
import '../services/format_utils.dart';
import '../services/settings_service.dart';
import '../constants/app_colors.dart';

class CertificateCard extends StatefulWidget {
  final Rabbit rabbit;
  const CertificateCard({Key? key, required this.rabbit}) : super(key: key);

  @override
  State<CertificateCard> createState() => _CertificateCardState();
}

class _CertificateCardState extends State<CertificateCard> {
  final DatabaseService _db = DatabaseService();
  final SettingsService _settings = SettingsService.instance;
  String _sireName = '';
  String _damName = '';

  Color get _primaryColor =>
      widget.rabbit.type == RabbitType.buck ? kBlueDeep : kPinkDeep;

  @override
  void initState() {
    super.initState();
    _loadParentNames();
  }

  Future<void> _loadParentNames() async {
    try {
      if (widget.rabbit.sireId?.isNotEmpty ?? false) {
        final sire = await _db.getRabbit(widget.rabbit.sireId!);
        if (sire != null && mounted) setState(() => _sireName = sire.name);
      }
      if (widget.rabbit.damId?.isNotEmpty ?? false) {
        final dam = await _db.getRabbit(widget.rabbit.damId!);
        if (dam != null && mounted) setState(() => _damName = dam.name);
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kNeutral200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(
                  PhosphorIcons.certificate(PhosphorIconsStyle.duotone),
                  size: 20,
                  color: _primaryColor,
                ),
                const SizedBox(width: 10),
                const Text(
                  'BIRTH CERTIFICATE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1F2937),
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                const Text(
                  'Generate a printable birth certificate for this rabbit',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 13,
                      color: kNeutral500,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showPreviewModal(context),
                    icon: Icon(
                        PhosphorIcons.fileText(PhosphorIconsStyle.duotone),
                        size: 18),
                    label: const Text('Preview & Download'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kNeutral50,
                      foregroundColor: kNeutral700,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                        side: const BorderSide(color: kNeutral200),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPreviewModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CertificatePreviewSheet(
        rabbit: widget.rabbit,
        sireName: _sireName,
        damName: _damName,
        onDownload: (isPrint, includePhoto, includeWatercolor) =>
            _generateAndPrint(ctx, isPrint, includePhoto, includeWatercolor),
      ),
    );
  }

  Future<void> _generateAndPrint(
    BuildContext sheetContext,
    bool isPrint,
    bool includePhoto,
    bool includeWatercolor,
  ) async {
    Navigator.of(sheetContext).pop();

    try {
      final pdf = pw.Document(compress: false);

      final fontScript = await PdfGoogleFonts.caveatBold();
      final fontBold = await PdfGoogleFonts.latoBold();
      final fontRegular = await PdfGoogleFonts.latoRegular();

      Uint8List? rabbitPhotoBytes;
      if (includePhoto &&
          widget.rabbit.photos != null &&
          widget.rabbit.photos!.isNotEmpty) {
        final file = File(widget.rabbit.photos!.first);
        if (await file.exists()) {
          final data = await file.readAsBytes();
          rabbitPhotoBytes = Uint8List.fromList(data);
        }
      }

      Uint8List? farmLogoBytes;
      final logoPath = _settings.farmLogo;
      if (logoPath != null && logoPath.isNotEmpty) {
        final file = File(logoPath);
        if (await file.exists()) {
          final data = await file.readAsBytes();
          farmLogoBytes = Uint8List.fromList(data);
        }
      }

      final name = widget.rabbit.name;
      final breed = widget.rabbit.breed;
      final sex = widget.rabbit.type == RabbitType.doe ? 'Doe' : 'Buck';
      final color = widget.rabbit.color ?? '';
      final dob = widget.rabbit.dateOfBirth != null
          ? FormatUtils.formatDate(widget.rabbit.dateOfBirth!)
          : '';
      final address = _settings.farmAddress;
      final sire = _sireName.isEmpty ? 'Unknown' : _sireName;
      final dam = _damName.isEmpty ? 'Unknown' : _damName;

      pdf.addPage(
        pw.Page(
          // ✅ Letter size (8.5" x 11")
          pageFormat: PdfPageFormat.letter,
          margin: pw.EdgeInsets.zero, // We want the background to fill everything
          build: (pw.Context ctx) {
            return pw.Container(
              width: double.infinity,
              height: double.infinity,
              color: includeWatercolor ? const PdfColor(0.96, 0.94, 0.99) : PdfColors.white,
              child: pw.Padding(
                padding: const pw.EdgeInsets.all(40),
                child: pw.Container(
                  width: double.infinity,
                  height: double.infinity,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: const PdfColor(0.78, 0.74, 0.84), width: 1.5),
                  ),
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 50),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        if (farmLogoBytes != null) ...[
                          pw.Container(
                            height: 60,
                            child: pw.Image(pw.MemoryImage(farmLogoBytes), fit: pw.BoxFit.contain),
                          ),
                          pw.SizedBox(height: 12),
                        ],
                        pw.Text(_settings.farmName,
                            style: pw.TextStyle(font: fontScript, fontSize: 38, color: const PdfColor(0.42, 0.38, 0.52))),
                        pw.SizedBox(height: 15),
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 40, vertical: 12),
                          decoration: const pw.BoxDecoration(
                            color: PdfColor(0.91, 0.86, 0.97),
                            borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                          ),
                          child: pw.Text(
                            'CERTIFICATE OF BIRTH',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: 22,
                              letterSpacing: 3,
                              color: const PdfColor(0.52, 0.44, 0.66),
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 35),
                        if (rabbitPhotoBytes != null) ...[
                          pw.Container(
                            width: 170,
                            height: 150,
                            decoration: pw.BoxDecoration(
                              border: pw.Border.all(color: const PdfColor(0.78, 0.74, 0.84), width: 1.5),
                              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                            ),
                            child: pw.ClipRRect(
                              horizontalRadius: 6,
                              verticalRadius: 6,
                              child: pw.Image(pw.MemoryImage(rabbitPhotoBytes), fit: pw.BoxFit.cover),
                            ),
                          ),
                          pw.SizedBox(height: 30),
                        ] else ...[
                          pw.SizedBox(height: 8),
                        ],
                        pw.Text('This is to certify that',
                            style: pw.TextStyle(font: fontRegular, fontSize: 14, color: const PdfColor(0.45, 0.45, 0.45), fontStyle: pw.FontStyle.italic)),
                        pw.SizedBox(height: 16),
                        pw.Text(name.toUpperCase(),
                            style: pw.TextStyle(font: fontBold, fontSize: 34, letterSpacing: 2, color: PdfColors.black)),
                        pw.SizedBox(height: 14),
                        pw.Text('a $breed $sex' + (color.isNotEmpty ? ' in $color Color' : ''),
                            style: pw.TextStyle(font: fontRegular, fontSize: 16, color: const PdfColor(0.3, 0.3, 0.3))),
                        pw.SizedBox(height: 10),
                        pw.Text('was born to parents   $sire X $dam' + (dob.isNotEmpty ? ' on $dob' : ''),
                            style: pw.TextStyle(font: fontRegular, fontSize: 15, color: const PdfColor(0.35, 0.35, 0.35))),
                        pw.SizedBox(height: 10),
                        if (address.isNotEmpty)
                          pw.Text('In the city of $address',
                              style: pw.TextStyle(font: fontRegular, fontSize: 15, color: const PdfColor(0.35, 0.35, 0.35))),
                        pw.Spacer(),
                        pw.Text('Official Record Generated', 
                            style: pw.TextStyle(font: fontRegular, fontSize: 8, color: PdfColors.grey400)),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );

      final bytes = await pdf.save();
      await Printing.sharePdf(bytes: bytes, filename: 'BirthCertificate_${widget.rabbit.name}.pdf');
    } catch (e) {
      debugPrint('Certificate processing error: $e');
    }
  }
}

// ─── Preview Sheet ────────────────────────────────────────────────────────────

class _CertificatePreviewSheet extends StatefulWidget {
  final Rabbit rabbit;
  final String sireName;
  final String damName;
  final Function(bool isPrint, bool includePhoto, bool includeWatercolor)
      onDownload;

  const _CertificatePreviewSheet({
    required this.rabbit,
    required this.sireName,
    required this.damName,
    required this.onDownload,
  });

  @override
  State<_CertificatePreviewSheet> createState() =>
      _CertificatePreviewSheetState();
}

class _CertificatePreviewSheetState extends State<_CertificatePreviewSheet> {
  bool _includePhoto = true;
  bool _includeWatercolor = true;
  final SettingsService _settings = SettingsService.instance;

  @override
  Widget build(BuildContext context) {
    final bool hasPhoto = widget.rabbit.photos != null &&
        widget.rabbit.photos!.isNotEmpty;
    final String? photoPath = hasPhoto ? widget.rabbit.photos!.first : null;
    final bool photoExists =
        hasPhoto && photoPath != null && File(photoPath).existsSync();

    final logoPath = _settings.farmLogo;
    final bool hasLogo =
        logoPath != null && logoPath.isNotEmpty && File(logoPath).existsSync();

    final bgColor = _includeWatercolor ? const Color(0xFFF5F0FB) : Colors.white;

    // Prepared Strings
    final sex = widget.rabbit.type == RabbitType.doe ? 'Doe' : 'Buck';
    final color = widget.rabbit.color ?? '';
    final dob = widget.rabbit.dateOfBirth != null ? FormatUtils.formatDate(widget.rabbit.dateOfBirth!) : '';
    final sire = widget.sireName.isEmpty ? 'Unknown' : widget.sireName;
    final dam = widget.damName.isEmpty ? 'Unknown' : widget.damName;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
                color: kNeutral300, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Birth Certificate',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: kNeutral900)),
                IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close)),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Certificate Preview Box
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: const Color(0xFFCBC4D8), width: 1.2),
                    ),
                    child: Column(
                      children: [
                        if (hasLogo) ...[
                          Image.file(File(logoPath!),
                              height: 44, fit: BoxFit.contain),
                          const SizedBox(height: 10),
                        ],
                        Text(
                          _settings.farmName,
                          style: const TextStyle(
                            fontFamily: 'serif',
                            fontSize: 22,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w300,
                            color: Color(0xFF6B5F7E),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECE0F8),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'CERTIFICATE OF BIRTH',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.8,
                              color: Color(0xFF7B5FA0),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (_includePhoto && photoExists) ...[
                          Container(
                            width: 95,
                            height: 85,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: const Color(0xFFCBC4D8),
                                  width: 1.2),
                              image: DecorationImage(
                                image: FileImage(File(photoPath!)),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                        ] else if (_includePhoto) ...[
                          Container(
                            width: 90,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: kNeutral200),
                              color: kNeutral100,
                            ),
                            child: const Center(
                                child: Text('🐰',
                                    style: TextStyle(fontSize: 28))),
                          ),
                          const SizedBox(height: 16),
                        ],
                        const Text(
                          'This is to certify that',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF787774),
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.rabbit.name.toUpperCase(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF1F1F1F),
                            letterSpacing: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'a ${widget.rabbit.breed} $sex' + (color.isNotEmpty ? ' in $color Color' : ''),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF555555),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'was born to parents   $sire X $dam' + (dob.isNotEmpty ? ' on $dob' : ''),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF555555),
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_settings.farmAddress.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            'In the city of ${_settings.farmAddress}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF555555),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  _buildToggle('Include Photo', _includePhoto, (v) => setState(() => _includePhoto = v)),
                  _buildToggle('Watercolor Background', _includeWatercolor, (v) => setState(() => _includeWatercolor = v)),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => widget.onDownload(false, _includePhoto, _includeWatercolor),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kNeutral900,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: const Text('Download & Share PDF',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14)),
          Switch(value: value, onChanged: onChanged, activeColor: kPinkDeep),
        ],
      ),
    );
  }
}
