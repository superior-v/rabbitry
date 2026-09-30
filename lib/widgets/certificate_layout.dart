import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

/// Centralized layout specification for Birth Certificate PDF and Flutter Preview.
/// All positions, widths, and heights are defined as fractions of page width (W) and height (H).
/// Page size is US Letter Landscape: 792 x 612 pt (Aspect Ratio ~ 11 / 8.5).
class CertificateLayout {
  CertificateLayout._();

  // ─── PAGE DIMENSIONS ────────────────────────────────────────────────────────
  static const double pageWidthPt = 792.0;
  static const double pageHeightPt = 612.0;
  static const double aspectRatio = 792.0 / 612.0;

  // ─── ASSET PATHS ────────────────────────────────────────────────────────────
  static const String backgroundAsset = 'assets/images/certificate_background.png';
  static const String rabbitIconAsset = 'assets/images/rabbit_icon.png';

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
  static const Color colorTitle = Color(0xFF555555);
  static const Color colorBadgeBg = Color(0xFFDDBBDD);
  static const Color colorBadgeText = Color(0xFF6E5D72);
  static const Color colorKitText = Color(0xFF555555);
  static const Color colorSireCardBg = Color(0xFFB3E0F5);
  static const Color colorDamCardBg = Color(0xFFDDBBDD);
  static const Color colorCardText = Color(0xFF4A4A4A);
  static const Color colorCertifyText = Color(0xFF888888);
  static const Color colorSignatureText = Color(0xFF4A4A4A);
  static const Color colorContactText = Color(0xFFAAAAAA);

  // PDF Colors
  static const PdfColor pdfColorTitle = PdfColor(0.33, 0.33, 0.33);
  static const PdfColor pdfColorBadgeBg = PdfColor(0.867, 0.733, 0.867); // #DDBBDD
  static const PdfColor pdfColorBadgeText = PdfColor(0.43, 0.36, 0.45); // #6E5D72
  static const PdfColor pdfColorKitText = PdfColor(0.33, 0.33, 0.33);
  static const PdfColor pdfColorSireCardBg = PdfColor(0.702, 0.878, 0.961); // #B3E0F5
  static const PdfColor pdfColorDamCardBg = PdfColor(0.867, 0.733, 0.867); // #DDBBDD
  static const PdfColor pdfColorCardText = PdfColor(0.29, 0.29, 0.29);
  static const PdfColor pdfColorCertifyText = PdfColor(0.53, 0.53, 0.53); // #888888
  static const PdfColor pdfColorSignatureText = PdfColor(0.29, 0.29, 0.29);
  static const PdfColor pdfColorContactText = PdfColor(0.67, 0.67, 0.67); // #AAAAAA

  // ─── FONT SIZES (pt at 792 pt page width) ───────────────────────────────────
  static const double fontSizeTitlePt = 48.0;
  static const double fontSizeBadgePt = 22.0;
  static const double fontSizeKitRowsPt = 15.0;
  static const double fontSizeCardRowsPt = 12.0;
  static const double fontSizeCertifyPt = 13.5;
  static const double fontSizeSignaturePt = 24.0;
  static const double fontSizeContactPt = 11.0;

  // Font size multipliers (relative to page width W)
  static const double fontRatioTitle = fontSizeTitlePt / pageWidthPt;
  static const double fontRatioBadge = fontSizeBadgePt / pageWidthPt;
  static const double fontRatioKitRows = fontSizeKitRowsPt / pageWidthPt;
  static const double fontRatioCardRows = fontSizeCardRowsPt / pageWidthPt;
  static const double fontRatioCertify = fontSizeCertifyPt / pageWidthPt;
  static const double fontRatioSignature = fontSizeSignaturePt / pageWidthPt;
  static const double fontRatioContact = fontSizeContactPt / pageWidthPt;

  // ─── TITLE & BADGE SPEC ─────────────────────────────────────────────────────
  static const double titleCenterX = 0.5000;
  static const double titleCenterY = 0.0680;
  static const double titleBoxHeight = 0.0750; // H fraction
  static const double titleMaxWidth = 0.6000; // W fraction

  static const double badgeLeft = 0.3672;
  static const double badgeTop = 0.1250;
  static const double badgeWidth = 0.2620;
  static const double badgeHeight = 0.0590;
  static const double badgeRadius = 0.0150; // W fraction
  static const double badgeTextCenterY = 0.1545; // vertically centered in badge (0.1250 + 0.0590/2)

  // ─── KIT SPEC (Left Column) ─────────────────────────────────────────────────
  static const double kitPhotoLeft = 0.0587;
  static const double kitPhotoTop = 0.3270;
  static const double kitPhotoWidth = 0.3084;
  static const double kitPhotoHeight = 0.3120;
  static const double kitPhotoRadius = 0.0200; // W fraction

  static const double kitIconLeft = 0.3883;
  static const double kitIconWidth = 0.0198;
  static const double kitIconHeight = 0.0306;

  static const double kitTextLeft = 0.4205;
  static const double kitRowBoxHeight = 0.0400; // H fraction
  static const double kitTextMaxWidth = 0.3100;

  static const double kitNameCenterY = 0.3471;
  static const double kitBreedCenterY = 0.4127;
  static const double kitColorCenterY = 0.4814;
  static const double kitDobCenterY = 0.5563;
  static const double kitSexCenterY = 0.6311;

  // ─── SIRE SPEC (Right Column Top) ───────────────────────────────────────────
  static const double sirePhotoLeft = 0.7498;
  static const double sirePhotoTop = 0.1472;
  static const double sirePhotoWidth = 0.1900;
  static const double sirePhotoHeight = 0.1733;
  static const double sirePhotoRadius = 0.0150;

  static const double sireCardLeft = 0.7509;
  static const double sireCardTop = 0.3300;
  static const double sireCardWidth = 0.1910;
  static const double sireCardHeight = 0.1816;
  static const double sireCardRadius = 0.0120;

  static const double cardTextLeft = 0.7579;
  static const double cardTextMaxWidth = 0.1760;
  static const double cardRowBoxHeight = 0.0320;

  static const List<double> sireRowsCenterY = [
    0.3555, // Sire
    0.3875, // Breed
    0.4213, // Color
    0.4549, // DOB
    0.4912, // Wt
  ];

  // ─── DAM SPEC (Right Column Bottom) ─────────────────────────────────────────
  static const double damPhotoLeft = 0.7498;
  static const double damPhotoTop = 0.5556;
  static const double damPhotoWidth = 0.1900;
  static const double damPhotoHeight = 0.1733;
  static const double damPhotoRadius = 0.0150;

  static const double damCardLeft = 0.7510;
  static const double damCardTop = 0.7404;
  static const double damCardWidth = 0.1921;
  static const double damCardHeight = 0.1816;
  static const double damCardRadius = 0.0120;

  static const List<double> damRowsCenterY = [
    0.7658, // Dam
    0.7979, // Breed
    0.8330, // Color
    0.8653, // DOB
    0.9031, // Wt
  ];

  // ─── CERTIFICATION / FOOTER SPEC (Bottom Left) ──────────────────────────────
  static const double footerTextLeft = 0.0509;
  static const double footerTextMaxWidth = 0.4000;
  static const double footerRowBoxHeight = 0.0280;

  static const double certifyLine1CenterY = 0.8090;
  static const double certifyLine2CenterY = 0.8346;

  static const double signatureLeft = 0.0512;
  static const double signatureCenterY = 0.8791;
  static const double signatureBoxHeight = 0.0450;

  static const double addressLeft = 0.0506;
  static const double addressCenterY = 0.9031;

  static const double emailLeft = 0.0506;
  static const double emailCenterY = 0.9322;
}

/// Data holder model for populating a certificate
class CertificateData {
  final String farmName;
  final String ownerName;
  final String farmAddress;
  final String farmEmail;

  // Kit details
  final String kitName;
  final String kitBreed;
  final String kitColor;
  final String kitDob;
  final String kitSex;
  final String? kitPhotoPath;

  // Sire details
  final String sireName;
  final String sireBreed;
  final String sireColor;
  final String sireDob;
  final String sireWeight;
  final String? sirePhotoPath;

  // Dam details
  final String damName;
  final String damBreed;
  final String damColor;
  final String damDob;
  final String damWeight;
  final String? damPhotoPath;

  final bool includePhoto;

  const CertificateData({
    required this.farmName,
    required this.ownerName,
    required this.farmAddress,
    required this.farmEmail,
    required this.kitName,
    required this.kitBreed,
    required this.kitColor,
    required this.kitDob,
    required this.kitSex,
    this.kitPhotoPath,
    required this.sireName,
    required this.sireBreed,
    required this.sireColor,
    required this.sireDob,
    required this.sireWeight,
    this.sirePhotoPath,
    required this.damName,
    required this.damBreed,
    required this.damColor,
    required this.damDob,
    required this.damWeight,
    this.damPhotoPath,
    this.includePhoto = true,
  });
}
