import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../widgets/certificate_layout.dart';

class CertificatePdfService {
  CertificatePdfService._();

  /// Generates the Birth Certificate v2 PDF as a byte array.
  static Future<Uint8List> generatePdf(CertificateData data) async {
    final pdf = pw.Document(compress: true);

    // ─── 1. Load Background & Icon Assets ─────────────────────────────────────
    final bgByteData = await rootBundle.load(CertificateLayout.backgroundAsset);
    final bgImage = pw.MemoryImage(bgByteData.buffer.asUint8List());

    final iconByteData = await rootBundle.load(CertificateLayout.rabbitIconAsset);
    final rabbitIcon = pw.MemoryImage(iconByteData.buffer.asUint8List());

    // ─── 2. Load Bundled TTF Fonts ───────────────────────────────────────────
    final fontBadgeData = await rootBundle.load(CertificateLayout.fontBadgeWesternAsset);
    final fontDetailsData = await rootBundle.load(CertificateLayout.fontDetailsAsset);
    final fontDetailsBoldData = await rootBundle.load(CertificateLayout.fontDetailsBoldAsset);

    final fontBadge = pw.Font.ttf(fontBadgeData);
    final fontDetails = pw.Font.ttf(fontDetailsData);
    final fontDetailsBold = pw.Font.ttf(fontDetailsBoldData);

    // ─── 3. Load Photo (if enabled) ───────────────────────────────────────────
    pw.MemoryImage? photo;
    if (data.includePhoto && data.photoPath != null && data.photoPath!.isNotEmpty) {
      final file = File(data.photoPath!);
      if (await file.exists()) {
        photo = pw.MemoryImage(await file.readAsBytes());
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

          // Compute badge font size with auto-scaling if needed
          final double badgeFontSize = W * CertificateLayout.fontRatioBadge;

          // Detail rows definitions
          final List<_DetailRowDef> rows = [
            _DetailRowDef(
              label: 'Name:',
              value: data.name.isNotEmpty ? data.name : '—',
              iconTop: CertificateLayout.iconTopName,
              rowCenterY: CertificateLayout.rowNameCenterY,
            ),
            _DetailRowDef(
              label: 'Breed:',
              value: data.breed.isNotEmpty ? data.breed : '—',
              iconTop: CertificateLayout.iconTopBreed,
              rowCenterY: CertificateLayout.rowBreedCenterY,
            ),
            _DetailRowDef(
              label: 'Color:',
              value: data.color.isNotEmpty ? data.color : '—',
              iconTop: CertificateLayout.iconTopColor,
              rowCenterY: CertificateLayout.rowColorCenterY,
            ),
            _DetailRowDef(
              label: 'DOB:',
              value: data.dob.isNotEmpty ? data.dob : '—',
              iconTop: CertificateLayout.iconTopDob,
              rowCenterY: CertificateLayout.rowDobCenterY,
            ),
            _DetailRowDef(
              label: 'Sex:',
              value: data.sex.isNotEmpty ? data.sex : '—',
              iconTop: CertificateLayout.iconTopSex,
              rowCenterY: CertificateLayout.rowSexCenterY,
            ),
            _DetailRowDef(
              label: 'Parents:',
              value: 'Dam ${data.damName.isNotEmpty ? data.damName : "Unknown"} X Sire ${data.sireName.isNotEmpty ? data.sireName : "Unknown"}',
              iconTop: CertificateLayout.iconTopParents,
              rowCenterY: CertificateLayout.rowParentsCenterY,
            ),
          ];

          return pw.Stack(
            children: [
              // Layer 1: Background Watercolor (Full Bleed)
              pw.Positioned.fill(
                child: pw.Image(bgImage, fit: pw.BoxFit.fill),
              ),

              // Layer 2: Outer Border (3 pt #656263)
              pw.Positioned(
                left: W * CertificateLayout.outerBorderLeft,
                top: H * CertificateLayout.outerBorderTop,
                child: pw.Container(
                  width: W * CertificateLayout.outerBorderWidth,
                  height: H * CertificateLayout.outerBorderHeight,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: CertificateLayout.pdfColorBorderOuter,
                      width: CertificateLayout.outerBorderStrokePt,
                    ),
                  ),
                ),
              ),

              // Layer 3: Inner Border (2 pt #4F4C4D)
              pw.Positioned(
                left: W * CertificateLayout.innerBorderLeft,
                top: H * CertificateLayout.innerBorderTop,
                child: pw.Container(
                  width: W * CertificateLayout.innerBorderWidth,
                  height: H * CertificateLayout.innerBorderHeight,
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                      color: CertificateLayout.pdfColorBorderInner,
                      width: CertificateLayout.innerBorderStrokePt,
                    ),
                  ),
                ),
              ),

              // Layer 4: Top Badge (#AAE3EC fill, 1 pt white stroke)
              pw.Positioned(
                left: W * CertificateLayout.badgeLeft,
                top: H * CertificateLayout.badgeTop,
                child: pw.Container(
                  width: W * CertificateLayout.badgeWidth,
                  height: H * CertificateLayout.badgeHeight,
                  decoration: pw.BoxDecoration(
                    color: CertificateLayout.pdfColorBadgeBg,
                    border: pw.Border.all(
                      color: CertificateLayout.pdfColorBadgeStroke,
                      width: CertificateLayout.badgeStrokePt,
                    ),
                    borderRadius: pw.BorderRadius.all(
                      pw.Radius.circular(W * CertificateLayout.badgeRadius),
                    ),
                  ),
                  child: pw.Center(
                    child: pw.SizedBox(
                      width: W * CertificateLayout.badgeTextMaxWidth,
                      height: H * CertificateLayout.badgeHeight,
                      child: pw.FittedBox(
                        fit: pw.BoxFit.scaleDown,
                        alignment: pw.Alignment.center,
                        child: _buildOutlinedText(
                          text: CertificateLayout.badgeText,
                          font: fontBadge,
                          fontSize: badgeFontSize,
                          fillColor: CertificateLayout.pdfColorBadgeText,
                          outlineColor: PdfColors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Layer 5: Left Photo Frame
              pw.Positioned(
                left: W * CertificateLayout.photoLeft,
                top: H * CertificateLayout.photoTop,
                child: pw.Container(
                  width: W * CertificateLayout.photoWidth,
                  height: H * CertificateLayout.photoHeight,
                  decoration: pw.BoxDecoration(
                    borderRadius: pw.BorderRadius.all(
                      pw.Radius.circular(W * CertificateLayout.photoRadius),
                    ),
                    color: photo != null ? null : CertificateLayout.pdfColorPlaceholderBg,
                  ),
                  child: pw.Stack(
                    children: [
                      if (photo != null)
                        pw.Positioned.fill(
                          child: pw.ClipRRect(
                            horizontalRadius: W * CertificateLayout.photoRadius,
                            verticalRadius: W * CertificateLayout.photoRadius,
                            child: pw.Image(photo, fit: pw.BoxFit.cover),
                          ),
                        ),
                      pw.Positioned.fill(
                        child: pw.Container(
                          decoration: pw.BoxDecoration(
                            borderRadius: pw.BorderRadius.all(
                              pw.Radius.circular(W * CertificateLayout.photoRadius),
                            ),
                            border: pw.Border.all(
                              color: CertificateLayout.pdfColorPhotoBorder,
                              width: CertificateLayout.photoBorderWidthPt,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Layer 6: Right Detail Rows (Icons + Text)
              for (final r in rows) ..._buildPdfDetailRow(W, H, rabbitIcon, fontDetails, fontDetailsBold, r),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  // ─── OUTLINED TEXT RENDERER ─────────────────────────────────────────────────
  static pw.Widget _buildOutlinedText({
    required String text,
    required pw.Font font,
    required double fontSize,
    required PdfColor fillColor,
    required PdfColor outlineColor,
  }) {
    // Render outline by drawing small offsets around the center
    const double off = 1.0;
    return pw.Stack(
      alignment: pw.Alignment.center,
      children: [
        pw.Transform.translate(offset: const PdfPoint(-off, -off), child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: fontSize, color: outlineColor), maxLines: 1, softWrap: false)),
        pw.Transform.translate(offset: const PdfPoint(off, -off), child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: fontSize, color: outlineColor), maxLines: 1, softWrap: false)),
        pw.Transform.translate(offset: const PdfPoint(-off, off), child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: fontSize, color: outlineColor), maxLines: 1, softWrap: false)),
        pw.Transform.translate(offset: const PdfPoint(off, off), child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: fontSize, color: outlineColor), maxLines: 1, softWrap: false)),
        pw.Transform.translate(offset: const PdfPoint(0, -off * 1.2), child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: fontSize, color: outlineColor), maxLines: 1, softWrap: false)),
        pw.Transform.translate(offset: const PdfPoint(0, off * 1.2), child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: fontSize, color: outlineColor), maxLines: 1, softWrap: false)),
        pw.Transform.translate(offset: const PdfPoint(-off * 1.2, 0), child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: fontSize, color: outlineColor), maxLines: 1, softWrap: false)),
        pw.Transform.translate(offset: const PdfPoint(off * 1.2, 0), child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: fontSize, color: outlineColor), maxLines: 1, softWrap: false)),
        pw.Text(text, style: pw.TextStyle(font: font, fontSize: fontSize, color: fillColor), maxLines: 1, softWrap: false),
      ],
    );
  }

  // ─── DETAIL ROW RENDERER ────────────────────────────────────────────────────
  static List<pw.Widget> _buildPdfDetailRow(
    double W,
    double H,
    pw.MemoryImage rabbitIcon,
    pw.Font font,
    pw.Font fontBold,
    _DetailRowDef rowDef,
  ) {
    final double rowHeight = H * CertificateLayout.textRowHeight;
    final double totalRowWidth = W * (CertificateLayout.textLeft - CertificateLayout.iconLeft + CertificateLayout.textMaxWidth);

    double valueFontSize = W * CertificateLayout.fontRatioDetails;
    final double minFontSize = W * CertificateLayout.fontRatioDetailsMin;

    if (rowDef.value.length > 20) {
      valueFontSize = (valueFontSize * 20 / rowDef.value.length).clamp(minFontSize, valueFontSize);
    }

    final double labelFontSize = W * CertificateLayout.fontRatioDetails;

    return [
      pw.Positioned(
        left: W * CertificateLayout.iconLeft,
        top: H * rowDef.rowCenterY - (rowHeight / 2),
        child: pw.Container(
          width: totalRowWidth,
          height: rowHeight,
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.SizedBox(
                width: W * CertificateLayout.iconWidth,
                height: H * CertificateLayout.iconHeight,
                child: pw.Image(rabbitIcon, fit: pw.BoxFit.contain),
              ),
              pw.SizedBox(width: W * 0.012),
              pw.SizedBox(
                width: W * CertificateLayout.labelWidth,
                child: pw.Text(
                  rowDef.label,
                  style: pw.TextStyle(
                    font: fontBold,
                    fontSize: labelFontSize,
                    color: CertificateLayout.pdfColorDetailsText,
                    fontWeight: pw.FontWeight.bold,
                  ),
                  maxLines: 1,
                ),
              ),
              pw.SizedBox(width: W * CertificateLayout.labelGap),
              pw.Expanded(
                child: pw.Align(
                  alignment: pw.Alignment.centerLeft,
                  child: pw.Text(
                    rowDef.value,
                    style: pw.TextStyle(
                      font: font,
                      fontSize: valueFontSize,
                      color: CertificateLayout.pdfColorDetailsText,
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }
}

class _DetailRowDef {
  final String label;
  final String value;
  final double iconTop;
  final double rowCenterY;

  const _DetailRowDef({
    required this.label,
    required this.value,
    required this.iconTop,
    required this.rowCenterY,
  });
}
