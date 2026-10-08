import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/rabbit.dart';
import '../services/database_service.dart';
import '../services/format_utils.dart';
import '../constants/app_colors.dart';
import 'pedigree_layout.dart';
import 'pedigree_preview_modal.dart';

class PedigreeInlineCard extends StatefulWidget {
  final Rabbit rabbit;
  final VoidCallback? onUpdated;
  const PedigreeInlineCard({super.key, required this.rabbit, this.onUpdated});

  @override
  State<PedigreeInlineCard> createState() => _PedigreeInlineCardState();
}

class _PedigreeInlineCardState extends State<PedigreeInlineCard> {
  final DatabaseService _db = DatabaseService();
  int selectedGenerations = 4;
  bool _isLoading = true;
  Rabbit? _sire; 
  Rabbit? _dam;
  Rabbit? _ss, _sd, _ds, _dd;
  Rabbit? _sss, _ssd, _sds, _sdd, _dss, _dsd, _dds, _ddd;

  @override
  void initState() {
    super.initState();
    _loadPedigree();
  }

  Future<void> _loadPedigree() async {
    try {
      if (!mounted) return;
      setState(() => _isLoading = true);
      
      final tree = await _db.buildPedigreeTree(widget.rabbit.id, maxGenerations: selectedGenerations, initialRabbit: widget.rabbit);
      
      Rabbit? sire, dam, ss, sd, ds, dd;
      Rabbit? sss, ssd, sds, sdd, dss, dsd, dds, ddd;

      if (tree.sire != null) sire = await _db.getRabbit(tree.sire!.id);
      if (tree.dam != null) dam = await _db.getRabbit(tree.dam!.id);
      
      // 3 generations loads grandparents (ss, sd, ds, dd)
      if (selectedGenerations >= 3) {
        if (tree.sire?.sire != null) ss = await _db.getRabbit(tree.sire!.sire!.id);
        if (tree.sire?.dam != null) sd = await _db.getRabbit(tree.sire!.dam!.id);
        if (tree.dam?.sire != null) ds = await _db.getRabbit(tree.dam!.sire!.id);
        if (tree.dam?.dam != null) dd = await _db.getRabbit(tree.dam!.dam!.id);
      }

      // 4 generations loads great grandparents
      if (selectedGenerations >= 4) {
        if (tree.sire?.sire?.sire != null) sss = await _db.getRabbit(tree.sire!.sire!.sire!.id);
        if (tree.sire?.sire?.dam != null) ssd = await _db.getRabbit(tree.sire!.sire!.dam!.id);
        if (tree.sire?.dam?.sire != null) sds = await _db.getRabbit(tree.sire!.dam!.sire!.id);
        if (tree.sire?.dam?.dam != null) sdd = await _db.getRabbit(tree.sire!.dam!.dam!.id);
        if (tree.dam?.sire?.sire != null) dss = await _db.getRabbit(tree.dam!.sire!.sire!.id);
        if (tree.dam?.sire?.dam != null) dsd = await _db.getRabbit(tree.dam!.sire!.dam!.id);
        if (tree.dam?.dam?.sire != null) dds = await _db.getRabbit(tree.dam!.dam!.sire!.id);
        if (tree.dam?.dam?.dam != null) ddd = await _db.getRabbit(tree.dam!.dam!.dam!.id);
      }
      
      if (mounted) {
        setState(() {
          _sire = sire; _dam = dam;
          _ss = ss; _sd = sd; _ds = ds; _dd = dd;
          _sss = sss; _ssd = ssd; _sds = sds; _sdd = sdd;
          _dss = dss; _dsd = dsd; _dds = dds; _ddd = ddd;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportPedigree() async {
    try {
      final data = await PedigreeData.fromRabbit(widget.rabbit, db: _db);
      if (mounted) {
        PedigreePreviewSheet.show(context, data);
      }
    } catch (e) {
      debugPrint('Error preparing pedigree export: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2, color: kPinkDeep));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kNeutral200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                const Text(
                  'PEDIGREE',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF4F4F56),
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                PopupMenuButton<int>(
                  offset: const Offset(0, 32),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onSelected: (val) {
                    setState(() {
                      selectedGenerations = val;
                      _loadPedigree();
                    });
                  },
                  itemBuilder: (context) => [2, 3, 4].map((g) => PopupMenuItem(
                    value: g,
                    child: Text('$g Generations', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  )).toList(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: kNeutral100,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Row(
                      children: [
                        Text('$selectedGenerations Generations', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                        const SizedBox(width: 4),
                        Icon(Icons.keyboard_arrow_down, size: 16, color: kNeutral500),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _exportPedigree,
                  borderRadius: BorderRadius.circular(100),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: kNeutral100, borderRadius: BorderRadius.circular(100)),
                    child: Row(
                      children: [
                        Icon(PhosphorIcons.downloadSimple(), size: 14, color: kNeutral600),
                        const SizedBox(width: 6),
                        const Text('Export', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kNeutral600)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: kNeutral100),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 _buildSubjectCard(),

                 if (selectedGenerations >= 2) ...[
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

                 if (selectedGenerations >= 3) ...[
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

                 if (selectedGenerations >= 4) ...[
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
         ],
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
                if ((widget.rabbit.breederPrefix ?? '').isNotEmpty)
                  TextSpan(
                    text: '${widget.rabbit.breederPrefix} ',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2C2C2E),
                    ),
                  ),
                TextSpan(
                  text: widget.rabbit.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2C2C2E),
                  ),
                ),
              ],
            ),
          ),
          if (widget.rabbit.breed.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              widget.rabbit.breed,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF55555C),
              ),
            ),
          ],
          if ((widget.rabbit.earNumber ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'Ear #: ${widget.rabbit.earNumber}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: Color(0xFF8E8E93),
              ),
            ),
          ] else if (widget.rabbit.id.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'ID: ${widget.rabbit.id}',
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

  Future<void> _updateParent(RabbitType gender, bool isPrimary) async {
    final label = gender == RabbitType.buck ? 'Sire' : 'Dam';
    _showParentPickerDialog(label, gender, (selectedRabbit) async {
      final updated = widget.rabbit;
      if (gender == RabbitType.buck) {
        updated.sireId = selectedRabbit?.id;
      } else {
        updated.damId = selectedRabbit?.id;
      }
      await _db.updateRabbit(updated);
      _loadPedigree();
      if (widget.onUpdated != null) widget.onUpdated!();
    });
  }

  Future<void> _updateGrandparent(Rabbit? parent, RabbitType gender, String label) async {
    if (parent == null) {
      _showError('Please add the ${label.contains("Sire's") ? "Sire" : "Dam"} first.');
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
      _loadPedigree();
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: kPinkDeep),
    );
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
        breed: widget.rabbit.breed,
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
          color: color ?? (isPlaceholder ? kNeutral50.withOpacity(0.5) : const Color(0xFFFAFAFA)),
          borderRadius: BorderRadius.circular(12),
          border: isFullBorder
              ? Border.all(color: borderColor, width: 1.5)
              : Border(left: BorderSide(color: borderColor, width: 3)),
          boxShadow: [
             if (!isPlaceholder) BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
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
              if (!isPlaceholder && showEditIcon) Icon(Icons.edit, size: 10, color: const Color(0xFF787880).withOpacity(0.6)),
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

class PedigreeEntryModal extends StatefulWidget {
  final String label;
  final RabbitType type;
  final List<Rabbit> options;
  final Function(Rabbit?) onSelect;
  final DatabaseService db;
  final String? breed;

  const PedigreeEntryModal({
    super.key,
    required this.label,
    required this.type,
    required this.options,
    required this.onSelect,
    required this.db,
    this.breed,
  });

  @override
  State<PedigreeEntryModal> createState() => _PedigreeEntryModalState();
}

class _PedigreeEntryModalState extends State<PedigreeEntryModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  
  // Search Controller for Herd Tab
  final _herdSearchController = TextEditingController();
  String _herdSearchQuery = '';

  // Manual Entry Controllers
  final _nameController = TextEditingController();
  final _colorController = TextEditingController();
  final _lbsController = TextEditingController();
  final _ozController = TextEditingController();
  final _idController = TextEditingController();
  final _regController = TextEditingController();
  final _gcController = TextEditingController();
  final _legsController = TextEditingController();
  final _breedController = TextEditingController();
  final _champController = TextEditingController();
  final _genotypeController = TextEditingController();
  
  DateTime? _dateOfBirth;
  DateTime? _acquiredDate;
  bool _isBroken = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    if ((widget.breed ?? '').isNotEmpty) {
      _breedController.text = widget.breed!;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _herdSearchController.dispose();
    _nameController.dispose();
    _colorController.dispose();
    _lbsController.dispose();
    _ozController.dispose();
    _idController.dispose();
    _regController.dispose();
    _gcController.dispose();
    _legsController.dispose();
    _breedController.dispose();
    _champController.dispose();
    _genotypeController.dispose();
    super.dispose();
  }

  List<Rabbit> get _filteredHerdOptions {
    if (_herdSearchQuery.trim().isEmpty) return widget.options;
    final q = _herdSearchQuery.trim().toLowerCase();
    return widget.options.where((r) {
      final name = r.name.toLowerCase();
      final prefix = (r.breederPrefix ?? '').toLowerCase();
      final ear = (r.earNumber ?? '').toLowerCase();
      final breed = r.breed.toLowerCase();
      final color = (r.color ?? '').toLowerCase();
      final cage = (r.cage ?? '').toLowerCase();
      return name.contains(q) ||
          prefix.contains(q) ||
          ear.contains(q) ||
          breed.contains(q) ||
          color.contains(q) ||
          cage.contains(q);
    }).toList();
  }

  Widget _buildRabbitNameWidget(Rabbit rabbit, {double fontSize = 15}) {
    final isDoe = rabbit.type == RabbitType.doe || widget.type == RabbitType.doe;
    final nameColor = isDoe ? const Color(0xFFE04F9F) : const Color(0xFF2196F3);
    final prefix = (rabbit.breederPrefix ?? '').trim();
    final name = rabbit.name.trim();
    final ear = (rabbit.earNumber?.trim().isNotEmpty == true
            ? rabbit.earNumber!.trim()
            : '')
        .toUpperCase();

    return Text.rich(
      TextSpan(
        children: [
          if (prefix.isNotEmpty)
            TextSpan(
              text: '$prefix ',
              style: const TextStyle(
                color: Color(0xFF787774),
                fontWeight: FontWeight.w700,
              ),
            ),
          TextSpan(
            text: name,
            style: TextStyle(
              color: nameColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (ear.isNotEmpty && !name.toUpperCase().endsWith(ear))
            TextSpan(
              text: ' $ear',
              style: const TextStyle(
                color: Color(0xFF787774),
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
      style: TextStyle(fontSize: fontSize),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(
        color: Color(0xFFF9F7FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Purple Top Banner matching Log Birth Modal
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            decoration: const BoxDecoration(
              color: Color(0xFFE6BEFE),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A3E6D).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Set ${widget.label}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4A3E6D),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, color: Color(0xFF4A3E6D), size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          TabBar(
            controller: _tabController,
            indicatorColor: const Color(0xFF6B2D6D),
            labelColor: const Color(0xFF6B2D6D),
            unselectedLabelColor: const Color(0xFF787880),
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            tabs: const [
              Tab(text: 'SELECT FROM HERD'),
              Tab(text: 'MANUAL ENTRY'),
            ],
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHerdTab(),
                _buildManualTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHerdTab() {
    final filtered = _filteredHerdOptions;

    return Column(
      children: [
        if (widget.options.length > 3)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: TextField(
              controller: _herdSearchController,
              onChanged: (val) => setState(() => _herdSearchQuery = val),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Search by name, prefix, ear #, breed...',
                hintStyle: const TextStyle(color: Color(0xFF9E9EA7), fontSize: 13.5),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF7B6BA0), size: 20),
                suffixIcon: _herdSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18, color: Color(0xFF7B6BA0)),
                        onPressed: () {
                          _herdSearchController.clear();
                          setState(() => _herdSearchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: const Color(0xFFF7F2FD),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFFEDE5FA)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5),
                ),
              ),
            ),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            itemCount: filtered.length + 1,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              if (index == 0) {
                return InkWell(
                  onTap: () {
                    Navigator.pop(context);
                    widget.onSelect(null);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF2F2F7),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E5EA)),
                    ),
                    child: const Text(
                      'Leave Blank',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Color(0xFF636366),
                      ),
                    ),
                  ),
                );
              }

              final rabbit = filtered[index - 1];
              final details = <String>[];
              if (rabbit.breed.isNotEmpty) details.add(rabbit.breed);
              if ((rabbit.color ?? '').isNotEmpty) details.add(rabbit.color!);
              if ((rabbit.cage ?? '').isNotEmpty) details.add('Cage: ${rabbit.cage}');

              return InkWell(
                onTap: () {
                  Navigator.pop(context);
                  widget.onSelect(rabbit);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5DEEC)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildRabbitNameWidget(rabbit, fontSize: 15),
                            if (details.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                details.join(' • '),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF787774),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildManualTab() {
    return Form(
      key: _formKey,
      child: ListView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5DEEC)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                _buildOutlinedField('Name', _nameController),
                const SizedBox(height: 14),

                // Breed
                _buildOutlinedField('Breed', _breedController),
                const SizedBox(height: 14),

                // Color
                _buildOutlinedField('Color', _colorController),
                const SizedBox(height: 14),

                // Weight (divided into 2 boxes: Pounds & Ounces with light grey hint text)
                Row(
                  children: [
                    Expanded(
                      child: _buildOutlinedField(
                        'Pounds',
                        _lbsController,
                        hintText: 'lbs',
                        isNumber: true,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildOutlinedField(
                        'Ounces',
                        _ozController,
                        hintText: 'oz',
                        isNumber: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Ear # | Date of Birth
                Row(
                  children: [
                    Expanded(child: _buildOutlinedField('Ear #', _idController)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDatePicker('Date of Birth', _dateOfBirth, (d) => setState(() => _dateOfBirth = d))),
                  ],
                ),
                const SizedBox(height: 14),

                // Legs | Reg # | GC #
                Row(
                  children: [
                    Expanded(flex: 1, child: _buildOutlinedField('Legs', _legsController, isNumber: true)),
                    const SizedBox(width: 8),
                    Expanded(flex: 1, child: _buildOutlinedField('Reg #', _regController)),
                    const SizedBox(width: 8),
                    Expanded(flex: 1, child: _buildOutlinedField('GC #', _gcController)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onSelect(null);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF636366),
                    side: const BorderSide(color: Color(0xFFDCDCE0)),
                    backgroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Leave Blank', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Color(0xFF636366))),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _saveManual,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kLilacLight,
                    foregroundColor: kLilacText,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Save Ancestor', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: kLilacText)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  void _saveManual() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name for the ancestor'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    
    final earNo = _idController.text.trim();
    final id = 'PED-${DateTime.now().millisecondsSinceEpoch}';
    final lbs = double.tryParse(_lbsController.text.trim()) ?? 0.0;
    final oz = double.tryParse(_ozController.text.trim()) ?? 0.0;
    final double? weight = (lbs > 0 || oz > 0) ? (lbs + (oz / 16.0)) : null;

    final newRabbit = Rabbit(
      id: id,
      name: _nameController.text.trim(),
      type: RabbitType.pedigree,
      status: RabbitStatus.archived,
      breed: _breedController.text.isNotEmpty ? _breedController.text.trim() : 'Dwarf Hotot',
      color: _colorController.text.isNotEmpty ? _colorController.text.trim() : null,
      weight: weight,
      dateOfBirth: _dateOfBirth,
      acquiredDate: _acquiredDate,
      earNumber: earNo.isNotEmpty ? earNo : null,
      registrationNumber: _regController.text.isNotEmpty ? _regController.text.trim() : null,
      grandChampionNumber: _gcController.text.isNotEmpty ? _gcController.text.trim() : null,
      grandChampionLegs: int.tryParse(_legsController.text) ?? 0,
      genetics: _genotypeController.text.isNotEmpty ? _genotypeController.text.trim() : null,
      broken: _isBroken,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await widget.db.insertRabbit(newRabbit);
    Navigator.pop(context);
    widget.onSelect(newRabbit);
  }

  Widget _buildOutlinedField(
    String label,
    TextEditingController controller, {
    bool isNumber = false,
    String? hintText,
  }) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4F4F56)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 13),
        floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 14),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintText: hintText,
        hintStyle: const TextStyle(color: Color(0xFF8E8E93), fontWeight: FontWeight.w500, fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5DEEC))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5)),
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime? value, Function(DateTime) onSelect) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (picked != null) onSelect(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 13),
          floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 14),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5DEEC))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, size: 16, color: Color(0xFF4F4F56)),
            const SizedBox(width: 8),
            Text(
              value != null ? FormatUtils.formatDate(value) : '',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4F4F56),
              ),
            ),
          ],
        ),
      ),
    );
  }
}