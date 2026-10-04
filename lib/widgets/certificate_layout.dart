import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

/// Centralized layout specification for Birth Certificate v2 PDF and Flutter Preview.
/// All positions, widths, and heights are defined as fractions of page width (W) and height (H).
/// Page size is US Letter Landscape: 792 x 612 pt (Aspect Ratio ~ 11 / 8.5).
class CertificateLayout {
  CertificateLayout._();

  // ─── PAGE DIMENSIONS ────────────────────────────────────────────────────────
  static const double pageWidthPt = 792.0;
  static const double pageHeightPt = 612.0;
  static const double aspectRatio = 792.0 / 612.0;

  // ─── ASSET PATHS ────────────────────────────────────────────────────────────
  static const String backgroundAsset = 'assets/images/certificate_background_v2.png';
  static const String rabbitIconAsset = 'assets/images/rabbit_icon_v2.png';

  // Fonts
  static const String fontBadgeWesternAsset = 'assets/fonts/HoltwoodOneSC-Regular.ttf';
  static const String fontDetailsAsset = 'assets/fonts/PT_Sans-Web-Regular.ttf';
  static const String fontDetailsBoldAsset = 'assets/fonts/PT_Sans-Web-Bold.ttf';

  // Font family names registered in pubspec.yaml
  static const String fontFamilyBadgeWestern = 'CertificateBadgeWestern';
  static const String fontFamilyDetails = 'CertificateDetails';

  // ─── COLORS ─────────────────────────────────────────────────────────────────
  // Flutter UI Colors
  static const Color colorBorderOuter = Color(0xFF656263);
  static const Color colorBorderInner = Color(0xFF4F4C4D);
  static const Color colorBadgeBg = Color(0xFFAAE3EC);
  static const Color colorBadgeStroke = Colors.white;
  static const Color colorBadgeText = Color(0xFF6F6F6F);
  static const Color colorPhotoBorder = Color(0xFF4F4C4D);
  static const Color colorDetailsText = Color(0xFF6D6E71);
  static const Color colorPlaceholderBg = Color(0xFFE8E8E8);

  // PDF Colors
  static const PdfColor pdfColorBorderOuter = PdfColor(0.396, 0.384, 0.388); // #656263
  static const PdfColor pdfColorBorderInner = PdfColor(0.310, 0.298, 0.302); // #4F4C4D
  static const PdfColor pdfColorBadgeBg = PdfColor(0.667, 0.890, 0.925);     // #AAE3EC
  static const PdfColor pdfColorBadgeStroke = PdfColors.white;
  static const PdfColor pdfColorBadgeText = PdfColor(0.435, 0.435, 0.435);   // #6F6F6F
  static const PdfColor pdfColorPhotoBorder = PdfColor(0.310, 0.298, 0.302); // #4F4C4D
  static const PdfColor pdfColorDetailsText = PdfColor(0.427, 0.431, 0.443); // #6D6E71
  static const PdfColor pdfColorPlaceholderBg = PdfColor(0.91, 0.91, 0.91);

  // ─── FONT SIZES (pt at 792 pt page width) ───────────────────────────────────
  static const double fontSizeBadgePt = 50.6;
  static const double fontSizeDetailsPt = 19.0;
  static const double fontSizeDetailsMinPt = 12.0;

  // Font size multipliers (relative to page width W)
  static const double fontRatioBadge = fontSizeBadgePt / pageWidthPt;
  static const double fontRatioDetails = fontSizeDetailsPt / pageWidthPt;
  static const double fontRatioDetailsMin = fontSizeDetailsMinPt / pageWidthPt;

  // ─── BORDERS SPEC ───────────────────────────────────────────────────────────
  static const double outerBorderLeft = 0.0007;
  static const double outerBorderTop = 0.0032;
  static const double outerBorderWidth = 0.9987;
  static const double outerBorderHeight = 0.9987;
  static const double outerBorderStrokePt = 3.0;

  static const double innerBorderLeft = 0.0172;
  static const double innerBorderTop = 0.0209;
  static const double innerBorderWidth = 0.9658;
  static const double innerBorderHeight = 0.9614;
  static const double innerBorderStrokePt = 2.0;

  // ─── BADGE SPEC ─────────────────────────────────────────────────────────────
  static const double badgeLeft = 0.1643;
  static const double badgeTop = 0.0843;
  static const double badgeWidth = 0.6714;
  static const double badgeHeight = 0.1036;
  static const double badgeRadius = 0.0100; // W fraction
  static const double badgeStrokePt = 1.0;

  static const double badgeTextCenterX = 0.5000;
  static const double badgeTextCenterY = 0.1304;
  static const double badgeTextMaxWidth = 0.6200;
  static const String badgeText = 'CERTIFICATE OF BIRTH';

  // ─── PHOTO SPEC (Left Frame) ────────────────────────────────────────────────
  static const double photoLeft = 0.0658;
  static const double photoTop = 0.3044;
  static const double photoWidth = 0.4947;
  static const double photoHeight = 0.5005;
  static const double photoRadius = 0.0350; // W fraction
  static const double photoBorderWidthPt = 2.0;

  // ─── DETAILS SPEC (Right Column) ────────────────────────────────────────────
  static const double iconLeft = 0.6325;
  static const double iconWidth = 0.0250;
  static const double iconHeight = 0.0385;

  static const double iconTopName = 0.3150;
  static const double iconTopBreed = 0.4000;
  static const double iconTopColor = 0.4850;
  static const double iconTopDob = 0.5700;
  static const double iconTopSex = 0.6550;
  static const double iconTopParents = 0.7450;

  static const double textLeft = 0.6722;
  static const double textMaxWidth = 0.3000;
  static const double textRowHeight = 0.0450; // H fraction

  static const double rowNameCenterY = 0.3350;
  static const double rowBreedCenterY = 0.4200;
  static const double rowColorCenterY = 0.5050;
  static const double rowDobCenterY = 0.5900;
  static const double rowSexCenterY = 0.6750;
  static const double rowParentsCenterY = 0.7650;
}

/// Data holder model for populating a Certificate of Birth v2
class CertificateData {
  final String name;
  final String breed;
  final String color;
  final String dob;
  final String sex;
  final String damName;
  final String sireName;
  final String? photoPath;
  final bool includePhoto;

  const CertificateData({
    required this.name,
    required this.breed,
    required this.color,
    required this.dob,
    required this.sex,
    required this.damName,
    required this.sireName,
    this.photoPath,
    this.includePhoto = true,
  });
}
