import 'dart:io';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:printing/printing.dart';
import '../models/rabbit.dart';
import '../services/database_service.dart';
import '../services/format_utils.dart';
import '../services/settings_service.dart';
import '../services/certificate_pdf_service.dart';
import '../constants/app_colors.dart';
import 'certificate_layout.dart';

class CertificateCard extends StatefulWidget {
  final Rabbit rabbit;
  const CertificateCard({super.key, required this.rabbit});

  @override
  State<CertificateCard> createState() => _CertificateCardState();
}

class _CertificateCardState extends State<CertificateCard> {
  final DatabaseService _db = DatabaseService();
  final SettingsService _settings = SettingsService.instance;

  Rabbit? _sire;
  Rabbit? _dam;
  bool _isLoadingParents = true;

  @override
  void initState() {
    super.initState();
    _loadParents();
  }

  Future<void> _loadParents() async {
    try {
      Rabbit? sire;
      Rabbit? dam;

      if (widget.rabbit.sireId?.isNotEmpty ?? false) {
        sire = await _db.getRabbit(widget.rabbit.sireId!);
      }
      if (widget.rabbit.damId?.isNotEmpty ?? false) {
        dam = await _db.getRabbit(widget.rabbit.damId!);
      }

      if (mounted) {
        setState(() {
          _sire = sire;
          _dam = dam;
          _isLoadingParents = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingParents = false);
    }
  }

  String _formatWeight(double? weight) {
    if (weight == null || weight <= 0) return '—';
    if (_settings.weightUnit == 'lbs') {
      final int lbs = weight.floor();
      final int oz = ((weight - lbs) * 16).round();
      if (oz > 0) {
        return '${lbs}lbs ${oz}oz';
      } else {
        return '${lbs}lbs';
      }
    }
    return FormatUtils.formatWeight(weight);
  }

  String _fallbackDash(String? value) {
    if (value == null || value.trim().isEmpty || value.trim() == 'N/A') return '—';
    return value.trim();
  }

  CertificateData _buildCertificateData(bool includePhoto) {
    final rabbit = widget.rabbit;
    final sex = rabbit.type == RabbitType.doe ? 'Female' : 'Male';
    final dob = FormatUtils.formatCertificateDate(rabbit.dateOfBirth);

    final sireName = _sire?.name.trim().isNotEmpty == true
        ? _sire!.name.trim()
        : (rabbit.sireId?.trim().isNotEmpty == true ? rabbit.sireId!.trim() : 'Unknown');
    final sireBreed = _fallbackDash(_sire?.breed);
    final sireColor = _fallbackDash(_sire?.color);
    final sireDob = FormatUtils.formatCertificateDate(_sire?.dateOfBirth);
    final sireWeight = _formatWeight(_sire?.weight);
    final sirePhoto = _sire?.photos?.isNotEmpty == true ? _sire!.photos!.first : null;

    final damName = _dam?.name.trim().isNotEmpty == true
        ? _dam!.name.trim()
        : (rabbit.damId?.trim().isNotEmpty == true ? rabbit.damId!.trim() : 'Unknown');
    final damBreed = _fallbackDash(_dam?.breed);
    final damColor = _fallbackDash(_dam?.color);
    final damDob = FormatUtils.formatCertificateDate(_dam?.dateOfBirth);
    final damWeight = _formatWeight(_dam?.weight);
    final damPhoto = _dam?.photos?.isNotEmpty == true ? _dam!.photos!.first : null;

    final kitPhoto = rabbit.photos?.isNotEmpty == true ? rabbit.photos!.first : null;

    return CertificateData(
      farmName: _settings.farmName.trim().isNotEmpty ? _settings.farmName.trim() : 'Dynasty',
      ownerName: _settings.ownerName.trim(),
      farmAddress: _settings.farmAddress.trim(),
      farmEmail: _settings.farmEmail.trim(),
      kitName: rabbit.name.trim().isNotEmpty ? rabbit.name.trim() : '—',
      kitBreed: _fallbackDash(rabbit.breed),
      kitColor: _fallbackDash(rabbit.color),
      kitDob: dob,
      kitSex: sex,
      kitPhotoPath: kitPhoto,
      sireName: sireName,
      sireBreed: sireBreed,
      sireColor: sireColor,
      sireDob: sireDob,
      sireWeight: sireWeight,
      sirePhotoPath: sirePhoto,
      damName: damName,
      damBreed: damBreed,
      damColor: damColor,
      damDob: damDob,
      damWeight: damWeight,
      damPhotoPath: damPhoto,
      includePhoto: includePhoto,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kNeutral200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'BIRTH CERTIFICATE',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: Color(0xFF4F4F56),
                letterSpacing: 0.8,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              children: [
                const Text(
                  'Generate a printable birth certificate for this rabbit',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4F4F56),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoadingParents ? null : () => _showPreviewModal(context),
                    icon: Icon(
                      PhosphorIcons.fileText(PhosphorIconsStyle.duotone),
                      size: 18,
                      color: const Color(0xFF4F4F56),
                    ),
                    label: const Text(
                      'Preview Certificate',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4F4F56),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF4EBFE),
                      foregroundColor: const Color(0xFF4F4F56),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPreviewModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CertificatePreviewSheet(
        dataBuilder: _buildCertificateData,
        onDownload: (data) => _generateAndShare(ctx, data),
      ),
    );
  }

  Future<void> _generateAndShare(BuildContext sheetContext, CertificateData data) async {
    Navigator.of(sheetContext).pop();
    try {
      final bytes = await CertificatePdfService.generatePdf(data);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'BirthCertificate_${data.kitName.replaceAll(' ', '_')}.pdf',
      );
    } catch (e) {
      debugPrint('Certificate generation error: $e');
    }
  }
}

// ─── Preview Sheet ────────────────────────────────────────────────────────────

class _CertificatePreviewSheet extends StatefulWidget {
  final CertificateData Function(bool includePhoto) dataBuilder;
  final Function(CertificateData data) onDownload;

  const _CertificatePreviewSheet({
    required this.dataBuilder,
    required this.onDownload,
  });

  @override
  State<_CertificatePreviewSheet> createState() => _CertificatePreviewSheetState();
}

class _CertificatePreviewSheetState extends State<_CertificatePreviewSheet> {
  bool _includePhoto = true;

  @override
  Widget build(BuildContext context) {
    final certificateData = widget.dataBuilder(_includePhoto);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: kNeutral300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Birth Certificate Preview',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: kNeutral900,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // WYSIWYG 1:1 Preview Box
                  CertificatePreviewWidget(data: certificateData),
                  const SizedBox(height: 24),
                  _buildToggle(
                    'Include Photos',
                    _includePhoto,
                    (v) => setState(() => _includePhoto = v),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => widget.onDownload(certificateData),
                      icon: const Icon(Icons.download_rounded, size: 20),
                      label: const Text(
                        'Download & Share PDF',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7B6BA0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle(String label, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          Switch(value: value, onChanged: onChanged, activeColor: kPinkDeep),
        ],
      ),
    );
  }
}

// ─── WYSIWYG Preview Widget ───────────────────────────────────────────────────

class CertificatePreviewWidget extends StatelessWidget {
  final CertificateData data;

  const CertificatePreviewWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: CertificateLayout.aspectRatio,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kNeutral300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double W = constraints.maxWidth;
            final double H = constraints.maxHeight;

            final hasKitPhoto = data.includePhoto &&
                data.kitPhotoPath != null &&
                File(data.kitPhotoPath!).existsSync();

            final hasSirePhoto = data.includePhoto &&
                data.sirePhotoPath != null &&
                File(data.sirePhotoPath!).existsSync();

            final hasDamPhoto = data.includePhoto &&
                data.damPhotoPath != null &&
                File(data.damPhotoPath!).existsSync();

            return Stack(
              children: [
                // Layer 1: Background Template Image (Full Bleed)
                Positioned.fill(
                  child: Image.asset(
                    CertificateLayout.backgroundAsset,
                    fit: BoxFit.fill,
                  ),
                ),

                // Layer 2: Farm Name (Title) with auto-scaling to avoid overflow/collision
                Positioned(
                  left: W * (0.5000 - CertificateLayout.titleMaxWidth / 2),
                  top: H * CertificateLayout.titleCenterY - (H * CertificateLayout.titleBoxHeight / 2),
                  width: W * CertificateLayout.titleMaxWidth,
                  height: H * CertificateLayout.titleBoxHeight,
                  child: Align(
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        data.farmName,
                        style: TextStyle(
                          fontFamily: CertificateLayout.fontFamilyTitle,
                          fontSize: W * CertificateLayout.fontRatioTitle,
                          color: CertificateLayout.colorTitle,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),

                // Layer 2: "Birth Certificate" Badge
                Positioned(
                  left: W * CertificateLayout.badgeLeft,
                  top: H * CertificateLayout.badgeTop,
                  width: W * CertificateLayout.badgeWidth,
                  height: H * CertificateLayout.badgeHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: CertificateLayout.colorBadgeBg,
                      borderRadius: BorderRadius.circular(W * CertificateLayout.badgeRadius),
                    ),
                    child: Center(
                      child: Text(
                        'Birth Certificate',
                        style: TextStyle(
                          fontFamily: CertificateLayout.fontFamilyBadge,
                          fontSize: W * CertificateLayout.fontRatioBadge,
                          color: CertificateLayout.colorBadgeText,
                          letterSpacing: 0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),

                // Layer 2: Kit Photo (Left Column)
                Positioned(
                  left: W * CertificateLayout.kitPhotoLeft,
                  top: H * CertificateLayout.kitPhotoTop,
                  width: W * CertificateLayout.kitPhotoWidth,
                  height: H * CertificateLayout.kitPhotoHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(W * CertificateLayout.kitPhotoRadius),
                      color: hasKitPhoto ? null : Colors.black.withValues(alpha: 0.06),
                    ),
                    child: hasKitPhoto
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(W * CertificateLayout.kitPhotoRadius),
                            child: Image.file(
                              File(data.kitPhotoPath!),
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Center(
                            child: Text(
                              'No Photo',
                              style: TextStyle(
                                fontFamily: CertificateLayout.fontFamilyDetails,
                                fontSize: 11,
                                color: Color(0xFF999999),
                              ),
                            ),
                          ),
                  ),
                ),

                // Layer 2: Kit Detail Rows (Center)
                ..._buildKitRow(W, H, CertificateLayout.kitNameCenterY, 'Name: ${data.kitName}'),
                ..._buildKitRow(W, H, CertificateLayout.kitBreedCenterY, 'Breed: ${data.kitBreed}'),
                ..._buildKitRow(W, H, CertificateLayout.kitColorCenterY, 'Color: ${data.kitColor}'),
                ..._buildKitRow(W, H, CertificateLayout.kitDobCenterY, 'DOB: ${data.kitDob}'),
                ..._buildKitRow(W, H, CertificateLayout.kitSexCenterY, 'Sex: ${data.kitSex}'),

                // Layer 2: Sire Photo (Right Column Top)
                Positioned(
                  left: W * CertificateLayout.sirePhotoLeft,
                  top: H * CertificateLayout.sirePhotoTop,
                  width: W * CertificateLayout.sirePhotoWidth,
                  height: H * CertificateLayout.sirePhotoHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(W * CertificateLayout.sirePhotoRadius),
                      color: hasSirePhoto ? null : Colors.black.withValues(alpha: 0.06),
                    ),
                    child: hasSirePhoto
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(W * CertificateLayout.sirePhotoRadius),
                            child: Image.file(
                              File(data.sirePhotoPath!),
                              fit: BoxFit.cover,
                            ),
                          )
                        : const Center(
                            child: Text(
                              'Sire Photo',
                              style: TextStyle(
                                fontFamily: CertificateLayout.fontFamilyDetails,
                                fontSize: 9,
                                color: Color(0xFF999999),
                              ),
                            ),
                          ),
                  ),
                ),

                // Layer 2: Sire Card
                Positioned(
                  left: W * CertificateLayout.sireCardLeft,
                  top: H * CertificateLayout.sireCardTop,
                  width: W * CertificateLayout.sireCardWidth,
                  height: H * CertificateLayout.sireCardHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: CertificateLayout.colorSireCardBg,
                      borderRadius: BorderRadius.circular(W * CertificateLayout.sireCardRadius),
                    ),
                  ),
                ),
                ..._buildCardRow(W, H, CertificateLayout.sireRowsCenterY[0], 'Sire: ${data.sireName}'),
                ..._buildCardRow(W, H, CertificateLayout.sireRowsCenterY[1], 'Breed: ${data.sireBreed}'),
                ..._buildCardRow(W, H, CertificateLayout.sireRowsCenterY[2], 'Color: ${data.sireColor}'),
                ..._buildCardRow(W, H, CertificateLayout.sireRowsCenterY[3], 'DOB: ${data.sireDob}'),
                ..._buildCardRow(W, H, CertificateLayout.sireRowsCenterY[4], 'Wt: ${data.sireWeight}'),

                // Layer 2: Dam Photo (Right Column Bottom with White Frame)
                Positioned(
                  left: W * CertificateLayout.damPhotoLeft,
                  top: H * CertificateLayout.damPhotoTop,
                  width: W * CertificateLayout.damPhotoWidth,
                  height: H * CertificateLayout.damPhotoHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(W * CertificateLayout.damPhotoRadius),
                    ),
                    padding: const EdgeInsets.all(2.5),
                    child: hasDamPhoto
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(W * CertificateLayout.damPhotoRadius * 0.8),
                            child: Image.file(
                              File(data.damPhotoPath!),
                              fit: BoxFit.cover,
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(W * CertificateLayout.damPhotoRadius * 0.8),
                            ),
                            child: const Center(
                              child: Text(
                                'Dam Photo',
                                style: TextStyle(
                                  fontFamily: CertificateLayout.fontFamilyDetails,
                                  fontSize: 9,
                                  color: Color(0xFF999999),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),

                // Layer 2: Dam Card
                Positioned(
                  left: W * CertificateLayout.damCardLeft,
                  top: H * CertificateLayout.damCardTop,
                  width: W * CertificateLayout.damCardWidth,
                  height: H * CertificateLayout.damCardHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      color: CertificateLayout.colorDamCardBg,
                      borderRadius: BorderRadius.circular(W * CertificateLayout.damCardRadius),
                    ),
                  ),
                ),
                ..._buildCardRow(W, H, CertificateLayout.damRowsCenterY[0], 'Dam: ${data.damName}'),
                ..._buildCardRow(W, H, CertificateLayout.damRowsCenterY[1], 'Breed: ${data.damBreed}'),
                ..._buildCardRow(W, H, CertificateLayout.damRowsCenterY[2], 'Color: ${data.damColor}'),
                ..._buildCardRow(W, H, CertificateLayout.damRowsCenterY[3], 'DOB: ${data.damDob}'),
                ..._buildCardRow(W, H, CertificateLayout.damRowsCenterY[4], 'Wt: ${data.damWeight}'),

                // Layer 2: Footer / Certification (Bottom Left)
                Positioned(
                  left: W * CertificateLayout.footerTextLeft,
                  top: H * CertificateLayout.certifyLine1CenterY - (H * CertificateLayout.footerRowBoxHeight / 2),
                  width: W * CertificateLayout.footerTextMaxWidth,
                  height: H * CertificateLayout.footerRowBoxHeight,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'I hereby certify this certificate is true',
                      style: TextStyle(
                        fontFamily: CertificateLayout.fontFamilyDetails,
                        fontSize: W * CertificateLayout.fontRatioCertify,
                        color: CertificateLayout.colorCertifyText,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
                Positioned(
                  left: W * CertificateLayout.footerTextLeft,
                  top: H * CertificateLayout.certifyLine2CenterY - (H * CertificateLayout.footerRowBoxHeight / 2),
                  width: W * CertificateLayout.footerTextMaxWidth,
                  height: H * CertificateLayout.footerRowBoxHeight,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'to the best of my knowledge',
                      style: TextStyle(
                        fontFamily: CertificateLayout.fontFamilyDetails,
                        fontSize: W * CertificateLayout.fontRatioCertify,
                        color: CertificateLayout.colorCertifyText,
                      ),
                      maxLines: 1,
                    ),
                  ),
                ),
                if (data.ownerName.trim().isNotEmpty)
                  Positioned(
                    left: W * CertificateLayout.signatureLeft,
                    top: H * CertificateLayout.signatureCenterY - (H * CertificateLayout.signatureBoxHeight / 2),
                    width: W * CertificateLayout.footerTextMaxWidth,
                    height: H * CertificateLayout.signatureBoxHeight,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        data.ownerName.trim(),
                        style: TextStyle(
                          fontFamily: CertificateLayout.fontFamilySignature,
                          fontSize: W * CertificateLayout.fontRatioSignature,
                          color: CertificateLayout.colorSignatureText,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                if (data.farmAddress.trim().isNotEmpty)
                  Positioned(
                    left: W * CertificateLayout.addressLeft,
                    top: H * CertificateLayout.addressCenterY - (H * CertificateLayout.footerRowBoxHeight / 2),
                    width: W * CertificateLayout.footerTextMaxWidth,
                    height: H * CertificateLayout.footerRowBoxHeight,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        data.farmAddress.trim(),
                        style: TextStyle(
                          fontFamily: CertificateLayout.fontFamilyDetails,
                          fontSize: W * CertificateLayout.fontRatioContact,
                          color: CertificateLayout.colorContactText,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
                if (data.farmEmail.trim().isNotEmpty)
                  Positioned(
                    left: W * CertificateLayout.emailLeft,
                    top: H * CertificateLayout.emailCenterY - (H * CertificateLayout.footerRowBoxHeight / 2),
                    width: W * CertificateLayout.footerTextMaxWidth,
                    height: H * CertificateLayout.footerRowBoxHeight,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        data.farmEmail.trim(),
                        style: TextStyle(
                          fontFamily: CertificateLayout.fontFamilyDetails,
                          fontSize: W * CertificateLayout.fontRatioContact,
                          color: CertificateLayout.colorContactText,
                        ),
                        maxLines: 1,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  static List<Widget> _buildKitRow(double W, double H, double centerY, String text) {
    final rowHeight = H * CertificateLayout.kitRowBoxHeight;
    final iconHeight = H * CertificateLayout.kitIconHeight;
    final iconWidth = W * CertificateLayout.kitIconWidth;

    return [
      Positioned(
        left: W * CertificateLayout.kitIconLeft,
        top: H * centerY - (iconHeight / 2),
        width: iconWidth,
        height: iconHeight,
        child: Image.asset(CertificateLayout.rabbitIconAsset, fit: BoxFit.contain),
      ),
      Positioned(
        left: W * CertificateLayout.kitTextLeft,
        top: H * centerY - (rowHeight / 2),
        width: W * CertificateLayout.kitTextMaxWidth,
        height: rowHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: TextStyle(
              fontFamily: CertificateLayout.fontFamilyDetails,
              fontSize: W * CertificateLayout.fontRatioKitRows,
              color: CertificateLayout.colorKitText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ];
  }

  static List<Widget> _buildCardRow(double W, double H, double centerY, String text) {
    final rowHeight = H * CertificateLayout.cardRowBoxHeight;
    return [
      Positioned(
        left: W * CertificateLayout.cardTextLeft,
        top: H * centerY - (rowHeight / 2),
        width: W * CertificateLayout.cardTextMaxWidth,
        height: rowHeight,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            text,
            style: TextStyle(
              fontFamily: CertificateLayout.fontFamilyDetails,
              fontSize: W * CertificateLayout.fontRatioCardRows,
              color: CertificateLayout.colorCardText,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ];
  }
}
