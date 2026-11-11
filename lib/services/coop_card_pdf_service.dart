import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../widgets/certificate_layout.dart';

/// Supported coop (cage) card sizes. Dimensions are given as short x long side in inches.
enum CoopCardSize {
  twoByThree('2X3', 2, 3),
  threeByFive('3X5', 3, 5),
  fourBySeven('4X7', 4, 7);

  const CoopCardSize(this.label, this.shortIn, this.longIn);
  final String label;
  final double shortIn;
  final double longIn;

  String dimensionLabel({required bool landscape}) {
    final w = landscape ? longIn.toInt() : shortIn.toInt();
    final h = landscape ? shortIn.toInt() : longIn.toInt();
    return '$w" × $h" (${landscape ? 'Landscape' : 'Portrait'})';
  }
}

/// Data shown on a coop card.
class CoopCardData {
  final String name;
  final String breed;
  final String ageClass;
  final String color;
  final String tattoo;
  final String dob;
  final String cage;
  final String weight;
  final String sire;
  final String dam;

  const CoopCardData({
    required this.name,
    required this.breed,
    required this.ageClass,
    this.color = '',
    this.tattoo = '',
    this.dob = '',
    this.cage = '',
    this.weight = '',
    this.sire = '',
    this.dam = '',
  });

  /// Second line in the grey band, e.g. "Netherland Dwarf Senior".
  String get subtitle =>
      [breed.trim(), ageClass.trim()].where((e) => e.isNotEmpty).join(' ');

  /// Age class derived from the date of birth (Junior under 6 months, otherwise Senior).
  static String ageClassFor(DateTime? dob, {DateTime? now, bool isGrowout = false}) {
    if (dob == null) return isGrowout ? 'Junior' : 'Senior';
    final today = now ?? DateTime.now();
    var months = (today.year - dob.year) * 12 + (today.month - dob.month);
    if (today.day < dob.day) months -= 1;
    return months < 6 ? 'Junior' : 'Senior';
  }
}

/// Generates coop card PDFs in 2x3, 3x5 and 4x7 inches, landscape or portrait.
class CoopCardPdfService {
  CoopCardPdfService._();

  static const PdfColor _textColor = PdfColor(0.15, 0.15, 0.16);
  static const PdfColor _subtitleColor = PdfColor(0.33, 0.33, 0.35);
  static const PdfColor _bandColor = PdfColor(0.925, 0.925, 0.93);
  static const PdfColor _borderColor = PdfColor(0.35, 0.35, 0.37);

  /// Exact card dimensions in PDF points (1 inch = 72 pt).
  static PdfPageFormat cardFormatFor(CoopCardSize size, {required bool landscape}) {
    final shortPt = size.shortIn * PdfPageFormat.inch;
    final longPt = size.longIn * PdfPageFormat.inch;
    return landscape
        ? PdfPageFormat(longPt, shortPt)
        : PdfPageFormat(shortPt, longPt);
  }

  /// Standard US Letter sheet oriented to match the card so it prints at true physical inches.
  static PdfPageFormat pageFormatFor(CoopCardSize size, {required bool landscape}) {
    return landscape ? PdfPageFormat.letter.landscape : PdfPageFormat.letter.portrait;
  }

  static Future<Uint8List> generatePdf(
    CoopCardData data, {
    required CoopCardSize size,
    required bool landscape,
  }) async {
    final fontBody =
        pw.Font.ttf(await rootBundle.load(CertificateLayout.fontQuicksandMediumAsset));
    final fontBold =
        pw.Font.ttf(await rootBundle.load(CertificateLayout.fontQuicksandBoldAsset));
    final fontName =
        pw.Font.ttf(await rootBundle.load(CertificateLayout.fontAscenderAsset));

    final cardFormat = cardFormatFor(size, landscape: landscape);
    final pageFormat = pageFormatFor(size, landscape: landscape);
    final W = cardFormat.width;
    final H = cardFormat.height;

    // Scale relative to the 4x7 card's short side (4 inches = 288 pt).
    final u = (landscape ? H : W) / 288.0;

    pw.Widget field(String label, String value, {double fontSize = 15.0}) =>
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label.isEmpty ? '' : '$label ',
              style: pw.TextStyle(
                font: fontBody,
                fontSize: fontSize * u,
                color: _textColor,
              ),
            ),
            pw.Expanded(
              child: pw.Text(
                value,
                style: pw.TextStyle(
                  font: fontBold,
                  fontSize: fontSize * u,
                  color: _textColor,
                ),
                maxLines: 1,
              ),
            ),
          ],
        );

    final padH = 12.0 * u;
    final nameStyleSize = (landscape ? 50.0 : 42.0) * u;

    final header = pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
          height: (landscape ? 68.0 : 62.0) * u,
          padding: pw.EdgeInsets.symmetric(horizontal: padH, vertical: 4 * u),
          alignment: pw.Alignment.center,
          child: pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            child: pw.Text(
              (data.name.trim().isNotEmpty ? data.name.trim() : 'RABBIT').toUpperCase(),
              style: pw.TextStyle(
                font: fontName,
                fontSize: nameStyleSize,
                color: PdfColors.black,
              ),
              maxLines: 1,
            ),
          ),
        ),
        pw.Container(
          height: (landscape ? 36.0 : 32.0) * u,
          color: _bandColor,
          padding: pw.EdgeInsets.symmetric(horizontal: padH, vertical: 4 * u),
          alignment: pw.Alignment.center,
          child: pw.FittedBox(
            fit: pw.BoxFit.scaleDown,
            child: pw.Text(
              data.subtitle.isNotEmpty ? data.subtitle : '—',
              style: pw.TextStyle(
                font: fontBody,
                fontSize: 18.5 * u,
                color: _subtitleColor,
              ),
              maxLines: 1,
            ),
          ),
        ),
      ],
    );

    pw.Widget body;
    if (landscape) {
      body = pw.Padding(
        padding: pw.EdgeInsets.fromLTRB(padH, 10 * u, padH, 8 * u),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Row(
              children: [
                pw.Expanded(flex: 11, child: field('Color:', data.color)),
                pw.SizedBox(width: 6 * u),
                pw.Expanded(flex: 9, child: field('Tattoo:', data.tattoo)),
              ],
            ),
            pw.Row(
              children: [
                pw.Expanded(flex: 11, child: field('Date of Birth:', data.dob)),
                pw.SizedBox(width: 6 * u),
                pw.Expanded(flex: 9, child: field('Cage No.:', data.cage)),
              ],
            ),
            field('Weight:', data.weight),
            field('Sire:', data.sire),
            field('Dam:', data.dam),
          ],
        ),
      );
    } else {
      body = pw.Padding(
        padding: pw.EdgeInsets.fromLTRB(padH, 12 * u, padH, 12 * u),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            field('Color:', data.color),
            field('Tattoo:', data.tattoo),
            field('Date of Birth:', data.dob),
            field('Cage No.:', data.cage),
            field('Weight:', data.weight),
            field('Sire:', data.sire),
            field('Dam:', data.dam),
          ],
        ),
      );
    }

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (context) => pw.Center(
          child: pw.Container(
            width: W,
            height: H,
            decoration: pw.BoxDecoration(
              color: PdfColors.white,
              border: pw.Border.all(color: _borderColor, width: 0.85),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                header,
                pw.Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
    return pdf.save();
  }
}
