import 'dart:io';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:printing/printing.dart';
import '../models/rabbit.dart';
import '../services/database_service.dart';
import '../services/format_utils.dart';
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

  Rabbit? _sire;
  Rabbit? _dam;
  bool _isLoadingParents = true;
  bool _includePhoto = true;

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

  String _fallbackDash(String? value) {
    if (value == null || value.trim().isEmpty || value.trim() == 'N/A') return '—';
    return value.trim();
  }

  CertificateData _buildCertificateData(bool includePhoto) {
    final rabbit = widget.rabbit;
    final sex = rabbit.type == RabbitType.buck ? 'Buck' : 'Doe';
    final dob = FormatUtils.formatCertificateDatePadded(rabbit.dateOfBirth);

    final sireName = _sire?.name.trim().isNotEmpty == true
        ? _sire!.name.trim()
        : (rabbit.sireId?.trim().isNotEmpty == true ? rabbit.sireId!.trim() : 'Unknown');

    final damName = _dam?.name.trim().isNotEmpty == true
        ? _dam!.name.trim()
        : (rabbit.damId?.trim().isNotEmpty == true ? rabbit.damId!.trim() : 'Unknown');

    final photo = rabbit.photos?.isNotEmpty == true ? rabbit.photos!.first : null;

    return CertificateData(
      name: rabbit.name.trim().isNotEmpty ? rabbit.name.trim() : '—',
      breed: _fallbackDash(rabbit.breed),
      color: _fallbackDash(rabbit.color),
      dob: dob,
      sex: sex,
      damName: damName,
      sireName: sireName,
      photoPath: photo,
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
                      color: const Color(0xFF5C4A70),
                    ),
                    label: const Text(
                      'Preview Certificate',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF5C4A70),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFD4B3EE),
                      foregroundColor: const Color(0xFF5C4A70),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Toggle option
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Include Photo',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF374151),
                      ),
                    ),
                    Switch(
                      value: _includePhoto,
                      onChanged: (val) => setState(() => _includePhoto = val),
                      activeColor: const Color(0xFF7B6BA0),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showPreviewModal(BuildContext context) {
    final certData = _buildCertificateData(_includePhoto);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CertificatePreviewModal(
        data: certData,
        rabbitName: widget.rabbit.name,
      ),
    );
  }
}

class _CertificatePreviewModal extends StatelessWidget {
  final CertificateData data;
  final String rabbitName;

  const _CertificatePreviewModal({
    required this.data,
    required this.rabbitName,
  });

  @override
  Widget build(BuildContext context) {
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
                  'Certificate Preview',
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
                  CertificatePreviewWidget(data: data),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          final pdfBytes = await CertificatePdfService.generatePdf(data);
                          final safeName = (rabbitName.trim().isNotEmpty ? rabbitName.trim() : 'Rabbit')
                              .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
                          await Printing.sharePdf(
                            bytes: pdfBytes,
                            filename: 'BirthCertificate_$safeName.pdf',
                          );
                        } catch (e) {
                          debugPrint('Error sharing Certificate PDF: $e');
                        }
                      },
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
}

// ─── WYSIWYG PREVIEW WIDGET ───────────────────────────────────────────────────

class CertificatePreviewWidget extends StatelessWidget {
  final CertificateData data;

  const CertificatePreviewWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: CertificateLayout.aspectRatio,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kNeutral300),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
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

            final hasPhoto = data.includePhoto &&
                data.photoPath != null &&
                data.photoPath!.isNotEmpty &&
                File(data.photoPath!).existsSync();

            final double badgeFontSize = W * CertificateLayout.fontRatioBadge;

            final List<_PreviewRowDef> rows = [
              _PreviewRowDef(
                fullText: 'Name: ${data.name.isNotEmpty ? data.name : "—"}',
                iconTop: CertificateLayout.iconTopName,
                rowCenterY: CertificateLayout.rowNameCenterY,
              ),
              _PreviewRowDef(
                fullText: 'Breed: ${data.breed.isNotEmpty ? data.breed : "—"}',
                iconTop: CertificateLayout.iconTopBreed,
                rowCenterY: CertificateLayout.rowBreedCenterY,
              ),
              _PreviewRowDef(
                fullText: 'Color: ${data.color.isNotEmpty ? data.color : "—"}',
                iconTop: CertificateLayout.iconTopColor,
                rowCenterY: CertificateLayout.rowColorCenterY,
              ),
              _PreviewRowDef(
                fullText: 'DOB: ${data.dob.isNotEmpty ? data.dob : "—"}',
                iconTop: CertificateLayout.iconTopDob,
                rowCenterY: CertificateLayout.rowDobCenterY,
              ),
              _PreviewRowDef(
                fullText: 'Sex: ${data.sex.isNotEmpty ? data.sex : "—"}',
                iconTop: CertificateLayout.iconTopSex,
                rowCenterY: CertificateLayout.rowSexCenterY,
              ),
              _PreviewRowDef(
                fullText: 'Dam ${data.damName.isNotEmpty ? data.damName : "Unknown"} X Sire ${data.sireName.isNotEmpty ? data.sireName : "Unknown"}',
                iconTop: CertificateLayout.iconTopParents,
                rowCenterY: CertificateLayout.rowParentsCenterY,
              ),
            ];

            return Stack(
              children: [
                // Layer 1: Background Watercolor
                Positioned.fill(
                  child: Image.asset(
                    CertificateLayout.backgroundAsset,
                    fit: BoxFit.fill,
                  ),
                ),

                // Layer 2: Outer Border
                Positioned(
                  left: W * CertificateLayout.outerBorderLeft,
                  top: H * CertificateLayout.outerBorderTop,
                  child: Container(
                    width: W * CertificateLayout.outerBorderWidth,
                    height: H * CertificateLayout.outerBorderHeight,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: CertificateLayout.colorBorderOuter,
                        width: CertificateLayout.outerBorderStrokePt * (W / 792.0),
                      ),
                    ),
                  ),
                ),

                // Layer 3: Inner Border
                Positioned(
                  left: W * CertificateLayout.innerBorderLeft,
                  top: H * CertificateLayout.innerBorderTop,
                  child: Container(
                    width: W * CertificateLayout.innerBorderWidth,
                    height: H * CertificateLayout.innerBorderHeight,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: CertificateLayout.colorBorderInner,
                        width: CertificateLayout.innerBorderStrokePt * (W / 792.0),
                      ),
                    ),
                  ),
                ),

                // Layer 4: Top Badge
                Positioned(
                  left: W * CertificateLayout.badgeLeft,
                  top: H * CertificateLayout.badgeTop,
                  child: Container(
                    width: W * CertificateLayout.badgeWidth,
                    height: H * CertificateLayout.badgeHeight,
                    decoration: BoxDecoration(
                      color: CertificateLayout.colorBadgeBg,
                      border: Border.all(
                        color: CertificateLayout.colorBadgeStroke,
                        width: CertificateLayout.badgeStrokePt * (W / 792.0),
                      ),
                      borderRadius: BorderRadius.circular(W * CertificateLayout.badgeRadius),
                    ),
                    child: Center(
                      child: SizedBox(
                        width: W * CertificateLayout.badgeTextMaxWidth,
                        height: H * CertificateLayout.badgeHeight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.center,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // White outline behind text
                              Text(
                                CertificateLayout.badgeText,
                                maxLines: 1,
                                softWrap: false,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: CertificateLayout.fontFamilyBadgeWestern,
                                  fontSize: badgeFontSize,
                                  foreground: Paint()
                                    ..style = PaintingStyle.stroke
                                    ..strokeWidth = 2.0 * (W / 792.0)
                                    ..color = Colors.white,
                                ),
                              ),
                              // Grey text fill
                              Text(
                                CertificateLayout.badgeText,
                                maxLines: 1,
                                softWrap: false,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: CertificateLayout.fontFamilyBadgeWestern,
                                  fontSize: badgeFontSize,
                                  color: CertificateLayout.colorBadgeText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Layer 5: Photo Frame
                Positioned(
                  left: W * CertificateLayout.photoLeft,
                  top: H * CertificateLayout.photoTop,
                  child: Container(
                    width: W * CertificateLayout.photoWidth,
                    height: H * CertificateLayout.photoHeight,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(W * CertificateLayout.photoRadius),
                      color: hasPhoto ? null : CertificateLayout.colorPlaceholderBg,
                    ),
                    child: Stack(
                      children: [
                        if (hasPhoto)
                          Positioned.fill(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(W * CertificateLayout.photoRadius),
                              child: Image.file(
                                File(data.photoPath!),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(W * CertificateLayout.photoRadius),
                              border: Border.all(
                                color: CertificateLayout.colorPhotoBorder,
                                width: CertificateLayout.photoBorderWidthPt * (W / 792.0),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Layer 6: Right Detail Rows
                for (final r in rows)
                  Positioned(
                    left: W * CertificateLayout.iconLeft,
                    top: H * r.rowCenterY - (H * CertificateLayout.textRowHeight / 2),
                    child: SizedBox(
                      width: W * (CertificateLayout.textLeft - CertificateLayout.iconLeft + CertificateLayout.textMaxWidth),
                      height: H * CertificateLayout.textRowHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: W * CertificateLayout.iconWidth,
                            height: H * CertificateLayout.iconHeight,
                            child: Image.asset(
                              CertificateLayout.rabbitIconAsset,
                              fit: BoxFit.contain,
                            ),
                          ),
                          SizedBox(width: W * 0.015),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: _buildAutoShrinkText(
                                text: r.fullText,
                                baseSize: W * CertificateLayout.fontRatioDetails,
                                minSize: W * CertificateLayout.fontRatioDetailsMin,
                              ),
                            ),
                          ),
                        ],
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

  Widget _buildAutoShrinkText({
    required String text,
    required double baseSize,
    required double minSize,
  }) {
    double size = baseSize;
    if (text.length > 22) {
      size = (baseSize * 22 / text.length).clamp(minSize, baseSize);
    }

    return Text(
      text,
      style: TextStyle(
        fontFamily: CertificateLayout.fontFamilyDetails,
        fontSize: size,
        color: CertificateLayout.colorDetailsText,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _PreviewRowDef {
  final String fullText;
  final double iconTop;
  final double rowCenterY;

  const _PreviewRowDef({
    required this.fullText,
    required this.iconTop,
    required this.rowCenterY,
  });
}
