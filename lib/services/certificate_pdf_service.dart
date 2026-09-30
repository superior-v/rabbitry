import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../widgets/certificate_layout.dart';

class CertificatePdfService {
  CertificatePdfService._();

  /// Generates the Birth Certificate PDF as a byte array.
  static Future<Uint8List> generatePdf(CertificateData data) async {
    final pdf = pw.Document(compress: true);

    // ─── 1. Load Background & Icon Assets ─────────────────────────────────────
    final bgByteData = await rootBundle.load(CertificateLayout.backgroundAsset);
    final bgImage = pw.MemoryImage(bgByteData.buffer.asUint8List());

    final iconByteData = await rootBundle.load(CertificateLayout.rabbitIconAsset);
    final rabbitIcon = pw.MemoryImage(iconByteData.buffer.asUint8List());

    // ─── 2. Load Bundled TTF Fonts ───────────────────────────────────────────
    final fontTitleData = await rootBundle.load(CertificateLayout.fontTitleAsset);
    final fontBadgeData = await rootBundle.load(CertificateLayout.fontBadgeAsset);
    final fontDetailsData = await rootBundle.load(CertificateLayout.fontDetailsAsset);
    final fontSignatureData = await rootBundle.load(CertificateLayout.fontSignatureAsset);

    final fontTitle = pw.Font.ttf(fontTitleData);
    final fontBadge = pw.Font.ttf(fontBadgeData);
    final fontDetails = pw.Font.ttf(fontDetailsData);
    final fontSignature = pw.Font.ttf(fontSignatureData);

    // ─── 3. Load Photos (if enabled) ──────────────────────────────────────────
    pw.MemoryImage? kitPhoto;
    if (data.includePhoto && data.kitPhotoPath != null && data.kitPhotoPath!.isNotEmpty) {
      final file = File(data.kitPhotoPath!);
      if (await file.exists()) {
        kitPhoto = pw.MemoryImage(await file.readAsBytes());
      }
    }

    pw.MemoryImage? sirePhoto;
    if (data.includePhoto && data.sirePhotoPath != null && data.sirePhotoPath!.isNotEmpty) {
      final file = File(data.sirePhotoPath!);
      if (await file.exists()) {
        sirePhoto = pw.MemoryImage(await file.readAsBytes());
      }
    }

    pw.MemoryImage? damPhoto;
    if (data.includePhoto && data.damPhotoPath != null && data.damPhotoPath!.isNotEmpty) {
      final file = File(data.damPhotoPath!);
      if (await file.exists()) {
        damPhoto = pw.MemoryImage(await file.readAsBytes());
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

          // Auto-scale title font size to prevent overflow or colliding with badge
          double titleFontSize = W * CertificateLayout.fontRatioTitle;
          if (data.farmName.length > 14) {
            titleFontSize = (titleFontSize * 14 / data.farmName.length)
                .clamp(W * 0.022, W * CertificateLayout.fontRatioTitle);
          }

          return pw.Stack(
            children: [
              // Layer 1: Background Template (Full Bleed)
              pw.Positioned.fill(
                child: pw.Image(bgImage, fit: pw.BoxFit.fill),
              ),

              // Layer 2: Everything else drawn in code

              // ─── Top Farm Name (Title) ──────────────────────────────────────
              pw.Positioned(
                left: W * (0.5000 - CertificateLayout.titleMaxWidth / 2),
                top: H * CertificateLayout.titleCenterY - (H * CertificateLayout.titleBoxHeight / 2),
                child: pw.SizedBox(
                  width: W * CertificateLayout.titleMaxWidth,
                  height: H * CertificateLayout.titleBoxHeight,
                  child: pw.Align(
                    alignment: pw.Alignment.center,
                    child: pw.Text(
                      data.farmName,
                      style: pw.TextStyle(
                        font: fontTitle,
                        fontSize: titleFontSize,
                        color: CertificateLayout.pdfColorTitle,
                      ),
                      textAlign: pw.TextAlign.center,
                      maxLines: 1,
                    ),
                  ),
                ),
              ),

              // ─── "Birth Certificate" Badge ──────────────────────────────────
              pw.Positioned(
                left: W * CertificateLayout.badgeLeft,
                top: H * CertificateLayout.badgeTop,
                child: pw.Container(
                  width: W * CertificateLayout.badgeWidth,
                  height: H * CertificateLayout.badgeHeight,
                  decoration: pw.BoxDecoration(
                    color: CertificateLayout.pdfColorBadgeBg,
                    borderRadius: pw.BorderRadius.all(
                      pw.Radius.circular(W * CertificateLayout.badgeRadius),
                    ),
                  ),
                  child: pw.Center(
                    child: pw.Text(
                      'Birth Certificate',
                      style: pw.TextStyle(
                        font: fontBadge,
                        fontSize: W * CertificateLayout.fontRatioBadge,
                        color: CertificateLayout.pdfColorBadgeText,
                        letterSpacing: 0.5,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ),
                ),
              ),

              // ─── Left Column: Kit Photo ─────────────────────────────────────
              pw.Positioned(
                left: W * CertificateLayout.kitPhotoLeft,
                top: H * CertificateLayout.kitPhotoTop,
                child: pw.Container(
                  width: W * CertificateLayout.kitPhotoWidth,
                  height: H * CertificateLayout.kitPhotoHeight,
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.all(
                      pw.Radius.circular(W * CertificateLayout.kitPhotoRadius),
                    ),
                    color: kitPhoto != null ? null : const PdfColor(0.92, 0.92, 0.92),
                  ),
                  child: kitPhoto != null
                      ? pw.ClipRRect(
                          horizontalRadius: W * CertificateLayout.kitPhotoRadius,
                          verticalRadius: W * CertificateLayout.kitPhotoRadius,
                          child: pw.Image(kitPhoto, fit: pw.BoxFit.cover),
                        )
                      : pw.Center(
                          child: pw.Text(
                            'No Photo',
                            style: pw.TextStyle(
                              font: fontDetails,
                              fontSize: 12,
                              color: const PdfColor(0.6, 0.6, 0.6),
                            ),
                          ),
                        ),
                ),
              ),

              // ─── Center: Kit Details Rows ───────────────────────────────────
              ..._buildKitRow(
                W,
                H,
                rabbitIcon,
                fontDetails,
                CertificateLayout.kitNameCenterY,
                'Name: ${data.kitName}',
              ),
              ..._buildKitRow(
                W,
                H,
                rabbitIcon,
                fontDetails,
                CertificateLayout.kitBreedCenterY,
                'Breed: ${data.kitBreed}',
              ),
              ..._buildKitRow(
                W,
                H,
                rabbitIcon,
                fontDetails,
                CertificateLayout.kitColorCenterY,
                'Color: ${data.kitColor}',
              ),
              ..._buildKitRow(
                W,
                H,
                rabbitIcon,
                fontDetails,
                CertificateLayout.kitDobCenterY,
                'DOB: ${data.kitDob}',
              ),
              ..._buildKitRow(
                W,
                H,
                rabbitIcon,
                fontDetails,
                CertificateLayout.kitSexCenterY,
                'Sex: ${data.kitSex}',
              ),

              // ─── Right Column Top: Sire Photo ───────────────────────────────
              pw.Positioned(
                left: W * CertificateLayout.sirePhotoLeft,
                top: H * CertificateLayout.sirePhotoTop,
                child: pw.Container(
                  width: W * CertificateLayout.sirePhotoWidth,
                  height: H * CertificateLayout.sirePhotoHeight,
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.all(
                      pw.Radius.circular(W * CertificateLayout.sirePhotoRadius),
                    ),
                    color: sirePhoto != null ? null : const PdfColor(0.92, 0.92, 0.92),
                  ),
                  child: sirePhoto != null
                      ? pw.ClipRRect(
                          horizontalRadius: W * CertificateLayout.sirePhotoRadius,
                          verticalRadius: W * CertificateLayout.sirePhotoRadius,
                          child: pw.Image(sirePhoto, fit: pw.BoxFit.cover),
                        )
                      : pw.Center(
                          child: pw.Text(
                            'Sire Photo',
                            style: pw.TextStyle(
                              font: fontDetails,
                              fontSize: 10,
                              color: const PdfColor(0.6, 0.6, 0.6),
                            ),
                          ),
                        ),
                ),
              ),

              // ─── Right Column Top: Sire Card ────────────────────────────────
              pw.Positioned(
                left: W * CertificateLayout.sireCardLeft,
                top: H * CertificateLayout.sireCardTop,
                child: pw.Container(
                  width: W * CertificateLayout.sireCardWidth,
                  height: H * CertificateLayout.sireCardHeight,
                  decoration: pw.BoxDecoration(
                    color: CertificateLayout.pdfColorSireCardBg,
                    borderRadius: pw.BorderRadius.all(
                      pw.Radius.circular(W * CertificateLayout.sireCardRadius),
                    ),
                  ),
                ),
              ),

              // Sire Card Text Rows
              ..._buildCardRow(W, H, fontDetails, CertificateLayout.sireRowsCenterY[0], 'Sire: ${data.sireName}'),
              ..._buildCardRow(W, H, fontDetails, CertificateLayout.sireRowsCenterY[1], 'Breed: ${data.sireBreed}'),
              ..._buildCardRow(W, H, fontDetails, CertificateLayout.sireRowsCenterY[2], 'Color: ${data.sireColor}'),
              ..._buildCardRow(W, H, fontDetails, CertificateLayout.sireRowsCenterY[3], 'DOB: ${data.sireDob}'),
              ..._buildCardRow(W, H, fontDetails, CertificateLayout.sireRowsCenterY[4], 'Wt: ${data.sireWeight}'),

              // ─── Right Column Bottom: Dam Photo (with white frame) ──────────
              pw.Positioned(
                left: W * CertificateLayout.damPhotoLeft,
                top: H * CertificateLayout.damPhotoTop,
                child: pw.Container(
                  width: W * CertificateLayout.damPhotoWidth,
                  height: H * CertificateLayout.damPhotoHeight,
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: pw.BorderRadius.all(
                      pw.Radius.circular(W * CertificateLayout.damPhotoRadius),
                    ),
                  ),
                  padding: const pw.EdgeInsets.all(3),
                  child: damPhoto != null
                      ? pw.ClipRRect(
                          horizontalRadius: W * CertificateLayout.damPhotoRadius * 0.8,
                          verticalRadius: W * CertificateLayout.damPhotoRadius * 0.8,
                          child: pw.Image(damPhoto, fit: pw.BoxFit.cover),
                        )
                      : pw.Center(
                          child: pw.Text(
                            'Dam Photo',
                            style: pw.TextStyle(
                              font: fontDetails,
                              fontSize: 10,
                              color: const PdfColor(0.6, 0.6, 0.6),
                            ),
                          ),
                        ),
                ),
              ),

              // ─── Right Column Bottom: Dam Card ──────────────────────────────
              pw.Positioned(
                left: W * CertificateLayout.damCardLeft,
                top: H * CertificateLayout.damCardTop,
                child: pw.Container(
                  width: W * CertificateLayout.damCardWidth,
                  height: H * CertificateLayout.damCardHeight,
                  decoration: pw.BoxDecoration(
                    color: CertificateLayout.pdfColorDamCardBg,
                    borderRadius: pw.BorderRadius.all(
                      pw.Radius.circular(W * CertificateLayout.damCardRadius),
                    ),
                  ),
                ),
              ),

              // Dam Card Text Rows
              ..._buildCardRow(W, H, fontDetails, CertificateLayout.damRowsCenterY[0], 'Dam: ${data.damName}'),
              ..._buildCardRow(W, H, fontDetails, CertificateLayout.damRowsCenterY[1], 'Breed: ${data.damBreed}'),
              ..._buildCardRow(W, H, fontDetails, CertificateLayout.damRowsCenterY[2], 'Color: ${data.damColor}'),
              ..._buildCardRow(W, H, fontDetails, CertificateLayout.damRowsCenterY[3], 'DOB: ${data.damDob}'),
              ..._buildCardRow(W, H, fontDetails, CertificateLayout.damRowsCenterY[4], 'Wt: ${data.damWeight}'),

              // ─── Bottom Left: Certification & Footer ────────────────────────
              // Line 1: "I hereby certify this certificate is true"
              pw.Positioned(
                left: W * CertificateLayout.footerTextLeft,
                top: H * CertificateLayout.certifyLine1CenterY - (H * CertificateLayout.footerRowBoxHeight / 2),
                child: pw.SizedBox(
                  width: W * CertificateLayout.footerTextMaxWidth,
                  height: H * CertificateLayout.footerRowBoxHeight,
                  child: pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(
                      'I hereby certify this certificate is true',
                      style: pw.TextStyle(
                        font: fontDetails,
                        fontSize: W * CertificateLayout.fontRatioCertify,
                        color: CertificateLayout.pdfColorCertifyText,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),

              // Line 2: "to the best of my knowledge"
              pw.Positioned(
                left: W * CertificateLayout.footerTextLeft,
                top: H * CertificateLayout.certifyLine2CenterY - (H * CertificateLayout.footerRowBoxHeight / 2),
                child: pw.SizedBox(
                  width: W * CertificateLayout.footerTextMaxWidth,
                  height: H * CertificateLayout.footerRowBoxHeight,
                  child: pw.Align(
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(
                      'to the best of my knowledge',
                      style: pw.TextStyle(
                        font: fontDetails,
                        fontSize: W * CertificateLayout.fontRatioCertify,
                        color: CertificateLayout.pdfColorCertifyText,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
              ),

              // Breeder Signature (only drawn if ownerName is non-empty)
              if (data.ownerName.trim().isNotEmpty)
                pw.Positioned(
                  left: W * CertificateLayout.signatureLeft,
                  top: H * CertificateLayout.signatureCenterY - (H * CertificateLayout.signatureBoxHeight / 2),
                  child: pw.SizedBox(
                    width: W * CertificateLayout.footerTextMaxWidth,
                    height: H * CertificateLayout.signatureBoxHeight,
                    child: pw.Align(
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        data.ownerName.trim(),
                        style: pw.TextStyle(
                          font: fontSignature,
                          fontSize: W * CertificateLayout.fontRatioSignature,
                          color: CertificateLayout.pdfColorSignatureText,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),

              // Address
              if (data.farmAddress.trim().isNotEmpty)
                pw.Positioned(
                  left: W * CertificateLayout.addressLeft,
                  top: H * CertificateLayout.addressCenterY - (H * CertificateLayout.footerRowBoxHeight / 2),
                  child: pw.SizedBox(
                    width: W * CertificateLayout.footerTextMaxWidth,
                    height: H * CertificateLayout.footerRowBoxHeight,
                    child: pw.Align(
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        data.farmAddress.trim(),
                        style: pw.TextStyle(
                          font: fontDetails,
                          fontSize: W * CertificateLayout.fontRatioContact,
                          color: CertificateLayout.pdfColorContactText,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),

              // Email
              if (data.farmEmail.trim().isNotEmpty)
                pw.Positioned(
                  left: W * CertificateLayout.emailLeft,
                  top: H * CertificateLayout.emailCenterY - (H * CertificateLayout.footerRowBoxHeight / 2),
                  child: pw.SizedBox(
                    width: W * CertificateLayout.footerTextMaxWidth,
                    height: H * CertificateLayout.footerRowBoxHeight,
                    child: pw.Align(
                      alignment: pw.Alignment.centerLeft,
                      child: pw.Text(
                        data.farmEmail.trim(),
                        style: pw.TextStyle(
                          font: fontDetails,
                          fontSize: W * CertificateLayout.fontRatioContact,
                          color: CertificateLayout.pdfColorContactText,
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

  static List<pw.Widget> _buildKitRow(
    double W,
    double H,
    pw.MemoryImage rabbitIcon,
    pw.Font font,
    double centerY,
    String text,
  ) {
    final rowHeight = H * CertificateLayout.kitRowBoxHeight;
    final iconHeight = H * CertificateLayout.kitIconHeight;
    final iconWidth = W * CertificateLayout.kitIconWidth;

    return [
      // Rabbit Bullet Icon
      pw.Positioned(
        left: W * CertificateLayout.kitIconLeft,
        top: H * centerY - (iconHeight / 2),
        child: pw.SizedBox(
          width: iconWidth,
          height: iconHeight,
          child: pw.Image(rabbitIcon, fit: pw.BoxFit.contain),
        ),
      ),
      // Text Row
      pw.Positioned(
        left: W * CertificateLayout.kitTextLeft,
        top: H * centerY - (rowHeight / 2),
        child: pw.SizedBox(
          width: W * CertificateLayout.kitTextMaxWidth,
          height: rowHeight,
          child: pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(
              text,
              style: pw.TextStyle(
                font: font,
                fontSize: W * CertificateLayout.fontRatioKitRows,
                color: CertificateLayout.pdfColorKitText,
              ),
              maxLines: 1,
            ),
          ),
        ),
      ),
    ];
  }

  static List<pw.Widget> _buildCardRow(
    double W,
    double H,
    pw.Font font,
    double centerY,
    String text,
  ) {
    final rowHeight = H * CertificateLayout.cardRowBoxHeight;
    return [
      pw.Positioned(
        left: W * CertificateLayout.cardTextLeft,
        top: H * centerY - (rowHeight / 2),
        child: pw.SizedBox(
          width: W * CertificateLayout.cardTextMaxWidth,
          height: rowHeight,
          child: pw.Align(
            alignment: pw.Alignment.centerLeft,
            child: pw.Text(
              text,
              style: pw.TextStyle(
                font: font,
                fontSize: W * CertificateLayout.fontRatioCardRows,
                color: CertificateLayout.pdfColorCardText,
              ),
              maxLines: 1,
            ),
          ),
        ),
      ),
    ];
  }
}
