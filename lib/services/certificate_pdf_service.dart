import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../widgets/certificate_layout.dart';

class CertificatePdfService {
  CertificatePdfService._();

  /// Generates the Birth Certificate PDF as a byte array matching the reference layout.
  static Future<Uint8List> generatePdf(CertificateData data) async {
    final pdf = pw.Document(compress: true);

    // ─── 1. Load Bundled Fonts ──────────────────────────────────────────────
    final fontDetailsData = await rootBundle.load(CertificateLayout.fontDetailsAsset);
    final fontDetails = pw.Font.ttf(fontDetailsData);

    // ─── 2. Load Photo (if enabled) ─────────────────────────────────────────
    pw.MemoryImage? photo;
    if (data.hasPhoto && data.photoPath != null && data.photoPath!.isNotEmpty) {
      final file = File(data.photoPath!);
      if (await file.exists()) {
        try {
          photo = pw.MemoryImage(await file.readAsBytes());
        } catch (_) {}
      }
    }

    if (data.isColorWithPhoto) {
      // ════ COLOR WITH PHOTO LAYOUT (Matches reference PDF) ════
      final bgByteData = await rootBundle.load(CertificateLayout.templateColorPhotoAsset);
      final bgImage = pw.MemoryImage(bgByteData.buffer.asUint8List());

      const pageFormat = PdfPageFormat(
        CertificateLayout.pageColorPhotoWidthPt,
        CertificateLayout.pageColorPhotoHeightPt,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            return pw.Stack(
              children: [
                // Layer 1: Background Template (Border, Floral Bouquet, Title, Bunny icons)
                pw.Positioned.fill(
                  child: pw.Image(bgImage, fit: pw.BoxFit.fill),
                ),

                // Layer 2: Photo inside Rounded Rectangle Frame
                if (photo != null)
                  pw.Positioned(
                    left: CertificateLayout.photoLeftPt,
                    top: CertificateLayout.photoTopPt,
                    child: pw.Container(
                      width: CertificateLayout.photoWidthPt,
                      height: CertificateLayout.photoHeightPt,
                      decoration: pw.BoxDecoration(
                        borderRadius: pw.BorderRadius.circular(CertificateLayout.photoRadiusPt),
                        border: pw.Border.all(
                          color: CertificateLayout.pdfColorPhotoFrameBorder,
                          width: 2.0,
                        ),
                      ),
                      child: pw.ClipRRect(
                        horizontalRadius: 13.0,
                        verticalRadius: 13.0,
                        child: pw.Image(photo, fit: pw.BoxFit.cover),
                      ),
                    ),
                  ),

                // Layer 3: Row 1 - Name
                pw.Positioned(
                  left: CertificateLayout.detailsLeftPt,
                  top: CertificateLayout.row1TopPt,
                  child: pw.Text(
                    'Name: ${data.name}',
                    style: pw.TextStyle(
                      font: fontDetails,
                      fontSize: CertificateLayout.detailsFontSizePt,
                      color: CertificateLayout.pdfColorDetailsPhoto,
                    ),
                  ),
                ),

                // Layer 4: Row 2 - Breed
                pw.Positioned(
                  left: CertificateLayout.detailsLeftPt,
                  top: CertificateLayout.row2TopPt,
                  child: pw.Text(
                    'Breed: ${data.breed}',
                    style: pw.TextStyle(
                      font: fontDetails,
                      fontSize: CertificateLayout.detailsFontSizePt,
                      color: CertificateLayout.pdfColorDetailsPhoto,
                    ),
                  ),
                ),

                // Layer 5: Row 3 - Color
                pw.Positioned(
                  left: CertificateLayout.detailsLeftPt,
                  top: CertificateLayout.row3TopPt,
                  child: pw.Text(
                    'Color: ${data.color}',
                    style: pw.TextStyle(
                      font: fontDetails,
                      fontSize: CertificateLayout.detailsFontSizePt,
                      color: CertificateLayout.pdfColorDetailsPhoto,
                    ),
                  ),
                ),

                // Layer 6: Row 4 - DOB
                pw.Positioned(
                  left: CertificateLayout.detailsLeftPt,
                  top: CertificateLayout.row4TopPt,
                  child: pw.Text(
                    'DOB: ${data.dob}',
                    style: pw.TextStyle(
                      font: fontDetails,
                      fontSize: CertificateLayout.detailsFontSizePt,
                      color: CertificateLayout.pdfColorDetailsPhoto,
                    ),
                  ),
                ),

                // Layer 7: Row 5 - Sex
                pw.Positioned(
                  left: CertificateLayout.detailsLeftPt,
                  top: CertificateLayout.row5TopPt,
                  child: pw.Text(
                    'Sex: ${data.sex}',
                    style: pw.TextStyle(
                      font: fontDetails,
                      fontSize: CertificateLayout.detailsFontSizePt,
                      color: CertificateLayout.pdfColorDetailsPhoto,
                    ),
                  ),
                ),

                // Layer 8: Row 6 - Dam X Sire
                pw.Positioned(
                  left: CertificateLayout.detailsLeftPt,
                  top: CertificateLayout.row6TopPt,
                  child: pw.Text(
                    data.parentsSentence,
                    style: pw.TextStyle(
                      font: fontDetails,
                      fontSize: CertificateLayout.detailsFontSizePt,
                      color: CertificateLayout.pdfColorDetailsPhoto,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    } else {
      // ════ STANDARD LAYOUT (Black & White and Color no photo) ════
      final bgAsset = data.isBlackAndWhite
          ? CertificateLayout.templateBwAsset
          : CertificateLayout.templateColorAsset;
      final bgByteData = await rootBundle.load(bgAsset);
      final bgImage = pw.MemoryImage(bgByteData.buffer.asUint8List());

      final fontDetailsBoldData = await rootBundle.load(CertificateLayout.fontDetailsBoldAsset);
      final fontScriptData = await rootBundle.load(CertificateLayout.fontScriptAsset);

      final fontDetailsBold = pw.Font.ttf(fontDetailsBoldData);
      final fontScript = pw.Font.ttf(fontScriptData);

      const pageFormat = PdfPageFormat(
        CertificateLayout.pageWidthPt,
        CertificateLayout.pageHeightPt,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pw.EdgeInsets.zero,
          build: (pw.Context context) {
            final double W = pageFormat.width;
            final double H = pageFormat.height;

            final PdfColor textColor = CertificateLayout.pdfColorText;

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

            return pw.Stack(
              children: [
                // Layer 1: Background Template (Full Bleed)
                pw.Positioned.fill(
                  child: pw.Image(bgImage, fit: pw.BoxFit.fill),
                ),

                // Layer 2: "This certifies that"
                pw.Positioned(
                  top: topCertifies,
                  left: 0,
                  child: pw.Container(
                    width: W,
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      'This certifies that',
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        font: fontDetails,
                        fontSize: fontSizeCertifies,
                        color: textColor,
                      ),
                    ),
                  ),
                ),

                // Layer 3: Rabbit Name (Script font)
                pw.Positioned(
                  top: topName,
                  left: 0,
                  child: pw.Container(
                    width: W,
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      data.name,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        font: fontScript,
                        fontSize: fontSizeName,
                        color: textColor,
                      ),
                    ),
                  ),
                ),

                // Layer 4: Birth Sentence ("a Holland Lop rabbit was born on Oct 10, 2026")
                pw.Positioned(
                  top: topBorn,
                  left: 0,
                  child: pw.Container(
                    width: W,
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      data.birthSentence,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        font: fontDetails,
                        fontSize: fontSizeBorn,
                        color: textColor,
                      ),
                    ),
                  ),
                ),

                // Layer 5: Location Sentence ("at Amaranth, Ontario Canada")
                pw.Positioned(
                  top: topLocation,
                  left: 0,
                  child: pw.Container(
                    width: W,
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      data.locationSentence,
                      textAlign: pw.TextAlign.center,
                      style: pw.TextStyle(
                        font: fontDetails,
                        fontSize: fontSizeLocation,
                        color: textColor,
                      ),
                    ),
                  ),
                ),

                // Layer 6: Bottom Details Grid - Row 1 (Color & Sex)
                // Color (Left)
                pw.Positioned(
                  top: topGridRow1,
                  left: leftColX,
                  child: pw.Container(
                    width: colWidth,
                    child: pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text(
                          'Color: ',
                          style: pw.TextStyle(
                            font: fontDetailsBold,
                            fontSize: fontSizeGrid,
                            color: textColor,
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            data.color,
                            style: pw.TextStyle(
                              font: fontDetails,
                              fontSize: fontSizeGrid,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: pw.TextOverflow.clip,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Sex (Right)
                pw.Positioned(
                  top: topGridRow1,
                  left: rightColX,
                  child: pw.Container(
                    width: colWidth,
                    child: pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text(
                          'Sex: ',
                          style: pw.TextStyle(
                            font: fontDetailsBold,
                            fontSize: fontSizeGrid,
                            color: textColor,
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            data.sex,
                            style: pw.TextStyle(
                              font: fontDetails,
                              fontSize: fontSizeGrid,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: pw.TextOverflow.clip,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Layer 7: Bottom Details Grid - Row 2 (Sire & Dam)
                // Sire (Left)
                pw.Positioned(
                  top: topGridRow2,
                  left: leftColX,
                  child: pw.Container(
                    width: colWidth,
                    child: pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text(
                          'Sire: ',
                          style: pw.TextStyle(
                            font: fontDetailsBold,
                            fontSize: fontSizeGrid,
                            color: textColor,
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            data.sireName,
                            style: pw.TextStyle(
                              font: fontDetails,
                              fontSize: fontSizeGrid,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: pw.TextOverflow.clip,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Dam (Right)
                pw.Positioned(
                  top: topGridRow2,
                  left: rightColX,
                  child: pw.Container(
                    width: colWidth,
                    child: pw.Row(
                      mainAxisSize: pw.MainAxisSize.min,
                      children: [
                        pw.Text(
                          'Dam: ',
                          style: pw.TextStyle(
                            font: fontDetailsBold,
                            fontSize: fontSizeGrid,
                          ),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            data.damName,
                            style: pw.TextStyle(
                              font: fontDetails,
                              fontSize: fontSizeGrid,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: pw.TextOverflow.clip,
                          ),
                        ),
                      ],
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
}
