import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import '../models/pedigree.dart';
import '../models/rabbit.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../services/format_utils.dart';

/// Centralized layout specification for Pedigree PDF and Flutter Preview.
/// All positions, widths, and heights are defined as fractions of page width (W) and height (H).
/// Page size is US Letter Landscape: 792 x 612 pt.
class PedigreeLayout {
  PedigreeLayout._();

  // ─── PAGE DIMENSIONS ────────────────────────────────────────────────────────
  static const double pageWidthPt = 792.0;
  static const double pageHeightPt = 612.0;
  static const double aspectRatio = 792.0 / 612.0;

  // ─── ASSET PATHS ────────────────────────────────────────────────────────────
  static const String logoAsset = 'assets/images/bunny_pedigree_logo.png';

  // Fonts
  static const String fontTitleAsset = 'assets/fonts/MrDeHaviland-Regular.ttf';
  static const String fontBadgeAsset = 'assets/fonts/EBGaramond-Regular.ttf';
  static const String fontDetailsAsset = 'assets/fonts/PT_Sans-Web-Regular.ttf';
  static const String fontDetailsBoldAsset = 'assets/fonts/PT_Sans-Web-Bold.ttf';
  static const String fontSignatureAsset = 'assets/fonts/MrsSaintDelafield-Regular.ttf';

  // Font family names registered in pubspec.yaml
  static const String fontFamilyTitle = 'CertificateTitle';
  static const String fontFamilyBadge = 'CertificateBadge';
  static const String fontFamilyDetails = 'CertificateDetails';
  static const String fontFamilySignature = 'CertificateSignature';

  // ─── COLORS ─────────────────────────────────────────────────────────────────
  // Flutter UI Colors
  static const Color colorSireCardBg = Color(0xFFA095A3); // gray-mauve
  static const Color colorDamCardBg = Color(0xFFCE87CA);  // lilac
  static const Color colorSubjectBoxBg = Color(0xFFE1F5FB); // light cyan/blue
  static const Color colorSubjectPhotoOutline = Color(0xFF3DB7E4); // cyan
  static const Color colorHeaderTitle = Color(0xFF787878);
  static const Color colorHeaderContact = Color(0xFF888888);
  static const Color colorHeaderUnderline = Color(0xFF9E9E9E);
  static const Color colorSubjectText = Color(0xFF3A3A3C);
  static const Color colorCardText = Colors.white;
  static const Color colorFooterCertify = Color(0xFF6E6E73);
  static const Color colorFooterSignature = Color(0xFF3A3A3C);
  static const Color colorFooterPhone = Color(0xFF555555);

  // PDF Colors
  static const PdfColor pdfColorSireCardBg = PdfColor(0.627, 0.584, 0.639); // #A095A3
  static const PdfColor pdfColorDamCardBg = PdfColor(0.808, 0.529, 0.792);  // #CE87CA
  static const PdfColor pdfColorSubjectBoxBg = PdfColor(0.882, 0.961, 0.984); // #E1F5FB
  static const PdfColor pdfColorSubjectPhotoOutline = PdfColor(0.239, 0.718, 0.894); // #3DB7E4
  static const PdfColor pdfColorHeaderTitle = PdfColor(0.47, 0.47, 0.47);
  static const PdfColor pdfColorHeaderContact = PdfColor(0.53, 0.53, 0.53);
  static const PdfColor pdfColorHeaderUnderline = PdfColor(0.62, 0.62, 0.62);
  static const PdfColor pdfColorSubjectText = PdfColor(0.23, 0.23, 0.24);
  static const PdfColor pdfColorCardText = PdfColors.white;
  static const PdfColor pdfColorFooterCertify = PdfColor(0.43, 0.43, 0.45);
  static const PdfColor pdfColorFooterSignature = PdfColor(0.23, 0.23, 0.24);
  static const PdfColor pdfColorFooterPhone = PdfColor(0.33, 0.33, 0.33);

  // ─── FONT SIZES (pt at 792 pt page width) ───────────────────────────────────
  static const double fontSizeFarmTitlePt = 33.2;
  static const double fontSizeHeaderContactPt = 11.0;
  static const double fontSizeSubjectPt = 14.0;
  static const double fontSizeGen1Pt = 12.0;
  static const double fontSizeGen2Pt = 12.0;
  static const double fontSizeGen3Pt = 10.0;
  static const double fontSizeCertifyPt = 12.0;
  static const double fontSizeSignaturePt = 18.0;
  static const double fontSizePhonePt = 12.0;

  // Font size multipliers (relative to page width W)
  static const double fontRatioFarmTitle = fontSizeFarmTitlePt / pageWidthPt;
  static const double fontRatioHeaderContact = fontSizeHeaderContactPt / pageWidthPt;
  static const double fontRatioSubject = fontSizeSubjectPt / pageWidthPt;
  static const double fontRatioGen1 = fontSizeGen1Pt / pageWidthPt;
  static const double fontRatioGen2 = fontSizeGen2Pt / pageWidthPt;
  static const double fontRatioGen3 = fontSizeGen3Pt / pageWidthPt;
  static const double fontRatioCertify = fontSizeCertifyPt / pageWidthPt;
  static const double fontRatioSignature = fontSizeSignaturePt / pageWidthPt;
  static const double fontRatioPhone = fontSizePhonePt / pageWidthPt;

  // ─── HEADER SPEC ────────────────────────────────────────────────────────────
  static const double farmTitleLeft = 0.0262;
  static const double farmTitleCenterY = 0.0697;
  static const double farmTitleBoxHeight = 0.0650;
  static const double farmTitleMaxWidth = 0.3500;

  static const double addressLeft = 0.0302;
  static const double emailLeft = 0.1960;
  static const double contactCenterY = 0.1055;
  static const double contactBoxHeight = 0.0280;

  static const double underlineX0 = 0.0283;
  static const double underlineX1 = 0.3478;
  static const double underlineY = 0.1171;

  // ─── LOGO SPEC ──────────────────────────────────────────────────────────────
  static const double logoLeft = 0.0600;
  static const double logoTop = 0.1850;
  static const double logoWidth = 0.1450;
  static const double logoHeight = 0.1676;

  // ─── SUBJECT BOX SPEC (Left) ────────────────────────────────────────────────
  static const double subjectBoxLeft = 0.0313;
  static const double subjectBoxTop = 0.3533;
  static const double subjectBoxWidth = 0.2270;
  static const double subjectBoxHeight = 0.2921;
  static const double subjectBoxRadius = 0.0120; // W fraction

  static const double subjectTextLeft = 0.0396;
  static const double subjectSecondColLeft = 0.1660;
  static const double subjectRowBoxHeight = 0.0320;

  static const double subjectNameCenterY = 0.3812;
  static const double subjectColorCenterY = 0.4342;
  static const double subjectBreedCenterY = 0.4728;
  static const double subjectSexCenterY = 0.5063;
  static const double subjectDobCenterY = 0.5493;
  static const double subjectEarWtCenterY = 0.5872;
  static const double subjectRegLegsCenterY = 0.6219;

  // ─── SUBJECT PHOTO ELLIPSE ──────────────────────────────────────────────────
  static const double photoLeft = 0.2722;
  static const double photoTop = 0.3829;
  static const double photoWidth = 0.2295;
  static const double photoHeight = 0.2227;
  static const double photoOutlineWidthPt = 1.5;

  // ─── CARDS SPEC ─────────────────────────────────────────────────────────────
  static const double cardCornerRadius = 0.0120; // W fraction

  // Generation 1 (Parents)
  static const double gen1Width = 0.2354;
  static const double gen1Height = 0.1532;
  static const double gen1TextDx = 0.0069;
  static const double gen1SecondColDx = 0.1410;
  static const List<double> gen1RowDy = [0.0233, 0.0669, 0.0987, 0.1304];

  static const double sireLeft = 0.2675;
  static const double sireTop = 0.1774;

  static const double damLeft = 0.2679;
  static const double damTop = 0.6644;

  // Generation 2 (Grandparents)
  static const double gen2Width = 0.2354;
  static const double gen2Height = 0.1532;
  static const double gen2TextDx = 0.0070;
  static const double gen2SecondColDx = 0.1400;
  static const List<double> gen2RowDy = [0.0252, 0.0688, 0.1003, 0.1322];

  static const double ssLeft = 0.5105;
  static const double ssTop = 0.0549;

  static const double sdLeft = 0.5105;
  static const double sdTop = 0.2996;

  static const double dsLeft = 0.5159;
  static const double dsTop = 0.5502;

  static const double ddLeft = 0.5159;
  static const double ddTop = 0.7949;

  // Generation 3 (Great-Grandparents)
  static const double gen3Left = 0.7582;
  static const double gen3Width = 0.2271;
  static const double gen3Height = 0.1143;
  static const double gen3TextDx = 0.0095;
  static const double gen3SecondColDx = 0.1370;
  static const List<double> gen3RowDy = [0.0165, 0.0490, 0.0727, 0.0964];

  static const double sssTop = 0.0147;
  static const double ssdTop = 0.1372;
  static const double sdsTop = 0.2596;
  static const double sddTop = 0.3813;
  static const double dssTop = 0.5014;
  static const double dsdTop = 0.6239;
  static const double ddsTop = 0.7464;
  static const double dddTop = 0.8680;

  // ─── FOOTER SPEC (Bottom Left) ──────────────────────────────────────────────
  static const double certifyLeft = 0.0260;
  static const double certifyLine1CenterY = 0.8684;
  static const double certifyLine2CenterY = 0.8909;
  static const double certifyBoxHeight = 0.0260;

  static const double signatureLeft = 0.0282;
  static const double signatureCenterY = 0.9389;
  static const double signatureBoxHeight = 0.0400;

  static const double signatureUnderlineX0 = 0.0260;
  static const double signatureUnderlineX1 = 0.1771;
  static const double signatureUnderlineY = 0.9492;

  static const double phoneLeft = 0.0260;
  static const double phoneCenterY = 0.9726;
  static const double phoneBoxHeight = 0.0260;
}

/// Data container for generating and previewing a Pedigree chart
class PedigreeData {
  final String farmName;
  final String farmAddress;
  final String farmEmail;
  final String farmPhone;
  final String ownerName;

  // Subject rabbit
  final String subjectName;
  final String subjectBreed;
  final String subjectColor;
  final String subjectSex;
  final String subjectDob;
  final String subjectEarNo;
  final String subjectWeight;
  final String subjectRegNo;
  final String subjectLegs;
  final String? subjectPhotoPath;

  // 4-Generation Pedigree Tree Root
  final PedigreeRabbit? tree;

  const PedigreeData({
    required this.farmName,
    required this.farmAddress,
    required this.farmEmail,
    required this.farmPhone,
    required this.ownerName,
    required this.subjectName,
    required this.subjectBreed,
    required this.subjectColor,
    required this.subjectSex,
    required this.subjectDob,
    required this.subjectEarNo,
    required this.subjectWeight,
    required this.subjectRegNo,
    required this.subjectLegs,
    this.subjectPhotoPath,
    this.tree,
  });

  /// Builds a complete PedigreeData structure with 4 generations from a Rabbit model
  static Future<PedigreeData> fromRabbit(
    Rabbit rabbit, {
    DatabaseService? db,
    SettingsService? settings,
  }) async {
    final database = db ?? DatabaseService();
    final appSettings = settings ?? SettingsService.instance;

    final tree = await database.buildPedigreeTree(rabbit.id, maxGenerations: 4);

    final sex = rabbit.type == RabbitType.doe ? 'Doe' : 'Buck';
    final dob = rabbit.dateOfBirth != null
        ? FormatUtils.formatCertificateDate(rabbit.dateOfBirth!)
        : '';
    final weight = rabbit.weight != null && rabbit.weight! > 0
        ? FormatUtils.formatWeight(rabbit.weight!)
        : '';
    final earNo = rabbit.earNumber ?? '';
    final regNo = rabbit.registrationNumber ?? '';
    final legs = rabbit.grandChampionLegs != null && rabbit.grandChampionLegs! > 0
        ? '${rabbit.grandChampionLegs}'
        : '';
    final photo = rabbit.photos?.isNotEmpty == true ? rabbit.photos!.first : null;

    return PedigreeData(
      farmName: appSettings.farmName.trim(),
      farmAddress: appSettings.farmAddress.trim(),
      farmEmail: appSettings.farmEmail.trim(),
      farmPhone: appSettings.farmPhone.trim(),
      ownerName: appSettings.ownerName.trim(),
      subjectName: rabbit.name.trim(),
      subjectBreed: rabbit.breed.trim(),
      subjectColor: rabbit.color?.trim() ?? '',
      subjectSex: sex,
      subjectDob: dob,
      subjectEarNo: earNo,
      subjectWeight: weight,
      subjectRegNo: regNo,
      subjectLegs: legs,
      subjectPhotoPath: photo,
      tree: tree,
    );
  }
}
