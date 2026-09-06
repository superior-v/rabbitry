import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:typed_data';
import 'dart:io';
import '../models/rabbit.dart';
import '../services/database_service.dart';
import '../services/format_utils.dart';
import '../services/settings_service.dart';
import '../constants/app_colors.dart';

const String rabbitSvg = '''
<svg viewBox="0 0 24 24" fill="currentColor">
  <path d="M12 2c.55 0 1 .45 1 1v5c0 .55-.45 1-1 1s-1-.45-1-1V3c0-.55.45-1 1-1zm3 1c.55 0 1 .45 1 1v4c0 .55-.45 1-1 1s-1-.45-1-1V4c0-.55.45-1 1-1zm-6 7c-2.21 0-4 1.79-4 4 0 1.5.83 2.8 2.06 3.5-.06.16-.06.33-.06.5 0 .83.67 1.5 1.5 1.5h7c.83 0 1.5-.67 1.5-1.5 0-.17 0-.34-.06-.5 1.23-.7 2.06-2 2.06-3.5 0-2.21-1.79-4-4-4H9z"/>
</svg>
''';

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
                    label: const Text('Preview Certificate'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF4EBFE),
                      foregroundColor: const Color(0xFF7B6BA0),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
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

      final fontScript = await PdfGoogleFonts.greatVibesRegular();
      final fontBold = await PdfGoogleFonts.playfairDisplayBold();
      final fontLabel = await PdfGoogleFonts.latoRegular();

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

      Uint8List? templateBytes;
      try {
        final byteData = await rootBundle.load('assets/images/certificate_template1.png');
        templateBytes = byteData.buffer.asUint8List();
      } catch (e) {
        debugPrint('Certificate template1 asset not found: $e');
      }

      final name = widget.rabbit.name;
      final breed = widget.rabbit.breed;
      final sex = widget.rabbit.type == RabbitType.doe ? 'Doe' : 'Buck';
      final color = widget.rabbit.color ?? '';
      final dob = widget.rabbit.dateOfBirth != null
          ? FormatUtils.formatDate(widget.rabbit.dateOfBirth!)
          : 'N/A';
      final address = _settings.farmAddress;
      final sire = _sireName.isEmpty ? 'Unknown' : _sireName;
      final dam = _damName.isEmpty ? 'Unknown' : _damName;
      final ownerName = _settings.ownerName.isNotEmpty ? _settings.ownerName : 'Farm Owner';

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.letter.landscape,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context ctx) {
            final double W = PdfPageFormat.letter.landscape.width;
            final double H = PdfPageFormat.letter.landscape.height;
            final double valueFontSize = 13.5;
            final dynamicTextColor = const PdfColor(0.35, 0.35, 0.35); // Dark grey

            final Map<String, double> fieldYRatios = {
              'name': 0.3141,
              'breed': 0.3782,
              'color': 0.4457,
              'dob': 0.5184,
              'sex': 0.5914,
              'sire': 0.6625,
              'dam': 0.7346,
            };
            final double valueX = W * 0.70;

            final Map<String, String> fields = {
              'name': name.toUpperCase(),
              'breed': breed,
              'color': color.isEmpty ? 'N/A' : color,
              'dob': dob,
              'sex': sex,
              'sire': sire,
              'dam': dam,
            };

            return pw.Stack(
              children: [
                // Background template if loaded
                if (templateBytes != null)
                  pw.Positioned.fill(
                    child: pw.Image(
                      pw.MemoryImage(templateBytes),
                      fit: pw.BoxFit.fill,
                    ),
                  )
                else
                  pw.Positioned.fill(
                    child: pw.Container(
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        gradient: includeWatercolor
                            ? const pw.LinearGradient(
                                begin: pw.Alignment.topLeft,
                                end: pw.Alignment.bottomRight,
                                colors: [
                                  PdfColor(0.96, 0.94, 0.98),
                                  PdfColor(0.98, 0.96, 0.98),
                                  PdfColor(0.95, 0.93, 0.97),
                                ],
                              )
                            : null,
                      ),
                      child: pw.Padding(
                        padding: const pw.EdgeInsets.all(12),
                        child: pw.Container(
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: const PdfColor(0.2, 0.2, 0.2), width: 1.5),
                          ),
                          child: pw.Padding(
                            padding: const pw.EdgeInsets.all(8),
                            child: pw.Container(
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: const PdfColor(0.42, 0.38, 0.52), width: 3),
                                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                // Fallback static labels and titles (only drawn if template PNG is missing)
                if (templateBytes == null) ...[
                  // Cursive Farm Name
                  pw.Positioned(
                    left: 0,
                    right: 0,
                    top: 40,
                    child: pw.Text(
                      _settings.farmName,
                      style: pw.TextStyle(font: fontScript, fontSize: 36, color: const PdfColor(0.3, 0.3, 0.3)),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                  // Title Block
                  pw.Positioned(
                    left: (W - 300) / 2,
                    top: 90,
                    child: pw.SizedBox(
                      width: 300,
                      child: pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: const pw.BoxDecoration(
                          color: PdfColor(0.97, 0.91, 0.94),
                          borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
                        ),
                        child: pw.Text(
                          'CERTIFICATE OF BIRTH',
                          style: pw.TextStyle(
                            font: fontBold,
                            fontSize: 22,
                            letterSpacing: 2,
                            color: const PdfColor(0.42, 0.38, 0.52),
                          ),
                          textAlign: pw.TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  // Metadata pre-printed labels (fallback only — template PNG has these built-in)
                  pw.Positioned(
                    left: W * 0.55,
                    top: H * 0.305,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildFallbackLabelRow('Name',  fontLabel),
                        _buildFallbackLabelRow('Breed', fontLabel),
                        _buildFallbackLabelRow('Color', fontLabel),
                        _buildFallbackLabelRow('DOB',   fontLabel),
                        _buildFallbackLabelRow('Sex',   fontLabel),
                        _buildFallbackLabelRow('Sire',  fontLabel),
                        _buildFallbackLabelRow('Dam',   fontLabel),
                      ],
                    ),
                  ),
                  // Signature Block
                  pw.Positioned(
                    right: 50,
                    bottom: 40,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'I here certify all the above mentioned information',
                          style: pw.TextStyle(
                              font: fontLabel,
                              fontSize: 10,
                              color: const PdfColor(0.45, 0.45, 0.45),
                              fontStyle: pw.FontStyle.italic),
                        ),
                        pw.SizedBox(height: 6),
                        pw.Text(
                          ownerName,
                          style: pw.TextStyle(font: fontScript, fontSize: 24, color: const PdfColor(0.3, 0.3, 0.3)),
                        ),
                        pw.SizedBox(height: 4),
                        if (address.isNotEmpty)
                          pw.Text(
                            address,
                            style: pw.TextStyle(font: fontLabel, fontSize: 10, color: const PdfColor(0.45, 0.45, 0.45)),
                          ),
                        if (_settings.farmEmail.isNotEmpty)
                          pw.Text(
                            _settings.farmEmail,
                            style: pw.TextStyle(font: fontLabel, fontSize: 10, color: const PdfColor(0.45, 0.45, 0.45)),
                          ),
                      ],
                    ),
                  ),
                ],

                // Overlaid Dynamic Photo (perfectly nested inside the border)
                pw.Positioned(
                  left: W * 0.1593,
                  top: H * 0.3076,
                  child: pw.SizedBox(
                    width: W * 0.3703,
                    height: H * 0.3734,
                    child: rabbitPhotoBytes != null
                        ? pw.ClipRRect(
                            horizontalRadius: 10,
                            verticalRadius: 10,
                            child: pw.Image(pw.MemoryImage(rabbitPhotoBytes), fit: pw.BoxFit.cover),
                          )
                        : templateBytes == null
                            ? pw.Container(
                                decoration: const pw.BoxDecoration(
                                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(10)),
                                  color: PdfColor(0.92, 0.92, 0.92),
                                ),
                                child: pw.Center(
                                  child: pw.Text('🐰', style: pw.TextStyle(fontSize: 40)),
                                ),
                              )
                            : pw.SizedBox(),
                  ),
                ),

                // Values overlay — independently calibrated Y positions per field
                ...fields.entries.map((entry) {
                  final yRatio = fieldYRatios[entry.key] ?? 0.0;
                  return pw.Positioned(
                    left: valueX,
                    top: H * yRatio,
                    child: pw.Text(
                      entry.value,
                      style: pw.TextStyle(font: fontBold, fontSize: valueFontSize, color: dynamicTextColor),
                    ),
                  );
                }),
              ],
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

  /// Used only in the fallback PDF (no template PNG). Draws "Label:" text rows.
  pw.Widget _buildFallbackLabelRow(String label, pw.Font fontLabel) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 5.5),
      child: pw.Text(
        '$label:',
        style: pw.TextStyle(font: fontLabel, fontSize: 13, color: const PdfColor(0.35, 0.35, 0.35)),
      ),
    );
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

    // Prepared Strings
    final sex = widget.rabbit.type == RabbitType.doe ? 'Doe' : 'Buck';
    final color = widget.rabbit.color ?? '';
    final dob = widget.rabbit.dateOfBirth != null ? FormatUtils.formatDate(widget.rabbit.dateOfBirth!) : 'N/A';
    final sire = widget.sireName.isEmpty ? 'Unknown' : widget.sireName;
    final dam = widget.damName.isEmpty ? 'Unknown' : widget.damName;
    final ownerName = _settings.ownerName.isNotEmpty ? _settings.ownerName : 'Farm Owner';

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
                  // Certificate Double Border Preview Box
                  AspectRatio(
                    aspectRatio: 11 / 8.5,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: kNeutral300),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final W = constraints.maxWidth;
                          final H = constraints.maxHeight;
                          final valueFontSize = W * 0.024;
                          final dynamicTextColor = const Color(0xFF555555); // Dark grey

                          final Map<String, double> fieldYRatios = {
                            'name': 0.3141,
                            'breed': 0.3782,
                            'color': 0.4457,
                            'dob': 0.5184,
                            'sex': 0.5914,
                            'sire': 0.6625,
                            'dam': 0.7346,
                          };
                          final double valueX = W * 0.70;

                          final Map<String, String> fields = {
                            'name': widget.rabbit.name.toUpperCase(),
                            'breed': widget.rabbit.breed,
                            'color': color.isEmpty ? 'N/A' : color,
                            'dob': dob,
                            'sex': sex,
                            'sire': sire,
                            'dam': dam,
                          };

                          return Stack(
                            children: [
                              // Background Template Image
                              Positioned.fill(
                                child: Image.asset(
                                  'assets/images/certificate_template1.png',
                                  fit: BoxFit.fill,
                                  errorBuilder: (context, error, stackTrace) {
                                    // Fallback UI
                                    return Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        gradient: _includeWatercolor
                                            ? const LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  Color(0xFFF5F3FF),
                                                  Color(0xFFFCE7F3),
                                                  Color(0xFFEFF6FF),
                                                ],
                                              )
                                            : null,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: const Color(0xFF1F2937), width: 1.2),
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: const Color(0xFF7B5FA0), width: 2.2),
                                        ),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                          child: Column(
                                            children: [
                                              // Cursive Farm Name
                                              Text(
                                                _settings.farmName,
                                                style: const TextStyle(
                                                  fontFamily: 'serif',
                                                  fontSize: 22,
                                                  fontStyle: FontStyle.italic,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF5B4F73),
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                              const SizedBox(height: 6),
                                              // Title Block
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFFFDF2F8),
                                                  borderRadius: BorderRadius.circular(8),
                                                ),
                                                child: const Text(
                                                  'CERTIFICATE OF BIRTH',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 1.5,
                                                    color: Color(0xFF7B5FA0),
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),
                                              ),
                                              const SizedBox(height: 20),
                                              // Details Layout (Fallback)
                                              Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  // Photo
                                                  Expanded(
                                                    flex: 5,
                                                    child: Column(
                                                      children: [
                                                        if (_includePhoto && photoExists)
                                                          Container(
                                                            width: 110,
                                                            height: 90,
                                                            decoration: BoxDecoration(
                                                              borderRadius: BorderRadius.circular(10),
                                                              border: Border.all(color: const Color(0xFF1F2937), width: 1.2),
                                                              image: DecorationImage(
                                                                image: FileImage(File(photoPath!)),
                                                                fit: BoxFit.cover,
                                                              ),
                                                            ),
                                                          )
                                                        else if (_includePhoto)
                                                          Container(
                                                            width: 110,
                                                            height: 90,
                                                            decoration: BoxDecoration(
                                                              borderRadius: BorderRadius.circular(10),
                                                              border: Border.all(color: const Color(0xFF1F2937), width: 1.2),
                                                              color: kNeutral100,
                                                            ),
                                                            child: const Center(
                                                              child: Text('🐰', style: TextStyle(fontSize: 28)),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  // Metadata
                                                  Expanded(
                                                    flex: 6,
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        _buildPreviewDetailRow('Name', widget.rabbit.name),
                                                        _buildPreviewDetailRow('Breed', widget.rabbit.breed),
                                                        _buildPreviewDetailRow('Color', color.isEmpty ? 'N/A' : color),
                                                        _buildPreviewDetailRow('DOB', dob),
                                                        _buildPreviewDetailRow('Sex', sex),
                                                        _buildPreviewDetailRow('Sire', sire),
                                                        _buildPreviewDetailRow('Dam', dam),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const Spacer(),
                                              // Signature Block (Fallback)
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.end,
                                                children: [
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.end,
                                                    children: [
                                                      const Text(
                                                        'I here certify all the above mentioned information',
                                                        style: TextStyle(
                                                            fontSize: 8,
                                                            color: Color(0xFF6B7280),
                                                            fontStyle: FontStyle.italic),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        ownerName,
                                                        style: const TextStyle(
                                                          fontFamily: 'serif',
                                                          fontSize: 14,
                                                          fontStyle: FontStyle.italic,
                                                          fontWeight: FontWeight.bold,
                                                          color: Color(0xFF5B4F73),
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      if (_settings.farmAddress.isNotEmpty)
                                                        Text(
                                                          _settings.farmAddress,
                                                          style: const TextStyle(fontSize: 8, color: Color(0xFF6B7280)),
                                                        ),
                                                      if (_settings.farmEmail.isNotEmpty)
                                                        Text(
                                                          _settings.farmEmail,
                                                          style: const TextStyle(fontSize: 8, color: Color(0xFF6B7280)),
                                                        ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                              // Overlaid Dynamic Photo (centered inside the black frame)
                              Positioned(
                                left: W * 0.1593,
                                top: H * 0.3076,
                                width: W * 0.3703,
                                height: H * 0.3734,
                                child: _includePhoto && photoExists
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(W * 0.020),
                                        child: Image.file(
                                          File(photoPath!),
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : const SizedBox(),
                              ),

                              // Text Overlays — independently calibrated Y positions per field
                              ...fields.entries.map((entry) {
                                final yRatio = fieldYRatios[entry.key] ?? 0.0;
                                return Positioned(
                                  left: valueX,
                                  top: H * yRatio,
                                  child: Text(
                                    entry.value,
                                    style: GoogleFonts.playfairDisplay(
                                      fontSize: valueFontSize,
                                      fontWeight: FontWeight.w600,
                                      color: dynamicTextColor,
                                    ),
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                      ),
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
                        backgroundColor: const Color(0xFF7B6BA0),
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

  Widget _buildPreviewDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SvgPicture.string(
            rabbitSvg,
            width: 14,
            height: 14,
            colorFilter: const ColorFilter.mode(Color(0xFF7B5FA0), BlendMode.srcIn),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563), fontWeight: FontWeight.normal),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, color: Color(0xFF111827), fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
