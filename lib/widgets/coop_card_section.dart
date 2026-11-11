import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:printing/printing.dart';
import '../constants/app_colors.dart';
import '../models/rabbit.dart';
import '../services/coop_card_pdf_service.dart';
import '../services/database_service.dart';
import '../services/format_utils.dart';
import 'certificate_layout.dart';

class CoopCardSection extends StatefulWidget {
  final Rabbit rabbit;
  const CoopCardSection({super.key, required this.rabbit});

  @override
  State<CoopCardSection> createState() => _CoopCardSectionState();
}

class _CoopCardSectionState extends State<CoopCardSection> {
  final DatabaseService _db = DatabaseService();

  Rabbit? _sire;
  Rabbit? _dam;
  bool _isLoadingParents = true;
  CoopCardSize _selectedSize = CoopCardSize.fourBySeven;
  bool _landscape = true;

  @override
  void initState() {
    super.initState();
    _loadParents();
  }

  @override
  void didUpdateWidget(covariant CoopCardSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rabbit.id != widget.rabbit.id ||
        oldWidget.rabbit.sireId != widget.rabbit.sireId ||
        oldWidget.rabbit.damId != widget.rabbit.damId) {
      _loadParents();
    }
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
    } catch (_) {
      if (mounted) setState(() => _isLoadingParents = false);
    }
  }

  Widget _buildToggleChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF5C4A70)
                    : const Color(0xFF6B7280),
                height: 1.15,
              ),
            ),
          ),
        ),
      ),
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
              'COOP CARD',
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
                  'Generate a printable coop card for this rabbit',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF4F4F56),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                // 3 Sizes: 2X3, 3X5, 4X7
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E5EA)),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      _buildToggleChip(
                        label: '2X3',
                        isSelected: _selectedSize == CoopCardSize.twoByThree,
                        onTap: () => setState(
                            () => _selectedSize = CoopCardSize.twoByThree),
                      ),
                      _buildToggleChip(
                        label: '3X5',
                        isSelected: _selectedSize == CoopCardSize.threeByFive,
                        onTap: () => setState(
                            () => _selectedSize = CoopCardSize.threeByFive),
                      ),
                      _buildToggleChip(
                        label: '4X7',
                        isSelected: _selectedSize == CoopCardSize.fourBySeven,
                        onTap: () => setState(
                            () => _selectedSize = CoopCardSize.fourBySeven),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // Orientation: Landscape / Portrait
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E5EA)),
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [
                      _buildToggleChip(
                        label: 'Landscape',
                        isSelected: _landscape,
                        onTap: () => setState(() => _landscape = true),
                      ),
                      _buildToggleChip(
                        label: 'Portrait',
                        isSelected: !_landscape,
                        onTap: () => setState(() => _landscape = false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isLoadingParents
                        ? null
                        : () => _showPreviewModal(context),
                    icon: Icon(
                      PhosphorIcons.identificationCard(
                          PhosphorIconsStyle.duotone),
                      size: 18,
                      color: const Color(0xFF5C4A70),
                    ),
                    label: const Text(
                      'Preview Coop Card',
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
      builder: (ctx) => CoopCardPreviewModal(
        initialSize: _selectedSize,
        initialLandscape: _landscape,
        rabbit: widget.rabbit,
        sire: _sire,
        dam: _dam,
        onSelectionChanged: (sz, isLandscape) {
          setState(() {
            _selectedSize = sz;
            _landscape = isLandscape;
          });
        },
      ),
    );
  }
}

class CoopCardPreviewModal extends StatefulWidget {
  final CoopCardSize initialSize;
  final bool initialLandscape;
  final Rabbit rabbit;
  final Rabbit? sire;
  final Rabbit? dam;
  final void Function(CoopCardSize size, bool landscape)? onSelectionChanged;

  const CoopCardPreviewModal({
    super.key,
    required this.initialSize,
    required this.initialLandscape,
    required this.rabbit,
    this.sire,
    this.dam,
    this.onSelectionChanged,
  });

  @override
  State<CoopCardPreviewModal> createState() => _CoopCardPreviewModalState();
}

class _CoopCardPreviewModalState extends State<CoopCardPreviewModal> {
  late CoopCardSize _size;
  late bool _landscape;

  @override
  void initState() {
    super.initState();
    _size = widget.initialSize;
    _landscape = widget.initialLandscape;
  }

  void _updateSelection({CoopCardSize? size, bool? landscape}) {
    setState(() {
      if (size != null) _size = size;
      if (landscape != null) _landscape = landscape;
    });
    widget.onSelectionChanged?.call(_size, _landscape);
  }

  String _resolveParentName(Rabbit? parent, String? rawId) {
    if (parent != null) {
      final full = parent.fullName.trim();
      if (full.isNotEmpty) return full;
      if (parent.name.trim().isNotEmpty) return parent.name.trim();
    }
    if (rawId != null && rawId.trim().isNotEmpty) {
      final trimmed = rawId.trim();
      final isInternalId =
          RegExp(r'^(R-|PED-|ped_|K-|F-|\d+|[0-9a-fA-F-]{8,})')
              .hasMatch(trimmed);
      if (!isInternalId) return trimmed;
    }
    return '';
  }

  CoopCardData _buildData() {
    final r = widget.rabbit;
    final prefix = r.breederPrefix?.trim() ?? '';
    final baseName = r.name.trim();
    String displayTitle;
    if (prefix.isNotEmpty &&
        !baseName.toLowerCase().startsWith(prefix.toLowerCase())) {
      displayTitle = '$prefix $baseName';
    } else {
      displayTitle = baseName;
    }

    return CoopCardData(
      name: displayTitle,
      breed: r.breed.trim(),
      ageClass: CoopCardData.ageClassFor(
        r.dateOfBirth,
        isGrowout: r.status == RabbitStatus.growout || r.type == RabbitType.kit,
      ),
      color: (r.color ?? '').trim(),
      tattoo: (r.earNumber ?? '').trim(),
      dob: r.dateOfBirth != null ? FormatUtils.formatDate(r.dateOfBirth!) : '',
      cage: (r.cage ?? '').trim(),
      weight: r.weight != null && r.weight! > 0
          ? FormatUtils.formatWeight(r.weight!)
          : '',
      sire: _resolveParentName(widget.sire, r.sireId),
      dam: _resolveParentName(widget.dam, r.damId),
    );
  }

  Widget _buildModalToggle({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF5C4A70)
                    : const Color(0xFF6B7280),
                height: 1.15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardData = _buildData();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
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
            padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Coop Card Preview',
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
          // Size toggles inside modal
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E5EA)),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildModalToggle(
                    label: '2X3',
                    isSelected: _size == CoopCardSize.twoByThree,
                    onTap: () =>
                        _updateSelection(size: CoopCardSize.twoByThree),
                  ),
                  _buildModalToggle(
                    label: '3X5',
                    isSelected: _size == CoopCardSize.threeByFive,
                    onTap: () =>
                        _updateSelection(size: CoopCardSize.threeByFive),
                  ),
                  _buildModalToggle(
                    label: '4X7',
                    isSelected: _size == CoopCardSize.fourBySeven,
                    onTap: () =>
                        _updateSelection(size: CoopCardSize.fourBySeven),
                  ),
                ],
              ),
            ),
          ),
          // Orientation toggles inside modal
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF2F2F7),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E5EA)),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildModalToggle(
                    label: 'Landscape',
                    isSelected: _landscape,
                    onTap: () => _updateSelection(landscape: true),
                  ),
                  _buildModalToggle(
                    label: 'Portrait',
                    isSelected: !_landscape,
                    onTap: () => _updateSelection(landscape: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Text(
                    _size.dimensionLabel(landscape: _landscape),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const SizedBox(height: 10),
                  CoopCardPreviewWidget(
                    data: cardData,
                    size: _size,
                    landscape: _landscape,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        try {
                          final pdfBytes = await CoopCardPdfService.generatePdf(
                            cardData,
                            size: _size,
                            landscape: _landscape,
                          );
                          final safeName = (widget.rabbit.name.trim().isNotEmpty
                                  ? widget.rabbit.name.trim()
                                  : 'Rabbit')
                              .replaceAll(RegExp(r'[^a-zA-Z0-9_\-]'), '_');
                          final orient =
                              _landscape ? 'Landscape' : 'Portrait';
                          await Printing.sharePdf(
                            bytes: pdfBytes,
                            filename:
                                'CoopCard_${safeName}_${_size.label}_$orient.pdf',
                          );
                        } catch (e) {
                          debugPrint('Error sharing Coop Card PDF: $e');
                        }
                      },
                      icon: const Icon(Icons.download_rounded, size: 20),
                      label: const Text(
                        'Download & Share PDF',
                        style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15),
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

/// WYSIWYG Flutter Preview Widget matching CoopCard.pdf and CoopCardPdfService.
class CoopCardPreviewWidget extends StatelessWidget {
  final CoopCardData data;
  final CoopCardSize size;
  final bool landscape;

  const CoopCardPreviewWidget({
    super.key,
    required this.data,
    required this.size,
    required this.landscape,
  });

  double get _sizeWidthFraction {
    switch (size) {
      case CoopCardSize.twoByThree:
        return landscape ? 0.72 : 0.56;
      case CoopCardSize.threeByFive:
        return landscape ? 0.86 : 0.66;
      case CoopCardSize.fourBySeven:
        return landscape ? 1.0 : 0.76;
    }
  }

  @override
  Widget build(BuildContext context) {
    final aspectRatio = landscape
        ? (size.longIn / size.shortIn)
        : (size.shortIn / size.longIn);

    return Center(
      child: FractionallySizedBox(
        widthFactor: _sizeWidthFraction,
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFF59595E), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final W = constraints.maxWidth;
                final H = constraints.maxHeight;
                // Scale relative to 4x7 short side (288 pt)
                final u = (landscape ? H : W) / 288.0;
                final padH = 12.0 * u;
                final nameFontSize = (landscape ? 50.0 : 42.0) * u;
                final subtitleFontSize = 18.5 * u;
                final fieldFontSize = 15.0 * u;

                Widget buildField(String label, String value) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label.isEmpty ? '' : '$label ',
                        style: TextStyle(
                          fontFamily: CertificateLayout.fontFamilyQuicksand,
                          fontSize: fieldFontSize,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF262629),
                          height: 1.15,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          value,
                          style: TextStyle(
                            fontFamily: CertificateLayout.fontFamilyQuicksand,
                            fontSize: fieldFontSize,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF262629),
                            height: 1.15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  );
                }

                final header = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: (landscape ? 68.0 : 62.0) * u,
                      padding: EdgeInsets.symmetric(
                          horizontal: padH, vertical: 4 * u),
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          (data.name.trim().isNotEmpty
                                  ? data.name.trim()
                                  : 'RABBIT')
                              .toUpperCase(),
                          style: TextStyle(
                            fontFamily: CertificateLayout.fontFamilyAscender,
                            fontSize: nameFontSize,
                            color: Colors.black,
                            height: 1.0,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                    Container(
                      height: (landscape ? 36.0 : 32.0) * u,
                      color: const Color(0xFFECECED),
                      padding: EdgeInsets.symmetric(
                          horizontal: padH, vertical: 4 * u),
                      alignment: Alignment.center,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          data.subtitle.isNotEmpty ? data.subtitle : '—',
                          style: TextStyle(
                            fontFamily: CertificateLayout.fontFamilyQuicksand,
                            fontSize: subtitleFontSize,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF545459),
                            height: 1.1,
                          ),
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                );

                final Widget body = landscape
                    ? Padding(
                        padding: EdgeInsets.fromLTRB(
                            padH, 10 * u, padH, 8 * u),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                    flex: 11,
                                    child: buildField('Color:', data.color)),
                                SizedBox(width: 6 * u),
                                Expanded(
                                    flex: 9,
                                    child: buildField('Tattoo:', data.tattoo)),
                              ],
                            ),
                            Row(
                              children: [
                                Expanded(
                                    flex: 11,
                                    child: buildField(
                                        'Date of Birth:', data.dob)),
                                SizedBox(width: 6 * u),
                                Expanded(
                                    flex: 9,
                                    child: buildField('Cage No.:', data.cage)),
                              ],
                            ),
                            buildField('Weight:', data.weight),
                            buildField('Sire:', data.sire),
                            buildField('Dam:', data.dam),
                          ],
                        ),
                      )
                    : Padding(
                        padding: EdgeInsets.fromLTRB(
                            padH, 12 * u, padH, 12 * u),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            buildField('Color:', data.color),
                            buildField('Tattoo:', data.tattoo),
                            buildField('Date of Birth:', data.dob),
                            buildField('Cage No.:', data.cage),
                            buildField('Weight:', data.weight),
                            buildField('Sire:', data.sire),
                            buildField('Dam:', data.dam),
                          ],
                        ),
                      );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    header,
                    Expanded(child: body),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

