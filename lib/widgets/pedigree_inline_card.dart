import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/rabbit.dart';
import '../models/pedigree.dart';
import '../services/database_service.dart';
import '../services/format_utils.dart';
import '../constants/app_colors.dart';
import '../screens/add_rabbit_screen.dart';

class PedigreeInlineCard extends StatefulWidget {
  final Rabbit rabbit;
  final VoidCallback? onUpdated;
  const PedigreeInlineCard({Key? key, required this.rabbit, this.onUpdated}) : super(key: key);

  @override
  State<PedigreeInlineCard> createState() => _PedigreeInlineCardState();
}

class _PedigreeInlineCardState extends State<PedigreeInlineCard> {
  final DatabaseService _db = DatabaseService();
  int selectedGenerations = 3;
  bool _isLoading = true;
  PedigreeRabbit? _tree;
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
      
      final tree = await _db.buildPedigreeTree(widget.rabbit.id, maxGenerations: selectedGenerations);
      
      Rabbit? sire, dam, ss, sd, ds, dd;
      Rabbit? sss, ssd, sds, sdd, dss, dsd, dds, ddd;

      if (tree.sire != null) sire = await _db.getRabbit(tree.sire!.id);
      if (tree.dam != null) dam = await _db.getRabbit(tree.dam!.id);
      
      // 2 generations always loads grandparents (ss, sd, ds, dd)
      if (tree.sire?.sire != null) ss = await _db.getRabbit(tree.sire!.sire!.id);
      if (tree.sire?.dam != null) sd = await _db.getRabbit(tree.sire!.dam!.id);
      if (tree.dam?.sire != null) ds = await _db.getRabbit(tree.dam!.sire!.id);
      if (tree.dam?.dam != null) dd = await _db.getRabbit(tree.dam!.dam!.id);

      // 3 generations also loads great grandparents
      if (selectedGenerations >= 3) {
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
          _tree = tree;
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

  Color get _primaryColor => widget.rabbit.type == RabbitType.buck ? kBlueDeep : kPinkDeep;
  Color get _washColor => widget.rabbit.type == RabbitType.buck ? kBlueWash : kPinkWash;

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
                  itemBuilder: (context) => [2, 3].map((g) => PopupMenuItem(
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
                Container(
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

                 if (selectedGenerations >= 3) ...[
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
      builder: (context) => _PedigreeEntryModal(
        label: label,
        type: type,
        options: options,
        onSelect: onSelect,
        db: _db,
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

class _PedigreeEntryModal extends StatefulWidget {
  final String label;
  final RabbitType type;
  final List<Rabbit> options;
  final Function(Rabbit?) onSelect;
  final DatabaseService db;

  const _PedigreeEntryModal({
    required this.label,
    required this.type,
    required this.options,
    required this.onSelect,
    required this.db,
  });

  @override
  State<_PedigreeEntryModal> createState() => _PedigreeEntryModalState();
}

class _PedigreeEntryModalState extends State<_PedigreeEntryModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _formKey = GlobalKey<FormState>();
  
  // Manual Entry Controllers
  final _nameController = TextEditingController();
  final _colorController = TextEditingController();
  final _weightController = TextEditingController();
  final _idController = TextEditingController();
  final _regController = TextEditingController();
  final _gcController = TextEditingController();
  final _legsController = TextEditingController();
  final _breedController = TextEditingController();
  final _champController = TextEditingController();
  final _genotypeController = TextEditingController();
  
  DateTime? _dateOfBirth;
  DateTime? _acquiredDate;
  late RabbitType _gender;
  bool _isBroken = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _gender = widget.type;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            widget.onSelect(null);
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            'Leave Blank',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
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
     return ListView.separated(
       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
       itemCount: widget.options.length + 1,
       separatorBuilder: (context, index) => const Divider(height: 1, color: Color(0xFFE5DEEC)),
       itemBuilder: (context, index) {
         if (index == 0) {
           return ListTile(
             contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
             leading: Container(
               width: 38,
               height: 38,
               decoration: BoxDecoration(
                 color: Colors.red.shade50,
                 shape: BoxShape.circle,
                 border: Border.all(color: Colors.red.shade200),
               ),
               child: Icon(Icons.block, color: Colors.red.shade700, size: 18),
             ),
             title: Text(
               'None (Leave Blank)',
               style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Colors.red.shade700),
             ),
             subtitle: Text(
               'Clear ${widget.label.toLowerCase()} and leave this field blank',
               style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
             ),
             trailing: const Icon(Icons.chevron_right, size: 18, color: Color(0xFF94A3B8)),
             onTap: () {
               Navigator.pop(context);
               widget.onSelect(null);
             },
           );
         }

         final rabbit = widget.options[index - 1];
         final breedStr = (rabbit.breed != null && rabbit.breed!.isNotEmpty) ? rabbit.breed! : 'Dwarf Hotot';
         final earStr = (rabbit.earNumber != null && rabbit.earNumber!.isNotEmpty) ? rabbit.earNumber! : '-';
         final idStr = rabbit.id.length > 8 ? rabbit.id.substring(0, 8).toUpperCase() : rabbit.id.toUpperCase();

         return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            title: Text(
              rabbit.fullName,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF334155)),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                'Breed: $breedStr • Ear: $earStr • ID: $idStr',
                style: const TextStyle(fontSize: 12.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
              ),
            ),
            trailing: const Icon(Icons.chevron_right, size: 18, color: Color(0xFF94A3B8)),
            onTap: () {
              Navigator.pop(context);
              widget.onSelect(rabbit);
            },
         );
       },
     );
  }

  Widget _buildManualTab() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
                // NAME
                _buildOutlinedField('NAME', _nameController, hint: 'e.g. Bella'),
                const SizedBox(height: 14),

                // BREED
                _buildOutlinedField('BREED', _breedController, hint: 'e.g. Dwarf Hotot'),
                const SizedBox(height: 14),

                // Color | Weight
                Row(
                  children: [
                    Expanded(child: _buildOutlinedField('Color', _colorController, hint: 'e.g. Black')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildOutlinedField('Weight', _weightController, hint: 'e.g. 3.5', isNumber: true)),
                  ],
                ),
                const SizedBox(height: 14),

                // EAR # | BORN
                Row(
                  children: [
                    Expanded(child: _buildOutlinedField('EAR #', _idController, hint: 'e.g. L01')),
                    const SizedBox(width: 12),
                    Expanded(child: _buildDatePicker('BORN', _dateOfBirth, (d) => setState(() => _dateOfBirth = d))),
                  ],
                ),
                const SizedBox(height: 14),

                // LEGS | REG # | GC #
                Row(
                  children: [
                    Expanded(flex: 1, child: _buildOutlinedField('LEGS', _legsController, isNumber: true)),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: _buildOutlinedField('REG #', _regController)),
                    const SizedBox(width: 10),
                    Expanded(flex: 2, child: _buildOutlinedField('GC #', _gcController)),
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
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Leave Blank', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: _saveManual,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B2D6D),
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: const Text('Save Ancestor', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
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
    final weight = double.tryParse(_weightController.text);

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

  Widget _buildOutlinedField(String label, TextEditingController controller, {String? hint, bool isNumber = false}) {
    return TextField(
      controller: controller,
      keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF4F4F56)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 13),
        floatingLabelStyle: const TextStyle(color: Color(0xFF4F4F56), fontWeight: FontWeight.w600, fontSize: 14),
        floatingLabelBehavior: FloatingLabelBehavior.always,
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w400, fontSize: 13),
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
              value != null ? FormatUtils.formatDate(value) : 'Select Date',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: value != null ? const Color(0xFF4F4F56) : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}