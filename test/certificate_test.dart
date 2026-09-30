import 'package:flutter_test/flutter_test.dart';
import 'package:rearticle_app/widgets/certificate_layout.dart';
import 'package:rearticle_app/services/certificate_pdf_service.dart';
import 'package:rearticle_app/services/format_utils.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Certificate layout coordinates & collision avoidance', () {
    expect(CertificateLayout.pageWidthPt, 792.0);
    expect(CertificateLayout.pageHeightPt, 612.0);
    expect(CertificateLayout.badgeTop, 0.1250);
    expect(CertificateLayout.titleCenterY, 0.0680);
    expect(CertificateLayout.badgeWidth, 0.2620);
    expect(CertificateLayout.badgeLeft, 0.3672);

    // Verify breathing room between title box bottom and badge top is at least 0.008 * H
    final titleBottom = CertificateLayout.titleCenterY + (CertificateLayout.titleBoxHeight / 2);
    final breathingRoom = CertificateLayout.badgeTop - titleBottom;
    expect(breathingRoom, greaterThanOrEqualTo(0.008));
  });

  test('FormatUtils.formatCertificateDate validation', () {
    expect(FormatUtils.formatCertificateDate(DateTime(2026, 5, 12)), 'May 12, 2026');
    expect(FormatUtils.formatCertificateDate(DateTime(2026, 2, 1)), 'Feb 1, 2026');
    expect(FormatUtils.formatCertificateDate(DateTime(2026, 2, 2)), 'Feb 2, 2026');
    expect(FormatUtils.formatCertificateDate(DateTime(2022, 2, 21)), 'Feb 21, 2022');
    expect(FormatUtils.formatCertificateDate(DateTime(2023, 3, 29)), 'Mar 29, 2023');
    expect(FormatUtils.formatCertificateDate(null), '—');
    expect(FormatUtils.formatCertificateDate(''), '—');
    expect(FormatUtils.formatCertificateDate('2026-02-01T00:00:00.000'), 'Feb 1, 2026');
  });

  test('Certificate PDF generation with real & empty breeder details', () async {
    // 1. Data matching user's exact case (kit "gg", sire "Bill", dam "Max", farm "Dynasty Bunnies Jumping")
    final dataWithOwner = CertificateData(
      farmName: 'Dynasty Bunnies Jumping',
      ownerName: 'Gaayathri Vijayakumar',
      farmAddress: 'Amaranth, ON L9W 3Y4',
      farmEmail: 'SillyBillySilkies@gmail.com',
      kitName: 'gg',
      kitBreed: 'hiii',
      kitColor: 'black',
      kitDob: FormatUtils.formatCertificateDate(DateTime(2026, 2, 1)),
      kitSex: 'Female',
      sireName: 'Bill',
      sireBreed: '—',
      sireColor: 'White',
      sireDob: FormatUtils.formatCertificateDate(DateTime(2026, 2, 2)),
      sireWeight: '5lbs',
      damName: 'Max',
      damBreed: 'Holland Lop',
      damColor: 'black',
      damDob: FormatUtils.formatCertificateDate(DateTime(2026, 2, 1)),
      damWeight: '6lbs',
      includePhoto: false,
    );

    final pdfBytes1 = await CertificatePdfService.generatePdf(dataWithOwner);
    expect(pdfBytes1, isNotEmpty);
    expect(String.fromCharCodes(pdfBytes1.take(5)), equals('%PDF-'));

    // 2. Data with empty ownerName, address, email (should not print "Farm Owner")
    final dataEmptyOwner = CertificateData(
      farmName: 'Dynasty',
      ownerName: '',
      farmAddress: '',
      farmEmail: '',
      kitName: 'gg',
      kitBreed: 'hiii',
      kitColor: 'black',
      kitDob: 'Feb 1, 2026',
      kitSex: 'Female',
      sireName: 'Bill',
      sireBreed: '—',
      sireColor: 'White',
      sireDob: 'Feb 2, 2026',
      sireWeight: '5lbs',
      damName: 'Max',
      damBreed: 'Holland Lop',
      damColor: 'black',
      damDob: 'Feb 1, 2026',
      damWeight: '6lbs',
      includePhoto: false,
    );

    final pdfBytes2 = await CertificatePdfService.generatePdf(dataEmptyOwner);
    expect(pdfBytes2, isNotEmpty);
    expect(String.fromCharCodes(pdfBytes2.take(5)), equals('%PDF-'));
  });
}
