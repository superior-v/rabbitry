import 'package:flutter/material.dart';
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
      final data = await PedigreeData.fromRabbit(_baseRabbit, db: _db);
      if (mounted) {
        PedigreePreviewSheet.show(context, data);
      }
    } catch (e) {
      debugPrint('Error preparing pedigree export: $e');
    }
  }

  void _showParentPickerDialog(String label, RabbitType type, Function(Rabbit?) onSelect) async {
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
      ),
    );
  }

  Future<void> _updateParent(RabbitType gender, bool isPrimary) async {
    final label = gender == RabbitType.buck ? 'Sire' : 'Dam';
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
      await _db.insertRabbit(base);
      setState(() => _baseRabbit = base);
      _loadPedigreeData();
    });
  }

  Future<void> _updateGrandparent(Rabbit? parent, RabbitType gender, String label) async {
    if (parent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please add the ${label.contains("Sire") ? "Sire" : "Dam"} first.'),
          backgroundColor: kPinkDeep,
        ),
      );
      return;
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
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Color(0xFF1F2937), size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pedigree Chart',
          style: TextStyle(color: Color(0xFF1F2937), fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          PopupMenuButton<int>(
            offset: const Offset(0, 40),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (val) {
              setState(() {
                _generations = val;
                _loadPedigreeData();
              });
            },
            itemBuilder: (context) => [2, 3, 4].map((g) => PopupMenuItem(
              value: g,
              child: Text('$g Generations', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            )).toList(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              margin: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Row(
                children: [
                  Text('$_generations Generations', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, size: 16, color: Color(0xFF6B7280)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: Icon(PhosphorIcons.downloadSimple(), color: const Color(0xFF1F2937), size: 20),
            tooltip: 'Export Pedigree PDF',
            onPressed: _exportPedigree,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFD4809A)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E5EA)),
                ),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSubjectCard(),

                    if (_generations >= 2) ...[
                      const SizedBox(height: 20),
                      _buildLabel('PARENTS'),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildParentCard(
                              label: 'SIRE',
                              rabbit: _sire,
                              isMale: true,
                              onTap: () => _updateParent(RabbitType.buck, true),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildParentCard(
                              label: 'DAM',
                              rabbit: _dam,
                              isMale: false,
                              onTap: () => _updateParent(RabbitType.doe, true),
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (_generations >= 3) ...[
                      const SizedBox(height: 20),
                      _buildLabel('GRANDPARENTS'),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sire's Parents
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSubLabel('${_sire?.name ?? "Sire"}\'s parents'),
                                _buildBaseCard(
                                  name: _ss?.name ?? 'Sire\'s Sire',
                                  id: _ss?.id ?? '--',
                                  borderColor: kBlueDeep,
                                  isSmall: true,
                                  onTap: () => _updateGrandparent(_sire, RabbitType.buck, 'Sire\'s Sire'),
                                ),
                                const SizedBox(height: 8),
                                _buildBaseCard(
                                  name: _sd?.name ?? 'Sire\'s Dam',
                                  id: _sd?.id ?? '--',
                                  borderColor: kPinkDeep,
                                  isSmall: true,
                                  onTap: () => _updateGrandparent(_sire, RabbitType.doe, 'Sire\'s Dam'),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Dam's Parents
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSubLabel('${_dam?.name ?? "Dam"}\'s parents'),
                                _buildBaseCard(
                                  name: _ds?.name ?? 'Dam\'s Sire',
                                  id: _ds?.id ?? '--',
                                  borderColor: kBlueDeep,
                                  isSmall: true,
                                  onTap: () => _updateGrandparent(_dam, RabbitType.buck, 'Dam\'s Sire'),
                                ),
                                const SizedBox(height: 8),
                                _buildBaseCard(
                                  name: _dd?.name ?? 'Dam\'s Dam',
                                  id: _dd?.id ?? '--',
                                  borderColor: kPinkDeep,
                                  isSmall: true,
                                  onTap: () => _updateGrandparent(_dam, RabbitType.doe, 'Dam\'s Dam'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (_generations >= 4) ...[
                      const SizedBox(height: 20),
                      _buildLabel('GREAT-GRANDPARENTS'),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildAncestorCol(_ss, 'Sire\'s paternal', _sss, _ssd)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildAncestorCol(_sd, 'Sire\'s maternal', _sds, _sdd)),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildAncestorCol(_ds, 'Dam\'s paternal', _dss, _dsd)),
                          const SizedBox(width: 8),
                          Expanded(child: _buildAncestorCol(_dd, 'Dam\'s maternal', _dds, _ddd)),
                        ],
                      ),
                    ],
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
        border: Border.all(color: const Color(0xFFF7B4DE), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'SUBJECT',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Color(0xFF55555C),
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
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2C2C2E),
                    ),
                  ),
                TextSpan(
                  text: _baseRabbit.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2C2C2E),
                  ),
                ),
              ],
            ),
          ),
          if (_baseRabbit.breed.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              _baseRabbit.breed,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF55555C),
              ),
            ),
          ],
          if ((_baseRabbit.earNumber ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Ear #: ${_baseRabbit.earNumber}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Color(0xFF8E8E93),
              ),
            ),
          ] else if (_baseRabbit.id.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'ID: ${_baseRabbit.id}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Color(0xFF8E8E93),
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
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF86DAFF), Color(0xFFF0F9FF)],
          )
        : const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFBCE7), Color(0xFFFFF0F9)],
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
            color: isMale ? const Color(0xFFBFE0F7) : const Color(0xFFF7B4DE),
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
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF55555C),
                    letterSpacing: 1.4,
                  ),
                ),
                Icon(
                  hasDetails ? Icons.edit : Icons.add_circle_outline,
                  size: 14,
                  color: const Color(0xFF55555C).withValues(alpha: 0.6),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!hasDetails) ...[
              Text(
                isMale ? 'Add Sire' : 'Add Dam',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF55555C),
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Tap to select',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8E8E93),
                ),
              ),
            ] else ...[
              RichText(
                text: TextSpan(
                  children: [
                    if ((rabbit.breederPrefix ?? '').isNotEmpty)
                      TextSpan(
                        text: '${rabbit.breederPrefix} ',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2C2C2E),
                        ),
                      ),
                    TextSpan(
                      text: rabbit.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2C2C2E),
                      ),
                    ),
                  ],
                ),
              ),
              if (rabbit.breed.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  rabbit.breed,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF55555C),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if ((rabbit.earNumber ?? '').isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'Ear #: ${rabbit.earNumber}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF8E8E93),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ] else if (rabbit.id.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  'ID: ${rabbit.id}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF8E8E93),
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
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF4F4F56), letterSpacing: 0.8),
      ),
    );
  }

  Widget _buildSubLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: Color(0xFF55555C), letterSpacing: 0.3),
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
          color: color ?? (isPlaceholder ? const Color(0xFFF9F9FB).withValues(alpha: 0.5) : const Color(0xFFFAFAFA)),
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
                      color: isPlaceholder ? const Color(0xFF787880) : const Color(0xFF2C2C2E),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (!isPlaceholder && showEditIcon) Icon(Icons.edit, size: 10, color: const Color(0xFF787880).withValues(alpha: 0.6)),
              ],
            ),
            Text(
              id,
              style: TextStyle(
                fontSize: isSmall ? 10 : 11,
                fontWeight: FontWeight.w600,
                color: isPlaceholder ? const Color(0xFFAEAEB2) : const Color(0xFF55555C),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (breed != null && !isSmall) ...[
              const SizedBox(height: 2),
              Text(
                breed,
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF55555C)),
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
