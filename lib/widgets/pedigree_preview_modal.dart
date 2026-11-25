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
          topPt: 66.5,
          widthPt: 195.0,
          label: 'Name:  ',
          value: data.subjectName,
          semiboldValue: true,
        ),
        _buildPortraitSubjectField(
          scaleW: scaleW,
          scaleH: scaleH,
          leftPt: 21.875,
          topPt: 80.9,
          widthPt: 195.0,
          label: 'Ear #: ',
          value: data.subjectEarNo,
        ),
        _buildPortraitSubjectField(
          scaleW: scaleW,
          scaleH: scaleH,
          leftPt: 21.875,
          topPt: 95.3,
          widthPt: 195.0,
          label: 'Reg #: ',
          value: data.subjectRegNo,
        ),
        if (data.soldTo.trim().isNotEmpty)
        _buildPortraitSubjectField(
          scaleW: scaleW,
          scaleH: scaleH,
          leftPt: 28.9,
          topPt: 530.0,
          widthPt: 160.0,
          label: 'Sold to: ',
          value: data.soldTo,
        ),

        // ─── Subject Details: Column 2 (Breed, Sex, Color, Sold on) ───────
        _buildPortraitSubjectField(
          scaleW: scaleW,
          scaleH: scaleH,
          leftPt: 220.87,
          topPt: 66.5,
          widthPt: 195.0,
          label: 'Breed: ',
          value: data.subjectBreed,
        ),
        _buildPortraitSubjectField(
          scaleW: scaleW,
          scaleH: scaleH,
          leftPt: 220.87,
          topPt: 80.9,
          widthPt: 195.0,
          label: 'Sex:  ',
          value: data.subjectSex,
        ),
        _buildPortraitSubjectField(
          scaleW: scaleW,
          scaleH: scaleH,
          leftPt: 220.87,
          topPt: 95.3,
          widthPt: 195.0,
          label: 'Color: ',
          value: data.subjectColor,
        ),
        if (data.soldOn.trim().isNotEmpty)
        _buildPortraitSubjectField(
          scaleW: scaleW,
          scaleH: scaleH,
          leftPt: 28.9,
          topPt: 544.0,
          widthPt: 160.0,
          label: 'Sold on: ',
          value: data.soldOn,
        ),

        // ─── Subject Details: Column 3 (Born, Weight, Legs) ───────────────
        _buildPortraitSubjectField(
          scaleW: scaleW,
          scaleH: scaleH,
          leftPt: 420.89,
          topPt: 66.5,
          widthPt: 180.0,
          label: 'Born:  ',
          value: data.subjectDob,
        ),
        _buildPortraitSubjectField(
          scaleW: scaleW,
          scaleH: scaleH,
          leftPt: 420.89,
          topPt: 80.9,
          widthPt: 180.0,
          label: 'Weight:  ',
          value: data.subjectWeight,
        ),
        _buildPortraitSubjectField(
          scaleW: scaleW,
          scaleH: scaleH,
          leftPt: 420.89,
          topPt: 95.3,
          widthPt: 180.0,
          label: 'Legs: ',
          value: data.subjectLegs,
        ),

        // ─── Bottom Double Horizontal Rule ────────────────────────────────
        Positioned(
          left: 4.875 * scaleW,
          top: 116.55 * scaleH,
          width: 602.25 * scaleW,
          height: (0.5 * scaleH).clamp(0.5, 1.5),
          child: Container(color: Colors.black),
        ),
        Positioned(
          left: 4.875 * scaleW,
          top: 119.4 * scaleH,
          width: 602.25 * scaleW,
          height: (0.5 * scaleH).clamp(0.5, 1.5),
          child: Container(color: Colors.black),
        ),

        // ─── Generation Column Headers ────────────────────────────────────
        Positioned(
          left: 20.99 * scaleW,
          top: 125.0 * scaleH,
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
          top: 125.0 * scaleH,
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
          top: 125.0 * scaleH,
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
                    fontSize: 11.0 * scaleW,
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
              fontSize: 7.0 * scaleW,
              color: Colors.black,
            ),
          ),
        ),
    ];
  }

  // ─── LANDSCAPE PREVIEW ──────────────────────────────────────────────────────
  Widget _buildLandscapePreview(BuildContext context, double W, double H) {
    final hasPhoto = data.subjectPhotoPath != null &&
        data.subjectPhotoPath!.isNotEmpty &&
        File(data.subjectPhotoPath!).existsSync();

    final tree = data.tree;

    return Stack(
      children: [
        // Top Left: Farm Header
        Positioned(
          left: W * PedigreeLayout.pedigreeHeaderLeft,
          top: H * PedigreeLayout.farmTitleCenterY - (H * PedigreeLayout.farmTitleBoxHeight / 2),
          width: W * PedigreeLayout.farmTitleMaxWidth,
          height: H * PedigreeLayout.farmTitleBoxHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                data.farmName,
                style: TextStyle(
                  fontFamily: 'Overthink',
                  fontFamilyFallback: const [PedigreeLayout.fontFamilyTitle],
                  fontSize: W * PedigreeLayout.fontRatioFarmTitle,
                  color: PedigreeLayout.colorHeaderTitle,
                ),
                maxLines: 1,
              ),
            ),
          ),
        ),

        // Address + Email on one line, grey underline, breed subtitle
        if (data.farmAddress.isNotEmpty || data.farmEmail.isNotEmpty)
          Positioned(
            left: W * PedigreeLayout.addressLeft,
            top: H * (PedigreeLayout.contactCenterY - PedigreeLayout.contactBoxHeight / 2),
            child: Row(
              children: [
                if (data.farmAddress.isNotEmpty)
                  Text(
                    data.farmAddress,
                    style: TextStyle(
                      fontFamily: PedigreeLayout.fontFamilyDetails,
                      fontSize: W * PedigreeLayout.fontRatioHeaderContact,
                      color: PedigreeLayout.colorHeaderContact,
                    ),
                  ),
                if (data.farmAddress.isNotEmpty && data.farmEmail.isNotEmpty)
                  const SizedBox(width: 14),
                if (data.farmEmail.isNotEmpty)
                  Text(
                    data.farmEmail,
                    style: TextStyle(
                      fontFamily: PedigreeLayout.fontFamilyDetails,
                      fontSize: W * PedigreeLayout.fontRatioHeaderContact,
                      color: PedigreeLayout.colorHeaderContact,
                    ),
                  ),
              ],
            ),
          ),
        Positioned(
          left: W * PedigreeLayout.underlineX0,
          top: H * PedigreeLayout.underlineY,
          width: W * (PedigreeLayout.underlineX1 - PedigreeLayout.underlineX0),
          height: 1.0,
          child: Container(color: PedigreeLayout.colorHeaderUnderline),
        ),
        if (data.subjectBreed.trim().isNotEmpty)
          Positioned(
            left: W * PedigreeLayout.breedSubtitleLeft,
            top: H * PedigreeLayout.breedSubtitleTop,
            child: Text(
              '${data.subjectBreed.trim()} Pedigree',
              style: TextStyle(
                fontFamily: PedigreeLayout.fontFamilyDetails,
                fontSize: W * PedigreeLayout.fontRatioSubject,
                color: PedigreeLayout.colorSubjectText,
              ),
              maxLines: 1,
            ),
          ),
        if (data.farmWebsite.isNotEmpty || data.farmSocialLink.isNotEmpty)
          Positioned(
            left: W * PedigreeLayout.addressLeft,
            top: H * PedigreeLayout.websiteTop,
            width: W * 0.30,
            child: Text(
              [
                if (data.farmWebsite.isNotEmpty) data.farmWebsite,
                if (data.farmSocialLink.isNotEmpty) data.farmSocialLink,
              ].join('  •  '),
              style: TextStyle(
                fontFamily: PedigreeLayout.fontFamilyDetails,
                fontSize: W * (PedigreeLayout.fontRatioHeaderContact * 0.9),
                color: PedigreeLayout.colorHeaderContact,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

        // "Bunny Pedigree" Logo Image
        Positioned(
          left: W * PedigreeLayout.logoLeft,
          top: H * PedigreeLayout.logoTop,
          width: W * PedigreeLayout.logoWidth,
          height: H * PedigreeLayout.logoHeight,
          child: Image.asset(PedigreeLayout.logoAsset, fit: BoxFit.contain),
        ),

        // Subject Box Background
        Positioned(
          left: W * PedigreeLayout.subjectBoxLeft,
          top: H * PedigreeLayout.subjectBoxTop,
          width: W * PedigreeLayout.subjectBoxWidth,
          height: H * PedigreeLayout.subjectBoxHeight,
          child: Container(
            decoration: BoxDecoration(
              color: PedigreeLayout.colorSubjectBoxBg,
              borderRadius: BorderRadius.circular(W * PedigreeLayout.subjectBoxRadius),
            ),
          ),
        ),

        // Subject Box Rows
        ..._buildSubjectSingleRow(W, H, PedigreeLayout.subjectNameCenterY, 'Name:', data.subjectName),
        ..._buildSubjectSingleRow(W, H, PedigreeLayout.subjectColorCenterY, 'Color:', data.subjectColor),
        ..._buildSubjectSingleRow(W, H, PedigreeLayout.subjectBreedCenterY, 'Breed:', data.subjectBreed),
        ..._buildSubjectSingleRow(W, H, PedigreeLayout.subjectSexCenterY, 'Sex:', data.subjectSex),
        ..._buildSubjectSingleRow(W, H, PedigreeLayout.subjectDobCenterY, 'DOB:', data.subjectDob),
        ..._buildSubjectDualRow(W, H, PedigreeLayout.subjectEarWtCenterY, 'Ear No.:', data.subjectEarNo, 'Wt:', data.subjectWeight),
        ..._buildSubjectDualRow(W, H, PedigreeLayout.subjectRegLegsCenterY, 'Reg No.:', data.subjectRegNo, 'Legs:', data.subjectLegs),

        // Genotype & Sale Details (below Subject Box)
        if (data.subjectGenotype.isNotEmpty || data.soldTo.isNotEmpty || data.soldOn.isNotEmpty)
          Positioned(
            left: W * PedigreeLayout.subjectBoxLeft,
            top: H * 0.658,
            width: W * PedigreeLayout.subjectBoxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (data.subjectGenotype.isNotEmpty)
                  _buildMetadataLine(W, 'Genotype:', data.subjectGenotype),
                if (data.soldTo.isNotEmpty)
                  _buildMetadataLine(W, 'Sold To:', data.soldTo),
                if (data.soldOn.isNotEmpty)
                  _buildMetadataLine(W, 'Sold On:', data.soldOn),
              ],
            ),
          ),

        // Subject Photo Ellipse
        if (SettingsService.instance.pedigreeShowPhoto)
          Positioned(
            left: W * PedigreeLayout.photoLeft,
            top: H * PedigreeLayout.photoTop,
            width: W * PedigreeLayout.photoWidth,
            height: H * PedigreeLayout.photoHeight,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: PedigreeLayout.colorSubjectPhotoOutline,
                  width: 1.5,
                ),
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

        // Gen 1 (Parents)
        ..._buildAncestorCard(W, H, 1, 'Sire', true, PedigreeLayout.sireLeft, PedigreeLayout.sireTop, tree?.sire),
        ..._buildAncestorCard(W, H, 1, 'Dam', false, PedigreeLayout.damLeft, PedigreeLayout.damTop, tree?.dam),

        // Gen 2 (Grandparents)
        ..._buildAncestorCard(W, H, 2, 'G.Sire', true, PedigreeLayout.ssLeft, PedigreeLayout.ssTop, tree?.sire?.sire),
        ..._buildAncestorCard(W, H, 2, 'G.Dam', false, PedigreeLayout.sdLeft, PedigreeLayout.sdTop, tree?.sire?.dam),
        ..._buildAncestorCard(W, H, 2, 'G.Sire', true, PedigreeLayout.dsLeft, PedigreeLayout.dsTop, tree?.dam?.sire),
        ..._buildAncestorCard(W, H, 2, 'G.Dam', false, PedigreeLayout.ddLeft, PedigreeLayout.ddTop, tree?.dam?.dam),

        // Gen 3 (Great-Grandparents)
        ..._buildAncestorCard(W, H, 3, 'G.G.Sire', true, PedigreeLayout.gen3Left, PedigreeLayout.sssTop, tree?.sire?.sire?.sire),
        ..._buildAncestorCard(W, H, 3, 'G.G.Dam', false, PedigreeLayout.gen3Left, PedigreeLayout.ssdTop, tree?.sire?.sire?.dam),
        ..._buildAncestorCard(W, H, 3, 'G.G.Sire', true, PedigreeLayout.gen3Left, PedigreeLayout.sdsTop, tree?.sire?.dam?.sire),
        ..._buildAncestorCard(W, H, 3, 'G.G.Dam', false, PedigreeLayout.gen3Left, PedigreeLayout.sddTop, tree?.sire?.dam?.dam),
        ..._buildAncestorCard(W, H, 3, 'G.G.Sire', true, PedigreeLayout.gen3Left, PedigreeLayout.dssTop, tree?.dam?.sire?.sire),
        ..._buildAncestorCard(W, H, 3, 'G.G.Dam', false, PedigreeLayout.gen3Left, PedigreeLayout.dsdTop, tree?.dam?.sire?.dam),
        ..._buildAncestorCard(W, H, 3, 'G.G.Sire', true, PedigreeLayout.gen3Left, PedigreeLayout.ddsTop, tree?.dam?.dam?.sire),
        ..._buildAncestorCard(W, H, 3, 'G.G.Dam', false, PedigreeLayout.gen3Left, PedigreeLayout.dddTop, tree?.dam?.dam?.dam),

        // Footer (Certification & Signature)
        Positioned(
          left: W * PedigreeLayout.certifyLeft,
          top: H * PedigreeLayout.certifyLine1CenterY - (H * PedigreeLayout.certifyBoxHeight / 2),
          height: H * PedigreeLayout.certifyBoxHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'I hereby certify this pedigree is correct',
              style: TextStyle(
                fontFamily: PedigreeLayout.fontFamilyDetails,
                fontSize: W * PedigreeLayout.fontRatioCertify,
                color: PedigreeLayout.colorFooterCertify,
              ),
            ),
          ),
        ),
        Positioned(
          left: W * PedigreeLayout.certifyLeft,
          top: H * PedigreeLayout.certifyLine2CenterY - (H * PedigreeLayout.certifyBoxHeight / 2),
          height: H * PedigreeLayout.certifyBoxHeight,
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'to the best of my knowledge',
              style: TextStyle(
                fontFamily: PedigreeLayout.fontFamilyDetails,
                fontSize: W * PedigreeLayout.fontRatioCertify,
                color: PedigreeLayout.colorFooterCertify,
              ),
            ),
          ),
        ),
        if (data.ownerName.trim().isNotEmpty)
          Positioned(
            left: W * PedigreeLayout.signatureLeft,
            top: H * PedigreeLayout.signatureCenterY - (H * PedigreeLayout.signatureBoxHeight / 2),
            height: H * PedigreeLayout.signatureBoxHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                data.ownerName.trim(),
                style: TextStyle(
                  fontFamily: 'TheDecember',
                  fontFamilyFallback: const [PedigreeLayout.fontFamilySignature],
                  fontSize: W * PedigreeLayout.fontRatioSignature,
                  color: PedigreeLayout.colorFooterSignature,
                ),
              ),
            ),
          ),
        Positioned(
          left: W * PedigreeLayout.signatureUnderlineX0,
          top: H * PedigreeLayout.signatureUnderlineY,
          width: W * (PedigreeLayout.signatureUnderlineX1 - PedigreeLayout.signatureUnderlineX0),
          height: 0.75,
          child: Container(color: PedigreeLayout.colorHeaderUnderline),
        ),
        if (data.farmPhone.trim().isNotEmpty)
          Positioned(
            left: W * PedigreeLayout.phoneLeft,
            top: H * PedigreeLayout.phoneCenterY - (H * PedigreeLayout.phoneBoxHeight / 2),
            height: H * PedigreeLayout.phoneBoxHeight,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                data.farmPhone.trim(),
                style: TextStyle(
                  fontFamily: PedigreeLayout.fontFamilyDetails,
                  fontSize: W * PedigreeLayout.fontRatioPhone,
                  color: PedigreeLayout.colorFooterPhone,
                ),
              ),
            ),
          ),
      ],
    );
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
        top: H * (top + rowDy[0]) - (rowHeight / 2),
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
        top: H * (top + rowDy[1]) - (rowHeight / 2),
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
        top: H * (top + rowDy[2]) - (rowHeight / 2),
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
        top: H * (top + rowDy[2]) - (rowHeight / 2),
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

      // Row 3: Ear No. & Legs
      Positioned(
        left: W * (left + textDx),
        top: H * (top + rowDy[3]) - (rowHeight / 2),
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
        top: H * (top + rowDy[3]) - (rowHeight / 2),
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
              fontSize: baseFontSize * 0.55,
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
