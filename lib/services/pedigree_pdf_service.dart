import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../widgets/pedigree_layout.dart';
import '../models/pedigree.dart';
import 'format_utils.dart';

class PedigreePdfService {
  PedigreePdfService._();

  /// Generates the Pedigree PDF document as a Uint8List byte array.
  static Future<Uint8List> generatePedigree(PedigreeData data) => generatePdf(data);

  static Future<Uint8List> generatePdf(PedigreeData data) async {
    final pdf = pw.Document(compress: true);

    // ─── 1. Load Assets ───────────────────────────────────────────────────────
    final logoByteData = await rootBundle.load(PedigreeLayout.logoAsset);
    final logoImage = pw.MemoryImage(logoByteData.buffer.asUint8List());

    // ─── 2. Load Bundled TTF Fonts ───────────────────────────────────────────
    final fontTitleData = await rootBundle.load(PedigreeLayout.fontTitleAsset);
    final fontDetailsData = await rootBundle.load(PedigreeLayout.fontDetailsAsset);
    final fontDetailsBoldData = await rootBundle.load(PedigreeLayout.fontDetailsBoldAsset);
    final fontSignatureData = await rootBundle.load(PedigreeLayout.fontSignatureAsset);

    final fontTitle = pw.Font.ttf(fontTitleData);
    final fontDetails = pw.Font.ttf(fontDetailsData);
    final fontDetailsBold = pw.Font.ttf(fontDetailsBoldData);
    final fontSignature = pw.Font.ttf(fontSignatureData);

    // ─── 3. Load Subject Photo ────────────────────────────────────────────────
    pw.MemoryImage? subjectPhoto;
    if (data.subjectPhotoPath != null && data.subjectPhotoPath!.isNotEmpty) {
      final file = File(data.subjectPhotoPath!);
      if (await file.exists()) {
        subjectPhoto = pw.MemoryImage(await file.readAsBytes());
      }
    }

    // ─── 4. Build Document Page ───────────────────────────────────────────────
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.letter.landscape,
        margin: pw.EdgeInsets.zero,
        build: (pw.Context context) {
          final double W = PdfPageFormat.letter.landscape.width;
          final double H = PdfPageFormat.letter.landscape.height;

          // Auto-scale farm title font size
          double farmTitleSize = W * PedigreeLayout.fontRatioFarmTitle;
          if (data.farmName.length > 18) {
            farmTitleSize = (farmTitleSize * 18 / data.farmName.length)
                .clamp(W * 0.025, W * PedigreeLayout.fontRatioFarmTitle);
          }

          final tree = data.tree;

          return pw.Stack(
            children: [
              // Plain White Page Background
              pw.Positioned.fill(
                child: pw.Container(color: PdfColors.white),
              ),

              // ─── Top Left: Farm Header ──────────────────────────────────────
              pw.Positioned(
                left: W * PedigreeLayout.farmTitleLeft,
                top: H * PedigreeLayout.farmTitleCenterY - (H * PedigreeLayout.farmTitleBoxHeight / 2),
                child: pw.SizedBox(
                  width: W * PedigreeLayout.farmTitleMaxWidth,
                  height: H * PedigreeLayout.farmTitleBoxHeight,
                  child: pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(
                      data.farmName,
                      style: pw.TextStyle(
                        font: fontTitle,
                        fontSize: farmTitleSize,
                        color: PedigreeLayout.pdfColorHeaderTitle,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),

              // Address and Email line
              if (data.farmAddress.isNotEmpty || data.farmEmail.isNotEmpty)
                pw.Positioned(
                  left: W * PedigreeLayout.addressLeft,
                  top: H * PedigreeLayout.contactCenterY - (H * PedigreeLayout.contactBoxHeight / 2),
                  child: pw.Row(
                    children: [
                      if (data.farmAddress.isNotEmpty)
                        pw.Text(
                          data.farmAddress,
                          style: pw.TextStyle(
                            font: fontDetails,
                            fontSize: W * PedigreeLayout.fontRatioHeaderContact,
                            color: PedigreeLayout.pdfColorHeaderContact,
                          ),
                        ),
                      if (data.farmAddress.isNotEmpty && data.farmEmail.isNotEmpty)
                        pw.SizedBox(width: W * 0.04),
                      if (data.farmEmail.isNotEmpty)
                        pw.Text(
                          data.farmEmail,
                          style: pw.TextStyle(
                            font: fontDetails,
                            fontSize: W * PedigreeLayout.fontRatioHeaderContact,
                            color: PedigreeLayout.pdfColorHeaderContact,
                          ),
                        ),
                    ],
                  ),
                ),

              // Header Underline
              pw.Positioned(
                left: W * PedigreeLayout.underlineX0,
                top: H * PedigreeLayout.underlineY,
                child: pw.Container(
                  width: W * (PedigreeLayout.underlineX1 - PedigreeLayout.underlineX0),
                  height: 0.75,
                  color: PedigreeLayout.pdfColorHeaderUnderline,
                ),
              ),

              // ─── "Bunny Pedigree" Logo ──────────────────────────────────────
              pw.Positioned(
                left: W * PedigreeLayout.logoLeft,
                top: H * PedigreeLayout.logoTop,
                child: pw.SizedBox(
                  width: W * PedigreeLayout.logoWidth,
                  height: H * PedigreeLayout.logoHeight,
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                ),
              ),

              // ─── Left: Subject Details Box ──────────────────────────────────
              pw.Positioned(
                left: W * PedigreeLayout.subjectBoxLeft,
                top: H * PedigreeLayout.subjectBoxTop,
                child: pw.Container(
                  width: W * PedigreeLayout.subjectBoxWidth,
                  height: H * PedigreeLayout.subjectBoxHeight,
                  decoration: pw.BoxDecoration(
                    color: PedigreeLayout.pdfColorSubjectBoxBg,
                    borderRadius: pw.BorderRadius.all(
                      pw.Radius.circular(W * PedigreeLayout.subjectBoxRadius),
                    ),
                  ),
                ),
              ),

              // Subject Details Rows
              ..._buildSubjectSingleRow(W, H, fontDetails, fontDetailsBold, PedigreeLayout.subjectNameCenterY, 'Name:', data.subjectName),
              ..._buildSubjectSingleRow(W, H, fontDetails, fontDetailsBold, PedigreeLayout.subjectColorCenterY, 'Color:', data.subjectColor),
              ..._buildSubjectSingleRow(W, H, fontDetails, fontDetailsBold, PedigreeLayout.subjectBreedCenterY, 'Breed:', data.subjectBreed),
              ..._buildSubjectSingleRow(W, H, fontDetails, fontDetailsBold, PedigreeLayout.subjectSexCenterY, 'Sex:', data.subjectSex),
              ..._buildSubjectSingleRow(W, H, fontDetails, fontDetailsBold, PedigreeLayout.subjectDobCenterY, 'DOB:', data.subjectDob),
              ..._buildSubjectDualRow(W, H, fontDetails, fontDetailsBold, PedigreeLayout.subjectEarWtCenterY, 'Ear No.:', data.subjectEarNo, 'Wt:', data.subjectWeight),
              ..._buildSubjectDualRow(W, H, fontDetails, fontDetailsBold, PedigreeLayout.subjectRegLegsCenterY, 'Reg No.:', data.subjectRegNo, 'Legs:', data.subjectLegs),

              // ─── Subject Photo Ellipse ──────────────────────────────────────
              pw.Positioned(
                left: W * PedigreeLayout.photoLeft,
                top: H * PedigreeLayout.photoTop,
                child: pw.Container(
                  width: W * PedigreeLayout.photoWidth,
                  height: H * PedigreeLayout.photoHeight,
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.all(
                      pw.Radius.elliptical(
                        W * PedigreeLayout.photoWidth / 2,
                        H * PedigreeLayout.photoHeight / 2,
                      ),
                    ),
                    border: pw.Border.all(
                      color: PedigreeLayout.pdfColorSubjectPhotoOutline,
                      width: PedigreeLayout.photoOutlineWidthPt,
                    ),
                    color: subjectPhoto == null ? const PdfColor(0.92, 0.92, 0.92) : null,
                  ),
                  child: subjectPhoto != null
                      ? pw.ClipOval(
                          child: pw.Image(subjectPhoto, fit: pw.BoxFit.cover),
                        )
                      : pw.SizedBox(),
                ),
              ),

              // ─── Generation 1 (Parents) ─────────────────────────────────────
              ..._buildAncestorCard(W, H, fontDetails, fontDetailsBold, 1, 'Sire', true, PedigreeLayout.sireLeft, PedigreeLayout.sireTop, tree?.sire),
              ..._buildAncestorCard(W, H, fontDetails, fontDetailsBold, 1, 'Dam', false, PedigreeLayout.damLeft, PedigreeLayout.damTop, tree?.dam),

              // ─── Generation 2 (Grandparents) ────────────────────────────────
              ..._buildAncestorCard(W, H, fontDetails, fontDetailsBold, 2, 'G.Sire', true, PedigreeLayout.ssLeft, PedigreeLayout.ssTop, tree?.sire?.sire),
              ..._buildAncestorCard(W, H, fontDetails, fontDetailsBold, 2, 'G.Dam', false, PedigreeLayout.sdLeft, PedigreeLayout.sdTop, tree?.sire?.dam),
              ..._buildAncestorCard(W, H, fontDetails, fontDetailsBold, 2, 'G.Sire', true, PedigreeLayout.dsLeft, PedigreeLayout.dsTop, tree?.dam?.sire),
              ..._buildAncestorCard(W, H, fontDetails, fontDetailsBold, 2, 'G.Dam', false, PedigreeLayout.ddLeft, PedigreeLayout.ddTop, tree?.dam?.dam),

              // ─── Generation 3 (Great-Grandparents) ───────────────────────────
              ..._buildAncestorCard(W, H, fontDetails, fontDetailsBold, 3, 'G.G.Sire', true, PedigreeLayout.gen3Left, PedigreeLayout.sssTop, tree?.sire?.sire?.sire),
              ..._buildAncestorCard(W, H, fontDetails, fontDetailsBold, 3, 'G.G.Dam', false, PedigreeLayout.gen3Left, PedigreeLayout.ssdTop, tree?.sire?.sire?.dam),
              ..._buildAncestorCard(W, H, fontDetails, fontDetailsBold, 3, 'G.G.Sire', true, PedigreeLayout.gen3Left, PedigreeLayout.sdsTop, tree?.sire?.dam?.sire),
              ..._buildAncestorCard(W, H, fontDetails, fontDetailsBold, 3, 'G.G.Dam', false, PedigreeLayout.gen3Left, PedigreeLayout.sddTop, tree?.sire?.dam?.dam),
              ..._buildAncestorCard(W, H, fontDetails, fontDetailsBold, 3, 'G.G.Sire', true, PedigreeLayout.gen3Left, PedigreeLayout.dssTop, tree?.dam?.sire?.sire),
              ..._buildAncestorCard(W, H, fontDetails, fontDetailsBold, 3, 'G.G.Dam', false, PedigreeLayout.gen3Left, PedigreeLayout.dsdTop, tree?.dam?.sire?.dam),
              ..._buildAncestorCard(W, H, fontDetails, fontDetailsBold, 3, 'G.G.Sire', true, PedigreeLayout.gen3Left, PedigreeLayout.ddsTop, tree?.dam?.dam?.sire),
              ..._buildAncestorCard(W, H, fontDetails, fontDetailsBold, 3, 'G.G.Dam', false, PedigreeLayout.gen3Left, PedigreeLayout.dddTop, tree?.dam?.dam?.dam),

              // ─── Bottom Left: Certification & Footer ────────────────────────
              // Line 1: "I hereby certify this pedigree is correct"
              pw.Positioned(
                left: W * PedigreeLayout.certifyLeft,
                top: H * PedigreeLayout.certifyLine1CenterY - (H * PedigreeLayout.certifyBoxHeight / 2),
                child: pw.SizedBox(
                  height: H * PedigreeLayout.certifyBoxHeight,
                  child: pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(
                      'I hereby certify this pedigree is correct',
                      style: pw.TextStyle(
                        font: fontDetails,
                        fontSize: W * PedigreeLayout.fontRatioCertify,
                        color: PedigreeLayout.pdfColorFooterCertify,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),

              // Line 2: "to the best of my knowledge"
              pw.Positioned(
                left: W * PedigreeLayout.certifyLeft,
                top: H * PedigreeLayout.certifyLine2CenterY - (H * PedigreeLayout.certifyBoxHeight / 2),
                child: pw.SizedBox(
                  height: H * PedigreeLayout.certifyBoxHeight,
                  child: pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(
                      'to the best of my knowledge',
                      style: pw.TextStyle(
                        font: fontDetails,
                        fontSize: W * PedigreeLayout.fontRatioCertify,
                        color: PedigreeLayout.pdfColorFooterCertify,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),

              // Breeder Signature
              if (data.ownerName.trim().isNotEmpty)
                pw.Positioned(
                  left: W * PedigreeLayout.signatureLeft,
                  top: H * PedigreeLayout.signatureCenterY - (H * PedigreeLayout.signatureBoxHeight / 2),
                  child: pw.SizedBox(
                    height: H * PedigreeLayout.signatureBoxHeight,
                    child: pw.Align(
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        data.ownerName.trim(),
                        style: pw.TextStyle(
                          font: fontSignature,
                          fontSize: W * PedigreeLayout.fontRatioSignature,
                          color: PedigreeLayout.pdfColorFooterSignature,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),

              // Signature Underline
              pw.Positioned(
                left: W * PedigreeLayout.signatureUnderlineX0,
                top: H * PedigreeLayout.signatureUnderlineY,
                child: pw.Container(
                  width: W * (PedigreeLayout.signatureUnderlineX1 - PedigreeLayout.signatureUnderlineX0),
                  height: 0.75,
                  color: PedigreeLayout.pdfColorHeaderUnderline,
                ),
              ),

              // Phone Number
              if (data.farmPhone.trim().isNotEmpty)
                pw.Positioned(
                  left: W * PedigreeLayout.phoneLeft,
                  top: H * PedigreeLayout.phoneCenterY - (H * PedigreeLayout.phoneBoxHeight / 2),
                  child: pw.SizedBox(
                    height: H * PedigreeLayout.phoneBoxHeight,
                    child: pw.Align(
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        data.farmPhone.trim(),
                        style: pw.TextStyle(
                          font: fontDetails,
                          fontSize: W * PedigreeLayout.fontRatioPhone,
                          color: PedigreeLayout.pdfColorFooterPhone,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ─── SUBJECT ROW BUILDERS ───────────────────────────────────────────────────

  static List<pw.Widget> _buildSubjectSingleRow(
    double W,
    double H,
    pw.Font font,
    pw.Font fontBold,
    double centerY,
    String label,
    String value,
  ) {
    final rowHeight = H * PedigreeLayout.subjectRowBoxHeight;
    return [
      pw.Positioned(
        left: W * PedigreeLayout.subjectTextLeft,
        top: H * centerY - (rowHeight / 2),
        child: pw.SizedBox(
          width: W * (PedigreeLayout.subjectBoxWidth - 0.015),
          height: rowHeight,
          child: pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: '$label ',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: W * PedigreeLayout.fontRatioSubject,
                      color: PedigreeLayout.pdfColorSubjectText,
                    ),
                  ),
                  pw.TextSpan(
                    text: value,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: W * PedigreeLayout.fontRatioSubject,
                      color: PedigreeLayout.pdfColorSubjectText,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
            ),
          ),
        ),
      ),
    ];
  }

  static List<pw.Widget> _buildSubjectDualRow(
    double W,
    double H,
    pw.Font font,
    pw.Font fontBold,
    double centerY,
    String label1,
    String value1,
    String label2,
    String value2,
  ) {
    final rowHeight = H * PedigreeLayout.subjectRowBoxHeight;
    return [
      // Col 1
      pw.Positioned(
        left: W * PedigreeLayout.subjectTextLeft,
        top: H * centerY - (rowHeight / 2),
        child: pw.SizedBox(
          width: W * (PedigreeLayout.subjectSecondColLeft - PedigreeLayout.subjectTextLeft),
          height: rowHeight,
          child: pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: '$label1 ',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: W * PedigreeLayout.fontRatioSubject,
                      color: PedigreeLayout.pdfColorSubjectText,
                    ),
                  ),
                  pw.TextSpan(
                    text: value1,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: W * PedigreeLayout.fontRatioSubject,
                      color: PedigreeLayout.pdfColorSubjectText,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
            ),
          ),
        ),
      ),
      // Col 2
      pw.Positioned(
        left: W * PedigreeLayout.subjectSecondColLeft,
        top: H * centerY - (rowHeight / 2),
        child: pw.SizedBox(
          width: W * (PedigreeLayout.subjectBoxLeft + PedigreeLayout.subjectBoxWidth - PedigreeLayout.subjectSecondColLeft - 0.005),
          height: rowHeight,
          child: pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: '$label2 ',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: W * PedigreeLayout.fontRatioSubject,
                      color: PedigreeLayout.pdfColorSubjectText,
                    ),
                  ),
                  pw.TextSpan(
                    text: value2,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: W * PedigreeLayout.fontRatioSubject,
                      color: PedigreeLayout.pdfColorSubjectText,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
            ),
          ),
        ),
      ),
    ];
  }

  // ─── ANCESTOR CARD BUILDER ──────────────────────────────────────────────────

  static List<pw.Widget> _buildAncestorCard(
    double W,
    double H,
    pw.Font font,
    pw.Font fontBold,
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

    // Auto-shrink ancestor name if too long
    double nameFontSize = baseFontSize;
    final int charLimit = generation == 3 ? 18 : 22;
    if (name.length > charLimit) {
      nameFontSize = (baseFontSize * charLimit / name.length)
          .clamp(generation == 3 ? baseFontSize * 0.70 : baseFontSize * 0.65, baseFontSize);
    }

    final double rowHeight = H * (generation == 3 ? 0.0240 : 0.0280);

    return [
      // Card Container Background
      pw.Positioned(
        left: W * left,
        top: H * top,
        child: pw.Container(
          width: W * cardW,
          height: H * cardH,
          decoration: pw.BoxDecoration(
            color: isSireSide ? PedigreeLayout.pdfColorSireCardBg : PedigreeLayout.pdfColorDamCardBg,
            borderRadius: pw.BorderRadius.all(
              pw.Radius.circular(W * PedigreeLayout.cardCornerRadius),
            ),
          ),
        ),
      ),

      // Row 0: Role & Name
      pw.Positioned(
        left: W * (left + textDx),
        top: H * (top + rowDy[0]) - (rowHeight / 2),
        child: pw.SizedBox(
          width: W * (cardW - textDx - 0.005),
          height: rowHeight,
          child: pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: '$role: ',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: nameFontSize,
                      color: PedigreeLayout.pdfColorCardText,
                    ),
                  ),
                  pw.TextSpan(
                    text: name,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: nameFontSize,
                      color: PedigreeLayout.pdfColorCardText,
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
      pw.Positioned(
        left: W * (left + textDx),
        top: H * (top + rowDy[1]) - (rowHeight / 2),
        child: pw.SizedBox(
          width: W * (cardW - textDx - 0.005),
          height: rowHeight,
          child: pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: 'Color: ',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: baseFontSize,
                      color: PedigreeLayout.pdfColorCardText,
                    ),
                  ),
                  pw.TextSpan(
                    text: color,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: baseFontSize,
                      color: PedigreeLayout.pdfColorCardText,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
            ),
          ),
        ),
      ),

      // Row 2: DOB & Wt
      // Col 1: DOB
      pw.Positioned(
        left: W * (left + textDx),
        top: H * (top + rowDy[2]) - (rowHeight / 2),
        child: pw.SizedBox(
          width: W * (secondColDx - textDx),
          height: rowHeight,
          child: pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: 'DOB: ',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: baseFontSize,
                      color: PedigreeLayout.pdfColorCardText,
                    ),
                  ),
                  pw.TextSpan(
                    text: dob,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: baseFontSize,
                      color: PedigreeLayout.pdfColorCardText,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
            ),
          ),
        ),
      ),
      // Col 2: Wt
      pw.Positioned(
        left: W * (left + secondColDx),
        top: H * (top + rowDy[2]) - (rowHeight / 2),
        child: pw.SizedBox(
          width: W * (cardW - secondColDx - 0.004),
          height: rowHeight,
          child: pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: 'Wt: ',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: baseFontSize,
                      color: PedigreeLayout.pdfColorCardText,
                    ),
                  ),
                  pw.TextSpan(
                    text: wt,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: baseFontSize,
                      color: PedigreeLayout.pdfColorCardText,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
            ),
          ),
        ),
      ),

      // Row 3: Ear No. & Legs
      // Col 1: Ear No.
      pw.Positioned(
        left: W * (left + textDx),
        top: H * (top + rowDy[3]) - (rowHeight / 2),
        child: pw.SizedBox(
          width: W * (secondColDx - textDx),
          height: rowHeight,
          child: pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: 'Ear No.: ',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: baseFontSize,
                      color: PedigreeLayout.pdfColorCardText,
                    ),
                  ),
                  pw.TextSpan(
                    text: earNo,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: baseFontSize,
                      color: PedigreeLayout.pdfColorCardText,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
            ),
          ),
        ),
      ),
      // Col 2: Legs
      pw.Positioned(
        left: W * (left + secondColDx),
        top: H * (top + rowDy[3]) - (rowHeight / 2),
        child: pw.SizedBox(
          width: W * (cardW - secondColDx - 0.004),
          height: rowHeight,
          child: pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: 'Legs: ',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: baseFontSize,
                      color: PedigreeLayout.pdfColorCardText,
                    ),
                  ),
                  pw.TextSpan(
                    text: legs,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: baseFontSize,
                      color: PedigreeLayout.pdfColorCardText,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
            ),
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
      if (oz > 0) return '${lbs}lb ${oz}oz';
      return '${lbs}lbs';
    }
    return wtStr.trim();
  }
}
