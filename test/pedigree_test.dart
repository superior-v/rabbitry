import 'package:flutter_test/flutter_test.dart';
import 'package:rearticle_app/widgets/pedigree_layout.dart';
import 'package:rearticle_app/services/pedigree_pdf_service.dart';
import 'package:rearticle_app/models/pedigree.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PedigreeLayout matches pedigree_layout.json spec', () {
    expect(PedigreeLayout.pageWidthPt, 792.0);
    expect(PedigreeLayout.pageHeightPt, 612.0);
    expect(PedigreeLayout.aspectRatio, 792.0 / 612.0);

    // Farm title
    expect(PedigreeLayout.farmTitleLeft, 0.0262);
    expect(PedigreeLayout.farmTitleCenterY, 0.0697);

    // Contact
    expect(PedigreeLayout.addressLeft, 0.0302);
    expect(PedigreeLayout.emailLeft, 0.1960);
    expect(PedigreeLayout.contactCenterY, 0.1055);
    expect(PedigreeLayout.underlineX0, 0.0283);
    expect(PedigreeLayout.underlineX1, 0.3478);
    expect(PedigreeLayout.underlineY, 0.1171);

    // Logo
    expect(PedigreeLayout.logoLeft, 0.0600);
    expect(PedigreeLayout.logoTop, 0.1850);
    expect(PedigreeLayout.logoWidth, 0.1450);
    expect(PedigreeLayout.logoHeight, 0.1676);

    // Subject box
    expect(PedigreeLayout.subjectBoxLeft, 0.0313);
    expect(PedigreeLayout.subjectBoxTop, 0.3533);
    expect(PedigreeLayout.subjectBoxWidth, 0.2270);
    expect(PedigreeLayout.subjectBoxHeight, 0.2921);
    expect(PedigreeLayout.subjectTextLeft, 0.0396);
    expect(PedigreeLayout.subjectSecondColLeft, 0.1660);

    // Subject photo
    expect(PedigreeLayout.photoLeft, 0.2722);
    expect(PedigreeLayout.photoTop, 0.3829);
    expect(PedigreeLayout.photoWidth, 0.2295);
    expect(PedigreeLayout.photoHeight, 0.2227);

    // Gen 1
    expect(PedigreeLayout.gen1Width, 0.2354);
    expect(PedigreeLayout.gen1Height, 0.1532);
    expect(PedigreeLayout.sireLeft, 0.2675);
    expect(PedigreeLayout.sireTop, 0.1774);
    expect(PedigreeLayout.damLeft, 0.2679);
    expect(PedigreeLayout.damTop, 0.6644);

    // Gen 2
    expect(PedigreeLayout.gen2Width, 0.2354);
    expect(PedigreeLayout.gen2Height, 0.1532);
    expect(PedigreeLayout.ssLeft, 0.5105);
    expect(PedigreeLayout.ssTop, 0.0549);
    expect(PedigreeLayout.sdLeft, 0.5105);
    expect(PedigreeLayout.sdTop, 0.2996);
    expect(PedigreeLayout.dsLeft, 0.5159);
    expect(PedigreeLayout.dsTop, 0.5502);
    expect(PedigreeLayout.ddLeft, 0.5159);
    expect(PedigreeLayout.ddTop, 0.7949);

    // Gen 3
    expect(PedigreeLayout.gen3Left, 0.7582);
    expect(PedigreeLayout.gen3Width, 0.2271);
    expect(PedigreeLayout.gen3Height, 0.1143);
    expect(PedigreeLayout.sssTop, 0.0147);
    expect(PedigreeLayout.ssdTop, 0.1372);
    expect(PedigreeLayout.sdsTop, 0.2596);
    expect(PedigreeLayout.sddTop, 0.3813);
    expect(PedigreeLayout.dssTop, 0.5014);
    expect(PedigreeLayout.dsdTop, 0.6239);
    expect(PedigreeLayout.ddsTop, 0.7464);
    expect(PedigreeLayout.dddTop, 0.8680);

    // Footer
    expect(PedigreeLayout.certifyLeft, 0.0260);
    expect(PedigreeLayout.certifyLine1CenterY, 0.8684);
    expect(PedigreeLayout.certifyLine2CenterY, 0.8909);
    expect(PedigreeLayout.signatureLeft, 0.0282);
    expect(PedigreeLayout.signatureCenterY, 0.9389);
    expect(PedigreeLayout.signatureUnderlineX0, 0.0260);
    expect(PedigreeLayout.signatureUnderlineX1, 0.1771);
    expect(PedigreeLayout.signatureUnderlineY, 0.9492);
    expect(PedigreeLayout.phoneLeft, 0.0260);
    expect(PedigreeLayout.phoneCenterY, 0.9726);
  });

  test('Mochi sample 4-generation pedigree PDF generation', () async {
    // Build 4-gen tree matching SBS-12-Mochi.pdf sample
    final tree = PedigreeRabbit(
      id: 'SBS-12',
      name: "SBS's Mochi",
      breed: 'Netherland Dwarf',
      color: 'Blue Vienna Mark',
      sex: 'Buck',
      registrationNumber: '',
      earNumber: '',
      legs: 0,
      generation: 0,
      sire: PedigreeRabbit(
        id: 'sire_1',
        name: "Lee's Lavish Lops Marvel",
        color: 'Blue VM',
        dateOfBirth: DateTime(2024, 10, 9),
        earNumber: '15210702',
        generation: 1,
        sire: PedigreeRabbit(
          id: 'ss_1',
          name: "Lee's Lavish Lops Atlas",
          color: 'Blue VM',
          dateOfBirth: DateTime(2024, 3, 8),
          earNumber: '3LMD1',
          generation: 2,
          sire: PedigreeRabbit(
            id: 'sss_1',
            name: "Lee's Lavish Lops Mouse",
            color: 'Blue VM',
            dateOfBirth: DateTime(2023, 6, 30),
            earNumber: '3L410',
            generation: 3,
          ),
          dam: PedigreeRabbit(
            id: 'ssd_1',
            name: "Lee's Lavish Lops Dallas",
            color: 'Broken Blue VC',
            dateOfBirth: DateTime(2023, 6, 15),
            earNumber: '3L433',
            generation: 3,
          ),
        ),
        dam: PedigreeRabbit(
          id: 'sd_1',
          name: 'Beyond Blessed Dwarfs Marie',
          color: 'Blue Eyed White',
          dateOfBirth: DateTime(2021, 6, 21),
          weight: '2.5625', // 2lb 9oz
          earNumber: 'CL22',
          generation: 2,
          sire: PedigreeRabbit(
            id: 'sds_1',
            name: 'Renew Farm Bunnies Toby',
            color: 'Blue Eyed White',
            dateOfBirth: DateTime(2020, 4, 13),
            weight: '2.1875', // 2lb 3oz
            earNumber: 'T',
            generation: 3,
          ),
          dam: PedigreeRabbit(
            id: 'sdd_1',
            name: 'Beyond Blessed Dwarfs Caludia',
            color: 'Blue VM',
            dateOfBirth: DateTime(2020, 12, 17),
            earNumber: 'FR2',
            generation: 3,
          ),
        ),
      ),
      dam: PedigreeRabbit(
        id: 'dam_1',
        name: "Lee's Lavish Lops Topaz",
        color: 'Blue VM',
        dateOfBirth: DateTime(2024, 6, 25),
        earNumber: '3LTJ1',
        generation: 1,
        sire: PedigreeRabbit(
          id: 'ds_1',
          name: "A3C's Jaskier Jester",
          color: 'BEW',
          dateOfBirth: DateTime(2023, 6, 25),
          weight: '2.0625', // 2lb 1oz
          earNumber: 'A112',
          generation: 2,
          sire: PedigreeRabbit(
            id: 'dss_1',
            name: "A3C's Armani",
            color: 'Chocolate Otter VM',
            dateOfBirth: DateTime(2023, 1, 1),
            earNumber: 'A3C82',
            generation: 3,
          ),
          dam: PedigreeRabbit(
            id: 'dsd_1',
            name: "A3C's Ophelia",
            color: 'BEW',
            dateOfBirth: DateTime(2022, 10, 15),
            earNumber: 'A3C76',
            generation: 3,
          ),
        ),
        dam: PedigreeRabbit(
          id: 'dd_1',
          name: 'Tiny Pawz Tawney',
          color: 'Blue Heavy VM',
          dateOfBirth: DateTime(2023, 1, 30),
          weight: '2.125', // 2lb 2oz
          generation: 2,
          sire: PedigreeRabbit(
            id: 'dds_1',
            name: 'Tiny Pawz Levi',
            color: 'Blue VM',
            dateOfBirth: DateTime(2022, 7, 1),
            weight: '1.8125', // 1lb 13oz
            generation: 3,
          ),
          dam: PedigreeRabbit(
            id: 'ddd_1',
            name: 'Tiny Pawz Skyler',
            color: 'Blue VC',
            dateOfBirth: DateTime(2023, 5, 10),
            weight: '2.4375', // 2lb 7oz
            generation: 3,
          ),
        ),
      ),
    );

    final pedData = PedigreeData(
      farmName: 'Silly Billy Silkies',
      farmAddress: 'Amaranth, ON L9W 3Y4',
      farmEmail: 'SillyBillySilkies@gmail.com',
      farmPhone: '416-806-3485',
      ownerName: 'Gaayathri Vijayakumar',
      subjectName: "SBS's Mochi",
      subjectBreed: 'Netherland Dwarf',
      subjectColor: 'Blue Vienna Mark',
      subjectSex: 'Buck',
      subjectDob: 'July 06, 2026',
      subjectEarNo: '',
      subjectWeight: '',
      subjectRegNo: '',
      subjectLegs: '',
      tree: tree,
    );

    final pdfBytes = await PedigreePdfService.generatePdf(pedData);
    expect(pdfBytes, isNotEmpty);
    expect(String.fromCharCodes(pdfBytes.take(5)), equals('%PDF-'));
  });

  test('Sparse pedigree tree with null ancestors generates valid PDF without crashing', () async {
    final pedData = const PedigreeData(
      farmName: 'Highland Rabbitry',
      farmAddress: '',
      farmEmail: '',
      farmPhone: '',
      ownerName: 'Jane Doe',
      subjectName: 'Buster',
      subjectBreed: 'Mini Rex',
      subjectColor: 'Castor',
      subjectSex: 'Buck',
      subjectDob: 'Jan 01, 2026',
      subjectEarNo: 'EX-01',
      subjectWeight: '4lbs 2oz',
      subjectRegNo: 'REG-999',
      subjectLegs: '3',
      tree: null,
    );

    final pdfBytes = await PedigreePdfService.generatePdf(pedData);
    expect(pdfBytes, isNotEmpty);
    expect(String.fromCharCodes(pdfBytes.take(5)), equals('%PDF-'));
  });

  test('Long ancestor names and empty fields handled gracefully', () async {
    final longTree = PedigreeRabbit(
      id: 'long_1',
      name: 'Grand Champion Supercalifragilisticexpialidocious Long Name Bunny The Great',
      breed: 'French Angora Wool Extraordinaire',
      color: 'Broken Black Gold Tipped Steel Harlequin',
      sex: 'Doe',
      generation: 0,
      sire: PedigreeRabbit(
        id: 'sire_long',
        name: 'The Most Honorable High Prince Of Canterbury Castle Royal Bloodline',
        color: 'Sable Point Extreme Non-Extension',
        generation: 1,
      ),
    );

    final pedData = PedigreeData(
      farmName: 'The Very Long And Prestigious Rabbitry Of North America',
      farmAddress: '1234 Very Long Street Name Road Highway Suite 500, City, ST 12345',
      farmEmail: 'verylongemailaddressfortherabbitryowner@subdomain.example.com',
      farmPhone: '+1 (555) 019-2834 ext. 42',
      ownerName: 'Professor Gaayathri Vijayakumar III, Esq.',
      subjectName: 'Supercalifragilisticexpialidocious',
      subjectBreed: 'French Angora Wool',
      subjectColor: 'Broken Black Gold Tipped Steel',
      subjectSex: 'Doe',
      subjectDob: 'Oct 01, 2026',
      subjectEarNo: 'LONG-EAR-NUMBER-12345',
      subjectWeight: '12lbs 8oz',
      subjectRegNo: 'REG-1234567890-ABCDEF',
      subjectLegs: '15',
      tree: longTree,
    );

    final pdfBytes = await PedigreePdfService.generatePdf(pedData);
    expect(pdfBytes, isNotEmpty);
    expect(String.fromCharCodes(pdfBytes.take(5)), equals('%PDF-'));
  });
}
