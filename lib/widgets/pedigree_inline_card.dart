import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/rabbit.dart';
import '../models/pedigree.dart';
import '../services/database_service.dart';
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
      
      final tree = await _db.buildPedigreeTree(widget.rabbit.id, maxGenerations: selectedGenerations - 1);
      
      // We still map these for easier access in build()
      Rabbit? sire, dam, ss, sd, ds, dd;
      Rabbit? sss, ssd, sds, sdd, dss, dsd, dds, ddd;

      if (tree.sire != null) sire = await _db.getRabbit(tree.sire!.id);
      if (tree.dam != null) dam = await _db.getRabbit(tree.dam!.id);
      
      if (selectedGenerations >= 3) {
        if (tree.sire?.sire != null) ss = await _db.getRabbit(tree.sire!.sire!.id);
        if (tree.sire?.dam != null) sd = await _db.getRabbit(tree.sire!.dam!.id);
        if (tree.dam?.sire != null) ds = await _db.getRabbit(tree.dam!.sire!.id);
        if (tree.dam?.dam != null) dd = await _db.getRabbit(tree.dam!.dam!.id);
      }

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
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(PhosphorIcons.treeStructure(PhosphorIconsStyle.bold), size: 16, color: kNeutral500),
                    const SizedBox(width: 8),
                    const Text(
                      'PEDIGREE',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kNeutral500, letterSpacing: 0.6),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('$selectedGenerations', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF1F2937), height: 1)),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text('generations visibility', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kNeutral500)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Generations Selector
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
                    const Spacer(),
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
              ],
            ),
          ),

          const Divider(height: 1, color: kNeutral100),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 const SizedBox(height: 16),
                 _buildLabel('SUBJECT'),
                 _buildBaseCard(
                   name: widget.rabbit.name,
                   id: widget.rabbit.id,
                   breed: widget.rabbit.breed ?? '--',
                   color: _washColor,
                   borderColor: _primaryColor.withOpacity(0.5),
                   isFullBorder: true,
                   onTap: () {}, // Subject is not editable here
                 ),

                 if (selectedGenerations >= 2) ...[
                   const SizedBox(height: 24),
                   _buildLabel('PARENTS'),
                   Row(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Expanded(
                         child: _buildBaseCard(
                           name: _sire?.name ?? 'Sire',
                           id: _sire?.id ?? 'Add Buck',
                           breed: _sire?.breed ?? '--',
                           borderColor: kBlueDeep,
                           onTap: () => _updateParent(RabbitType.buck, true),
                         ),
                       ),
                       const SizedBox(width: 12),
                       Expanded(
                         child: _buildBaseCard(
                           name: _dam?.name ?? 'Dam',
                           id: _dam?.id ?? 'Add Doe',
                           breed: _dam?.breed ?? '--',
                           borderColor: kPinkDeep,
                           onTap: () => _updateParent(RabbitType.doe, true),
                         ),
                       ),
                     ],
                   ),
                 ],

                 if (selectedGenerations >= 3) ...[
                   const SizedBox(height: 24),
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
                    const SizedBox(height: 24),
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
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: kNeutral400, letterSpacing: 0.8),
      ),
    );
  }

  Widget _buildSubLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        text,
        style: TextStyle(fontSize: 8, fontWeight: FontWeight.w600, color: kNeutral400, letterSpacing: 0.3),
      ),
    );
  }

  Future<void> _updateParent(RabbitType gender, bool isPrimary) async {
    final label = gender == RabbitType.buck ? 'Sire' : 'Dam';
    _showParentPickerDialog(label, gender, (selectedRabbit) async {
      final updated = widget.rabbit;
      if (gender == RabbitType.buck) {
        updated.sireId = selectedRabbit.id;
      } else {
        updated.damId = selectedRabbit.id;
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
        updatedParent.sireId = selectedRabbit.id;
      } else {
        updatedParent.damId = selectedRabbit.id;
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

  void _showParentPickerDialog(String label, RabbitType type, Function(Rabbit) onSelect) async {
    final options = await _db.getRabbitsByType(type);
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: kNeutral200, borderRadius: BorderRadius.circular(2))),
            
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Select $label',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1F2937)),
                      ),
                      const SizedBox(height: 2),
                      Text('Choose from herd or add new', style: TextStyle(fontSize: 13, color: kNeutral500, fontWeight: FontWeight.w500)),
                    ],
                  ),
                  IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: kNeutral100, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 18, color: kNeutral600),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            Expanded(
              child: options.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(PhosphorIcons.users(), size: 48, color: kNeutral200),
                          const SizedBox(height: 16),
                          Text(
                            'No ${type == RabbitType.buck ? "Bucks" : "Does"} in herd',
                            style: TextStyle(color: kNeutral400, fontWeight: FontWeight.w600, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text('Add ancestors to build your pedigree', style: TextStyle(color: kNeutral300, fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: options.length,
                      separatorBuilder: (context, index) => const Divider(height: 1, color: kNeutral100),
                      itemBuilder: (context, index) {
                        final rabbit = options[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          leading: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: type == RabbitType.buck ? kBlueWash : kPinkWash,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              rabbit.name.isNotEmpty ? rabbit.name[0].toUpperCase() : '?',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: type == RabbitType.buck ? kBlueDeep : kPinkDeep,
                              ),
                            ),
                          ),
                          title: Text(
                            rabbit.name,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF1F2937)),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              '${rabbit.breed} • ${rabbit.id}',
                              style: TextStyle(color: kNeutral500, fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          onTap: () {
                            Navigator.pop(context);
                            onSelect(rabbit);
                          },
                        );
                      },
                    ),
            ),

            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(context);
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AddRabbitScreen()),
                        );
                        if (result == true) {
                          _loadPedigree();
                          if (widget.onUpdated != null) widget.onUpdated!();
                        }
                      },
                      icon: const Icon(Icons.add_rounded, size: 20, color: Colors.white),
                      label: const Text('Add New to Herd', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: type == RabbitType.buck ? kBlueDeep : kPinkDeep,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
        ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: isSmall ? 12 : 14,
              fontWeight: FontWeight.w800,
              color: isPlaceholder ? kNeutral400 : const Color(0xFF1F2937),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            id,
            style: TextStyle(
              fontSize: isSmall ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: isPlaceholder ? kNeutral300 : kNeutral400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (breed != null && !isSmall) ...[
            const SizedBox(height: 2),
            Text(
              breed,
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: kNeutral400),
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