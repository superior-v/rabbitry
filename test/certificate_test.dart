import 'package:flutter_test/flutter_test.dart';
import 'package:rearticle_app/widgets/certificate_layout.dart';
import 'package:rearticle_app/services/certificate_pdf_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('CertificatePdfService generates PDF for colorWithPhoto', () async {
    const data = CertificateData(
      name: 'Brussels',
      breed: 'Netherland Dwarf',
      color: 'Opal',
      dob: 'Feb 02, 2025',
      sex: 'Buck',
      damName: 'DC 57',
      sireName: 'Carrot',
      option: CertificateOption.colorWithPhoto,
    );

    final bytes = await CertificatePdfService.generatePdf(data);
    expect(bytes.isNotEmpty, isTrue);
  });

  test('CertificatePdfService generates PDF for colorNoPhoto and blackAndWhite', () async {
    const dataColor = CertificateData(
      name: 'Brussels',
      breed: 'Netherland Dwarf',
      color: 'Opal',
      dob: 'Feb 02, 2025',
      sex: 'Buck',
      damName: 'DC 57',
      sireName: 'Carrot',
      option: CertificateOption.colorNoPhoto,
    );

    final bytesColor = await CertificatePdfService.generatePdf(dataColor);
    expect(bytesColor.isNotEmpty, isTrue);

    const dataBw = CertificateData(
      name: 'Brussels',
      breed: 'Netherland Dwarf',
      color: 'Opal',
      dob: 'Feb 02, 2025',
      sex: 'Buck',
      damName: 'DC 57',
      sireName: 'Carrot',
      option: CertificateOption.blackAndWhite,
    );

    final bytesBw = await CertificatePdfService.generatePdf(dataBw);
    expect(bytesBw.isNotEmpty, isTrue);
  });
}
