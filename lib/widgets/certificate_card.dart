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
  String _sireName = 'Unknown';
  String _damName = 'Unknown';

  // Theme Helpers
  Color get _primaryColor => widget.rabbit.type == RabbitType.buck ? kBlueDeep : kPinkDeep;

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
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Icon(PhosphorIcons.certificate(PhosphorIconsStyle.duotone), size: 20, color: _primaryColor),
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
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _showPreviewModal(context),
                    icon: Icon(PhosphorIcons.fileText(PhosphorIconsStyle.duotone), size: 18),
                    label: const Text('Preview Certificate'),
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

  Future<void> _showPreviewModal(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CertificatePreviewSheet(
        rabbit: widget.rabbit,
        sireName: _sireName,
        damName: _damName,
        onDownload: (isPrint, includePhoto) => _generateAndPrint(context, isPrint, includePhoto),
      ),
    );
  }

  Future<void> _generateAndPrint(BuildContext context, bool isPrint, bool includePhoto) async {
    Navigator.pop(context);
    
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.outfitBold();
    final fontRegular = await PdfGoogleFonts.outfitRegular();
    
    // Load Rabbit Photo
    Uint8List? rabbitPhotoBytes;
    if (includePhoto && widget.rabbit.photos != null && widget.rabbit.photos!.isNotEmpty) {
      final file = File(widget.rabbit.photos!.first);
      if (await file.exists()) {
        rabbitPhotoBytes = await file.readAsBytes();
      }
    }
    
    // Load Farm Logo
    Uint8List? farmLogoBytes;
    if (_settings.farmLogo != null) {
      final logoFile = File(_settings.farmLogo!);
      if (await logoFile.exists()) {
        farmLogoBytes = await logoFile.readAsBytes();
      }
    }
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.FullPage(
            ignoreMargins: true,
            child: pw.Container(
              padding: const pw.EdgeInsets.all(30),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(width: 12, color: PdfColors.black),
              ),
              child: pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(width: 2, color: PdfColors.black),
                ),
                padding: const pw.EdgeInsets.all(20),
                child: pw.Column(
                  children: [
                    // Header Logo
                    if (farmLogoBytes != null)
                      pw.Container(
                        height: 50,
                        margin: const pw.EdgeInsets.only(bottom: 10),
                        child: pw.Image(pw.MemoryImage(farmLogoBytes), fit: pw.BoxFit.contain),
                      ),
                    
                    pw.Text(_settings.farmName.toUpperCase(), 
                      style: pw.TextStyle(font: font, fontSize: 16, letterSpacing: 2, color: PdfColors.grey700)),
                    pw.SizedBox(height: 10),
                    
                    pw.Text('CERTIFICATE OF BIRTH',
                      style: pw.TextStyle(font: font, fontSize: 28, letterSpacing: 3, fontWeight: pw.FontWeight.bold)),
                    pw.SizedBox(height: 10),
                    pw.Container(height: 1.5, width: 180, color: PdfColors.black),
                    pw.SizedBox(height: 25),
                    
                    // Rabbit Image or Icon Container
                    pw.Container(
                      width: 140,
                      height: 140,
                      decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle,
                        border: pw.Border.all(color: PdfColors.grey300, width: 2),
                      ),
                      child: pw.ClipOval(
                        child: rabbitPhotoBytes != null 
                          ? pw.Image(pw.MemoryImage(rabbitPhotoBytes), fit: pw.BoxFit.cover)
                          : pw.Center(child: pw.Text('🐰', style: const pw.TextStyle(fontSize: 50))),
                      ),
                    ),
                    
                    pw.SizedBox(height: 25),
                    pw.Text('THIS IS TO CERTIFY THAT', 
                      style: pw.TextStyle(font: fontRegular, fontSize: 12, letterSpacing: 1, color: PdfColors.grey600)),
                    pw.SizedBox(height: 15),
                    pw.Text(widget.rabbit.name.toUpperCase(),
                      style: pw.TextStyle(font: font, fontSize: 38, color: PdfColors.black)),
                    pw.SizedBox(height: 8),
                    pw.Container(height: 0.5, width: 250, color: PdfColors.grey400),
                    pw.SizedBox(height: 25),
                    
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.center,
                      children: [
                        pw.Column(
                          children: [
                            pw.Text('BREED', style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey500)),
                            pw.Text(widget.rabbit.breed.toUpperCase(), style: pw.TextStyle(font: font, fontSize: 14)),
                          ],
                        ),
                        pw.SizedBox(width: 30),
                        pw.Column(
                          children: [
                            pw.Text('DATE OF BIRTH', style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey500)),
                            pw.Text(FormatUtils.formatDate(widget.rabbit.dateOfBirth ?? DateTime.now()).toUpperCase(), style: pw.TextStyle(font: font, fontSize: 14)),
                          ],
                        ),
                        pw.SizedBox(width: 30),
                        pw.Column(
                          children: [
                            pw.Text('SEX', style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey500)),
                            pw.Text(widget.rabbit.type == RabbitType.doe ? 'DOE' : 'BUCK', style: pw.TextStyle(font: font, fontSize: 14)),
                          ],
                        ),
                      ],
                    ),
                    
                    pw.SizedBox(height: 40),
                    pw.Text('LINEAGE', style: pw.TextStyle(font: font, fontSize: 10, letterSpacing: 2, color: PdfColors.grey600)),
                    pw.SizedBox(height: 15),
                    
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                      children: [
                        pw.Column(
                          children: [
                            pw.Text('SIRE', style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey500)),
                            pw.Text(_sireName.toUpperCase(), style: pw.TextStyle(font: font, fontSize: 16)),
                          ],
                        ),
                        pw.Column(
                          children: [
                            pw.Text('DAM', style: pw.TextStyle(font: fontRegular, fontSize: 9, color: PdfColors.grey500)),
                            pw.Text(_damName.toUpperCase(), style: pw.TextStyle(font: font, fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                    
                    pw.Spacer(),
                    pw.Text('OFFICIAL BIRTH RECORD GENERATED BY DYNASTY', 
                      style: pw.TextStyle(font: fontRegular, fontSize: 7, letterSpacing: 0.5, color: PdfColors.grey400)),
                    pw.SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );

    if (isPrint) {
      await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => pdf.save());
    } else {
      // For mobile "Download" feel, we use share which provides "Save to Files"
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'Certificate_${widget.rabbit.name}.pdf');
    }
  }
}

class _CertificatePreviewSheet extends StatefulWidget {
  final Rabbit rabbit;
  final String sireName;
  final String damName;
  final Function(bool isPrint, bool includePhoto) onDownload;

  const _CertificatePreviewSheet({
    required this.rabbit,
    required this.sireName,
    required this.damName,
    required this.onDownload,
  });

  @override
  State<_CertificatePreviewSheet> createState() => _CertificatePreviewSheetState();
}

class _CertificatePreviewSheetState extends State<_CertificatePreviewSheet> {
  bool _includePhoto = true;
  final SettingsService _settings = SettingsService.instance;

  @override
  Widget build(BuildContext context) {
    final bool hasPhoto = widget.rabbit.photos != null && widget.rabbit.photos!.isNotEmpty;
    final String? photoPath = hasPhoto ? widget.rabbit.photos!.first : null;
    final String? logoPath = _settings.farmLogo;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: kNeutral300, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Birth Certificate', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: kNeutral900)),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
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
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kNeutral900, width: 1.5),
                    ),
                    child: Column(
                      children: [
                        if (logoPath != null && File(logoPath).existsSync())
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Image.file(File(logoPath), height: 32, fit: BoxFit.contain),
                          ),
                        Text(_settings.farmName.toUpperCase(), 
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: kNeutral500)),
                        const SizedBox(height: 8),
                        const Text(
                          'CERTIFICATE OF BIRTH',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: kNeutral900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Rabbit Image in Preview
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: kNeutral200, width: 1),
                            image: (hasPhoto && photoPath != null && File(photoPath).existsSync())
                                ? DecorationImage(image: FileImage(File(photoPath)), fit: BoxFit.cover)
                                : null,
                          ),
                          child: (hasPhoto && photoPath != null && File(photoPath).existsSync())
                              ? null
                              : const Center(child: Text('🐰', style: TextStyle(fontSize: 32))),
                        ),
                        
                        const SizedBox(height: 12),
                        const Text('This certifies that', style: TextStyle(fontSize: 12, color: kNeutral500, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.only(bottom: 2),
                          decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kNeutral900, width: 1.5))),
                          child: Text(
                            widget.rabbit.name.toUpperCase(),
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kNeutral900),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Born ${FormatUtils.formatDate(widget.rabbit.dateOfBirth ?? DateTime.now())}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kNeutral900),
                        ),
                        Text(
                          '${widget.rabbit.breed} • ${widget.rabbit.color ?? "--"} • ${widget.rabbit.type == RabbitType.doe ? "Doe" : "Buck"}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: kNeutral500),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: kNeutral50, borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('SIRE', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kNeutral400, letterSpacing: 0.5)),
                                    Text(widget.sireName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kNeutral800)),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('DAM', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kNeutral400, letterSpacing: 0.5)),
                                    Text(widget.damName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kNeutral800)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),
                  
                  // Options
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('OPTIONS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kNeutral500, letterSpacing: 0.5)),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Include Photo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: kNeutral800)),
                        Switch(
                          value: _includePhoto,
                          onChanged: (v) => setState(() => _includePhoto = v),
                          activeColor: Colors.white,
                          activeTrackColor: kPinkDeep,
                          inactiveThumbColor: Colors.white,
                          inactiveTrackColor: kNeutral300,
                          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => widget.onDownload(false, _includePhoto),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kNeutral900,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: const Text('Download PDF', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: kNeutral200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          onPressed: () => widget.onDownload(true, _includePhoto),
                          icon: Icon(PhosphorIcons.printer(PhosphorIconsStyle.fill), size: 20),
                          padding: const EdgeInsets.all(14),
                          color: kNeutral700,
                        ),
                      ),
                    ],
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
}
