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
        // Farm name: same font as the Certificate of Birth (Shakies)
        'assets/fonts/Shakies-OpenType-TT.ttf',
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
        'assets/fonts/Birthstone-Regular.ttf',
      ],
      PedigreeLayout.fontSignatureAsset,
    );

    // Portrait-specific fonts (Cabinet of the Outlander, Myriad Pro, Myriad Pro Semi Bold, Overthink)
    final fontPortraitTitle = await _loadFontWithFallback(
      const [
        // Farm name: same font as the Certificate of Birth (Shakies)
        'assets/fonts/Shakies-OpenType-TT.ttf',
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
        'assets/fonts/Birthstone-Regular.ttf',
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
        _buildLandscapePdfPage(
          data: data,
          fontTitle: fontTitle,
          fontRegular: fontPortraitRegular,
          fontSignature: fontSignature,
          logo: logoImage,
          subjectPhoto: subjectPhoto,
        ),
      );
    }

    return pdf.save();
  }

  // ─── LANDSCAPE PDF PAGE BUILDER (matches Landscape.pdf design) ─────────────
  static pw.Page _buildLandscapePdfPage({
    required PedigreeData data,
    required pw.Font fontTitle,
    required pw.Font fontRegular,
    required pw.Font fontSignature,
    required pw.MemoryImage logo,
    pw.MemoryImage? subjectPhoto,
  }) {
    const grey = PdfColor(0.577, 0.586, 0.596);
    const headGrey = PdfColor(0.655, 0.663, 0.675);
    const subjInk = PdfColor(0.439, 0.447, 0.451);
    const lineInk = PdfColor(0.427, 0.431, 0.443);
    const certInk = PdfColor(0.502, 0.510, 0.522);

    pw.Widget txt(String t, double x, double y, double w, double fs, PdfColor c,
        {pw.Font? font}) {
      return pw.Positioned(
        left: x,
        top: y,
        child: pw.SizedBox(
          width: w,
          height: fs * 1.3,
          child: pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(
              t,
              style: pw.TextStyle(font: font ?? fontRegular, fontSize: fs, color: c),
              maxLines: 1,
            ),
          ),
        ),
      );
    }

    return pw.Page(
      pageFormat: PdfPageFormat.letter.landscape,
      margin: pw.EdgeInsets.zero,
      build: (pw.Context context) {
        final tree = data.tree;
        final contactLine = [
          data.farmEmail.trim(),
          data.farmWebsite.trim(),
          data.farmSocialLink.trim(),
        ].where((e) => e.isNotEmpty).join('          ');
        final widgets = <pw.Widget>[
          pw.Positioned.fill(child: pw.Container(color: PdfColors.white)),

          // Header
          txt(data.farmName, 16.3, 11.0, 370, 33.2, headGrey, font: fontTitle),
          // Address, then Email / Website / Social (as per Settings toggles).
          // Scaled down to fit so long text never runs into the cards.
          if (data.farmAddress.trim().isNotEmpty)
            txt(data.farmAddress.trim(), 19.4, 55.1, 375, 10, headGrey),
          if (contactLine.isNotEmpty)
            txt(contactLine, 19.9, 69.3, 375, 10, headGrey),
          pw.Positioned(
            left: 19.4,
            top: 83.0,
            child: pw.Container(width: 232.0, height: 1.0, color: grey),
          ),

          // Logo
          pw.Positioned(
            left: 52.7,
            top: 121.0,
            child: pw.SizedBox(width: 110.0, height: 112.0, child: pw.Image(logo, fit: pw.BoxFit.contain)),
          ),

          // Subject box
          pw.Positioned(
            left: 21.8,
            top: 216.2,
            child: pw.Container(
              width: 173.7,
              height: 178.8,
              decoration: pw.BoxDecoration(
                color: LandscapeLayout.pdfSubjectBox,
                borderRadius: pw.BorderRadius.circular(18),
              ),
            ),
          ),
          for (final c in LandscapeLayout.subjectCells(data))
            txt(c.text, c.x, c.y, c.w, 12, subjInk),

          // Sold To / Sold On / Genotype
          if (data.showSoldTo)
            txt('Sold To: ${data.soldTo}', 24.2, 414.5, 175, 11, lineInk),
          if (data.showSoldOn)
            txt('Sold On: ${data.soldOn}', 24.2, 427.7, 175, 11, lineInk),
          if (data.subjectGenotype.isNotEmpty)
            txt('Genotype: ${data.subjectGenotype}', 24.2, 441.0, 175, 11, lineInk),

          // Photo ellipse
          if (SettingsService.instance.pedigreeShowPhoto)
            pw.Positioned(
              left: 216.3,
              top: 236.0,
              child: pw.Container(
                width: 178.3,
                height: 134.6,
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.all(pw.Radius.elliptical(89.15, 67.3)),
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
        ];

        // Ancestor cards
        for (final c in LandscapeLayout.specs) {
          final r = LandscapeLayout.resolve(tree, c.path);
          widgets.add(pw.Positioned(
            left: c.left,
            top: c.top,
            child: pw.Container(
              width: c.width,
              height: c.height,
              decoration: pw.BoxDecoration(
                color: c.isSire ? LandscapeLayout.pdfSireCard : LandscapeLayout.pdfDamCard,
                borderRadius: pw.BorderRadius.circular(LandscapeLayout.cardRadius),
              ),
            ),
          ));
          for (final cell in LandscapeLayout.cardCells(c, r, _formatCardWeight(r?.weight))) {
            widgets.add(txt(cell.text, c.left + cell.x, c.top + cell.y, cell.w, c.fontSize, PdfColors.white));
          }
          final win = (r?.winnings ?? '').trim();
          if (win.isNotEmpty && c.gen < 3) {
            widgets.add(txt(win, c.left, c.top + c.height + 0.5, c.width, c.fontSize - 1, lineInk));
          }
        }

        // Footer
        widgets.addAll([
          txt('I hereby certify this pedigree is correct', 22.1, 495.3, 250, 10, certInk),
          txt('to the best of my knowledge', 22.1, 507.3, 250, 10, certInk),
          // Bottom: only the owner's name (signature) and phone number
          if (data.ownerName.trim().isNotEmpty)
            txt(data.ownerName.trim(), 20.5, 543.0, 185, 20, lineInk, font: fontSignature),
          if (data.farmPhone.trim().isNotEmpty)
            txt(data.farmPhone.trim(), 24.1, 578.2, 185, 12, lineInk),
        ]);

        return pw.Stack(children: widgets);
      },
    );
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
    final contactLine = [
      data.farmEmail.trim(),
      data.farmWebsite.trim(),
      data.farmSocialLink.trim(),
    ].where((e) => e.isNotEmpty).join('          ');
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
              top: 3.0,
              child: pw.SizedBox(
                height: 30.0,
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

            // ─── Header: Address, then Email / Website / Social (Settings toggles)
            if (data.farmAddress.trim().isNotEmpty)
              pw.Positioned(
                left: 30,
                right: 30,
                top: 32.0,
                child: pw.SizedBox(
                  height: 13.0,
                  child: pw.FittedBox(
                    fit: pw.BoxFit.scaleDown,
                    child: pw.Text(
                      data.farmAddress.trim(),
                      style: pw.TextStyle(font: fontRegular, fontSize: 10.0, color: const PdfColor(0.95, 0.95, 0.95)),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),
            if (contactLine.isNotEmpty)
              pw.Positioned(
                left: 30,
                right: 30,
                top: 46.2,
                child: pw.SizedBox(
                  height: 13.0,
                  child: pw.FittedBox(
                    fit: pw.BoxFit.scaleDown,
                    child: pw.Text(
                      contactLine,
                      style: pw.TextStyle(font: fontRegular, fontSize: 10.0, color: const PdfColor(0.95, 0.95, 0.95)),
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
            if (data.showSoldTo)
              _buildPortraitPdfSubjectField(
                left: 22.0,
                top: 167.5,
                width: 190.0,
                label: 'Sold To: ',
                value: data.soldTo,
                fontLabel: fontRegular,
                fontValue: fontRegular,
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
            if (data.showSoldOn)
              _buildPortraitPdfSubjectField(
                left: 22.0,
                top: 184.4,
                width: 190.0,
                label: 'Sold On: ',
                value: data.soldOn,
                fontLabel: fontRegular,
                fontValue: fontRegular,
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
              top: 111.6,
              child: pw.Container(
                width: 602.25,
                height: 0.5,
                color: PdfColors.black,
              ),
            ),
            pw.Positioned(
              left: 4.875,
              top: 114.45,
              child: pw.Container(
                width: 602.25,
                height: 0.5,
                color: PdfColors.black,
              ),
            ),

            // ─── Generation Column Headers ────────────────────────────────────
            pw.Positioned(
              left: 20.99,
              top: 120.0,
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
              top: 120.0,
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
              top: 120.0,
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

            // ─── Bottom Left: only Name (signature) + Phone ─────────────────
            pw.Positioned(
              left: 24.9,
              top: 708.0,
              child: pw.SizedBox(
                width: 185.0,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (data.ownerName.trim().isNotEmpty)
                      pw.FittedBox(
                        fit: pw.BoxFit.scaleDown,
                        alignment: pw.Alignment.centerLeft,
                        child: pw.Text(
                          data.ownerName.trim(),
                          style: pw.TextStyle(font: fontSignature, fontSize: 16.0, color: PdfColors.black),
                        ),
                      ),
                    if (data.farmPhone.trim().isNotEmpty) ...[
                      pw.SizedBox(height: 4.0),
                      pw.Text(
                        data.farmPhone.trim(),
                        style: pw.TextStyle(font: fontRegular, fontSize: 10.0, color: PdfColors.black),
                      ),
                    ],
                  ],
                ),
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
          padding: const pw.EdgeInsets.fromLTRB(4.2, 0.6, 4.0, 0),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
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
            ].map((w) => pw.SizedBox(
                  height: 12.15,
                  child: pw.Align(alignment: pw.Alignment.centerLeft, child: w),
                )).toList(),
          ),
        ),
      ),
      if (winnings.isNotEmpty)
        pw.Positioned(
          left: left,
          top: top + height + 0.3,
          child: pw.SizedBox(
            width: width,
            child: pw.Text(
              winnings,
              style: pw.TextStyle(
                font: fontRegular,
                fontSize: 9.5,
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
    final String regNo = rabbit?.registrationNumber ?? '';
    final String gcNo = rabbit?.grandChampionNumber ?? '';
    // 5 evenly spaced rows: Name, Color, DOB/Wt, Ear/Reg, GC/Legs
    final List<double> rd = List<double>.generate(
        5, (i) => rowDy[0] + i * (cardH - 2 * rowDy[0]) / 4);

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
        top: H * (top + rd[0]) - (rowHeight / 2),
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
        top: H * (top + rd[1]) - (rowHeight / 2),
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
        top: H * (top + rd[2]) - (rowHeight / 2),
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
        top: H * (top + rd[2]) - (rowHeight / 2),
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

      // Row 3: Ear No. & Reg #
      // Col 1: Ear No.
      pw.Positioned(
        left: W * (left + textDx),
        top: H * (top + rd[3]) - (rowHeight / 2),
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
        top: H * (top + rd[3]) - (rowHeight / 2),
        child: pw.SizedBox(
          width: W * (cardW - secondColDx - 0.004),
          height: rowHeight,
          child: pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: 'Reg #: ',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: baseFontSize,
                      color: PedigreeLayout.pdfColorCardText,
                    ),
                  ),
                  pw.TextSpan(
                    text: regNo,
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
      // Row 4: GC# & Legs
      // Col 1: Ear No.
      pw.Positioned(
        left: W * (left + textDx),
        top: H * (top + rd[4]) - (rowHeight / 2),
        child: pw.SizedBox(
          width: W * (secondColDx - textDx),
          height: rowHeight,
          child: pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.RichText(
              text: pw.TextSpan(
                children: [
                  pw.TextSpan(
                    text: 'GC#: ',
                    style: pw.TextStyle(
                      font: fontBold,
                      fontSize: baseFontSize,
                      color: PedigreeLayout.pdfColorCardText,
                    ),
                  ),
                  pw.TextSpan(
                    text: gcNo,
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
        top: H * (top + rd[4]) - (rowHeight / 2),
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
                fontSize: baseFontSize * 0.55 + 2.5,
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
