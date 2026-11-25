import 'package:flutter/material.dart';
import '../services/appearance_service.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/rabbit.dart';
import '../services/database_service.dart';
import '../constants/app_colors.dart';
import '../widgets/pedigree_layout.dart';
import '../widgets/pedigree_preview_modal.dart';
import '../widgets/pedigree_inline_card.dart';

class PedigreeScreen extends StatefulWidget {
  final String rabbitId;
  final Rabbit? initialRabbit;

  const PedigreeScreen({super.key, required this.rabbitId, this.initialRabbit});

  @override
  State<PedigreeScreen> createState() => _PedigreeScreenState();
}

class _PedigreeScreenState extends State<PedigreeScreen> {
  late Rabbit _baseRabbit;
  bool _isLoading = true;
  final DatabaseService _db = DatabaseService();
  int _generations = 4; // Default to 4 generations
  PedigreeOrientation _orientation = PedigreeOrientation.landscape;

  Rabbit? _sire;
  Rabbit? _dam;
  Rabbit? _ss, _sd, _ds, _dd;
  Rabbit? _sss, _ssd, _sds, _sdd, _dss, _dsd, _dds, _ddd;

  @override
  void initState() {
    super.initState();
    _loadPedigreeData();
  }

  Future<void> _loadPedigreeData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      Rabbit? rabbit = widget.initialRabbit ?? await _db.getRabbit(widget.rabbitId);
      if (rabbit == null) return;
      _baseRabbit = rabbit;

      Rabbit? sire, dam, ss, sd, ds, dd;
      Rabbit? sss, ssd, sds, sdd, dss, dsd, dds, ddd;

      if (rabbit.sireId != null) sire = await _db.getRabbit(rabbit.sireId!);
      if (rabbit.damId != null) dam = await _db.getRabbit(rabbit.damId!);

      // 3 generations: Grandparents (ss, sd, ds, dd)
      if (_generations >= 3) {
        if (sire?.sireId != null) ss = await _db.getRabbit(sire!.sireId!);
        if (sire?.damId != null) sd = await _db.getRabbit(sire!.damId!);
        if (dam?.sireId != null) ds = await _db.getRabbit(dam!.sireId!);
        if (dam?.damId != null) dd = await _db.getRabbit(dam!.damId!);
      }

      // 4 generations: Great-Grandparents
      if (_generations >= 4) {
        if (ss?.sireId != null) sss = await _db.getRabbit(ss!.sireId!);
        if (ss?.damId != null) ssd = await _db.getRabbit(ss!.damId!);
        if (sd?.sireId != null) sds = await _db.getRabbit(sd!.sireId!);
        if (sd?.damId != null) sdd = await _db.getRabbit(sd!.damId!);
        if (ds?.sireId != null) dss = await _db.getRabbit(ds!.sireId!);
        if (ds?.damId != null) dsd = await _db.getRabbit(ds!.damId!);
        if (dd?.sireId != null) dds = await _db.getRabbit(dd!.sireId!);
        if (dd?.damId != null) ddd = await _db.getRabbit(dd!.damId!);
      }

      if (mounted) {
        setState(() {
          _sire = sire;
          _dam = dam;
          _ss = ss;
          _sd = sd;
          _ds = ds;
          _dd = dd;
          _sss = sss;
          _ssd = ssd;
          _sds = sds;
          _sdd = sdd;
          _dss = dss;
          _dsd = dsd;
          _dds = dds;
          _ddd = ddd;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportPedigree() async {
    try {
      final data = await PedigreeData.fromRabbit(
        _baseRabbit,
        db: _db,
        orientation: _orientation,
      );
      if (mounted) {
        PedigreePreviewSheet.show(
          context,
          data,
          onOrientationChanged: (opt) => setState(() => _orientation = opt),
        );
      }
    } catch (e) {
      debugPrint('Error preparing pedigree export: ');
    }
  }

  Widget _buildOrientationToggle(String label, PedigreeOrientation opt) {
    final isSelected = _orientation == opt;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _orientation = opt),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 2),
          decoration: BoxDecoration(
            color: isSelected ? kAppCardWhite : Colors.transparent,
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
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? appColor(0xFF5C4A70) : appColor(0xFF6B7280),
                height: 1.15,
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showParentPickerDialog(String label, RabbitType type, Function(Rabbit?) onSelect, {Rabbit? currentRabbit, String? suggestedPrefix}) async {
    final options = await _db.getRabbitsByType(type);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PedigreeEntryModal(
        label: label,
        type: type,
        options: options,
        onSelect: onSelect,
        db: _db,
        breed: _baseRabbit.breed,
        currentRabbit: currentRabbit,
        suggestedPrefix: suggestedPrefix,
      ),
    );
  }

  Future<void> _updateParent(RabbitType gender, bool isPrimary) async {
    final label = gender == RabbitType.buck ? 'Sire' : 'Dam';
    Rabbit? current = gender == RabbitType.buck ? _sire : _dam;
    if (current == null) {
      final parentId = gender == RabbitType.buck ? _baseRabbit.sireId : _baseRabbit.damId;
      if (parentId != null && parentId.isNotEmpty) {
        current = await _db.getRabbit(parentId);
      }
    }
    _showParentPickerDialog(label, gender, (selectedRabbit) async {
      Rabbit base = _baseRabbit;
      final existing = await _db.getRabbit(base.id);
      if (existing == null) {
        await _db.insertRabbit(base);
      }
      if (gender == RabbitType.buck) {
        base.sireId = selectedRabbit?.id;
      } else {
        base.damId = selectedRabbit?.id;
      }
      await _db.updateRabbit(base);
      setState(() => _baseRabbit = base);
      _loadPedigreeData();
    }, currentRabbit: current);
  }

  Future<void> _updateGrandparent(Rabbit? parent, RabbitType gender, String label, [Rabbit? currentGrandparent]) async {
    if (parent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please add the ${label.contains("Sire") ? "Sire" : "Dam"} first.'),
          backgroundColor: kPinkDeep,
        ),
      );
      return;
    }

    Rabbit? existing = currentGrandparent;
    if (existing == null) {
      final id = gender == RabbitType.buck ? parent.sireId : parent.damId;
      if (id != null && id.isNotEmpty) {
        existing = await _db.getRabbit(id);
      }
    }

    _showParentPickerDialog(label, gender, (selectedRabbit) async {
      final updatedParent = parent;
      if (gender == RabbitType.buck) {
        updatedParent.sireId = selectedRabbit?.id;
      } else {
        updatedParent.damId = selectedRabbit?.id;
      }
      await _db.updateRabbit(updatedParent);
      _loadPedigreeData();
    }, currentRabbit: existing);
  }

  Future<void> _editSlotOnPath(
    List<String> path,
    String label,
    RabbitType gender,
    Rabbit? currentSlotRabbit,
  ) async {
    final Rabbit? existingRecorded =
        isPedigreeAncestorRecorded(currentSlotRabbit) ? currentSlotRabbit : null;
    final suggestedPrefix = existingRecorded == null
        ? await pedigreeSuggestedPrefix(_db, _baseRabbit, path)
        : null;
    _showParentPickerDialog(
      label,
      gender,
      (selectedRabbit) async {
        final updatedBase = await savePedigreeSlotOnPath(
          db: _db,
          baseRabbit: _baseRabbit,
          path: path,
          selectedRabbit: selectedRabbit,
        );
        if (mounted) {
          setState(() => _baseRabbit = updatedBase);
        }
        await _loadPedigreeData();
      },
      currentRabbit: existingRecorded,
      suggestedPrefix: suggestedPrefix,
    );
  }

  String _buildSubjectSubtitle() {
    if (_isLoading) return '';
    final ear = (_baseRabbit.earNumber ?? '').trim();
    final prefix = (_baseRabbit.breederPrefix ?? '').trim();
    final name = _baseRabbit.name.trim();
    final fullName = prefix.isNotEmpty && name.isNotEmpty
        ? '$prefix $name'
        : (name.isNotEmpty ? name : prefix);
    if (ear.isNotEmpty && fullName.isNotEmpty) {
      return '$ear · $fullName';
    }
    return fullName.isNotEmpty ? fullName : ear;
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _buildSubjectSubtitle();
    return Scaffold(
      backgroundColor: appSurface(0xFFF9F9FB),
      appBar: AppBar(
        backgroundColor: kAppCardWhite,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: appColor(0xFF1F2937), size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Pedigree',
              style: TextStyle(
                color: appColor(0xFF1F2937),
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                style: TextStyle(
                  color: appColor(0xFF6B7280),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.share_outlined, color: appColor(0xFF1F2937), size: 21),
            tooltip: 'Export / Share Pedigree',
            onPressed: _exportPedigree,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(strokeWidth: 2, color: appColor(0xFFD4809A)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(14),
              child: Container(
                decoration: BoxDecoration(
                  color: kAppCardWhite,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: appSurface(0xFFE5E5EA)),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PedigreeThreeColumnTree(
                      generations: _generations,
                      sire: _sire,
                      dam: _dam,
                      ss: _ss,
                      sd: _sd,
                      ds: _ds,
                      dd: _dd,
                      sss: _sss,
                      ssd: _ssd,
                      sds: _sds,
                      sdd: _sdd,
                      dss: _dss,
                      dsd: _dsd,
                      dds: _dds,
                      ddd: _ddd,
                      onTapSlot: _editSlotOnPath,
                    ),

                    const SizedBox(height: 20),
                    // 2 Options / Toggle Buttons: Landscape & Portrait
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: appSurface(0xFFF2F2F7),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: appSurface(0xFFE5E5EA)),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(
                        children: [
                          _buildOrientationToggle('Landscape', PedigreeOrientation.landscape),
                          _buildOrientationToggle('Portrait', PedigreeOrientation.portrait),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Preview Pedigree Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _exportPedigree,
                        icon: Icon(
                          PhosphorIcons.treeStructure(PhosphorIconsStyle.duotone),
                          size: 18,
                          color: appColor(0xFF5C4A70),
                        ),
                        label: Text(
                          'Preview Pedigree',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: appColor(0xFF5C4A70),
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: appSurface(0xFFD4B3EE),
                          foregroundColor: appColor(0xFF5C4A70),
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
            ),
    );
  }

  Widget _buildSubjectCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kHeaderPink,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appSurface(0xFFF7B4DE), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'SUBJECT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: appColor(0xFF55555C),
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              children: [
                if ((_baseRabbit.breederPrefix ?? '').isNotEmpty)
                  TextSpan(
                    text: '${_baseRabbit.breederPrefix} ',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: appColor(0xFF2C2C2E),
                    ),
                  ),
                TextSpan(
                  text: _baseRabbit.name,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: appColor(0xFF2C2C2E),
                  ),
                ),
              ],
            ),
          ),
          if (_baseRabbit.breed.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              _baseRabbit.breed,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: appColor(0xFF55555C),
              ),
            ),
          ],
          if ((_baseRabbit.earNumber ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Ear #: ${_baseRabbit.earNumber}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: appColor(0xFF8E8E93),
              ),
            ),
          ] else if (_baseRabbit.id.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'ID: ${_baseRabbit.id}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: appColor(0xFF8E8E93),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildParentCard({
    required String label,
    required Rabbit? rabbit,
    required bool isMale,
    required VoidCallback onTap,
  }) {
    final Gradient cardGradient = isMale
        ? LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [appSurface(0xFF86DAFF), appSurface(0xFFF0F9FF)],
          )
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [appSurface(0xFFFFBCE7), appSurface(0xFFFFF0F9)],
          );

    final bool hasDetails = rabbit != null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: cardGradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isMale ? appSurface(0xFFBFE0F7) : appSurface(0xFFF7B4DE),
            width: 0.8,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: appColor(0xFF55555C),
                    letterSpacing: 1.4,
                  ),
                ),
                Icon(
                  hasDetails ? Icons.edit : Icons.add_circle_outline,
                  size: 14,
                  color: appColor(0xFF55555C).withValues(alpha: 0.6),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!hasDetails) ...[
              Text(
                isMale ? 'Add Sire' : 'Add Dam',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: appColor(0xFF55555C),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Tap to select',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: appColor(0xFF8E8E93),
                ),
              ),
            ] else ...[
              RichText(
                text: TextSpan(
                  children: [
                    if ((rabbit.breederPrefix ?? '').isNotEmpty)
                      TextSpan(
                        text: '${rabbit.breederPrefix} ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: appColor(0xFF2C2C2E),
                        ),
                      ),
                    TextSpan(
                      text: rabbit.name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: appColor(0xFF2C2C2E),
                      ),
                    ),
                  ],
                ),
              ),
              if (rabbit.breed.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  rabbit.breed,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: appColor(0xFF55555C),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if ((rabbit.earNumber ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Ear #: ${rabbit.earNumber}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: appColor(0xFF8E8E93),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ] else if (rabbit.id.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'ID: ${rabbit.id}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: appColor(0xFF8E8E93),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAncestorCol(Rabbit? parent, String label, Rabbit? sire, Rabbit? dam) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSubLabel(label),
        _buildBaseCard(
          name: sire?.name ?? 'Sire',
          id: sire?.id ?? '--',
          borderColor: kBlueDeep,
          isSmall: true,
          onTap: () => _updateGrandparent(parent, RabbitType.buck, label.contains('Sire') ? 'Sire\'s Paternal Sire' : 'Dam\'s Paternal Sire'),
        ),
        const SizedBox(height: 6),
        _buildBaseCard(
          name: dam?.name ?? 'Dam',
          id: dam?.id ?? '--',
          borderColor: kPinkDeep,
          isSmall: true,
          onTap: () => _updateGrandparent(parent, RabbitType.doe, label.contains('Sire') ? 'Sire\'s Paternal Dam' : 'Dam\'s Paternal Dam'),
        ),
      ],
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: appColor(0xFF4F4F56), letterSpacing: 0.8),
      ),
    );
  }

  Widget _buildSubLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: appColor(0xFF55555C), letterSpacing: 0.3),
      ),
    );
  }

  Widget _buildBaseCard({
    required String name,
    required String id,
    String? breed,
    Color? color,
    required Color borderColor,
    bool isFullBorder = false,
    bool isSmall = false,
    VoidCallback? onTap,
    bool showEditIcon = true,
  }) {
    final isPlaceholder = name.contains('Sire') || name.contains('Dam') || id.contains('Add');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isSmall ? 10 : 12),
        decoration: BoxDecoration(
          color: color ?? (isPlaceholder ? appSurface(0xFFF9F9FB).withValues(alpha: 0.5) : appSurface(0xFFFAFAFA)),
          borderRadius: BorderRadius.circular(12),
          border: isFullBorder
              ? Border.all(color: borderColor, width: 1.5)
              : Border(left: BorderSide(color: borderColor, width: 3)),
          boxShadow: [
            if (!isPlaceholder) BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontSize: isSmall ? 12 : 14,
                      fontWeight: FontWeight.w800,
                      color: isPlaceholder ? appColor(0xFF787880) : appColor(0xFF2C2C2E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isPlaceholder && showEditIcon) Icon(Icons.edit, size: 10, color: appColor(0xFF787880).withValues(alpha: 0.6)),
              ],
            ),
            Text(
              id,
              style: TextStyle(
                fontSize: isSmall ? 10 : 11,
                fontWeight: FontWeight.w600,
                color: isPlaceholder ? appColor(0xFFAEAEB2) : appColor(0xFF55555C),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (breed != null && !isSmall) ...[
              const SizedBox(height: 2),
              Text(
                breed,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: appColor(0xFF55555C)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}