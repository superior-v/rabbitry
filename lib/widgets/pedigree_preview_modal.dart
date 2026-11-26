import '../services/appearance_service.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../services/pedigree_pdf_service.dart';
import '../models/pedigree.dart';
import 'pedigree_layout.dart';
import '../constants/app_colors.dart';
import '../services/format_utils.dart';
import '../services/settings_service.dart';

/// Bottom sheet modal to preview and export the Pedigree chart PDF
class PedigreePreviewSheet extends StatefulWidget {
  final PedigreeData data;
  final ValueChanged<PedigreeOrientation>? onOrientationChanged;

  const PedigreePreviewSheet({super.key, required this.data, this.onOrientationChanged});

  static void show(
    BuildContext context,
    PedigreeData data, {
    ValueChanged<PedigreeOrientation>? onOrientationChanged,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PedigreePreviewSheet(
        data: data,
        onOrientationChanged: onOrientationChanged,
      ),
    );
  }

  @override
  State<PedigreePreviewSheet> createState() => _PedigreePreviewSheetState();
}

class _PedigreePreviewSheetState extends State<PedigreePreviewSheet> {
  late PedigreeOrientation _orientation;

  @override
  void initState() {
    super.initState();
    _orientation = widget.data.orientation;
  }

  Widget _buildOrientationToggle(String label, PedigreeOrientation opt) {
    final isSelected = _orientation == opt;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _orientation = opt);
          widget.onOrientationChanged?.call(opt);
        },
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? kAppCardWhite : Colors.transparent,
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
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? appColor(0xFF5C4A70) : appColor(0xFF6B7280),
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
    final activeData = widget.data.copyWith(orientation: _orientation);

    return Container(
      decoration: BoxDecoration(
        color: kAppCardWhite,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
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
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Pedigree Chart Preview',
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

          // 2 Options: Landscape & Portrait
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: appSurface(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: appSurface(0xFFE5E5EA)),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildOrientationToggle('Landscape', PedigreeOrientation.landscape),
                  _buildOrientationToggle('Portrait', PedigreeOrientation.portrait),
                ],
              ),
            ),
          ),

          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // WYSIWYG 1:1 Preview Box
                  PedigreePreviewWidget(data: activeData),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          final bytes = await PedigreePdfService.generatePdf(activeData);
                          final orientLabel = activeData.isPortrait ? 'Portrait' : 'Landscape';
                          await Printing.sharePdf(
                            bytes: bytes,
                            filename: 'Pedigree_${activeData.subjectName.replaceAll(' ', '_')}_$orientLabel.pdf',
                          );
                        } catch (e) {
                          debugPrint('Error generating pedigree PDF: $e');
                        }
                      },
                      icon: const Icon(Icons.download_rounded, size: 20),
                      label: const Text(
                        'Download & Share PDF',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: appSurface(0xFF7B6BA0),
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

class PedigreePreviewWidget extends StatelessWidget {
  final PedigreeData data;

  const PedigreePreviewWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) =>
      DarkModeGuard(child: _buildPreview(context));

  Widget _buildPreview(BuildContext context) {
    final currentAspectRatio = data.isPortrait
        ? PedigreeLayout.portraitAspectRatio
        : PedigreeLayout.aspectRatio;

    return AspectRatio(
      aspectRatio: currentAspectRatio,
      child: Container(
        decoration: BoxDecoration(
          color: kAppCardWhite,
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

            if (data.isPortrait) {
              return _buildPortraitPreview(context, W, H);
            }
            return _buildLandscapePreview(context, W, H);
          },
        ),
      ),
    );
  }

  // ─── PORTRAIT PREVIEW (Matches PortraitPedigree.pdf 1:1) ────────────────────
  Widget _buildPortraitPreview(BuildContext context, double W, double H) {
    final scaleW = W / PedigreeLayout.portraitPageWidthPt;
    final scaleH = H / PedigreeLayout.portraitPageHeightPt;

    final tree = data.tree;

    double farmTitleSize = 21.0 * scaleW;
    if (data.farmName.length > 26) {
      farmTitleSize = (farmTitleSize * 26 / data.farmName.length)
          .clamp(14.0 * scaleW, 21.0 * scaleW);
    }

    final String breedSubtitle = data.subjectBreed.trim().isNotEmpty
        ? '${data.subjectBreed.trim()} Pedigree'
        : 'Pedigree';

    return Stack(
      children: [
        // Purple header band
        Positioned(
          left: 0.5 * scaleW,
          top: 0.3 * scaleH,
          width: 611.0 * scaleW,
          height: 60.5 * scaleH,
          child: Container(color: PedigreeLayout.portraitBandColor),
        ),

        // ─── Header: Farm Name (Cabinet of the Outlander, 21pt, centered) ───
        Positioned(
          left: 0,
          right: 0,
          top: 8.0 * scaleH,
          height: 26.0 * scaleH,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                data.farmName,
                style: TextStyle(
                  fontFamily: 'Overthink',
                  fontFamilyFallback: const ['Shakies', PedigreeLayout.fontFamilyTitle],
                  fontSize: farmTitleSize,
                  color: Colors.white,
                ),
                maxLines: 1,
              ),
            ),
          ),
        ),

        // ─── Header: Breed Pedigree Subtitle (Myriad Pro, 18pt, centered) ───
        Positioned(
          left: 0,
          right: 0,
          top: 34.0 * scaleH,
          height: 22.0 * scaleH,
          child: Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                breedSubtitle,
                style: TextStyle(
                  fontFamily: 'Myriad Pro',
                  fontFamilyFallback: const [PedigreeLayout.fontFamilyDetails],
                  fontWeight: FontWeight.w400,
                  fontSize: 18.0 * scaleW,
                  color: Colors.white,
                ),
                maxLines: 1,
              ),
            ),
          ),
        ),

        // ─── Top Double Horizontal Rule ───────────────────────────────────
        Positioned(
          left: 4.875 * scaleW,
          top: 60.55 * scaleH,
          width: 602.25 * scaleW,
          height: (0.5 * scaleH).clamp(0.5, 1.5),
          child: Container(color: Colors.black),
        ),
        Positioned(
          left: 5.875 * scaleW,
          top: 63.44 * scaleH,
          width: 602.25 * scaleW,
          height: (0.5 * scaleH).clamp(0.5, 1.5),
          child: Container(color: Colors.black),
        ),

        // ─── Subject Details: Column 1 (Name, Ear #, Reg #, Sold to) ──────
        _buildPortraitSubjectField(
          scaleW: scaleW,
          scaleH: scaleH,
          leftPt: 21.875,
          topPt: 65.0,
          widthPt: 195.0,
          label: 'Name:  ',
          value: data.subjectName,
          semiboldValue: true,
        ),
        _buildPortraitSubjectField(
          scaleW: scaleW,
          scaleH: scaleH,
          leftPt: 21.875,
          topPt: 78.5,
          widthPt: 195.0,
          label: 'Ear #: ',
          value: data.subjectEarNo,
        ),
        _buildPortraitSubjectField(
          scaleW: scaleW,
          scaleH: scaleH,
          leftPt: 21.875,
          topPt: 92.0,
          widthPt: 195.0,
          label: 'Reg #: ',
          value: data.subjectRegNo,
        ),
        if (data.showSoldTo)
        _buildPortraitSubjectField(
          scaleW: scaleW,
          scaleH: scaleH,
          leftPt: 21.875,
          topPt: 105.5,
          widthPt: 195.0,
          label: 'Sold to: ',
          value: data.soldTo,
        ),

        // ─── Subject Details: Column 2 (Breed, Sex, Color, Sold on) ───────
        _buildPortraitSubjectField(
          scaleW: scaleW,
          scaleH: scaleH,
          leftPt: 220.87,
          topPt: 65.0,
          widthPt: 195.0,
          label: 'Breed: ',
          value: data.subjectBreed,
        ),
        _buildPortraitSubjectField(
          scaleW: scaleW,
          scaleH: scaleH,
          leftPt: 220.87,
          topPt: 78.5,
          widthPt: 195.0,
          label: 'Sex:  ',
          value: data.subjectSex,
        ),
        _buildPortraitSubjectField(
          scaleW: scaleW,
          scaleH: scaleH,
          leftPt: 220.87,
          topPt: 92.0,
          widthPt: 195.0,
          label: 'Color: ',
          value: data.subjectColor,
        ),
        if (data.showSoldOn)
        _buildPortraitSubjectField(
          scaleW: scaleW,
          scaleH: scaleH,
          leftPt: 220.87,
          topPt: 105.5,
          widthPt: 195.0,
          label: 'Sold on: ',
          value: data.soldOn,
        ),

        // ─── Subject Details: Column 3 (Born, Weight, Legs) ───────────────
        _buildPortraitSubjectField(
          scaleW: scaleW,
          scaleH: scaleH,
          leftPt: 420.89,
          topPt: 65.0,
          widthPt: 180.0,
          label: 'Born:  ',
          value: data.subjectDob,
        ),
        _buildPortraitSubjectField(
          scaleW: scaleW,
          scaleH: scaleH,
          leftPt: 420.89,
          topPt: 78.5,
          widthPt: 180.0,
          label: 'Weight:  ',
          value: data.subjectWeight,
        ),
        _buildPortraitSubjectField(
          scaleW: scaleW,
          scaleH: scaleH,
          leftPt: 420.89,
          topPt: 92.0,
          widthPt: 180.0,
          label: 'Legs: ',
          value: data.subjectLegs,
        ),

        // ─── Bottom Double Horizontal Rule ────────────────────────────────
        Positioned(
          left: 4.875 * scaleW,
          top: 121.0 * scaleH,
          width: 602.25 * scaleW,
          height: (0.5 * scaleH).clamp(0.5, 1.5),
          child: Container(color: Colors.black),
        ),
        Positioned(
          left: 4.875 * scaleW,
          top: 123.85 * scaleH,
          width: 602.25 * scaleW,
          height: (0.5 * scaleH).clamp(0.5, 1.5),
          child: Container(color: Colors.black),
        ),

        // ─── Generation Column Headers ────────────────────────────────────
        Positioned(
          left: 20.99 * scaleW,
          top: 128.5 * scaleH,
          child: Text(
            'PARENTS',
            style: TextStyle(
              fontFamily: 'Myriad Pro',
              fontFamilyFallback: const [PedigreeLayout.fontFamilyDetails],
              fontWeight: FontWeight.w400,
              fontSize: 11.0 * scaleW,
              color: const Color(0xFF262626),
            ),
          ),
        ),
        Positioned(
          left: 220.28 * scaleW,
          top: 128.5 * scaleH,
          child: Text(
            'GRANDPARENTS',
            style: TextStyle(
              fontFamily: 'Myriad Pro',
              fontFamilyFallback: const [PedigreeLayout.fontFamilyDetails],
              fontWeight: FontWeight.w400,
              fontSize: 11.0 * scaleW,
              color: const Color(0xFF262626),
            ),
          ),
        ),
        Positioned(
          left: 420.05 * scaleW,
          top: 128.5 * scaleH,
          child: Text(
            'GREAT-GRAND PARENTS',
            style: TextStyle(
              fontFamily: 'Myriad Pro',
              fontFamilyFallback: const [PedigreeLayout.fontFamilyDetails],
              fontWeight: FontWeight.w400,
              fontSize: 11.0 * scaleW,
              color: const Color(0xFF262626),
            ),
          ),
        ),

        // ─── Connector lines ──────────────────────────────────────────────
        Positioned.fill(
          child: CustomPaint(
            painter: _PortraitConnectorPainter(scaleW, scaleH),
          ),
        ),

        // ─── Subject photo square (fits whole photo, grey filler) ─────────
        if (SettingsService.instance.pedigreeShowPhoto)
          Positioned(
            left: PedigreeLayout.portraitPhotoLeft * scaleW,
            top: PedigreeLayout.portraitPhotoTop * scaleH,
            width: PedigreeLayout.portraitPhotoSize * scaleW,
            height: PedigreeLayout.portraitPhotoSize * scaleH,
            child: Container(
              decoration: BoxDecoration(
                color: (data.subjectPhotoPath != null &&
                        data.subjectPhotoPath!.isNotEmpty &&
                        File(data.subjectPhotoPath!).existsSync())
                    ? const Color(0xFFEBEBEB)
                    : null,
                border: Border.all(
                  color: PedigreeLayout.portraitPhotoBorder,
                  width: 2.0 * scaleW,
                ),
              ),
              child: (data.subjectPhotoPath != null &&
                      data.subjectPhotoPath!.isNotEmpty &&
                      File(data.subjectPhotoPath!).existsSync())
                  ? Image.file(File(data.subjectPhotoPath!), fit: BoxFit.contain)
                  : null,
            ),
          ),

        // ─── Column 1: PARENTS ────────────────────────────────────────────
        ..._buildPortraitCard(scaleW, scaleH, 'Sire', 19.74, 267.18, tree?.sire),
        ..._buildPortraitCard(scaleW, scaleH, 'Dam', 20.74, 566.42, tree?.dam),

        // ─── Column 2: GRANDPARENTS ───────────────────────────────────────
        ..._buildPortraitCard(scaleW, scaleH, 'Sire', 219.68, 192.31, tree?.sire?.sire),
        ..._buildPortraitCard(scaleW, scaleH, 'Dam', 219.68, 342.06, tree?.sire?.dam),
        ..._buildPortraitCard(scaleW, scaleH, 'Sire', 220.68, 491.05, tree?.dam?.sire),
        ..._buildPortraitCard(scaleW, scaleH, 'Dam', 220.68, 641.80, tree?.dam?.dam),

        // ─── Column 3: GREAT-GRAND PARENTS ────────────────────────────────
        ..._buildPortraitCard(scaleW, scaleH, 'Sire', 419.62, 157.39, tree?.sire?.sire?.sire),
        ..._buildPortraitCard(scaleW, scaleH, 'Dam', 419.62, 226.27, tree?.sire?.sire?.dam),
        ..._buildPortraitCard(scaleW, scaleH, 'Sire', 419.62, 307.14, tree?.sire?.dam?.sire),
        ..._buildPortraitCard(scaleW, scaleH, 'Dam', 419.62, 376.02, tree?.sire?.dam?.dam),
        ..._buildPortraitCard(scaleW, scaleH, 'Sire', 420.62, 455.88, tree?.dam?.sire?.sire),
        ..._buildPortraitCard(scaleW, scaleH, 'Dam', 420.62, 524.76, tree?.dam?.sire?.dam),
        ..._buildPortraitCard(scaleW, scaleH, 'Sire', 420.62, 606.63, tree?.dam?.dam?.sire),
        ..._buildPortraitCard(scaleW, scaleH, 'Dam', 420.62, 675.51, tree?.dam?.dam?.dam),

        // ─── Bottom Left: Certification (3 lines) ─────────────────────────
        Positioned(
          left: 24.83 * scaleW,
          top: 650.5 * scaleH,
          width: 185.0 * scaleW,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'I hereby certify that this pedigree',
                style: TextStyle(
                  fontFamily: 'Myriad Pro',
                  fontFamilyFallback: const [PedigreeLayout.fontFamilyDetails],
                  fontSize: 10.5 * scaleW,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 1.5 * scaleH),
              Text(
                'is correct to the best',
                style: TextStyle(
                  fontFamily: 'Myriad Pro',
                  fontFamilyFallback: const [PedigreeLayout.fontFamilyDetails],
                  fontSize: 10.5 * scaleW,
                  color: Colors.black,
                ),
              ),
              SizedBox(height: 1.5 * scaleH),
              Text(
                'of my knowledge',
                style: TextStyle(
                  fontFamily: 'Myriad Pro',
                  fontFamilyFallback: const [PedigreeLayout.fontFamilyDetails],
                  fontSize: 10.5 * scaleW,
                  color: Colors.black,
                ),
              ),
            ],
          ),
        ),

        // ─── Bottom Left: Signature (Overthink) + Email + Website ─────────
        Positioned(
          left: 25.74 * scaleW,
          top: 710.0 * scaleH,
          width: 190.0 * scaleW,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (data.ownerName.trim().isNotEmpty)
                Text(
                  data.ownerName.trim(),
                  style: TextStyle(
                    fontFamily: 'TheDecember',
                    fontFamilyFallback: const [PedigreeLayout.fontFamilySignature],
                    fontSize: 16.0 * scaleW,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              if (data.farmEmail.trim().isNotEmpty) ...[
                SizedBox(height: 2.0 * scaleH),
                Text(
                  data.farmEmail.trim(),
                  style: TextStyle(
                    fontFamily: 'Myriad Pro',
                    fontFamilyFallback: const [PedigreeLayout.fontFamilyDetails],
                    fontSize: 11.0 * scaleW,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (data.farmWebsite.trim().isNotEmpty || data.farmSocialLink.trim().isNotEmpty) ...[
                SizedBox(height: 1.5 * scaleH),
                Text(
                  data.farmWebsite.trim().isNotEmpty
                      ? data.farmWebsite.trim()
                      : data.farmSocialLink.trim(),
                  style: TextStyle(
                    fontFamily: 'Myriad Pro',
                    fontFamilyFallback: const [PedigreeLayout.fontFamilyDetails],
                    fontSize: 11.0 * scaleW,
                    color: Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static Widget _buildPortraitSubjectField({
    required double scaleW,
    required double scaleH,
    required double leftPt,
    required double topPt,
    required double widthPt,
    required String label,
    required String value,
    bool semiboldValue = false,
  }) {
    return Positioned(
      left: leftPt * scaleW,
      top: topPt * scaleH,
      width: widthPt * scaleW,
      height: 14.4 * scaleH,
      child: Align(
        alignment: Alignment.centerLeft,
        child: RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: label,
                style: TextStyle(
                  fontFamily: 'Myriad Pro',
                  fontFamilyFallback: const [PedigreeLayout.fontFamilyDetails],
                  fontWeight: FontWeight.w400,
                  fontSize: 12.0 * scaleW,
                  color: Colors.black,
                ),
              ),
              TextSpan(
                text: value,
                style: TextStyle(
                  fontFamily: 'Myriad Pro',
                  fontFamilyFallback: const [PedigreeLayout.fontFamilyDetails],
                  fontWeight: semiboldValue ? FontWeight.w700 : FontWeight.w400,
                  fontSize: 12.0 * scaleW,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  static List<Widget> _buildPortraitCard(
    double scaleW,
    double scaleH,
    String role,
    double leftPt,
    double topPt,
    PedigreeRabbit? rabbit,
  ) {
    const double widthPt = 172.645;
    const double heightPt = 62.24;
    final String name = rabbit?.displayName ?? '';
    final String color = rabbit?.color ?? '';
    final String earNo = rabbit?.earNumber ?? '';
    final String regNo = rabbit?.registrationNumber ?? '';
    final String dob = rabbit?.dateOfBirth != null
        ? FormatUtils.formatCertificateDate(rabbit!.dateOfBirth)
        : '';
    final String wt = _formatCardWeight(rabbit?.weight);
    final String gcNo = rabbit?.grandChampionNumber ?? '';
    final String legs = (rabbit?.legs != null && rabbit!.legs! > 0)
        ? '${rabbit.legs}'
        : '';
    final String winnings = (rabbit?.winnings ?? '').trim();

    final double textSize = 10.0 * scaleW;

    return [
      // Top shaded header strip (5% gray)
      Positioned(
        left: (leftPt + 0.44) * scaleW,
        top: (topPt + 0.44) * scaleH,
        width: 171.763 * scaleW,
        height: 14.62 * scaleH,
        child: Container(
          color: role == 'Dam'
              ? PedigreeLayout.portraitDamTint
              : PedigreeLayout.portraitSireTint,
        ),
      ),
      // Card outer border + 5 rows
      Positioned(
        left: leftPt * scaleW,
        top: topPt * scaleH,
        width: widthPt * scaleW,
        height: heightPt * scaleH,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: const Color(0xFF1A1A1A),
              width: (0.5 * scaleW).clamp(0.5, 1.2),
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            4.2 * scaleW,
            1.2 * scaleH,
            4.0 * scaleW,
            1.2 * scaleH,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Row 1: Sire/Dam + Name (Myriad Pro Semi Bold, 10pt)
              Text(
                '$role:  $name',
                style: TextStyle(
                  fontFamily: 'Myriad Pro',
                  fontFamilyFallback: const [PedigreeLayout.fontFamilyDetails],
                  fontWeight: FontWeight.w700,
                  fontSize: textSize,
                  color: Colors.black,
                  height: 1.05,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // Row 2: Color
              Text(
                'Color:  $color',
                style: TextStyle(
                  fontFamily: 'Myriad Pro',
                  fontFamilyFallback: const [PedigreeLayout.fontFamilyDetails],
                  fontWeight: FontWeight.w400,
                  fontSize: textSize,
                  color: Colors.black,
                  height: 1.05,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // Row 3: Ear # & Reg#
              Row(
                children: [
                  Expanded(
                    flex: 56,
                    child: Text(
                      'Ear #:  $earNo',
                      style: TextStyle(
                        fontFamily: 'Myriad Pro',
                        fontFamilyFallback: const [PedigreeLayout.fontFamilyDetails],
                        fontWeight: FontWeight.w400,
                        fontSize: textSize,
                        color: Colors.black,
                        height: 1.05,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 44,
                    child: Text(
                      'Reg#: $regNo',
                      style: TextStyle(
                        fontFamily: 'Myriad Pro',
                        fontFamilyFallback: const [PedigreeLayout.fontFamilyDetails],
                        fontWeight: FontWeight.w400,
                        fontSize: textSize,
                        color: Colors.black,
                        height: 1.05,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // Row 4: DOB & Wt
              Row(
                children: [
                  Expanded(
                    flex: 56,
                    child: Text(
                      'DOB:  $dob',
                      style: TextStyle(
                        fontFamily: 'Myriad Pro',
                        fontFamilyFallback: const [PedigreeLayout.fontFamilyDetails],
                        fontWeight: FontWeight.w400,
                        fontSize: textSize,
                        color: Colors.black,
                        height: 1.05,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 44,
                    child: Text(
                      'Wt:  $wt',
                      style: TextStyle(
                        fontFamily: 'Myriad Pro',
                        fontFamilyFallback: const [PedigreeLayout.fontFamilyDetails],
                        fontWeight: FontWeight.w400,
                        fontSize: textSize,
                        color: Colors.black,
                        height: 1.05,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              // Row 5: GC# & Legs
              Row(
                children: [
                  Expanded(
                    flex: 56,
                    child: Text(
                      'GC#:  $gcNo',
                      style: TextStyle(
                        fontFamily: 'Myriad Pro',
                        fontFamilyFallback: const [PedigreeLayout.fontFamilyDetails],
                        fontWeight: FontWeight.w400,
                        fontSize: textSize,
                        color: Colors.black,
                        height: 1.05,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Expanded(
                    flex: 44,
                    child: Text(
                      'Legs: $legs',
                      style: TextStyle(
                        fontFamily: 'Myriad Pro',
                        fontFamilyFallback: const [PedigreeLayout.fontFamilyDetails],
                        fontWeight: FontWeight.w400,
                        fontSize: textSize,
                        color: Colors.black,
                        height: 1.05,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      if (winnings.isNotEmpty)
        Positioned(
          left: leftPt * scaleW,
          top: (topPt + heightPt) * scaleH + 1.0,
          width: widthPt * scaleW,
          child: Text(
            winnings,
            style: TextStyle(
              fontFamily: 'Myriad Pro',
              fontFamilyFallback: const [PedigreeLayout.fontFamilyDetails],
              fontSize: 9.5 * scaleW,
              color: Colors.black,
            ),
          ),
        ),
    ];
  }

  // ─── LANDSCAPE PREVIEW ──────────────────────────────────────────────────────
  Widget _buildLandscapePreview(BuildContext context, double W, double H) {
    final double s = W / LandscapeLayout.pageW;
    final hasPhoto = data.subjectPhotoPath != null &&
        data.subjectPhotoPath!.isNotEmpty &&
        File(data.subjectPhotoPath!).existsSync();
    final tree = data.tree;

    const Color headGrey = Color(0xFFA7A9AC);
    const Color subjInk = Color(0xFF707273);
    const Color lineInk = Color(0xFF6D6E71);
    const Color certInk = Color(0xFF808285);
    const Color rule = Color(0xFF93959A);

    Widget txt(String t, double x, double y, double w, double fs, Color c,
        {String? family, List<String>? fallback}) {
      return Positioned(
        left: x * s,
        top: y * s,
        width: w * s,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            t,
            maxLines: 1,
            style: TextStyle(
              fontFamily: family ?? 'Myriad Pro',
              fontFamilyFallback: fallback ?? const [PedigreeLayout.fontFamilyDetails],
              fontSize: fs * s,
              color: c,
              height: 1.2,
            ),
          ),
        ),
      );
    }

    final children = <Widget>[
      txt(data.farmName, 20.8, 14.5, 330, 33.2, headGrey,
          family: 'Overthink', fallback: const [PedigreeLayout.fontFamilyTitle]),
      if (data.farmAddress.isNotEmpty || data.farmEmail.isNotEmpty)
        Positioned(
          left: 23.9 * s,
          top: 56.8 * s,
          child: Row(children: [
            if (data.farmAddress.isNotEmpty)
              Text(data.farmAddress,
                  style: TextStyle(
                      fontFamily: 'Myriad Pro',
                      fontFamilyFallback: const [PedigreeLayout.fontFamilyDetails],
                      fontSize: 11 * s,
                      height: 1.2,
                      color: headGrey)),
            if (data.farmAddress.isNotEmpty && data.farmEmail.isNotEmpty) SizedBox(width: 14 * s),
            if (data.farmEmail.isNotEmpty)
              Text(data.farmEmail,
                  style: TextStyle(
                      fontFamily: 'Myriad Pro',
                      fontFamilyFallback: const [PedigreeLayout.fontFamilyDetails],
                      fontSize: 11 * s,
                      height: 1.2,
                      color: headGrey)),
          ]),
        ),
      Positioned(
        left: 22.4 * s,
        top: 71.2 * s,
        width: 253.0 * s,
        height: 1.0 * s,
        child: Container(color: rule),
      ),
      if (data.subjectBreed.trim().isNotEmpty)
        txt('${data.subjectBreed.trim()} Pedigree', 23.6, 75.8, 300, 14, lineInk),
      Positioned(
        left: 52.7 * s,
        top: 121.0 * s,
        width: 110.0 * s,
        height: 112.0 * s,
        child: Image.asset(PedigreeLayout.logoAsset, fit: BoxFit.contain),
      ),
      Positioned(
        left: 21.8 * s,
        top: 216.2 * s,
        width: 173.7 * s,
        height: 178.8 * s,
        child: Container(
          decoration: BoxDecoration(
            color: LandscapeLayout.subjectBox,
            borderRadius: BorderRadius.circular(18 * s),
          ),
        ),
      ),
      for (final c in LandscapeLayout.subjectCells(data)) txt(c.text, c.x, c.y, c.w, 12, subjInk),
      if (data.showSoldTo) txt('Sold To: ${data.soldTo}', 24.2, 414.5, 175, 11, lineInk),
      if (data.showSoldOn) txt('Sold On: ${data.soldOn}', 24.2, 427.7, 175, 11, lineInk),
      if (data.subjectGenotype.isNotEmpty)
        txt('Genotype: ${data.subjectGenotype}', 24.2, 441.0, 175, 11, lineInk),
      if (SettingsService.instance.pedigreeShowPhoto)
        Positioned(
          left: 216.3 * s,
          top: 236.0 * s,
          width: 178.3 * s,
          height: 134.6 * s,
          child: Container(
            decoration: ShapeDecoration(
              shape: OvalBorder(side: BorderSide(color: LandscapeLayout.photoBorder, width: 1.0 * s)),
              color: hasPhoto ? null : Colors.black.withValues(alpha: 0.05),
            ),
            child: hasPhoto
                ? ClipOval(
                    child: Container(
                      color: const Color(0xFFE6E6E6),
                      child: Image.file(
                        File(data.subjectPhotoPath!),
                        fit: BoxFit.contain,
                        width: double.infinity,
                        height: double.infinity,
                      ),
                    ),
                  )
                : const SizedBox(),
          ),
        ),
    ];

    for (final c in LandscapeLayout.specs) {
      final r = LandscapeLayout.resolve(tree, c.path);
      children.add(Positioned(
        left: c.left * s,
        top: c.top * s,
        width: c.width * s,
        height: c.height * s,
        child: Container(
          decoration: BoxDecoration(
            color: c.isSire ? LandscapeLayout.sireCard : LandscapeLayout.damCard,
            borderRadius: BorderRadius.circular(LandscapeLayout.cardRadius * s),
          ),
        ),
      ));
      for (final cell in LandscapeLayout.cardCells(c, r, _formatCardWeight(r?.weight))) {
        children.add(txt(cell.text, c.left + cell.x, c.top + cell.y, cell.w, c.fontSize, Colors.white));
      }
      final win = (r?.winnings ?? '').trim();
      if (win.isNotEmpty && c.gen < 3) {
        children.add(txt(win, c.left, c.top + c.height + 0.5, c.width, c.fontSize - 1, lineInk));
      }
    }

    children.addAll([
      txt('I hereby certify this pedigree is correct', 20.6, 523.0, 250, 12, certInk),
      txt('to the best of my knowledge', 20.6, 537.4, 250, 12, certInk),
      if (data.ownerName.trim().isNotEmpty)
        txt(data.ownerName.trim(), 22.3, 548.0, 190, 20, lineInk,
            family: 'TheDecember', fallback: const [PedigreeLayout.fontFamilySignature]),
      Positioned(
        left: 20.6 * s,
        top: 580.4 * s,
        width: 119.6 * s,
        height: 1.0 * s,
        child: Container(color: rule),
      ),
      if (data.farmPhone.trim().isNotEmpty) txt(data.farmPhone.trim(), 20.6, 586.8, 150, 12, lineInk),
      if (data.farmWebsite.trim().isNotEmpty) txt(data.farmWebsite.trim(), 130.0, 588.0, 80, 10, lineInk),
    ]);

    return Stack(children: children);
  }

  static Widget _buildMetadataLine(double W, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: W * 0.004),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: '$label ',
              style: TextStyle(
                fontFamily: PedigreeLayout.fontFamilyDetails,
                fontWeight: FontWeight.w400,
                fontSize: W * (PedigreeLayout.fontRatioSubject * 0.85),
                color: PedigreeLayout.colorSubjectText,
              ),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                fontFamily: PedigreeLayout.fontFamilyDetails,
                fontWeight: FontWeight.w400,
                fontSize: W * (PedigreeLayout.fontRatioSubject * 0.85),
                color: PedigreeLayout.colorSubjectText,
              ),
            ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  static List<Widget> _buildSubjectSingleRow(
    double W,
    double H,
    double centerY,
    String label,
    String value,
  ) {
    final rowHeight = H * PedigreeLayout.subjectRowBoxHeight;
    return [
      Positioned(
        left: W * PedigreeLayout.subjectTextLeft,
        top: H * centerY - (rowHeight / 2),
        width: W * (PedigreeLayout.subjectBoxWidth - 0.015),
        height: rowHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label ',
                  style: TextStyle(
                    fontFamily: PedigreeLayout.fontFamilyDetails,
                    fontWeight: FontWeight.w400,
                    fontSize: W * PedigreeLayout.fontRatioSubject,
                    color: PedigreeLayout.colorSubjectText,
                  ),
                ),
                TextSpan(
                  text: value,
                  style: TextStyle(
                    fontFamily: PedigreeLayout.fontFamilyDetails,
                    fontWeight: FontWeight.w400,
                    fontSize: W * PedigreeLayout.fontRatioSubject,
                    color: PedigreeLayout.colorSubjectText,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ];
  }

  static List<Widget> _buildSubjectDualRow(
    double W,
    double H,
    double centerY,
    String label1,
    String value1,
    String label2,
    String value2,
  ) {
    final rowHeight = H * PedigreeLayout.subjectRowBoxHeight;
    return [
      Positioned(
        left: W * PedigreeLayout.subjectTextLeft,
        top: H * centerY - (rowHeight / 2),
        width: W * (PedigreeLayout.subjectSecondColLeft - PedigreeLayout.subjectTextLeft),
        height: rowHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label1 ',
                  style: TextStyle(
                    fontFamily: PedigreeLayout.fontFamilyDetails,
                    fontWeight: FontWeight.w400,
                    fontSize: W * PedigreeLayout.fontRatioSubject,
                    color: PedigreeLayout.colorSubjectText,
                  ),
                ),
                TextSpan(
                  text: value1,
                  style: TextStyle(
                    fontFamily: PedigreeLayout.fontFamilyDetails,
                    fontWeight: FontWeight.w400,
                    fontSize: W * PedigreeLayout.fontRatioSubject,
                    color: PedigreeLayout.colorSubjectText,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      Positioned(
        left: W * PedigreeLayout.subjectSecondColLeft,
        top: H * centerY - (rowHeight / 2),
        width: W * (PedigreeLayout.subjectBoxLeft + PedigreeLayout.subjectBoxWidth - PedigreeLayout.subjectSecondColLeft - 0.005),
        height: rowHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$label2 ',
                  style: TextStyle(
                    fontFamily: PedigreeLayout.fontFamilyDetails,
                    fontWeight: FontWeight.w400,
                    fontSize: W * PedigreeLayout.fontRatioSubject,
                    color: PedigreeLayout.colorSubjectText,
                  ),
                ),
                TextSpan(
                  text: value2,
                  style: TextStyle(
                    fontFamily: PedigreeLayout.fontFamilyDetails,
                    fontWeight: FontWeight.w400,
                    fontSize: W * PedigreeLayout.fontRatioSubject,
                    color: PedigreeLayout.colorSubjectText,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ];
  }

  static List<Widget> _buildAncestorCard(
    double W,
    double H,
    int generation,
    String role,
    bool isSireSide,
    double left,
    double top,
    PedigreeRabbit? rabbit,
  ) {
    final double cardW = generation == 3 ? PedigreeLayout.gen3Width : PedigreeLayout.gen1Width;
    final double cardH = generation == 3 ? PedigreeLayout.gen3Height : PedigreeLayout.gen1Height;
    final double textDx = generation == 3
        ? PedigreeLayout.gen3TextDx
        : (generation == 2 ? PedigreeLayout.gen2TextDx : PedigreeLayout.gen1TextDx);
    final double secondColDx = generation == 3
        ? PedigreeLayout.gen3SecondColDx
        : (generation == 2 ? PedigreeLayout.gen2SecondColDx : PedigreeLayout.gen1SecondColDx);
    final List<double> rowDy = generation == 3
        ? PedigreeLayout.gen3RowDy
        : (generation == 2 ? PedigreeLayout.gen2RowDy : PedigreeLayout.gen1RowDy);

    final double baseFontSize = generation == 3
        ? W * PedigreeLayout.fontRatioGen3
        : (generation == 2 ? W * PedigreeLayout.fontRatioGen2 : W * PedigreeLayout.fontRatioGen1);

    final String name = rabbit?.displayName ?? '';
    final String color = rabbit?.color ?? '';
    final String dob = rabbit?.dateOfBirth != null ? FormatUtils.formatCertificateDate(rabbit!.dateOfBirth) : '';
    final String wt = _formatCardWeight(rabbit?.weight);
    final String earNo = rabbit?.earNumber ?? '';
    final String legs = rabbit?.legs != null && rabbit!.legs! > 0 ? '${rabbit.legs}' : '';
    final String winnings = (rabbit?.winnings ?? '').trim();

    final double rowHeight = H * (generation == 3 ? 0.0240 : 0.0280);
    final String regNo = rabbit?.registrationNumber ?? '';
    final String gcNo = rabbit?.grandChampionNumber ?? '';
    // 5 evenly spaced rows: Name, Color, DOB/Wt, Ear/Reg, GC/Legs
    final List<double> rd = List<double>.generate(
        5, (i) => rowDy[0] + i * (cardH - 2 * rowDy[0]) / 4);

    return [
      // Container
      Positioned(
        left: W * left,
        top: H * top,
        width: W * cardW,
        height: H * cardH,
        child: Container(
          decoration: BoxDecoration(
            color: isSireSide ? PedigreeLayout.colorSireCardBg : PedigreeLayout.colorDamCardBg,
            borderRadius: BorderRadius.circular(W * PedigreeLayout.cardCornerRadius),
          ),
        ),
      ),

      // Row 0: Role & Name
      Positioned(
        left: W * (left + textDx),
        top: H * (top + rd[0]) - (rowHeight / 2),
        width: W * (cardW - textDx - 0.005),
        height: rowHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$role: ',
                    style: TextStyle(
                      fontFamily: PedigreeLayout.fontFamilyDetails,
                      fontWeight: FontWeight.w400,
                      fontSize: baseFontSize,
                      color: PedigreeLayout.colorCardText,
                    ),
                  ),
                  TextSpan(
                    text: name,
                    style: TextStyle(
                      fontFamily: PedigreeLayout.fontFamilyDetails,
                      fontWeight: FontWeight.w400,
                      fontSize: baseFontSize,
                      color: PedigreeLayout.colorCardText,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
            ),
          ),
        ),
      ),

      // Row 1: Color
      Positioned(
        left: W * (left + textDx),
        top: H * (top + rd[1]) - (rowHeight / 2),
        width: W * (cardW - textDx - 0.005),
        height: rowHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Color: ',
                  style: TextStyle(
                    fontFamily: PedigreeLayout.fontFamilyDetails,
                    fontWeight: FontWeight.w400,
                    fontSize: baseFontSize,
                    color: PedigreeLayout.colorCardText,
                  ),
                ),
                TextSpan(
                  text: color,
                  style: TextStyle(
                    fontFamily: PedigreeLayout.fontFamilyDetails,
                    fontWeight: FontWeight.w400,
                    fontSize: baseFontSize,
                    color: PedigreeLayout.colorCardText,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),

      // Row 2: DOB & Wt
      Positioned(
        left: W * (left + textDx),
        top: H * (top + rd[2]) - (rowHeight / 2),
        width: W * (secondColDx - textDx),
        height: rowHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'DOB: ',
                  style: TextStyle(
                    fontFamily: PedigreeLayout.fontFamilyDetails,
                    fontWeight: FontWeight.w400,
                    fontSize: baseFontSize,
                    color: PedigreeLayout.colorCardText,
                  ),
                ),
                TextSpan(
                  text: dob,
                  style: TextStyle(
                    fontFamily: PedigreeLayout.fontFamilyDetails,
                    fontWeight: FontWeight.w400,
                    fontSize: baseFontSize,
                    color: PedigreeLayout.colorCardText,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      Positioned(
        left: W * (left + secondColDx),
        top: H * (top + rd[2]) - (rowHeight / 2),
        width: W * (cardW - secondColDx - 0.004),
        height: rowHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Wt: ',
                  style: TextStyle(
                    fontFamily: PedigreeLayout.fontFamilyDetails,
                    fontWeight: FontWeight.w400,
                    fontSize: baseFontSize,
                    color: PedigreeLayout.colorCardText,
                  ),
                ),
                TextSpan(
                  text: wt,
                  style: TextStyle(
                    fontFamily: PedigreeLayout.fontFamilyDetails,
                    fontWeight: FontWeight.w400,
                    fontSize: baseFontSize,
                    color: PedigreeLayout.colorCardText,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),

      // Row 3: Ear No. & Reg #
      Positioned(
        left: W * (left + textDx),
        top: H * (top + rd[3]) - (rowHeight / 2),
        width: W * (secondColDx - textDx),
        height: rowHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Ear No.: ',
                  style: TextStyle(
                    fontFamily: PedigreeLayout.fontFamilyDetails,
                    fontWeight: FontWeight.w400,
                    fontSize: baseFontSize,
                    color: PedigreeLayout.colorCardText,
                  ),
                ),
                TextSpan(
                  text: earNo,
                  style: TextStyle(
                    fontFamily: PedigreeLayout.fontFamilyDetails,
                    fontWeight: FontWeight.w400,
                    fontSize: baseFontSize,
                    color: PedigreeLayout.colorCardText,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      Positioned(
        left: W * (left + secondColDx),
        top: H * (top + rd[3]) - (rowHeight / 2),
        width: W * (cardW - secondColDx - 0.004),
        height: rowHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Reg #: ',
                  style: TextStyle(
                    fontFamily: PedigreeLayout.fontFamilyDetails,
                    fontWeight: FontWeight.w400,
                    fontSize: baseFontSize,
                    color: PedigreeLayout.colorCardText,
                  ),
                ),
                TextSpan(
                  text: regNo,
                  style: TextStyle(
                    fontFamily: PedigreeLayout.fontFamilyDetails,
                    fontWeight: FontWeight.w400,
                    fontSize: baseFontSize,
                    color: PedigreeLayout.colorCardText,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      // Row 4: GC# & Legs
      Positioned(
        left: W * (left + textDx),
        top: H * (top + rd[4]) - (rowHeight / 2),
        width: W * (secondColDx - textDx),
        height: rowHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'GC#: ',
                  style: TextStyle(
                    fontFamily: PedigreeLayout.fontFamilyDetails,
                    fontWeight: FontWeight.w400,
                    fontSize: baseFontSize,
                    color: PedigreeLayout.colorCardText,
                  ),
                ),
                TextSpan(
                  text: gcNo,
                  style: TextStyle(
                    fontFamily: PedigreeLayout.fontFamilyDetails,
                    fontWeight: FontWeight.w400,
                    fontSize: baseFontSize,
                    color: PedigreeLayout.colorCardText,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      Positioned(
        left: W * (left + secondColDx),
        top: H * (top + rd[4]) - (rowHeight / 2),
        width: W * (cardW - secondColDx - 0.004),
        height: rowHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Legs: ',
                  style: TextStyle(
                    fontFamily: PedigreeLayout.fontFamilyDetails,
                    fontWeight: FontWeight.w400,
                    fontSize: baseFontSize,
                    color: PedigreeLayout.colorCardText,
                  ),
                ),
                TextSpan(
                  text: legs,
                  style: TextStyle(
                    fontFamily: PedigreeLayout.fontFamilyDetails,
                    fontWeight: FontWeight.w400,
                    fontSize: baseFontSize,
                    color: PedigreeLayout.colorCardText,
                  ),
                ),
              ],
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      if (winnings.isNotEmpty)
        Positioned(
          left: W * left,
          top: H * (top + cardH) + 1.0,
          width: W * cardW,
          child: Text(
            winnings,
            style: TextStyle(
              fontFamily: PedigreeLayout.fontFamilyDetails,
              fontSize: baseFontSize * 0.55 + 2.5,
              color: PedigreeLayout.colorCardText,
            ),
          ),
        ),
    ];
  }

  static String _formatCardWeight(String? wtStr) {
    if (wtStr == null || wtStr.trim().isEmpty || wtStr.trim() == 'N/A' || wtStr.trim() == '—') return '';
    final parsed = double.tryParse(wtStr);
    if (parsed != null && parsed > 0) {
      final int lbs = parsed.floor();
      final int oz = ((parsed - lbs) * 16).round();
      if (oz > 0) return '${lbs}lbs ${oz}oz';
      return '${lbs}lbs';
    }
    return wtStr.trim();
  }
}

class _PortraitConnectorPainter extends CustomPainter {
  final double scaleW;
  final double scaleH;
  _PortraitConnectorPainter(this.scaleW, this.scaleH);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF47474A)
      ..strokeWidth = 0.75 * scaleW
      ..style = PaintingStyle.stroke;
    for (final c in PedigreeLayout.portraitConnectors) {
      canvas.drawLine(
        Offset(c[0] * scaleW, c[1] * scaleH),
        Offset(c[2] * scaleW, c[3] * scaleH),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PortraitConnectorPainter old) =>
      old.scaleW != scaleW || old.scaleH != scaleH;
}
