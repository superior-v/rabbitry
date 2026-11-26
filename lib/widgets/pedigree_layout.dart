import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import '../models/pedigree.dart';
import '../models/rabbit.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';
import '../services/format_utils.dart';

/// 2 Pedigree orientation options
enum PedigreeOrientation {
  landscape,
  portrait,
}

/// Centralized layout specification for Pedigree PDF and Flutter Preview.
/// All positions, widths, and heights are defined as fractions of page width (W) and height (H).
/// Page size is US Letter Landscape: 792 x 612 pt, or US Letter Portrait: 612 x 792 pt.
class PedigreeLayout {
  PedigreeLayout._();

  // ─── PAGE DIMENSIONS (Landscape) ──────────────────────────────────────────
  static const double pageWidthPt = 792.0;
  static const double pageHeightPt = 612.0;
  static const double aspectRatio = 792.0 / 612.0;

  // ─── PORTRAIT REFERENCE (PortraitPedigreeC) ───────────────────────────────
  // Header band, card header tints, photo square and connector lines (pt).
  static const Color portraitBandColor = Color(0xFFAC85BC);
  static const Color portraitSireTint = Color(0xFFDCF1F9);
  static const Color portraitDamTint = Color(0xFFF9DCE9);
  static const Color portraitPhotoBorder = Color(0xFFDBF2F9);
  static const double portraitPhotoLeft = 28.9;
  static const double portraitPhotoTop = 371.2;
  static const double portraitPhotoSize = 153.4;
  // x1, y1, x2, y2
  static const List<List<double>> portraitConnectors = [
    [191.5, 267.3, 219.7, 254.5], [192.4, 329.4, 219.7, 342.1],
    [193.4, 566.4, 220.7, 553.3], [193.4, 628.7, 220.7, 641.8],
    [392.9, 192.3, 420.1, 157.5], [392.3, 254.5, 419.6, 288.5],
    [392.3, 342.1, 419.6, 307.1], [392.3, 404.3, 419.6, 438.3],
    [393.3, 491.1, 420.6, 455.9], [393.3, 553.3, 420.6, 587.0],
    [393.3, 641.8, 420.6, 606.6], [393.3, 704.0, 420.6, 737.8],
  ];

  // ─── PAGE DIMENSIONS (Portrait) ───────────────────────────────────────────
  static const double portraitPageWidthPt = 612.0;
  static const double portraitPageHeightPt = 792.0;
  static const double portraitAspectRatio = 612.0 / 792.0;

  // ─── ASSET PATHS ────────────────────────────────────────────────────────────
  static const String logoAsset = 'assets/images/bunny_pedigree_logo.png';

  // Fonts
  static const String fontTitleAsset = 'assets/fonts/MrDeHaviland-Regular.ttf';
  static const String fontBadgeAsset = 'assets/fonts/EBGaramond-Regular.ttf';
  static const String fontDetailsAsset = 'assets/fonts/PT_Sans-Web-Regular.ttf';
  // No bold anywhere on the pedigree: the "bold" slot maps to the regular face
  static const String fontDetailsBoldAsset = 'assets/fonts/PT_Sans-Web-Regular.ttf';
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
  static const double fontSizeSignaturePt = 13.3;
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
  // Shared left edge for farm name + contact lines (aligned with subject box)
  static const double pedigreeHeaderLeft = 0.0313;
  static const double farmTitleCenterY = 0.0562;
  static const double farmTitleBoxHeight = 0.0650;
  static const double farmTitleMaxWidth = 0.3500;

  static const double addressLeft = 0.0302;
  static const double emailLeft = 0.1960;
  static const double contactCenterY = 0.1055;
  static const double contactBoxHeight = 0.0280;

  static const double underlineX0 = 0.0283;
  static const double underlineX1 = 0.3478;
  static const double underlineY = 0.1171;
  // Breed subtitle (e.g. "Netherland Dwarf Pedigree"), 14pt at (23.6, 75.8)
  static const double breedSubtitleLeft = 0.0298;
  static const double breedSubtitleTop = 0.1239;
  static const double websiteTop = 0.1520;

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
  static const double signatureCenterY = 0.9176;
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
  final String farmWebsite;
  final String farmSocialLink;
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
  final String subjectGenotype;
  final String soldTo;
  final String soldOn;
  final bool showSoldTo;
  final bool showSoldOn;
  final String? subjectPhotoPath;

  // 4-Generation Pedigree Tree Root
  final PedigreeRabbit? tree;

  // Orientation
  final PedigreeOrientation orientation;

  const PedigreeData({
    required this.farmName,
    required this.farmAddress,
    required this.farmEmail,
    required this.farmPhone,
    this.farmWebsite = '',
    this.farmSocialLink = '',
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
    this.subjectGenotype = '',
    this.soldTo = '',
    this.soldOn = '',
    this.showSoldTo = false,
    this.showSoldOn = false,
    this.subjectPhotoPath,
    this.tree,
    this.orientation = PedigreeOrientation.landscape,
  });

  bool get isPortrait => orientation == PedigreeOrientation.portrait;

  PedigreeData copyWith({
    String? farmName,
    String? farmAddress,
    String? farmEmail,
    String? farmPhone,
    String? farmWebsite,
    String? farmSocialLink,
    String? ownerName,
    String? subjectName,
    String? subjectBreed,
    String? subjectColor,
    String? subjectSex,
    String? subjectDob,
    String? subjectEarNo,
    String? subjectWeight,
    String? subjectRegNo,
    String? subjectLegs,
    String? subjectGenotype,
    String? soldTo,
    String? soldOn,
    bool? showSoldTo,
    bool? showSoldOn,
    String? subjectPhotoPath,
    PedigreeRabbit? tree,
    PedigreeOrientation? orientation,
  }) {
    return PedigreeData(
      farmName: farmName ?? this.farmName,
      farmAddress: farmAddress ?? this.farmAddress,
      farmEmail: farmEmail ?? this.farmEmail,
      farmPhone: farmPhone ?? this.farmPhone,
      farmWebsite: farmWebsite ?? this.farmWebsite,
      farmSocialLink: farmSocialLink ?? this.farmSocialLink,
      ownerName: ownerName ?? this.ownerName,
      subjectName: subjectName ?? this.subjectName,
      subjectBreed: subjectBreed ?? this.subjectBreed,
      subjectColor: subjectColor ?? this.subjectColor,
      subjectSex: subjectSex ?? this.subjectSex,
      subjectDob: subjectDob ?? this.subjectDob,
      subjectEarNo: subjectEarNo ?? this.subjectEarNo,
      subjectWeight: subjectWeight ?? this.subjectWeight,
      subjectRegNo: subjectRegNo ?? this.subjectRegNo,
      subjectLegs: subjectLegs ?? this.subjectLegs,
      subjectGenotype: subjectGenotype ?? this.subjectGenotype,
      soldTo: soldTo ?? this.soldTo,
      soldOn: soldOn ?? this.soldOn,
      showSoldTo: showSoldTo ?? this.showSoldTo,
      showSoldOn: showSoldOn ?? this.showSoldOn,
      subjectPhotoPath: subjectPhotoPath ?? this.subjectPhotoPath,
      tree: tree ?? this.tree,
      orientation: orientation ?? this.orientation,
    );
  }

  /// Builds a complete PedigreeData structure with 4 generations from a Rabbit model
  static Future<PedigreeData> fromRabbit(
    Rabbit rabbit, {
    DatabaseService? db,
    SettingsService? settings,
    PedigreeOrientation orientation = PedigreeOrientation.landscape,
  }) async {
    final database = db ?? DatabaseService();
    final appSettings = settings ?? SettingsService.instance;
    await appSettings.init();

    final tree = await database.buildPedigreeTree(rabbit.id,
        maxGenerations: 4, initialRabbit: rabbit);

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
    final photo = (appSettings.pedigreeShowPhoto && rabbit.photos?.isNotEmpty == true)
        ? rabbit.photos!.first
        : null;

    final showAddress = appSettings.pedigreeShowAddress;
    final showCityStatePostal = appSettings.pedigreeShowCityStatePostal;
    final street = appSettings.farmStreetAddress;
    final cityStateZip = appSettings.farmCityStateZip;
    String resolvedAddress = [
      if (showAddress && street.isNotEmpty) street,
      if (showCityStatePostal && cityStateZip.isNotEmpty) cityStateZip,
    ].join(', ');
    if (resolvedAddress.isEmpty && showAddress && showCityStatePostal) {
      resolvedAddress = appSettings.farmAddress.trim();
    }

    final isSold = rabbit.archiveReason == ArchiveReason.sold ||
        (rabbit.buyerInfo?.trim().isNotEmpty ?? false);
    final soldToVal =
        appSettings.pedigreeShowSoldTo ? (rabbit.buyerInfo?.trim() ?? '') : '';
    final soldOnVal = (appSettings.pedigreeShowSoldOn &&
            isSold &&
            rabbit.archiveDate != null)
        ? FormatUtils.formatCertificateDate(rabbit.archiveDate!)
        : '';

    return PedigreeData(
      farmName: appSettings.farmName.trim(),
      farmAddress: resolvedAddress,
      farmEmail:
          appSettings.pedigreeShowEmail ? appSettings.farmEmail.trim() : '',
      farmPhone:
          appSettings.pedigreeShowPhone ? appSettings.farmPhone.trim() : '',
      farmWebsite:
          appSettings.pedigreeShowWebsite ? appSettings.farmWebsite.trim() : '',
      farmSocialLink: appSettings.pedigreeShowSocialLink
          ? appSettings.farmSocialLink.trim()
          : '',
      ownerName:
          appSettings.pedigreeShowOwnerName ? appSettings.ownerName.trim() : '',
      subjectName: [
        possessivePrefix(rabbit.breederPrefix),
        rabbit.name.trim(),
      ].where((e) => e.isNotEmpty).join(' '),
      subjectBreed: rabbit.breed.trim(),
      subjectColor: rabbit.color?.trim() ?? '',
      subjectSex: sex,
      subjectDob: dob,
      subjectEarNo: earNo,
      subjectWeight: weight,
      subjectRegNo: regNo,
      subjectLegs: legs,
      subjectGenotype: appSettings.pedigreeShowGenotype
          ? (rabbit.genetics?.trim() ?? '')
          : '',
      soldTo: soldToVal,
      soldOn: soldOnVal,
      showSoldTo: appSettings.pedigreeShowSoldTo,
      showSoldOn: appSettings.pedigreeShowSoldOn,
      subjectPhotoPath: photo,
      tree: tree,
      orientation: orientation,
    );
  }
}

/// One ancestor card on the NEW landscape pedigree (points on a 792x612 page,
/// extracted from the supplied Landscape.pdf design).
class LandscapeCardSpec {
  final String role;
  final bool isSire;
  final int gen;
  final double left;
  final double top;
  final String path; // 's'/'d' steps from the subject, e.g. 'sd' = sire's dam
  const LandscapeCardSpec(this.role, this.isSire, this.gen, this.left, this.top, this.path);

  double get width => gen == 3 ? 179.9 : 186.4;
  double get height => gen == 3 ? 70.0 : 95.1;
  double get fontSize => gen == 3 ? 10.0 : 11.0;
  double get textDx => gen == 3 ? 5.8 : 5.5;
  double get col2Dx => gen == 3 ? 94.7 : 110.4;
  double get row0 => gen == 3 ? 2.0 : 5.0;
  double get pitch => gen == 3 ? 13.1 : 18.15;
}

class LandscapeCell {
  final String text;
  final double x;
  final double y;
  final double w;
  const LandscapeCell(this.text, this.x, this.y, this.w);
}

class LandscapeLayout {
  static const double pageW = 792.0;
  static const double pageH = 612.0;
  static const double cardRadius = 13.0;

  static const Color sireCard = Color.fromRGBO(163, 155, 165, 1);
  static const Color damCard = Color.fromRGBO(204, 152, 196, 1);
  static const Color subjectBox = Color.fromRGBO(198, 232, 248, 1);
  static const Color photoBorder = Color.fromRGBO(65, 199, 242, 1);
  static const PdfColor pdfSireCard = PdfColor(0.6399, 0.6076, 0.6473);
  static const PdfColor pdfDamCard = PdfColor(0.8002, 0.5948, 0.7705);
  static const PdfColor pdfSubjectBox = PdfColor(0.7752, 0.9113, 0.9720);
  static const PdfColor pdfPhotoBorder = PdfColor(0.2568, 0.7809, 0.9484);

  static const List<LandscapeCardSpec> specs = [
    LandscapeCardSpec('Sire', true, 1, 210.8, 108.6, 's'),
    LandscapeCardSpec('Dam', false, 1, 210.8, 417.9, 'd'),
    LandscapeCardSpec('G.Sire', true, 2, 405.8, 34.7, 'ss'),
    LandscapeCardSpec('G.Dam', false, 2, 405.8, 184.7, 'sd'),
    LandscapeCardSpec('G.Sire', true, 2, 405.8, 332.2, 'ds'),
    LandscapeCardSpec('G.Dam', false, 2, 405.8, 481.3, 'dd'),
    LandscapeCardSpec('G.G.Sire', true, 3, 601.1, 10.6, 'sss'),
    LandscapeCardSpec('G.G.Dam', false, 3, 601.1, 84.0, 'ssd'),
    LandscapeCardSpec('G.G.Sire', true, 3, 601.1, 160.2, 'sds'),
    LandscapeCardSpec('G.G.Dam', false, 3, 601.1, 233.6, 'sdd'),
    LandscapeCardSpec('G.G.Sire', true, 3, 601.1, 308.5, 'dss'),
    LandscapeCardSpec('G.G.Dam', false, 3, 601.1, 381.9, 'dsd'),
    LandscapeCardSpec('G.G.Sire', true, 3, 601.1, 457.1, 'dds'),
    LandscapeCardSpec('G.G.Dam', false, 3, 601.1, 530.5, 'ddd'),
  ];

  static PedigreeRabbit? resolve(PedigreeRabbit? tree, String path) {
    PedigreeRabbit? cur = tree;
    for (final c in path.split('')) {
      if (cur == null) return null;
      cur = c == 's' ? cur.sire : cur.dam;
    }
    return cur;
  }

  /// Text cells (relative to the card) in the order of the reference design:
  /// name / color / DOB+Wt / Ear No.+Reg # / GC#+Legs.
  static List<LandscapeCell> cardCells(
      LandscapeCardSpec c, PedigreeRabbit? r, String weight) {
    final dob = r?.dateOfBirth != null
        ? FormatUtils.formatCertificateDate(r!.dateOfBirth)
        : '';
    final legs = (r?.legs != null && r!.legs! > 0) ? '${r.legs}' : '';
    final w1 = c.col2Dx - c.textDx - 2;
    final w2 = c.width - c.col2Dx - 4;
    double y(int i) => c.row0 + i * c.pitch;
    return [
      LandscapeCell('${c.role}: ${r?.displayName ?? ''}', c.textDx, y(0), c.width - c.textDx - 4),
      LandscapeCell('Color: ${r?.color ?? ''}', c.textDx, y(1), c.width - c.textDx - 4),
      LandscapeCell('DOB: $dob', c.textDx, y(2), w1),
      LandscapeCell('Wt: $weight', c.col2Dx, y(2), w2),
      LandscapeCell('Ear No.: ${r?.earNumber ?? ''}', c.textDx, y(3), w1),
      LandscapeCell('Reg #: ${r?.registrationNumber ?? ''}', c.col2Dx, y(3), w2),
      LandscapeCell('GC#: ${r?.grandChampionNumber ?? ''}', c.textDx, y(4), w1),
      LandscapeCell('Legs: $legs', c.col2Dx, y(4), w2),
    ];
  }

  /// Subject (blue box) text cells in absolute page points.
  static List<LandscapeCell> subjectCells(PedigreeData d) => [
        LandscapeCell('Name: ${d.subjectName}', 31.4, 225.3, 160),
        LandscapeCell('Color: ${d.subjectColor}', 31.4, 248.9, 160),
        LandscapeCell('Breed: ${d.subjectBreed}', 31.4, 272.5, 160),
        LandscapeCell('Sex: ${d.subjectSex}', 31.9, 296.0, 82),
        LandscapeCell('Reg No.: ${d.subjectRegNo}', 117.2, 296.0, 76),
        LandscapeCell('DOB: ${d.subjectDob}', 31.6, 319.6, 160),
        LandscapeCell('Ear No.: ${d.subjectEarNo}', 31.9, 343.2, 82),
        LandscapeCell('Wt: ${d.subjectWeight}', 117.4, 344.7, 76),
        LandscapeCell('GC No.:', 33.1, 368.3, 80),
        LandscapeCell('Legs: ${d.subjectLegs}', 116.3, 368.3, 76),
      ];
}
