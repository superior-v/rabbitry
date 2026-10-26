import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';

/// Centralized layout specification for Birth Certificate PDF and Flutter Preview.
/// Matches the reference layout (US Letter Landscape adjusted to 792 x 576 pt, aspect ratio 1.375).
class CertificateLayout {
  CertificateLayout._();

  // ─── PAGE DIMENSIONS ────────────────────────────────────────────────────────
  static const double pageWidthPt = 792.0;
  static const double pageHeightPt = 576.0;
  static const double aspectRatio = 792.0 / 576.0; // 1.375

  // ─── ASSET PATHS ────────────────────────────────────────────────────────────
  static const String templateBwAsset = 'assets/images/birth_cert_template_p1.png';
  static const String templateColorAsset = 'assets/images/birth_cert_template_p2.png';

  // Fonts
  static const String fontDetailsAsset = 'assets/fonts/PT_Sans-Web-Regular.ttf';
  static const String fontDetailsBoldAsset = 'assets/fonts/PT_Sans-Web-Bold.ttf';
  static const String fontScriptAsset = 'assets/fonts/DancingScript-VariableFont_wght.ttf';
  static const String fontShakiesAsset = 'assets/fonts/Shakies-OpenType-TT.ttf';

  // Font family names registered in pubspec.yaml
  static const String fontFamilyDetails = 'CertificateDetails';
  static const String fontFamilyScript = 'CertificateScript';
  static const String fontFamilyShakies = 'Shakies';

  // ─── COLORS ─────────────────────────────────────────────────────────────────
  // Flutter UI Colors
  static const Color colorText = Color(0xFF231F20);
  static const Color colorPhotoBorder = Color(0xFF662C91);
  static const Color colorPhotoBorderBw = Color(0xFF231F20);
  static const Color colorPlaceholderBg = Color(0xFFF3EDF8);

  // PDF Colors
  static const PdfColor pdfColorText = PdfColor(0.137, 0.122, 0.125); // #231F20
  static const PdfColor pdfColorPhotoBorder = PdfColor(0.400, 0.173, 0.569); // #662C91
  static const PdfColor pdfColorPhotoBorderBw = PdfColor(0.137, 0.122, 0.125);
  static const PdfColor pdfColorPlaceholderBg = PdfColor(0.95, 0.93, 0.97);

  // ─── FONT SIZES (pt at 792 pt page width) ───────────────────────────────────
  // No photo layout
  static const double fontSizeCertifiesPt = 18.0;
  static const double fontSizeNamePt = 48.0;
  static const double fontSizeBornPt = 18.0;
  static const double fontSizeLocationPt = 18.0;
  static const double fontSizeGridPt = 18.0;

  // With photo layout
  static const double fontSizeCertifiesWithPhotoPt = 15.5;
  static const double fontSizeNameWithPhotoPt = 34.0;
  static const double fontSizeBornWithPhotoPt = 15.5;
  static const double fontSizeLocationWithPhotoPt = 15.5;
  static const double fontSizeGridWithPhotoPt = 17.0;

  // Font size multipliers (relative to page width W)
  static const double fontRatioCertifies = fontSizeCertifiesPt / pageWidthPt;
  static const double fontRatioName = fontSizeNamePt / pageWidthPt;
  static const double fontRatioBorn = fontSizeBornPt / pageWidthPt;
  static const double fontRatioLocation = fontSizeLocationPt / pageWidthPt;
  static const double fontRatioGrid = fontSizeGridPt / pageWidthPt;

  static const double fontRatioCertifiesWithPhoto = fontSizeCertifiesWithPhotoPt / pageWidthPt;
  static const double fontRatioNameWithPhoto = fontSizeNameWithPhotoPt / pageWidthPt;
  static const double fontRatioBornWithPhoto = fontSizeBornWithPhotoPt / pageWidthPt;
  static const double fontRatioLocationWithPhoto = fontSizeLocationWithPhotoPt / pageWidthPt;
  static const double fontRatioGridWithPhoto = fontSizeGridWithPhotoPt / pageWidthPt;

  // ─── VERTICAL FRACTIONS (relative to page height H = 576 pt) ────────────────
  // Standard layout (Page 1 B&W & Page 2 Color no photo)
  // Shifted away from flower borders and centered
  static const double topRatioCertifies = 168.0 / 576.0;   // ~0.2917
  static const double topRatioName = 205.0 / 576.0;        // ~0.3559
  static const double topRatioBorn = 285.0 / 576.0;        // ~0.4948
  static const double topRatioLocation = 325.0 / 576.0;    // ~0.5642
  static const double topRatioGridRow1 = 390.0 / 576.0;    // ~0.6771
  static const double topRatioGridRow2 = 435.0 / 576.0;    // ~0.7552

  // Horizontal Grid Columns for standard layout (relative to page width W = 792 pt)
  // Moved towards the center to avoid flower bouquets on the left and right corners
  static const double gridLeftColRatio = 210.0 / 792.0;    // ~0.2652
  static const double gridRightColRatio = 440.0 / 792.0;   // ~0.5556
  static const double gridColWidthRatio = 190.0 / 792.0;   // ~0.2399

  // ─── COLOR WITH PHOTO LAYOUT (US Letter Landscape: 792 x 612 pt) ───────────
  static const double pageColorPhotoWidthPt = 792.0;
  static const double pageColorPhotoHeightPt = 612.0;
  static const double aspectRatioColorPhoto = 792.0 / 612.0; // ~1.2941176

  static const String templateColorPhotoAsset = 'assets/images/birth_cert_template_color_photo.png';

  // Photo Frame
  static const double photoLeftPt = 170.67;
  static const double photoTopPt = 216.75;
  static const double photoWidthPt = 300.65;
  static const double photoHeightPt = 235.03;
  static const double photoRadiusPt = 15.0;

  static const double photoLeftRatio = photoLeftPt / pageColorPhotoWidthPt;      // ~0.21549
  static const double photoTopRatio = photoTopPt / pageColorPhotoHeightPt;        // ~0.35417
  static const double photoWidthRatio = photoWidthPt / pageColorPhotoWidthPt;    // ~0.37961
  static const double photoHeightRatio = photoHeightPt / pageColorPhotoHeightPt; // ~0.38404

  // Right Details Column (starts after bunny icons at X = 532.4 pt)
  static const double detailsLeftPt = 532.4;
  static const double detailsLeftRatio = detailsLeftPt / pageColorPhotoWidthPt;  // ~0.67222
  static const double detailsFontSizePt = 19.0;
  static const double detailsFontRatio = detailsFontSizePt / pageColorPhotoWidthPt; // ~0.02399

  // Colors
  static const Color colorDetailsPhoto = Color(0xFF6D6E71);
  static const PdfColor pdfColorDetailsPhoto = PdfColor(0.427, 0.431, 0.443); // #6D6E71
  static const Color colorPhotoFrameBorder = Color(0xFF58595B);
  static const PdfColor pdfColorPhotoFrameBorder = PdfColor(0.345, 0.348, 0.356); // #58595B

  // Row Y positions
  static const double row1TopPt = 194.0;
  static const double row1TopRatio = row1TopPt / pageColorPhotoHeightPt; // ~0.31699

  static const double row2TopPt = 244.6;
  static const double row2TopRatio = row2TopPt / pageColorPhotoHeightPt; // ~0.39967

  static const double row3TopPt = 297.6;
  static const double row3TopRatio = row3TopPt / pageColorPhotoHeightPt; // ~0.48627

  static const double row4TopPt = 355.4;
  static const double row4TopRatio = row4TopPt / pageColorPhotoHeightPt; // ~0.58072

  static const double row5TopPt = 413.1;
  static const double row5TopRatio = row5TopPt / pageColorPhotoHeightPt; // ~0.67500

  static const double row6TopPt = 469.2;
  static const double row6TopRatio = row6TopPt / pageColorPhotoHeightPt; // ~0.76667
}

/// 3 Certificate display / generation options
enum CertificateOption {
  blackAndWhite,
  colorNoPhoto,
  colorWithPhoto,
}

/// Data holder model for populating a Birth Certificate
class CertificateData {
  final String name;
  final String breed;
  final String color;
  final String dob;
  final String sex;
  final String damName;
  final String sireName;
  final String? location;
  final String? photoPath;
  final CertificateOption option;

  const CertificateData({
    required this.name,
    required this.breed,
    required this.color,
    required this.dob,
    required this.sex,
    required this.damName,
    required this.sireName,
    this.location,
    this.photoPath,
    this.option = CertificateOption.colorWithPhoto,
  });

  bool get isBlackAndWhite => option == CertificateOption.blackAndWhite;
  bool get isColorWithPhoto => option == CertificateOption.colorWithPhoto;
  bool get hasPhoto => option == CertificateOption.colorWithPhoto;

  String get birthSentence {
    final cleanBreed = breed.trim();
    if (cleanBreed.isNotEmpty && cleanBreed != '—' && cleanBreed != 'Unknown') {
      return 'a $cleanBreed rabbit was born on $dob';
    }
    return 'a rabbit was born on $dob';
  }

  String get locationSentence {
    final cleanLoc = location?.trim();
    if (cleanLoc != null && cleanLoc.isNotEmpty && cleanLoc != '—') {
      final city = _extractCity(cleanLoc);
      return 'at $city';
    }
    return 'at Amaranth';
  }

  static String _extractCity(String input) {
    final parts = input.split(RegExp(r'[,;\n]')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (parts.isEmpty) return 'Amaranth';
    // If first component is a street number/address, use second component
    if (parts.length > 1 && RegExp(r'^\d+').hasMatch(parts.first)) {
      return parts[1];
    }
    return parts.first;
  }

  String get parentsSentence {
    final cleanDam = (damName.trim().isNotEmpty && damName != '—') ? damName.trim() : 'Unknown';
    final cleanSire = (sireName.trim().isNotEmpty && sireName != '—') ? sireName.trim() : 'Unknown';
    return 'Dam $cleanDam X Sire $cleanSire';
  }
}
