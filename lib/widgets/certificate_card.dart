import 'dart:io';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:printing/printing.dart';
import '../models/rabbit.dart';
import '../services/database_service.dart';
import '../services/format_utils.dart';
import '../services/settings_service.dart';
import '../services/certificate_pdf_service.dart';
import '../constants/app_colors.dart';
import 'certificate_layout.dart';

class CertificateCard extends StatefulWidget {
  final Rabbit rabbit;
  const CertificateCard({super.key, required this.rabbit});

  @override
  State<CertificateCard> createState() => _CertificateCardState();
}

class _CertificateCardState extends State<CertificateCard> {
  final DatabaseService _db = DatabaseService();

  Rabbit? _sire;
  Rabbit? _dam;
  bool _isLoadingParents = true;
  CertificateOption _selectedOption = CertificateOption.colorWithPhoto;

  @override
  void initState() {
    super.initState();
    _loadParents();
  }

  Future<void> _loadParents() async {
    try {
      Rabbit? sire;
      Rabbit? dam;

      if (widget.rabbit.sireId?.isNotEmpty ?? false) {
        sire = await _db.getRabbit(widget.rabbit.sireId!);
      }
      if (widget.rabbit.damId?.isNotEmpty ?? false) {
        dam = await _db.getRabbit(widget.rabbit.damId!);
      }

      if (mounted) {
        setState(() {
          _sire = sire;
          _dam = dam;
          _isLoadingParents = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingParents = false);
    }
  }

  Widget _buildToggleButton(String label, CertificateOption option) {
    final isSelected = _selectedOption == option;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedOption = option),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF5C4A70) : const Color(0xFF6B7280),
                height: 1.15,
              ),
            ),
          ),
        ),
      ),
    );
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
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'BIRTH CERTIFICATE',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF4F4F56),
                letterSpacing: 0.8,
              ),
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
                    color: Color(0xFF4F4F56),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                // 3 Options / Toggle Buttons
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E5EA)),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      _buildToggleButton('Black and White', CertificateOption.blackAndWhite),
                      _buildToggleButton('Color no Photo', CertificateOption.colorNoPhoto),
                      _buildToggleButton('Color with Photo', CertificateOption.colorWithPhoto),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoadingParents ? null : () => _showPreviewModal(context),
                    icon: Icon(
                      PhosphorIcons.fileText(PhosphorIconsStyle.duotone),
                      size: 18,
                      color: const Color(0xFF5C4A70),
                    ),
                    label: const Text(
                      'Preview Certificate',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF5C4A70),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4B3EE),
                      foregroundColor: const Color(0xFF5C4A70),
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
      builder: (ctx) => _CertificatePreviewModal(
        initialOption: _selectedOption,
        rabbit: widget.rabbit,
        sire: _sire,
        dam: _dam,
        onOptionChanged: (opt) {
          setState(() => _selectedOption = opt);
        },
      ),
    );
  }
}

class _CertificatePreviewModal extends StatefulWidget {
  final CertificateOption initialOption;
  final Rabbit rabbit;
  final Rabbit? sire;
  final Rabbit? dam;
  final ValueChanged<CertificateOption>? onOptionChanged;

  const _CertificatePreviewModal({
    required this.initialOption,
    required this.rabbit,
    this.sire,
    this.dam,
    this.onOptionChanged,
  });

  @override
  State<_CertificatePreviewModal> createState() => _CertificatePreviewModalState();
}

class _CertificatePreviewModalState extends State<_CertificatePreviewModal> {
  late CertificateOption _option;

  @override
  void initState() {
    super.initState();
    _option = widget.initialOption;
  }

  void _setOption(CertificateOption opt) {
    setState(() => _option = opt);
    widget.onOptionChanged?.call(opt);
  }

  String _fallbackDash(String? value) {
    if (value == null || value.trim().isEmpty || value.trim() == 'N/A') return '—';
    return value.trim();
  }

  CertificateData _buildData() {
    final rabbit = widget.rabbit;
    final sex = rabbit.type == RabbitType.buck ? 'Buck' : 'Doe';
    final dob = FormatUtils.formatCertificateDatePadded(rabbit.dateOfBirth);

    final sireName = widget.sire?.name.trim().isNotEmpty == true
        ? widget.sire!.name.trim()
        : (rabbit.sireId?.trim().isNotEmpty == true ? rabbit.sireId!.trim() : 'Unknown');

    final damName = widget.dam?.name.trim().isNotEmpty == true
        ? widget.dam!.name.trim()
        : (rabbit.damId?.trim().isNotEmpty == true ? rabbit.damId!.trim() : 'Unknown');

    final photo = rabbit.photos?.isNotEmpty == true ? rabbit.photos!.first : null;

    final location = (rabbit.location?.trim().isNotEmpty == true)
        ? rabbit.location!.trim()
        : SettingsService.instance.farmAddress.trim();

    return CertificateData(
      name: rabbit.name.trim().isNotEmpty ? rabbit.name.trim() : '—',
      breed: _fallbackDash(rabbit.breed),
      color: _fallbackDash(rabbit.color),
      dob: dob,
      sex: sex,
      damName: damName,
      sireName: sireName,
      location: location,
      photoPath: photo,
      option: _option,
    );
  }

  Widget _buildModalToggle(String label, CertificateOption opt) {
    final isSelected = _option == opt;
    return Expanded(
      child: GestureDetector(
        onTap: () => _setOption(opt),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF5C4A70) : const Color(0xFF6B7280),
                height: 1.15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final certData = _buildData();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: kNeutral300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Certificate Preview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: kNeutral900,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          // 3 Options inside preview modal
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E5EA)),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildModalToggle('Black and White', CertificateOption.blackAndWhite),
                  _buildModalToggle('Color no Photo', CertificateOption.colorNoPhoto),
                  _buildModalToggle('Color with Photo', CertificateOption.colorWithPhoto),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CertificatePreviewWidget(data: certData),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          final pdfBytes = await CertificatePdfService.generatePdf(certData);
                          final safeName = (widget.rabbit.name.trim().isNotEmpty ? widget.rabbit.name.trim() : 'Rabbit')
                              .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
                          await Printing.sharePdf(
                            bytes: pdfBytes,
                            filename: 'BirthCertificate_$safeName.pdf',
                          );
                        } catch (e) {
                          debugPrint('Error sharing Certificate PDF: $e');
                        }
                      },
                      icon: const Icon(Icons.download_rounded, size: 20),
                      label: const Text(
                        'Download & Share PDF',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7B6BA0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
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
}

// ─── WYSIWYG PREVIEW WIDGET ───────────────────────────────────────────────────

class CertificatePreviewWidget extends StatelessWidget {
  final CertificateData data;

  const CertificatePreviewWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final isColorWithPhoto = data.isColorWithPhoto;

    return AspectRatio(
      aspectRatio: isColorWithPhoto
          ? CertificateLayout.aspectRatioColorPhoto
          : CertificateLayout.aspectRatio,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kNeutral300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double W = constraints.maxWidth;
            final double H = constraints.maxHeight;

            if (isColorWithPhoto) {
              return _buildColorWithPhotoLayout(context, W, H);
            }
            return _buildStandardLayout(context, W, H);
          },
        ),
      ),
    );
  }

  // ─── COLOR WITH PHOTO LAYOUT (Matches reference PDF) ──────────────────────
  Widget _buildColorWithPhotoLayout(BuildContext context, double W, double H) {
    final hasPhotoFile = data.photoPath != null &&
        data.photoPath!.isNotEmpty &&
        File(data.photoPath!).existsSync();

    final scale = W / CertificateLayout.pageColorPhotoWidthPt;
    final detailsFontSize = W * CertificateLayout.detailsFontRatio;
    final detailsTextColor = CertificateLayout.colorDetailsPhoto;
    final detailsLeft = W * CertificateLayout.detailsLeftRatio;
    final rowWidth = W - detailsLeft - (24.0 * scale);

    return Stack(
      children: [
        // Layer 1: Background Template (Border, Title, Floral bouquet, Bunny icons)
        Positioned.fill(
          child: Image.asset(
            CertificateLayout.templateColorPhotoAsset,
            fit: BoxFit.fill,
          ),
        ),

        // Layer 2: Photo inside Rounded Rectangle Frame
        Positioned(
          left: W * CertificateLayout.photoLeftRatio,
          top: H * CertificateLayout.photoTopRatio,
          width: W * CertificateLayout.photoWidthRatio,
          height: H * CertificateLayout.photoHeightRatio,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(CertificateLayout.photoRadiusPt * scale),
              border: Border.all(
                color: CertificateLayout.colorPhotoFrameBorder,
                width: 2.0 * scale,
              ),
              color: const Color(0xFFF7F5FA),
            ),
            clipBehavior: Clip.antiAlias,
            child: hasPhotoFile
                ? Image.file(
                    File(data.photoPath!),
                    fit: BoxFit.cover,
                  )
                : Center(
                    child: Icon(
                      PhosphorIcons.rabbit(PhosphorIconsStyle.duotone),
                      size: 48.0 * scale,
                      color: const Color(0xFF9686BF).withValues(alpha: 0.6),
                    ),
                  ),
          ),
        ),

        // Layer 3: Row 1 - Name
        Positioned(
          left: detailsLeft,
          top: H * CertificateLayout.row1TopRatio,
          width: rowWidth,
          child: Text(
            'Name: ${data.name}',
            style: TextStyle(
              fontFamily: CertificateLayout.fontFamilyDetails,
              fontSize: detailsFontSize,
              fontWeight: FontWeight.w400,
              color: detailsTextColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Layer 4: Row 2 - Breed
        Positioned(
          left: detailsLeft,
          top: H * CertificateLayout.row2TopRatio,
          width: rowWidth,
          child: Text(
            'Breed: ${data.breed}',
            style: TextStyle(
              fontFamily: CertificateLayout.fontFamilyDetails,
              fontSize: detailsFontSize,
              fontWeight: FontWeight.w400,
              color: detailsTextColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Layer 5: Row 3 - Color
        Positioned(
          left: detailsLeft,
          top: H * CertificateLayout.row3TopRatio,
          width: rowWidth,
          child: Text(
            'Color: ${data.color}',
            style: TextStyle(
              fontFamily: CertificateLayout.fontFamilyDetails,
              fontSize: detailsFontSize,
              fontWeight: FontWeight.w400,
              color: detailsTextColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Layer 6: Row 4 - DOB
        Positioned(
          left: detailsLeft,
          top: H * CertificateLayout.row4TopRatio,
          width: rowWidth,
          child: Text(
            'DOB: ${data.dob}',
            style: TextStyle(
              fontFamily: CertificateLayout.fontFamilyDetails,
              fontSize: detailsFontSize,
              fontWeight: FontWeight.w400,
              color: detailsTextColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Layer 7: Row 5 - Sex
        Positioned(
          left: detailsLeft,
          top: H * CertificateLayout.row5TopRatio,
          width: rowWidth,
          child: Text(
            'Sex: ${data.sex}',
            style: TextStyle(
              fontFamily: CertificateLayout.fontFamilyDetails,
              fontSize: detailsFontSize,
              fontWeight: FontWeight.w400,
              color: detailsTextColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Layer 8: Row 6 - Dam X Sire
        Positioned(
          left: detailsLeft,
          top: H * CertificateLayout.row6TopRatio,
          width: rowWidth,
          child: Text(
            data.parentsSentence,
            style: TextStyle(
              fontFamily: CertificateLayout.fontFamilyDetails,
              fontSize: detailsFontSize,
              fontWeight: FontWeight.w400,
              color: detailsTextColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // ─── STANDARD LAYOUT (Black & White and Color no photo) ────────────────────
  Widget _buildStandardLayout(BuildContext context, double W, double H) {
    final isBw = data.isBlackAndWhite;
    final templateAsset = isBw
        ? CertificateLayout.templateBwAsset
        : CertificateLayout.templateColorAsset;

    final textColor = CertificateLayout.colorText;

    final double topCertifies = H * CertificateLayout.topRatioCertifies;
    final double fontSizeCertifies = W * CertificateLayout.fontRatioCertifies;

    final double topName = H * CertificateLayout.topRatioName;
    final double fontSizeName = W * CertificateLayout.fontRatioName;

    final double topBorn = H * CertificateLayout.topRatioBorn;
    final double fontSizeBorn = W * CertificateLayout.fontRatioBorn;

    final double topLocation = H * CertificateLayout.topRatioLocation;
    final double fontSizeLocation = W * CertificateLayout.fontRatioLocation;

    final double topGridRow1 = H * CertificateLayout.topRatioGridRow1;
    final double topGridRow2 = H * CertificateLayout.topRatioGridRow2;
    final double fontSizeGrid = W * CertificateLayout.fontRatioGrid;

    final double leftColX = W * CertificateLayout.gridLeftColRatio;
    final double rightColX = W * CertificateLayout.gridRightColRatio;
    final double colWidth = W * CertificateLayout.gridColWidthRatio;

    return Stack(
      children: [
        // Background Template
        Positioned.fill(
          child: Image.asset(
            templateAsset,
            fit: BoxFit.fill,
          ),
        ),

        // "This certifies that"
        Positioned(
          top: topCertifies,
          left: 0,
          right: 0,
          child: Text(
            'This certifies that',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: CertificateLayout.fontFamilyDetails,
              fontSize: fontSizeCertifies,
              fontWeight: FontWeight.w400,
              color: textColor,
            ),
          ),
        ),

        // Rabbit Name (Script font)
        Positioned(
          top: topName,
          left: 0,
          right: 0,
          child: Text(
            data.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: CertificateLayout.fontFamilyScript,
              fontSize: fontSizeName,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),

        // Birth Sentence ("a Holland Lop rabbit was born on Oct 10, 2026")
        Positioned(
          top: topBorn,
          left: 0,
          right: 0,
          child: Text(
            data.birthSentence,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: CertificateLayout.fontFamilyDetails,
              fontSize: fontSizeBorn,
              fontWeight: FontWeight.w400,
              color: textColor,
            ),
          ),
        ),

        // Location Sentence ("at Amaranth, Ontario Canada")
        Positioned(
          top: topLocation,
          left: 0,
          right: 0,
          child: Text(
            data.locationSentence,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: CertificateLayout.fontFamilyDetails,
              fontSize: fontSizeLocation,
              fontWeight: FontWeight.w400,
              color: textColor,
            ),
          ),
        ),

        // Bottom Details Grid - Row 1 (Color & Sex)
        Positioned(
          top: topGridRow1,
          left: leftColX,
          width: colWidth,
          child: _buildKeyValueRow(
            label: 'Color: ',
            value: data.color,
            fontSize: fontSizeGrid,
            textColor: textColor,
          ),
        ),
        Positioned(
          top: topGridRow1,
          left: rightColX,
          width: colWidth,
          child: _buildKeyValueRow(
            label: 'Sex: ',
            value: data.sex,
            fontSize: fontSizeGrid,
            textColor: textColor,
          ),
        ),

        // Bottom Details Grid - Row 2 (Sire & Dam)
        Positioned(
          top: topGridRow2,
          left: leftColX,
          width: colWidth,
          child: _buildKeyValueRow(
            label: 'Sire: ',
            value: data.sireName,
            fontSize: fontSizeGrid,
            textColor: textColor,
          ),
        ),
        Positioned(
          top: topGridRow2,
          left: rightColX,
          width: colWidth,
          child: _buildKeyValueRow(
            label: 'Dam: ',
            value: data.damName,
            fontSize: fontSizeGrid,
            textColor: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildKeyValueRow({
    required String label,
    required String value,
    required double fontSize,
    required Color textColor,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          label,
          style: TextStyle(
            fontFamily: CertificateLayout.fontFamilyDetails,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: TextStyle(
              fontFamily: CertificateLayout.fontFamilyDetails,
              fontSize: fontSize,
              fontWeight: FontWeight.w400,
              color: textColor,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }
}
