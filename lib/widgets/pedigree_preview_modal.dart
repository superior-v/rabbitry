import 'dart:io';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../services/pedigree_pdf_service.dart';
import '../models/pedigree.dart';
import 'pedigree_layout.dart';
import '../constants/app_colors.dart';
import '../services/format_utils.dart';

/// Bottom sheet modal to preview and export the Pedigree chart PDF
class PedigreePreviewSheet extends StatelessWidget {
  final PedigreeData data;

  const PedigreePreviewSheet({super.key, required this.data});

  static void show(BuildContext context, PedigreeData data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PedigreePreviewSheet(data: data),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
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
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
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
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // WYSIWYG 1:1 Preview Box
                  PedigreePreviewWidget(data: data),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          final bytes = await PedigreePdfService.generatePdf(data);
                          await Printing.sharePdf(
                            bytes: bytes,
                            filename: 'Pedigree_${data.subjectName.replaceAll(' ', '_')}.pdf',
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

class PedigreePreviewWidget extends StatelessWidget {
  final PedigreeData data;

  const PedigreePreviewWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: PedigreeLayout.aspectRatio,
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

            final hasPhoto = data.subjectPhotoPath != null &&
                data.subjectPhotoPath!.isNotEmpty &&
                File(data.subjectPhotoPath!).existsSync();

            final tree = data.tree;

            return Stack(
              children: [
                // Top Left: Farm Header
                Positioned(
                  left: W * PedigreeLayout.farmTitleLeft,
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
                          fontFamily: PedigreeLayout.fontFamilyTitle,
                          fontSize: W * PedigreeLayout.fontRatioFarmTitle,
                          color: PedigreeLayout.colorHeaderTitle,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),

                // Address & Email
                if (data.farmAddress.isNotEmpty || data.farmEmail.isNotEmpty)
                  Positioned(
                    left: W * PedigreeLayout.addressLeft,
                    top: H * PedigreeLayout.contactCenterY - (H * PedigreeLayout.contactBoxHeight / 2),
                    height: H * PedigreeLayout.contactBoxHeight,
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
                          SizedBox(width: W * 0.04),
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

                // Header Underline
                Positioned(
                  left: W * PedigreeLayout.underlineX0,
                  top: H * PedigreeLayout.underlineY,
                  width: W * (PedigreeLayout.underlineX1 - PedigreeLayout.underlineX0),
                  height: 0.75,
                  child: Container(color: PedigreeLayout.colorHeaderUnderline),
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

                // Subject Photo Ellipse
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
                            child: Image.file(
                              File(data.subjectPhotoPath!),
                              fit: BoxFit.cover,
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
                          fontFamily: PedigreeLayout.fontFamilySignature,
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
          },
        ),
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
                    fontWeight: FontWeight.w700,
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
                    fontWeight: FontWeight.w700,
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
                    fontWeight: FontWeight.w700,
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

    final String name = rabbit?.name ?? '';
    final String color = rabbit?.color ?? '';
    final String dob = rabbit?.dateOfBirth != null ? FormatUtils.formatCertificateDate(rabbit!.dateOfBirth) : '';
    final String wt = _formatCardWeight(rabbit?.weight);
    final String earNo = rabbit?.earNumber ?? '';
    final String legs = rabbit?.legs != null && rabbit!.legs! > 0 ? '${rabbit.legs}' : '';

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
                      fontWeight: FontWeight.w700,
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
                    fontWeight: FontWeight.w700,
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
                    fontWeight: FontWeight.w700,
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
                    fontWeight: FontWeight.w700,
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
                    fontWeight: FontWeight.w700,
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
                    fontWeight: FontWeight.w700,
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
