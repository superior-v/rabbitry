import 'dart:io';
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
    if (data.isPortrait) {
      pdf.addPage(
        _buildPortraitPdfPage(
          data: data,
          logoImage: logoImage,
          fontTitle: fontTitle,
          fontDetails: fontDetails,
          fontDetailsBold: fontDetailsBold,
          fontSignature: fontSignature,
          subjectPhoto: subjectPhoto,
        ),
      );
    } else {
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
    }

    return pdf.save();
  }

  // ─── PORTRAIT PDF PAGE BUILDER ──────────────────────────────────────────────
  static pw.Page _buildPortraitPdfPage({
    required PedigreeData data,
    required pw.MemoryImage logoImage,
    required pw.Font fontTitle,
    required pw.Font fontDetails,
    required pw.Font fontDetailsBold,
    required pw.Font fontSignature,
    required pw.MemoryImage? subjectPhoto,
  }) {
    return pw.Page(
      pageFormat: PdfPageFormat.letter.portrait,
      margin: pw.EdgeInsets.zero,
      build: (pw.Context context) {
        double farmTitleSize = 30.0;
        if (data.farmName.length > 20) {
          farmTitleSize = (farmTitleSize * 20 / data.farmName.length).clamp(18.0, 30.0);
        }

        final tree = data.tree;

        return pw.Stack(
          children: [
            // White background
            pw.Positioned.fill(
              child: pw.Container(color: PdfColors.white),
            ),

            // Farm Title
            pw.Positioned(
              left: 16.0,
              top: 18.0,
              child: pw.SizedBox(
                width: 380.0,
                height: 44.0,
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

            // Farm Contact Line
            pw.Positioned(
              left: 16.0,
              top: 62.0,
              child: pw.SizedBox(
                width: 480.0,
                height: 18.0,
                child: pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    [
                      if (data.farmAddress.isNotEmpty) data.farmAddress,
                      if (data.farmEmail.isNotEmpty) data.farmEmail,
                      if (data.farmPhone.isNotEmpty) data.farmPhone,
                    ].join('  •  '),
                    style: pw.TextStyle(
                      font: fontDetails,
                      fontSize: 10.0,
                      color: PedigreeLayout.pdfColorHeaderContact,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ),

            // Bunny Logo Image
            pw.Positioned(
              left: 520.0,
              top: 16.0,
              child: pw.SizedBox(
                width: 76.0,
                height: 66.0,
                child: pw.Image(logoImage, fit: pw.BoxFit.contain),
              ),
            ),

            // Header Separator Line
            pw.Positioned(
              left: 16.0,
              top: 86.0,
              child: pw.Container(
                width: 580.0,
                height: 0.8,
                color: PedigreeLayout.pdfColorHeaderUnderline,
              ),
            ),

            // Subject Box
            pw.Positioned(
              left: 16.0,
              top: 96.0,
              child: pw.Container(
                width: 390.0,
                height: 126.0,
                decoration: const pw.BoxDecoration(
                  color: PedigreeLayout.pdfColorSubjectBoxBg,
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(8.0)),
                ),
                padding: const pw.EdgeInsets.symmetric(horizontal: 10.0, vertical: 8.0),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
                  children: [
                    pw.RichText(
                      text: pw.TextSpan(
                        children: [
                          pw.TextSpan(
                            text: 'Subject: ',
                            style: pw.TextStyle(
                              font: fontDetailsBold,
                              fontSize: 13.0,
                              color: PedigreeLayout.pdfColorSubjectText,
                            ),
                          ),
                          pw.TextSpan(
                            text: data.subjectName,
                            style: pw.TextStyle(
                              font: fontDetailsBold,
                              fontSize: 13.0,
                              color: PedigreeLayout.pdfColorSubjectText,
                            ),
                          ),
                          if (data.subjectBreed.isNotEmpty)
                            pw.TextSpan(
                              text: ' (${data.subjectBreed})',
                              style: pw.TextStyle(
                                font: fontDetails,
                                fontSize: 12.0,
                                color: PedigreeLayout.pdfColorSubjectText,
                              ),
                            ),
                        ],
                      ),
                      maxLines: 1,
                    ),
                    _buildPortraitPdfSubjectRow(fontDetails, fontDetailsBold, 'Color:', data.subjectColor, 'Sex:', data.subjectSex),
                    _buildPortraitPdfSubjectRow(fontDetails, fontDetailsBold, 'DOB:', data.subjectDob, 'Ear No.:', data.subjectEarNo),
                    _buildPortraitPdfSubjectRow(fontDetails, fontDetailsBold, 'Weight:', data.subjectWeight, 'Reg No.:', data.subjectRegNo),
                    _buildPortraitPdfSubjectRow(fontDetails, fontDetailsBold, 'Legs:', data.subjectLegs, '', ''),
                  ],
                ),
              ),
            ),

            // Subject Photo Box
            pw.Positioned(
              left: 416.0,
              top: 96.0,
              child: pw.Container(
                width: 180.0,
                height: 126.0,
                decoration: pw.BoxDecoration(
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8.0)),
                  border: pw.Border.all(
                    color: PedigreeLayout.pdfColorSubjectPhotoOutline,
                    width: 1.5,
                  ),
                  color: subjectPhoto == null ? const PdfColor.fromInt(0x0A000000) : null,
                ),
                child: subjectPhoto != null
                    ? pw.ClipRRect(
                        horizontalRadius: 8.0,
                        verticalRadius: 8.0,
                        child: pw.Image(subjectPhoto, fit: pw.BoxFit.cover),
                      )
                    : pw.Center(
                        child: pw.Text(
                          'No Photo',
                          style: pw.TextStyle(
                            font: fontDetails,
                            fontSize: 10.0,
                            color: PedigreeLayout.pdfColorSubjectPhotoOutline,
                          ),
                        ),
                      ),
              ),
            ),

            // ─── Ancestor Cards (Sire Top Half) ───────────────────────
            ..._buildPortraitPdfCard(fontDetails, fontDetailsBold, 1, 'Sire', true, 16.0, 234.0, 178.0, 226.0, tree?.sire),
            ..._buildPortraitPdfCard(fontDetails, fontDetailsBold, 2, 'G.Sire', true, 202.0, 234.0, 186.0, 108.0, tree?.sire?.sire),
            ..._buildPortraitPdfCard(fontDetails, fontDetailsBold, 2, 'G.Dam', false, 202.0, 352.0, 186.0, 108.0, tree?.sire?.dam),

            ..._buildPortraitPdfCard(fontDetails, fontDetailsBold, 3, 'G.G.Sire', true, 396.0, 234.0, 200.0, 50.0, tree?.sire?.sire?.sire),
            ..._buildPortraitPdfCard(fontDetails, fontDetailsBold, 3, 'G.G.Dam', false, 396.0, 292.0, 200.0, 50.0, tree?.sire?.sire?.dam),
            ..._buildPortraitPdfCard(fontDetails, fontDetailsBold, 3, 'G.G.Sire', true, 396.0, 352.0, 200.0, 50.0, tree?.sire?.dam?.sire),
            ..._buildPortraitPdfCard(fontDetails, fontDetailsBold, 3, 'G.G.Dam', false, 396.0, 410.0, 200.0, 50.0, tree?.sire?.dam?.dam),

            // ─── Ancestor Cards (Dam Bottom Half) ─────────────────────
            ..._buildPortraitPdfCard(fontDetails, fontDetailsBold, 1, 'Dam', false, 16.0, 480.0, 178.0, 226.0, tree?.dam),
            ..._buildPortraitPdfCard(fontDetails, fontDetailsBold, 2, 'G.Sire', true, 202.0, 480.0, 186.0, 108.0, tree?.dam?.sire),
            ..._buildPortraitPdfCard(fontDetails, fontDetailsBold, 2, 'G.Dam', false, 202.0, 598.0, 186.0, 108.0, tree?.dam?.dam),

            ..._buildPortraitPdfCard(fontDetails, fontDetailsBold, 3, 'G.G.Sire', true, 396.0, 480.0, 200.0, 50.0, tree?.dam?.sire?.sire),
            ..._buildPortraitPdfCard(fontDetails, fontDetailsBold, 3, 'G.G.Dam', false, 396.0, 538.0, 200.0, 50.0, tree?.dam?.sire?.dam),
            ..._buildPortraitPdfCard(fontDetails, fontDetailsBold, 3, 'G.G.Sire', true, 396.0, 598.0, 200.0, 50.0, tree?.dam?.dam?.sire),
            ..._buildPortraitPdfCard(fontDetails, fontDetailsBold, 3, 'G.G.Dam', false, 396.0, 656.0, 200.0, 50.0, tree?.dam?.dam?.dam),

            // ─── Footer ───────────────────────────────────────────────
            pw.Positioned(
              left: 16.0,
              top: 722.0,
              child: pw.Text(
                'I hereby certify this pedigree is correct to the best of my knowledge.',
                style: pw.TextStyle(
                  font: fontDetails,
                  fontSize: 9.0,
                  color: PedigreeLayout.pdfColorFooterCertify,
                ),
              ),
            ),
            pw.Positioned(
              left: 16.0,
              top: 760.0,
              child: pw.Container(
                width: 180.0,
                height: 0.75,
                color: PedigreeLayout.pdfColorHeaderUnderline,
              ),
            ),
            if (data.ownerName.trim().isNotEmpty)
              pw.Positioned(
                left: 18.0,
                top: 738.0,
                child: pw.Text(
                  data.ownerName.trim(),
                  style: pw.TextStyle(
                    font: fontSignature,
                    fontSize: 18.0,
                    color: PedigreeLayout.pdfColorFooterSignature,
                  ),
                ),
              ),
            if (data.farmPhone.trim().isNotEmpty)
              pw.Positioned(
                left: 450.0,
                top: 742.0,
                child: pw.Text(
                  'Tel: ${data.farmPhone.trim()}',
                  style: pw.TextStyle(
                    font: fontDetails,
                    fontSize: 10.0,
                    color: PedigreeLayout.pdfColorFooterPhone,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  static pw.Widget _buildPortraitPdfSubjectRow(
    pw.Font fontDetails,
    pw.Font fontDetailsBold,
    String label1,
    String val1,
    String label2,
    String val2,
  ) {
    return pw.Row(
      children: [
        pw.Expanded(
          flex: 6,
          child: pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: '$label1 ',
                  style: pw.TextStyle(
                    font: fontDetailsBold,
                    fontSize: 10.0,
                    color: PedigreeLayout.pdfColorSubjectText,
                  ),
                ),
                pw.TextSpan(
                  text: val1,
                  style: pw.TextStyle(
                    font: fontDetails,
                    fontSize: 10.0,
                    color: PedigreeLayout.pdfColorSubjectText,
                  ),
                ),
              ],
            ),
            maxLines: 1,
          ),
        ),
        if (label2.isNotEmpty)
          pw.Expanded(
            flex: 5,
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: '$label2 ',
                    style: pw.TextStyle(
                      font: fontDetailsBold,
                      fontSize: 10.0,
                      color: PedigreeLayout.pdfColorSubjectText,
                    ),
                  ),
                  pw.TextSpan(
                    text: val2,
                    style: pw.TextStyle(
                      font: fontDetails,
                      fontSize: 10.0,
                      color: PedigreeLayout.pdfColorSubjectText,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
            ),
          )
        else
          pw.Spacer(flex: 5),
      ],
    );
  }

  static List<pw.Widget> _buildPortraitPdfCard(
    pw.Font font,
    pw.Font fontBold,
    int generation,
    String role,
    bool isSireSide,
    double left,
    double top,
    double width,
    double height,
    PedigreeRabbit? rabbit,
  ) {
    final String name = rabbit?.name ?? '';
    final String color = rabbit?.color ?? '';
    final String dob = rabbit?.dateOfBirth != null
        ? FormatUtils.formatCertificateDate(rabbit!.dateOfBirth)
        : '';
    final String wt = _formatCardWeight(rabbit?.weight);
    final String earNo = rabbit?.earNumber ?? '';
    final String legs = (rabbit?.legs != null && rabbit!.legs! > 0)
        ? '${rabbit.legs}'
        : '';

    final double titleSize = generation == 1
        ? 11.5
        : (generation == 2 ? 9.5 : 8.0);
    final double textSize = generation == 1
        ? 10.5
        : (generation == 2 ? 8.5 : 7.0);

    return [
      pw.Positioned(
        left: left,
        top: top,
        child: pw.Container(
          width: width,
          height: height,
          decoration: pw.BoxDecoration(
            color: isSireSide
                ? PedigreeLayout.pdfColorSireCardBg
                : PedigreeLayout.pdfColorDamCardBg,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6.0)),
          ),
          padding: pw.EdgeInsets.symmetric(
            horizontal: 6.0,
            vertical: (generation == 3 ? 3.0 : 6.0),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
            children: [
              // Role & Name
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: '$role: ',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: titleSize,
                        color: PedigreeLayout.pdfColorCardText,
                      ),
                    ),
                    pw.TextSpan(
                      text: name,
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: titleSize,
                        color: PedigreeLayout.pdfColorCardText,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
              ),

              // Color
              pw.RichText(
                text: pw.TextSpan(
                  children: [
                    pw.TextSpan(
                      text: 'Color: ',
                      style: pw.TextStyle(
                        font: fontBold,
                        fontSize: textSize,
                        color: PedigreeLayout.pdfColorCardText,
                      ),
                    ),
                    pw.TextSpan(
                      text: color,
                      style: pw.TextStyle(
                        font: font,
                        fontSize: textSize,
                        color: PedigreeLayout.pdfColorCardText,
                      ),
                    ),
                  ],
                ),
                maxLines: 1,
              ),

              // DOB & Wt
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 6,
                    child: pw.RichText(
                      text: pw.TextSpan(
                        children: [
                          pw.TextSpan(
                            text: 'DOB: ',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: textSize,
                              color: PedigreeLayout.pdfColorCardText,
                            ),
                          ),
                          pw.TextSpan(
                            text: dob,
                            style: pw.TextStyle(
                              font: font,
                              fontSize: textSize,
                              color: PedigreeLayout.pdfColorCardText,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                    ),
                  ),
                  pw.Expanded(
                    flex: 5,
                    child: pw.RichText(
                      text: pw.TextSpan(
                        children: [
                          pw.TextSpan(
                            text: 'Wt: ',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: textSize,
                              color: PedigreeLayout.pdfColorCardText,
                            ),
                          ),
                          pw.TextSpan(
                            text: wt,
                            style: pw.TextStyle(
                              font: font,
                              fontSize: textSize,
                              color: PedigreeLayout.pdfColorCardText,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                    ),
                  ),
                ],
              ),

              // Ear No. & Legs
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 6,
                    child: pw.RichText(
                      text: pw.TextSpan(
                        children: [
                          pw.TextSpan(
                            text: 'Ear No.: ',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: textSize,
                              color: PedigreeLayout.pdfColorCardText,
                            ),
                          ),
                          pw.TextSpan(
                            text: earNo,
                            style: pw.TextStyle(
                              font: font,
                              fontSize: textSize,
                              color: PedigreeLayout.pdfColorCardText,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                    ),
                  ),
                  pw.Expanded(
                    flex: 5,
                    child: pw.RichText(
                      text: pw.TextSpan(
                        children: [
                          pw.TextSpan(
                            text: 'Legs: ',
                            style: pw.TextStyle(
                              font: fontBold,
                              fontSize: textSize,
                              color: PedigreeLayout.pdfColorCardText,
                            ),
                          ),
                          pw.TextSpan(
                            text: legs,
                            style: pw.TextStyle(
                              font: font,
                              fontSize: textSize,
                              color: PedigreeLayout.pdfColorCardText,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ];
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
      if (oz > 0) return '${lbs}lbs ${oz}oz';
      return '${lbs}lbs';
    }
    return wtStr.trim();
  }
}
