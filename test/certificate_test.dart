import 'package:flutter_test/flutter_test.dart';
import 'package:rearticle_app/widgets/certificate_layout.dart';
import 'package:rearticle_app/services/certificate_pdf_service.dart';
import 'package:rearticle_app/services/format_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('CertificateLayout v2 matches certificate_v2_layout.json spec', () {
    expect(CertificateLayout.pageWidthPt, 792.0);
    expect(CertificateLayout.pageHeightPt, 612.0);
    expect(CertificateLayout.aspectRatio, 792.0 / 612.0);

    // Borders
    expect(CertificateLayout.outerBorderLeft, 0.0007);
    expect(CertificateLayout.outerBorderTop, 0.0032);
    expect(CertificateLayout.outerBorderWidth, 0.9987);
    expect(CertificateLayout.outerBorderHeight, 0.9987);
    expect(CertificateLayout.outerBorderStrokePt, 3.0);

    expect(CertificateLayout.innerBorderLeft, 0.0172);
    expect(CertificateLayout.innerBorderTop, 0.0209);
    expect(CertificateLayout.innerBorderWidth, 0.9658);
    expect(CertificateLayout.innerBorderHeight, 0.9614);
    expect(CertificateLayout.innerBorderStrokePt, 2.0);

    // Badge
    expect(CertificateLayout.badgeLeft, 0.1643);
    expect(CertificateLayout.badgeTop, 0.0843);
    expect(CertificateLayout.badgeWidth, 0.6714);
    expect(CertificateLayout.badgeHeight, 0.1036);
    expect(CertificateLayout.badgeRadius, 0.0100);
    expect(CertificateLayout.badgeStrokePt, 1.0);
    expect(CertificateLayout.badgeText, 'CERTIFICATE OF BIRTH');
    expect(CertificateLayout.badgeTextCenterX, 0.5000);
    expect(CertificateLayout.badgeTextCenterY, 0.1304);

    // Photo
    expect(CertificateLayout.photoLeft, 0.0658);
    expect(CertificateLayout.photoTop, 0.3044);
    expect(CertificateLayout.photoWidth, 0.4947);
    expect(CertificateLayout.photoHeight, 0.5005);
    expect(CertificateLayout.photoRadius, 0.0350);
    expect(CertificateLayout.photoBorderWidthPt, 2.0);

    // Icons & Detail rows
    expect(CertificateLayout.iconLeft, 0.6325);
    expect(CertificateLayout.iconWidth, 0.0250);
    expect(CertificateLayout.iconHeight, 0.0385);

    expect(CertificateLayout.iconTopName, 0.3054);
    expect(CertificateLayout.iconTopBreed, 0.3890);
    expect(CertificateLayout.iconTopColor, 0.4773);
    expect(CertificateLayout.iconTopDob, 0.5703);
    expect(CertificateLayout.iconTopSex, 0.6633);
    expect(CertificateLayout.iconTopParents, 0.7564);

    expect(CertificateLayout.textLeft, 0.6722);
    expect(CertificateLayout.textMaxWidth, 0.3000);
    expect(CertificateLayout.rowNameCenterY, 0.3389);
    expect(CertificateLayout.rowBreedCenterY, 0.4215);
    expect(CertificateLayout.rowColorCenterY, 0.5081);
    expect(CertificateLayout.rowDobCenterY, 0.6024);
    expect(CertificateLayout.rowSexCenterY, 0.6967);
    expect(CertificateLayout.rowParentsCenterY, 0.7885);
  });

  test('FormatUtils.formatCertificateDatePadded zero-padded validation', () {
    expect(FormatUtils.formatCertificateDatePadded(DateTime(2025, 2, 2)), 'Feb 02, 2025');
    expect(FormatUtils.formatCertificateDatePadded(DateTime(2026, 5, 12)), 'May 12, 2026');
    expect(FormatUtils.formatCertificateDatePadded(DateTime(2026, 1, 9)), 'Jan 09, 2026');
    expect(FormatUtils.formatCertificateDatePadded(null), '—');
    expect(FormatUtils.formatCertificateDatePadded(''), '—');
    expect(FormatUtils.formatCertificateDatePadded('2025-02-02T00:00:00.000'), 'Feb 02, 2025');
  });

  test('Brussels client example Certificate v2 PDF generation', () async {
    final brusselsData = CertificateData(
      name: 'Brussels',
      breed: 'Netherland Dwarf',
      color: 'Opal',
      dob: FormatUtils.formatCertificateDatePadded(DateTime(2025, 2, 2)),
      sex: 'Buck',
      damName: 'DC 57',
      sireName: 'Carrot',
      includePhoto: false,
    );

    final pdfBytes = await CertificatePdfService.generatePdf(brusselsData);
    expect(pdfBytes, isNotEmpty);
    expect(String.fromCharCodes(pdfBytes.take(5)), equals('%PDF-'));
  });

  test('Missing parents and empty fields generate valid PDF with fallbacks', () async {
    final emptyData = CertificateData(
      name: 'Solo Bun',
      breed: '',
      color: '',
      dob: '',
      sex: 'Doe',
      damName: '',
      sireName: '',
      includePhoto: false,
    );

    final pdfBytes = await CertificatePdfService.generatePdf(emptyData);
    expect(pdfBytes, isNotEmpty);
    expect(String.fromCharCodes(pdfBytes.take(5)), equals('%PDF-'));
  });

  test('Very long name and long parent names scale gracefully', () async {
    final longData = const CertificateData(
      name: 'Grand Champion Supercalifragilisticexpialidocious Bunny The Great',
      breed: 'French Angora Extraordinaire With Long Pedigree Heritage',
      color: 'Broken Black Gold Tipped Steel Harlequin Fox',
      dob: 'Feb 02, 2025',
      sex: 'Buck',
      damName: 'Lady Beatrice Of Canterbury Long Name Castle',
      sireName: 'Prince Montgomery Alexander Royal Lineage The Second',
      includePhoto: false,
    );

    final pdfBytes = await CertificatePdfService.generatePdf(longData);
    expect(pdfBytes, isNotEmpty);
    expect(String.fromCharCodes(pdfBytes.take(5)), equals('%PDF-'));
  });
}
