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
                   showEditIcon: false,
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
                    color: isPlaceholder ? kNeutral400 : const Color(0xFF1F2937),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!isPlaceholder && showEditIcon) Icon(Icons.edit, size: 10, color: kNeutral400.withOpacity(0.5)),
            ],
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

class _PedigreeEntryModal extends StatefulWidget {
  final String label;
  final RabbitType type;
  final List<Rabbit> options;
  final Function(Rabbit) onSelect;
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
  final _idController = TextEditingController();
  final _breedController = TextEditingController();
  final _regController = TextEditingController();
  final _champController = TextEditingController();
  final _legsController = TextEditingController();
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
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: kNeutral200, borderRadius: BorderRadius.circular(2))),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Set ${widget.label}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1F2937)),
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

          TabBar(
            controller: _tabController,
            indicatorColor: widget.type == RabbitType.buck ? kBlueDeep : kPinkDeep,
            labelColor: widget.type == RabbitType.buck ? kBlueDeep : kPinkDeep,
            unselectedLabelColor: kNeutral500,
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
     if (widget.options.isEmpty) {
       return Center(
         child: Column(
           mainAxisAlignment: MainAxisAlignment.center,
           children: [
             Icon(PhosphorIcons.users(), size: 48, color: kNeutral200),
             const SizedBox(height: 16),
             Text('No active herd members', style: TextStyle(color: kNeutral400, fontWeight: FontWeight.w600)),
             const SizedBox(height: 16),
             TextButton(
               onPressed: () => _tabController.animateTo(1),
               child: Text('Add Manually Instead', style: TextStyle(color: widget.type == RabbitType.buck ? kBlueDeep : kPinkDeep, fontWeight: FontWeight.w700)),
             ),
           ],
         ),
       );
     }

     return ListView.separated(
       padding: const EdgeInsets.all(20),
       itemCount: widget.options.length,
       separatorBuilder: (context, index) => const Divider(height: 1),
       itemBuilder: (context, index) {
         final rabbit = widget.options[index];
         return ListTile(
            title: Text(rabbit.name, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${rabbit.breed} • ${rabbit.id}'),
            trailing: const Icon(Icons.chevron_right, size: 16),
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
        padding: const EdgeInsets.all(24),
        children: [
          _buildTextField('NAME', _nameController, hint: 'e.g. Blue Moon'),
          const SizedBox(height: 16),
          _buildTextField('ID / EAR #', _idController, hint: 'e.g. BM-001'),
          const SizedBox(height: 16),
          _buildTextField('BREED', _breedController, hint: 'e.g. Netherland Dwarf'),
          const SizedBox(height: 24),
          
          Row(
            children: [
              Expanded(child: _buildDatePicker('BORN', _dateOfBirth, (d) => setState(() => _dateOfBirth = d))),
              const SizedBox(width: 16),
              Expanded(child: _buildDatePicker('ACQUIRED', _acquiredDate, (d) => setState(() => _acquiredDate = d))),
            ],
          ),
          const SizedBox(height: 24),
          
          Row(
            children: [
              const Text('SEX', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kNeutral500)),
              const Spacer(),
              _buildSexToggle(),
            ],
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(child: _buildTextField('REG #', _regController, hint: 'Optional')),
              const SizedBox(width: 16),
              Expanded(child: _buildTextField('CHAMP #', _champController, hint: 'Optional')),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
             children: [
               Expanded(child: _buildTextField('LEGS', _legsController, hint: '0', isNumber: true)),
               const SizedBox(width: 16),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     const Text('BROKEN', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kNeutral500)),
                     CheckboxListTile(
                       value: _isBroken,
                       onChanged: (val) => setState(() => _isBroken = val ?? false),
                       title: const Text('Broken Pattern', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                       contentPadding: EdgeInsets.zero,
                       controlAffinity: ListTileControlAffinity.leading,
                       dense: true,
                     ),
                   ],
                 ),
               ),
             ],
          ),
          const SizedBox(height: 16),
          _buildTextField('GENETICS / GENOTYPE', _genotypeController, hint: 'e.g. aa B- C- D- E-'),
          
          const SizedBox(height: 40),
          ElevatedButton(
            onPressed: _saveManual,
            style: ElevatedButton.styleFrom(
              backgroundColor: widget.type == RabbitType.buck ? kBlueDeep : kPinkDeep,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: const Text('Save Ancestor', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
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
    
    final id = _idController.text.isNotEmpty ? _idController.text : 'PED-${DateTime.now().millisecondsSinceEpoch}';
    
    final newRabbit = Rabbit(
      id: id,
      name: _nameController.text,
      type: _gender,
      status: RabbitStatus.inactive, // Pedigree entries are inactive/non-herd
      breed: _breedController.text.isNotEmpty ? _breedController.text : 'Unknown',
      dateOfBirth: _dateOfBirth,
      acquiredDate: _acquiredDate,
      registrationNumber: _regController.text,
      grandChampionNumber: _champController.text,
      grandChampionLegs: int.tryParse(_legsController.text) ?? 0,
      genetics: _genotypeController.text,
      broken: _isBroken,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await widget.db.insertRabbit(newRabbit);
    Navigator.pop(context);
    widget.onSelect(newRabbit);
  }

  Widget _buildTextField(String label, TextEditingController controller, {String? hint, bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kNeutral500, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: kNeutral400, fontWeight: FontWeight.normal),
            filled: true,
            fillColor: kNeutral50,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker(String label, DateTime? value, Function(DateTime) onSelect) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kNeutral500)),
        const SizedBox(height: 8),
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: value ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime.now(),
            );
            if (picked != null) onSelect(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(color: kNeutral50, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: kNeutral400),
                const SizedBox(width: 8),
                Text(
                  value != null ? "${value.day}/${value.month}/${value.year}" : 'Select Date',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: value != null ? kNeutral800 : kNeutral400),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSexToggle() {
    return Container(
      decoration: BoxDecoration(color: kNeutral100, borderRadius: BorderRadius.circular(100)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSexBtn('Buck', RabbitType.buck),
          _buildSexBtn('Doe', RabbitType.doe),
        ],
      ),
    );
  }

  Widget _buildSexBtn(String label, RabbitType type) {
    final active = _gender == type;
    final activeColor = type == RabbitType.buck ? kBlueDeep : kPinkDeep;
    return GestureDetector(
      onTap: () => setState(() => _gender = type),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: active ? activeColor : Colors.transparent,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: active ? Colors.white : kNeutral500),
        ),
      ),
    );
  }
}