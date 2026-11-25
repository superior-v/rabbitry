import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../widgets/pedigree_layout.dart';
import '../models/pedigree.dart';
import 'format_utils.dart';
import 'settings_service.dart';

class PedigreePdfService {
  PedigreePdfService._();

  /// Generates the Pedigree PDF document as a Uint8List byte array.
  static Future<Uint8List> generatePedigree(PedigreeData data) => generatePdf(data);

  static Future<pw.Font> _loadFontWithFallback(
    List<String> candidates,
    String fallbackAsset,
  ) async {
    for (final path in candidates) {
      try {
        final data = await rootBundle.load(path);
        return pw.Font.ttf(data);
      } catch (_) {}
    }
    final fallbackData = await rootBundle.load(fallbackAsset);
    return pw.Font.ttf(fallbackData);
  }

  static Future<Uint8List> generatePdf(PedigreeData data) async {
    final pdf = pw.Document(compress: true);

    // ─── 1. Load Assets ───────────────────────────────────────────────────────
    final logoByteData = await rootBundle.load(PedigreeLayout.logoAsset);
    final logoImage = pw.MemoryImage(logoByteData.buffer.asUint8List());

    // ─── 2. Load Bundled TTF Fonts ───────────────────────────────────────────
    final fontDetailsData = await rootBundle.load(PedigreeLayout.fontDetailsAsset);
    final fontDetailsBoldData = await rootBundle.load(PedigreeLayout.fontDetailsBoldAsset);

    // Landscape header/signature fonts: Overthink + The December (fallback to
    // the older bundled script fonts until the font files are added).
    final fontTitle = await _loadFontWithFallback(
      const [
        'assets/fonts/Overthink-Regular.ttf',
        'assets/fonts/Overthink.ttf',
        'assets/fonts/Overthink.otf',
      ],
      PedigreeLayout.fontTitleAsset,
    );
    final fontDetails = pw.Font.ttf(fontDetailsData);
    final fontDetailsBold = pw.Font.ttf(fontDetailsBoldData);
    final fontSignature = await _loadFontWithFallback(
      const [
        'assets/fonts/TheDecember-Regular.ttf',
        'assets/fonts/TheDecember.ttf',
        'assets/fonts/The December.ttf',
        'assets/fonts/TheDecember.otf',
      ],
      PedigreeLayout.fontSignatureAsset,
    );

    // Portrait-specific fonts (Cabinet of the Outlander, Myriad Pro, Myriad Pro Semi Bold, Overthink)
    final fontPortraitTitle = await _loadFontWithFallback(
      const [
        'assets/fonts/Overthink-Regular.ttf',
        'assets/fonts/Overthink.ttf',
        'assets/fonts/Overthink.otf',
      ],
      'assets/fonts/Shakies-OpenType-TT.ttf',
    );
    final fontPortraitRegular = await _loadFontWithFallback(
      const [
        'assets/fonts/MyriadPro-Regular.ttf',
        'assets/fonts/MyriadPro-Regular.otf',
      ],
      'assets/fonts/PT_Sans-Web-Regular.ttf',
    );
    final fontPortraitSemibold = await _loadFontWithFallback(
      const [
        'assets/fonts/MyriadPro-Semibold.ttf',
        'assets/fonts/MyriadPro-Semibold.otf',
      ],
      'assets/fonts/PT_Sans-Web-Bold.ttf',
    );
    final fontPortraitSignature = await _loadFontWithFallback(
      const [
        'assets/fonts/TheDecember-Regular.ttf',
        'assets/fonts/TheDecember.ttf',
        'assets/fonts/The December.ttf',
        'assets/fonts/TheDecember.otf',
      ],
      'assets/fonts/MrsSaintDelafield-Regular.ttf',
    );

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
          fontTitle: fontPortraitTitle,
          fontRegular: fontPortraitRegular,
          fontSemibold: fontPortraitSemibold,
          fontSignature: fontPortraitSignature,
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
                left: W * PedigreeLayout.pedigreeHeaderLeft,
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

              // Address + Email on one line, grey underline, breed subtitle
              if (data.farmAddress.isNotEmpty || data.farmEmail.isNotEmpty)
                pw.Positioned(
                  left: W * PedigreeLayout.addressLeft,
                  top: H * (PedigreeLayout.contactCenterY - PedigreeLayout.contactBoxHeight / 2),
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
                        pw.SizedBox(width: 14),
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
              pw.Positioned(
                left: W * PedigreeLayout.underlineX0,
                top: H * PedigreeLayout.underlineY,
                child: pw.Container(
                  width: W * (PedigreeLayout.underlineX1 - PedigreeLayout.underlineX0),
                  height: 1.0,
                  color: PedigreeLayout.pdfColorHeaderUnderline,
                ),
              ),
              if (data.subjectBreed.trim().isNotEmpty)
                pw.Positioned(
                  left: W * PedigreeLayout.breedSubtitleLeft,
                  top: H * PedigreeLayout.breedSubtitleTop,
                  child: pw.Text(
                    '${data.subjectBreed.trim()} Pedigree',
                    style: pw.TextStyle(
                      font: fontDetails,
                      fontSize: W * PedigreeLayout.fontRatioSubject,
                      color: PedigreeLayout.pdfColorSubjectText,
                    ),
                    maxLines: 1,
                  ),
                ),
              if (data.farmWebsite.isNotEmpty || data.farmSocialLink.isNotEmpty)
                pw.Positioned(
                  left: W * PedigreeLayout.addressLeft,
                  top: H * PedigreeLayout.websiteTop,
                  child: pw.SizedBox(
                    width: W * 0.30,
                    child: pw.Text(
                      [
                        if (data.farmWebsite.isNotEmpty) data.farmWebsite,
                        if (data.farmSocialLink.isNotEmpty) data.farmSocialLink,
                      ].join('  •  '),
                      style: pw.TextStyle(
                        font: fontDetails,
                        fontSize: W * (PedigreeLayout.fontRatioHeaderContact * 0.9),
                        color: PedigreeLayout.pdfColorHeaderContact,
                      ),
                      maxLines: 1,
                    ),
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

              // Genotype & Sale Details (below Subject Box)
              if (data.subjectGenotype.isNotEmpty || data.soldTo.isNotEmpty || data.soldOn.isNotEmpty)
                pw.Positioned(
                  left: W * PedigreeLayout.subjectBoxLeft,
                  top: H * 0.658,
                  child: pw.SizedBox(
                    width: W * PedigreeLayout.subjectBoxWidth,
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (data.subjectGenotype.isNotEmpty)
                          _buildPdfMetadataLine(W, fontDetails, fontDetailsBold, 'Genotype:', data.subjectGenotype),
                        if (data.soldTo.isNotEmpty)
                          _buildPdfMetadataLine(W, fontDetails, fontDetailsBold, 'Sold To:', data.soldTo),
                        if (data.soldOn.isNotEmpty)
                          _buildPdfMetadataLine(W, fontDetails, fontDetailsBold, 'Sold On:', data.soldOn),
                      ],
                    ),
                  ),
                ),

              // ─── Subject Photo Ellipse ──────────────────────────────────────
              if (SettingsService.instance.pedigreeShowPhoto)
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
                            child: pw.Container(
                              color: const PdfColor(0.90, 0.90, 0.90),
                              width: double.infinity,
                              height: double.infinity,
                              child: pw.Image(subjectPhoto, fit: pw.BoxFit.contain),
                            ),
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

  // ─── PORTRAIT PDF PAGE BUILDER (Matches PortraitPedigree.pdf 1:1) ──────────
  static pw.Page _buildPortraitPdfPage({
    required PedigreeData data,
    required pw.Font fontTitle,
    required pw.Font fontRegular,
    required pw.Font fontSemibold,
    required pw.Font fontSignature,
    pw.MemoryImage? subjectPhoto,
  }) {
    return pw.Page(
      pageFormat: PdfPageFormat.letter.portrait,
      margin: pw.EdgeInsets.zero,
      build: (pw.Context context) {
        double farmTitleSize = 21.0;
        if (data.farmName.length > 26) {
          farmTitleSize = (farmTitleSize * 26 / data.farmName.length).clamp(14.0, 21.0);
        }

        final String breedSubtitle = data.subjectBreed.trim().isNotEmpty
            ? '${data.subjectBreed.trim()} Pedigree'
            : 'Pedigree';
        final tree = data.tree;

        return pw.Stack(
          children: [
            // White background
            pw.Positioned.fill(
              child: pw.Container(color: PdfColors.white),
            ),

            // Purple header band
            pw.Positioned(
              left: 0.5,
              top: 0.3,
              child: pw.Container(
                width: 611.0,
                height: 60.5,
                color: const PdfColor(0.676, 0.52, 0.737),
              ),
            ),

            // ─── Header: Farm Name (Cabinet of the Outlander, 21pt, centered) ───
            pw.Positioned(
              left: 0,
              right: 0,
              top: 8.0,
              child: pw.SizedBox(
                height: 26.0,
                child: pw.Center(
                  child: pw.Text(
                    data.farmName,
                    style: pw.TextStyle(
                      font: fontTitle,
                      fontSize: farmTitleSize,
                      color: PdfColors.white,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ),

            // ─── Header: Breed Pedigree Subtitle (Myriad Pro, 18pt, centered) ───
            pw.Positioned(
              left: 0,
              right: 0,
              top: 34.0,
              child: pw.SizedBox(
                height: 22.0,
                child: pw.Center(
                  child: pw.Text(
                    breedSubtitle,
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 18.0,
                      color: PdfColors.white,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ),

            // ─── Top Double Horizontal Rule ───────────────────────────────────
            pw.Positioned(
              left: 4.875,
              top: 60.55,
              child: pw.Container(
                width: 602.25,
                height: 0.5,
                color: PdfColors.black,
              ),
            ),
            pw.Positioned(
              left: 5.875,
              top: 63.44,
              child: pw.Container(
                width: 602.25,
                height: 0.5,
                color: PdfColors.black,
              ),
            ),

            // ─── Subject Details: Column 1 (Name, Ear #, Reg #, Sold to) ──────
            _buildPortraitPdfSubjectField(
              left: 21.875,
              top: 66.5,
              width: 195.0,
              label: 'Name:  ',
              value: data.subjectName,
              fontLabel: fontRegular,
              fontValue: fontSemibold,
            ),
            _buildPortraitPdfSubjectField(
              left: 21.875,
              top: 80.9,
              width: 195.0,
              label: 'Ear #: ',
              value: data.subjectEarNo,
              fontLabel: fontRegular,
              fontValue: fontRegular,
            ),
            _buildPortraitPdfSubjectField(
              left: 21.875,
              top: 95.3,
              width: 195.0,
              label: 'Reg #: ',
              value: data.subjectRegNo,
              fontLabel: fontRegular,
              fontValue: fontRegular,
            ),
            if (data.soldTo.trim().isNotEmpty)
              _buildPortraitPdfSubjectField(
                left: 28.9,
                top: 530.0,
                width: 160.0,
                label: 'Sold to: ',
                value: data.soldTo,
                fontLabel: fontRegular,
                fontValue: fontRegular,
                fontSize: 10.5,
              ),

            // ─── Subject Details: Column 2 (Breed, Sex, Color, Sold on) ───────
            _buildPortraitPdfSubjectField(
              left: 220.87,
              top: 66.5,
              width: 195.0,
              label: 'Breed: ',
              value: data.subjectBreed,
              fontLabel: fontRegular,
              fontValue: fontRegular,
            ),
            _buildPortraitPdfSubjectField(
              left: 220.87,
              top: 80.9,
              width: 195.0,
              label: 'Sex:  ',
              value: data.subjectSex,
              fontLabel: fontRegular,
              fontValue: fontRegular,
            ),
            _buildPortraitPdfSubjectField(
              left: 220.87,
              top: 95.3,
              width: 195.0,
              label: 'Color: ',
              value: data.subjectColor,
              fontLabel: fontRegular,
              fontValue: fontRegular,
            ),
            if (data.soldOn.trim().isNotEmpty)
              _buildPortraitPdfSubjectField(
                left: 28.9,
                top: 544.0,
                width: 160.0,
                label: 'Sold on: ',
                value: data.soldOn,
                fontLabel: fontRegular,
                fontValue: fontRegular,
                fontSize: 10.5,
              ),

            // ─── Subject Details: Column 3 (Born, Weight, Legs) ───────────────
            _buildPortraitPdfSubjectField(
              left: 420.89,
              top: 66.5,
              width: 180.0,
              label: 'Born:  ',
              value: data.subjectDob,
              fontLabel: fontRegular,
              fontValue: fontRegular,
            ),
            _buildPortraitPdfSubjectField(
              left: 420.89,
              top: 80.9,
              width: 180.0,
              label: 'Weight:  ',
              value: data.subjectWeight,
              fontLabel: fontRegular,
              fontValue: fontRegular,
            ),
            _buildPortraitPdfSubjectField(
              left: 420.89,
              top: 95.3,
              width: 180.0,
              label: 'Legs: ',
              value: data.subjectLegs,
              fontLabel: fontRegular,
              fontValue: fontRegular,
            ),

            // ─── Bottom Double Horizontal Rule ────────────────────────────────
            pw.Positioned(
              left: 4.875,
              top: 116.55,
              child: pw.Container(
                width: 602.25,
                height: 0.5,
                color: PdfColors.black,
              ),
            ),
            pw.Positioned(
              left: 4.875,
              top: 119.4,
              child: pw.Container(
                width: 602.25,
                height: 0.5,
                color: PdfColors.black,
              ),
            ),

            // ─── Generation Column Headers ────────────────────────────────────
            pw.Positioned(
              left: 20.99,
              top: 125.0,
              child: pw.Text(
                'PARENTS',
                style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: 11.0,
                  color: const PdfColor(0.15, 0.15, 0.15),
                ),
              ),
            ),
            pw.Positioned(
              left: 220.28,
              top: 125.0,
              child: pw.Text(
                'GRANDPARENTS',
                style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: 11.0,
                  color: const PdfColor(0.15, 0.15, 0.15),
                ),
              ),
            ),
            pw.Positioned(
              left: 420.05,
              top: 125.0,
              child: pw.Text(
                'GREAT-GRAND PARENTS',
                style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: 11.0,
                  color: const PdfColor(0.15, 0.15, 0.15),
                ),
              ),
            ),

            // ─── Connector lines ──────────────────────────────────────────────
            pw.Positioned(
              left: 0,
              top: 0,
              child: pw.CustomPaint(
                size: const PdfPoint(612.0, 792.0),
                painter: (PdfGraphics canvas, PdfPoint size) {
                  canvas
                    ..setStrokeColor(const PdfColor(0.28, 0.28, 0.29))
                    ..setLineWidth(0.75);
                  for (final c in PedigreeLayout.portraitConnectors) {
                    canvas
                      ..moveTo(c[0], size.y - c[1])
                      ..lineTo(c[2], size.y - c[3])
                      ..strokePath();
                  }
                },
              ),
            ),

            // ─── Subject photo square (fits whole photo, grey filler) ─────────
            if (SettingsService.instance.pedigreeShowPhoto)
              pw.Positioned(
                left: PedigreeLayout.portraitPhotoLeft,
                top: PedigreeLayout.portraitPhotoTop,
                child: pw.Container(
                  width: PedigreeLayout.portraitPhotoSize,
                  height: PedigreeLayout.portraitPhotoSize,
                  decoration: pw.BoxDecoration(
                    color: subjectPhoto != null
                        ? const PdfColor(0.92, 0.92, 0.92)
                        : null,
                    border: pw.Border.all(
                      color: const PdfColor(0.86, 0.95, 0.98),
                      width: 2.0,
                    ),
                  ),
                  child: subjectPhoto != null
                      ? pw.Image(subjectPhoto, fit: pw.BoxFit.contain)
                      : pw.SizedBox(),
                ),
              ),

            // ─── Column 1: PARENTS ────────────────────────────────────────────
            ..._buildPortraitPdfCard(fontRegular, fontSemibold, 'Sire', 19.74, 267.18, tree?.sire),
            ..._buildPortraitPdfCard(fontRegular, fontSemibold, 'Dam', 20.74, 566.42, tree?.dam),

            // ─── Column 2: GRANDPARENTS ───────────────────────────────────────
            ..._buildPortraitPdfCard(fontRegular, fontSemibold, 'Sire', 219.68, 192.31, tree?.sire?.sire),
            ..._buildPortraitPdfCard(fontRegular, fontSemibold, 'Dam', 219.68, 342.06, tree?.sire?.dam),
            ..._buildPortraitPdfCard(fontRegular, fontSemibold, 'Sire', 220.68, 491.05, tree?.dam?.sire),
            ..._buildPortraitPdfCard(fontRegular, fontSemibold, 'Dam', 220.68, 641.80, tree?.dam?.dam),

            // ─── Column 3: GREAT-GRAND PARENTS ────────────────────────────────
            ..._buildPortraitPdfCard(fontRegular, fontSemibold, 'Sire', 419.62, 157.39, tree?.sire?.sire?.sire),
            ..._buildPortraitPdfCard(fontRegular, fontSemibold, 'Dam', 419.62, 226.27, tree?.sire?.sire?.dam),
            ..._buildPortraitPdfCard(fontRegular, fontSemibold, 'Sire', 419.62, 307.14, tree?.sire?.dam?.sire),
            ..._buildPortraitPdfCard(fontRegular, fontSemibold, 'Dam', 419.62, 376.02, tree?.sire?.dam?.dam),
            ..._buildPortraitPdfCard(fontRegular, fontSemibold, 'Sire', 420.62, 455.88, tree?.dam?.sire?.sire),
            ..._buildPortraitPdfCard(fontRegular, fontSemibold, 'Dam', 420.62, 524.76, tree?.dam?.sire?.dam),
            ..._buildPortraitPdfCard(fontRegular, fontSemibold, 'Sire', 420.62, 606.63, tree?.dam?.dam?.sire),
            ..._buildPortraitPdfCard(fontRegular, fontSemibold, 'Dam', 420.62, 675.51, tree?.dam?.dam?.dam),

            // ─── Bottom Left: Certification (3 lines) ─────────────────────────
            pw.Positioned(
              left: 24.83,
              top: 650.5,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'I hereby certify that this pedigree',
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 10.5,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.SizedBox(height: 1.5),
                  pw.Text(
                    'is correct to the best',
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 10.5,
                      color: PdfColors.black,
                    ),
                  ),
                  pw.SizedBox(height: 1.5),
                  pw.Text(
                    'of my knowledge',
                    style: pw.TextStyle(
                      font: fontRegular,
                      fontSize: 10.5,
                      color: PdfColors.black,
                    ),
                  ),
                ],
              ),
            ),

            // ─── Bottom Left: Signature (Overthink) + Email + Website ─────────
            pw.Positioned(
              left: 25.74,
              top: 710.0,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (data.ownerName.trim().isNotEmpty)
                    pw.Text(
                      data.ownerName.trim(),
                      style: pw.TextStyle(
                        font: fontSignature,
                        fontSize: 11.0,
                        color: PdfColors.black,
                      ),
                    ),
                  if (data.farmEmail.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 2.0),
                    pw.Text(
                      data.farmEmail.trim(),
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 11.0,
                        color: PdfColors.black,
                      ),
                    ),
                  ],
                  if (data.farmWebsite.trim().isNotEmpty || data.farmSocialLink.trim().isNotEmpty) ...[
                    pw.SizedBox(height: 1.5),
                    pw.Text(
                      data.farmWebsite.trim().isNotEmpty
                          ? data.farmWebsite.trim()
                          : data.farmSocialLink.trim(),
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 11.0,
                        color: PdfColors.black,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static pw.Widget _buildPortraitPdfSubjectField({
    required double left,
    required double top,
    required double width,
    required String label,
    required String value,
    required pw.Font fontLabel,
    required pw.Font fontValue,
    double fontSize = 12.0,
  }) {
    return pw.Positioned(
      left: left,
      top: top,
      child: pw.SizedBox(
        width: width,
        height: 14.4,
        child: pw.Align(
          alignment: pw.Alignment.centerLeft,
          child: pw.RichText(
            text: pw.TextSpan(
              children: [
                pw.TextSpan(
                  text: label,
                  style: pw.TextStyle(
                    font: fontLabel,
                    fontSize: fontSize,
                    color: PdfColors.black,
                  ),
                ),
                pw.TextSpan(
                  text: value,
                  style: pw.TextStyle(
                    font: fontValue,
                    fontSize: fontSize,
                    color: PdfColors.black,
                  ),
                ),
              ],
            ),
            maxLines: 1,
          ),
        ),
      ),
    );
  }

  static pw.Widget _buildPdfMetadataLine(
    double W,
    pw.Font font,
    pw.Font fontBold,
    String label,
    String value,
  ) {
    return pw.Padding(
      padding: pw.EdgeInsets.only(bottom: W * 0.004),
      child: pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(
              text: '$label ',
              style: pw.TextStyle(
                font: fontBold,
                fontSize: W * (PedigreeLayout.fontRatioSubject * 0.85),
                color: PedigreeLayout.pdfColorSubjectText,
              ),
            ),
            pw.TextSpan(
              text: value,
              style: pw.TextStyle(
                font: font,
                fontSize: W * (PedigreeLayout.fontRatioSubject * 0.85),
                color: PedigreeLayout.pdfColorSubjectText,
              ),
            ),
          ],
        ),
        maxLines: 1,
      ),
    );
  }

  static List<pw.Widget> _buildPortraitPdfCard(
    pw.Font fontRegular,
    pw.Font fontSemibold,
    String role,
    double left,
    double top,
    PedigreeRabbit? rabbit,
  ) {
    const double width = 172.645;
    const double height = 62.24;
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

    return [
      // Top shaded header strip (5% gray)
      pw.Positioned(
        left: left + 0.44,
        top: top + 0.44,
        child: pw.Container(
          width: 171.763,
          height: 14.62,
          color: role == 'Dam'
              ? const PdfColor(0.977, 0.863, 0.915)
              : const PdfColor(0.864, 0.947, 0.977),
        ),
      ),
      // Card outer border + 5 rows
      pw.Positioned(
        left: left,
        top: top,
        child: pw.Container(
          width: width,
          height: height,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
              color: const PdfColor(0.10, 0.10, 0.10),
              width: 0.5,
            ),
          ),
          padding: const pw.EdgeInsets.fromLTRB(4.2, 1.5, 4.0, 1.5),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              // Row 1: Sire/Dam + Name (Myriad Pro Semi Bold, 10pt)
              pw.Text(
                '$role:  $name',
                style: pw.TextStyle(
                  font: fontSemibold,
                  fontSize: 10.0,
                  color: PdfColors.black,
                ),
                maxLines: 1,
              ),
              // Row 2: Color (Myriad Pro Regular, 10pt)
              pw.Text(
                'Color:  $color',
                style: pw.TextStyle(
                  font: fontRegular,
                  fontSize: 10.0,
                  color: PdfColors.black,
                ),
                maxLines: 1,
              ),
              // Row 3: Ear # & Reg#
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 56,
                    child: pw.Text(
                      'Ear #:  $earNo',
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 10.0,
                        color: PdfColors.black,
                      ),
                      maxLines: 1,
                    ),
                  ),
                  pw.Expanded(
                    flex: 44,
                    child: pw.Text(
                      'Reg#: $regNo',
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 10.0,
                        color: PdfColors.black,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              // Row 4: DOB & Wt
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 56,
                    child: pw.Text(
                      'DOB:  $dob',
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 10.0,
                        color: PdfColors.black,
                      ),
                      maxLines: 1,
                    ),
                  ),
                  pw.Expanded(
                    flex: 44,
                    child: pw.Text(
                      'Wt:  $wt',
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 10.0,
                        color: PdfColors.black,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              // Row 5: GC# & Legs
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 56,
                    child: pw.Text(
                      'GC#:  $gcNo',
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 10.0,
                        color: PdfColors.black,
                      ),
                      maxLines: 1,
                    ),
                  ),
                  pw.Expanded(
                    flex: 44,
                    child: pw.Text(
                      'Legs: $legs',
                      style: pw.TextStyle(
                        font: fontRegular,
                        fontSize: 10.0,
                        color: PdfColors.black,
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
      if (winnings.isNotEmpty)
        pw.Positioned(
          left: left,
          top: top + height + 1.0,
          child: pw.SizedBox(
            width: width,
            child: pw.Text(
              winnings,
              style: pw.TextStyle(
                font: fontRegular,
                fontSize: 7.0,
                color: PdfColors.black,
              ),
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

    final String name = rabbit?.displayName ?? '';
    final String color = rabbit?.color ?? '';
    final String dob = rabbit?.dateOfBirth != null ? FormatUtils.formatCertificateDate(rabbit!.dateOfBirth) : '';
    final String wt = _formatCardWeight(rabbit?.weight);
    final String earNo = rabbit?.earNumber ?? '';
    final String legs = rabbit?.legs != null && rabbit!.legs! > 0 ? '${rabbit.legs}' : '';
    final String winnings = (rabbit?.winnings ?? '').trim();

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
      if (winnings.isNotEmpty)
        pw.Positioned(
          left: W * left,
          top: H * (top + cardH) + 1.0,
          child: pw.SizedBox(
            width: W * cardW,
            child: pw.Text(
              winnings,
              style: pw.TextStyle(
                font: font,
                fontSize: baseFontSize * 0.55,
                color: PedigreeLayout.pdfColorCardText,
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
