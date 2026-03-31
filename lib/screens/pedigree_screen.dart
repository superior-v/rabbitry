import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:uuid/uuid.dart';
import '../models/pedigree.dart';
import '../models/rabbit.dart';
import '../services/database_service.dart';
import '../constants/app_colors.dart';

// Colors matched to HTML reference
const Color _kBlueLeft = Color(0xFF5B8AD0);
const Color _kPurpleLeft = Color(0xFFB580C4);
const Color _kSubjectBorder = Color(0xFFD4809A);
const Color _kSubjectBg = Color(0xFFFDF2F5);

const Color _kNeutral50 = Color(0xFFF9F9FB);
const Color _kNeutral100 = Color(0xFFF3F4F6);
const Color _kNeutral200 = Color(0xFFE5E5EA);
const Color _kNeutral300 = Color(0xFFD1D1D6);
const Color _kNeutral400 = Color(0xFF9CA3AF);
const Color _kNeutral500 = Color(0xFF6B7280);
const Color _kNeutral700 = Color(0xFF374151);
const Color _kNeutral800 = Color(0xFF1F2937);

class PedigreeScreen extends StatefulWidget {
  final String rabbitId;

  const PedigreeScreen({super.key, required this.rabbitId});

  @override
  State<PedigreeScreen> createState() => _PedigreeScreenState();
}

class _PedigreeScreenState extends State<PedigreeScreen> {
  late Rabbit _baseRabbit;
  bool _isLoading = true;
  final DatabaseService _db = DatabaseService();
  int _generations = 3;

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
      final rabbit = await _db.getRabbit(widget.rabbitId);
      if (rabbit == null) return;
      _baseRabbit = rabbit;

      // Load 2nd Generation
      if (rabbit.sireId != null) _sire = await _db.getRabbit(rabbit.sireId!);
      if (rabbit.damId != null) _dam = await _db.getRabbit(rabbit.damId!);

      // Load 3rd Generation
      if (_sire?.sireId != null) _ss = await _db.getRabbit(_sire!.sireId!);
      if (_sire?.damId != null) _sd = await _db.getRabbit(_sire!.damId!);
      if (_dam?.sireId != null) _ds = await _db.getRabbit(_dam!.sireId!);
      if (_dam?.damId != null) _dd = await _db.getRabbit(_dam!.damId!);

      // Load 4th Generation if needed
      if (_generations >= 4) {
        if (_ss?.sireId != null) _sss = await _db.getRabbit(_ss!.sireId!);
        if (_ss?.damId != null) _ssd = await _db.getRabbit(_ss!.damId!);
        if (_sd?.sireId != null) _sds = await _db.getRabbit(_sd!.sireId!);
        if (_sd?.damId != null) _sdd = await _db.getRabbit(_sd!.damId!);
        if (_ds?.sireId != null) _dss = await _db.getRabbit(_ds!.sireId!);
        if (_ds?.damId != null) _dsd = await _db.getRabbit(_ds!.damId!);
        if (_dds?.sireId != null) _dds = await _db.getRabbit(_dd!.sireId!);
        if (_dd?.damId != null) _ddd = await _db.getRabbit(_dd!.damId!);
      }

      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleSaveAncestor(String parentId, String role, String name, String breed) async {
    if (name.trim().isEmpty) return;
    try {
      final parent = await _db.getRabbit(parentId);
      if (parent == null) return;

      final newId = const Uuid().v4();
      final newRabbit = Rabbit(
        id: newId,
        name: name.trim(),
        breed: breed.trim(),
        type: RabbitType.pedigree,
        status: RabbitStatus.archived,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _db.insertRabbit(newRabbit);

      if (role == 'sire') {
        parent.sireId = newId;
      } else {
        parent.damId = newId;
      }
      await _db.insertRabbit(parent);

      _loadPedigreeData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ancestor linked'), backgroundColor: Color(0xFF6366F1), duration: Duration(seconds: 1)),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: _kNeutral800, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pedigree Chart',
          style: TextStyle(color: _kNeutral800, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        actions: [
          _GenToggle(
            value: _generations,
            onChanged: (v) {
              setState(() => _generations = v);
              _loadPedigreeData();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: _kSubjectBorder))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLevel('SUBJECT', [
                  _PedCard(
                    rabbit: _baseRabbit,
                    isSubject: true,
                    isMale: _baseRabbit.type == RabbitType.buck,
                    cardWidth: double.infinity,
                  )
                ], scrollable: false),
                _buildLevel('PARENTS', [
                  _PedCard(
                    rabbit: _sire,
                    isMale: true,
                    parentId: _baseRabbit.id,
                    role: 'sire',
                    onSave: _handleSaveAncestor,
                  ),
                  const SizedBox(width: 12),
                  _PedCard(
                    rabbit: _dam,
                    isMale: false,
                    parentId: _baseRabbit.id,
                    role: 'dam',
                    onSave: _handleSaveAncestor,
                  ),
                ]),
                _buildLevel('GRANDPARENTS', [
                  _PairGroup(
                    label: "${_sire?.name ?? "Sire"}'s parents",
                    top: _PedCard(
                      rabbit: _ss, 
                      isMale: true, 
                      parentId: _sire?.id, 
                      role: 'sire', 
                      onSave: _handleSaveAncestor,
                      isCompact: true,
                    ),
                    bottom: _PedCard(
                      rabbit: _sd, 
                      isMale: false, 
                      parentId: _sire?.id, 
                      role: 'dam', 
                      onSave: _handleSaveAncestor,
                      isCompact: true,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _PairGroup(
                    label: "${_dam?.name ?? "Dam"}'s parents",
                    top: _PedCard(
                      rabbit: _ds, 
                      isMale: true, 
                      parentId: _dam?.id, 
                      role: 'sire', 
                      onSave: _handleSaveAncestor,
                      isCompact: true,
                    ),
                    bottom: _PedCard(
                      rabbit: _dd, 
                      isMale: false, 
                      parentId: _dam?.id, 
                      role: 'dam', 
                      onSave: _handleSaveAncestor,
                      isCompact: true,
                    ),
                  ),
                ]),
                if (_generations >= 4)
                  _buildLevel('G-GRANDPARENTS', [
                     // Simplified 4th gen for space
                     _PairGroup(
                       label: "Sire's paternal",
                       top: _PedCard(rabbit: _sss, isMale: true, isCompact: true, role: 'sire', parentId: _ss?.id, onSave: _handleSaveAncestor),
                       bottom: _PedCard(rabbit: _ssd, isMale: false, isCompact: true, role: 'dam', parentId: _ss?.id, onSave: _handleSaveAncestor),
                     ),
                     const SizedBox(width: 8),
                     _PairGroup(
                       label: "Sire's maternal",
                       top: _PedCard(rabbit: _sds, isMale: true, isCompact: true, role: 'sire', parentId: _sd?.id, onSave: _handleSaveAncestor),
                       bottom: _PedCard(rabbit: _sdd, isMale: false, isCompact: true, role: 'dam', parentId: _sd?.id, onSave: _handleSaveAncestor),
                     ),
                     const SizedBox(width: 8),
                     _PairGroup(
                       label: "Dam's paternal",
                       top: _PedCard(rabbit: _dss, isMale: true, isCompact: true, role: 'sire', parentId: _ds?.id, onSave: _handleSaveAncestor),
                       bottom: _PedCard(rabbit: _dsd, isMale: false, isCompact: true, role: 'dam', parentId: _ds?.id, onSave: _handleSaveAncestor),
                     ),
                     const SizedBox(width: 8),
                     _PairGroup(
                       label: "Dam's maternal",
                       top: _PedCard(rabbit: _dds, isMale: true, isCompact: true, role: 'sire', parentId: _dd?.id, onSave: _handleSaveAncestor),
                       bottom: _PedCard(rabbit: _ddd, isMale: false, isCompact: true, role: 'dam', parentId: _dd?.id, onSave: _handleSaveAncestor),
                     ),
                  ]),

                const SizedBox(height: 40),
                // Export/Print Actions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _kNeutral50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kNeutral100),
                  ),
                  child: Row(
                    children: [
                      _ActionButton(icon: PhosphorIcons.filePdf(), label: 'Export PDF', color: Color(0xFFD44C47)),
                      const SizedBox(width: 12),
                      _ActionButton(icon: PhosphorIcons.printer(), label: 'Print Chart', color: Color(0xFF6B7280)),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildLevel(String title, List<Widget> cards, {bool scrollable = true}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 12),
          child: Text(
            title,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _kNeutral400, letterSpacing: 1.0),
          ),
        ),
        if (scrollable)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            child: Row(children: cards),
          )
        else
          Row(children: cards),
      ],
    );
  }
}

class _PedCard extends StatefulWidget {
  final Rabbit? rabbit;
  final bool isSubject;
  final bool isMale;
  final bool isCompact;
  final double? cardWidth;
  
  // Persistence hooks
  final String? parentId;
  final String? role;
  final Function(String, String, String, String)? onSave;

  const _PedCard({
    this.rabbit,
    this.isSubject = false,
    required this.isMale,
    this.isCompact = false,
    this.cardWidth,
    this.parentId,
    this.role,
    this.onSave,
  });

  @override
  State<_PedCard> createState() => _PedCardState();
}

class _PedCardState extends State<_PedCard> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _breedCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final isEmpty = widget.rabbit == null;
    final width = widget.cardWidth ?? (widget.isCompact ? 130.0 : 160.0);

    if (isEmpty) {
      return Container(
        width: width,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _kNeutral200, style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            _buildInput("Name...", _nameCtrl),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: _buildInput("Breed...", _breedCtrl)),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    if (widget.parentId != null && widget.role != null) {
                      widget.onSave!(widget.parentId!, widget.role!, _nameCtrl.text, _breedCtrl.text);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: _kSubjectBg, borderRadius: BorderRadius.circular(4)),
                    child: const Icon(Icons.check, size: 16, color: _kSubjectBorder),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final Color sideBarColor = widget.isMale ? _kBlueLeft : _kPurpleLeft;

    return Container(
      width: width,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isSubject ? _kSubjectBg : const Color(0xFFFAFAFA),
        borderRadius: BorderRadius.circular(12),
        border: widget.isSubject 
          ? Border.all(color: _kSubjectBorder, width: 2)
          : Border(
              top: BorderSide(color: _kNeutral200),
              right: BorderSide(color: _kNeutral200),
              bottom: BorderSide(color: _kNeutral200),
              left: BorderSide(color: sideBarColor, width: 4),
            ),
        boxShadow: widget.isSubject ? [
          BoxShadow(color: _kSubjectBorder.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
        ] : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.rabbit!.name,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _kNeutral800, height: 1.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!widget.isSubject) 
                Icon(widget.isMale ? Icons.male : Icons.female, size: 14, color: sideBarColor.withOpacity(0.5)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            widget.rabbit!.earNumber ?? (widget.rabbit!.id.length > 8 ? widget.rabbit!.id.substring(0, 8) : widget.rabbit!.id),
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _kNeutral400),
          ),
          const SizedBox(height: 4),
          Text(
            widget.rabbit!.breed,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: _kNeutral500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInput(String hint, TextEditingController ctrl) {
    return SizedBox(
      height: 28,
      child: TextField(
        controller: ctrl,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _kNeutral800),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 11, color: _kNeutral400),
          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
          filled: true,
          fillColor: Colors.white,
          isDense: true,
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _kNeutral200)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _kSubjectBorder)),
        ),
      ),
    );
  }
}

class _PairGroup extends StatelessWidget {
  final String label;
  final Widget top;
  final Widget bottom;

  const _PairGroup({required this.label, required this.top, required this.bottom});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kNeutral100),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              label,
          await _loadPedigreeData();
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Profile picture updated successfully'), backgroundColor: Color(0xFF6366F1)));
        }
      } catch (e) {
        print('Error updating photo: $e');
        setState(() => _isLoading = false);
      }
    }
  } on PlatformException catch (e) {
      print('Platform Exception: ${e.code} - ${e.message}');

      String errorMessage = 'Failed to pick image';

      if (e.code == 'camera_access_denied') {
        errorMessage = 'Camera permission denied. Please enable it in settings.';
      } else if (e.code == 'photo_access_denied') {
        errorMessage = 'Photo library permission denied. Please enable it in settings.';
      } else if (e.message?.contains('channel') ?? false) {
        errorMessage = 'Camera/Gallery not available. Please check permissions.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Color(0xFFD44C47),
          action: SnackBarAction(
            label: 'Settings',
            textColor: Colors.white,
            onPressed: () => openAppSettings(),
          ),
        ),
      );
    } catch (e) {
      print('General Exception: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An error occurred: $e'),
          backgroundColor: Color(0xFFD44C47),
        ),
      );
    }
  }

  void _updateRabbitProfileImage(PedigreeRabbit rabbit, String? imagePath) {
    setState(() {
      rabbit.updateProfileImage(imagePath);
      // Force UI rebuild
    });

    // In production, save to database here
    // Example: _saveToDatabase(rabbit);
  }

  void _editAncestor(PedigreeRabbit? current, String? childId, bool isSire) {
    if (childId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Cannot add parent to unknown child')));
      return;
    }

    final TextEditingController nameController = TextEditingController(text: (current != null && current.name != 'Unknown') ? current.name : '');
    final TextEditingController idController = TextEditingController(text: (current != null && current.name != 'Unknown') ? current.id : '');
    final TextEditingController breedController = TextEditingController(text: (current != null && current.name != 'Unknown') ? current.breed : '');
    final TextEditingController colorController = TextEditingController(text: (current != null && current.name != 'Unknown') ? current.color : '');
    final TextEditingController regController = TextEditingController(text: (current != null && current.name != 'Unknown') ? current.registrationNumber : '');

    bool isExternal = current?.isExternal ?? true;
    Rabbit? selectedHerdRabbit;
    List<Rabbit> herdOptions = [];
    bool optionsLoaded = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          if (!optionsLoaded) {
            _db.getAllRabbits().then((all) {
              if (mounted) {
                setModalState(() {
                  herdOptions = all.where((r) => (isSire ? r.type == RabbitType.buck : r.type == RabbitType.doe) && r.id != childId).toList();
                  optionsLoaded = true;
                });
              }
            });
          }

          return Container(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isEmpty(current) ? 'Add ${isSire ? 'Sire' : 'Dam'}' : 'Edit ${isSire ? 'Sire' : 'Dam'}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                    ],
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Color(0xFFF7F7F5), borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        _buildTabButton('Search Herd', !isExternal, () => setModalState(() => isExternal = false)),
                        _buildTabButton('Manual Entry', isExternal, () => setModalState(() => isExternal = true)),
                      ],
                    ),
                  ),
                  SizedBox(height: 20),
                  if (!isExternal) ...[
                    Text('Select from Herd', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF787774))),
                    SizedBox(height: 6),
                    DropdownButtonFormField<Rabbit>(
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Color(0xFFF7F7F5),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      hint: Text('Choose a rabbit'),
                      value: selectedHerdRabbit,
                      items: herdOptions.map((r) => DropdownMenuItem(value: r, child: Text('${r.name} (${r.id})'))).toList(),
                      onChanged: (val) {
                        setModalState(() {
                          selectedHerdRabbit = val;
                          if (val != null) {
                            nameController.text = val.name;
                            idController.text = val.id;
                            breedController.text = val.breed;
                            colorController.text = val.color ?? '';
                          }
                        });
                      },
                    ),
                    SizedBox(height: 16),
                  ],
                  _buildTextField('Name', nameController),
                  SizedBox(height: 12),
                  if (isExternal) ...[
                    _buildTextField('ID / Ear Tag', idController),
                    SizedBox(height: 12),
                  ],
                  _buildTextField('Breed', breedController),
                  SizedBox(height: 12),
                  _buildTextField('Color', colorController),
                  SizedBox(height: 12),
                  _buildTextField('Registration #', regController),
                  SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _saveAncestorUpdate(childId, isSire, isExternal, selectedHerdRabbit, nameController.text, idController.text, breedController.text, colorController.text, regController.text),
                      style: ElevatedButton.styleFrom(backgroundColor: Color(0xFF6366F1), padding: EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: Text('Save Changes', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                  SizedBox(height: 20),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool isEmpty(PedigreeRabbit? r) => r == null || r.name == 'Unknown';

  Widget _buildTabButton(String label, bool isActive, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            boxShadow: isActive ? [BoxShadow(color: Colors.black12, blurRadius: 4)] : [],
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontWeight: isActive ? FontWeight.w600 : FontWeight.w400, color: isActive ? Color(0xFF6366F1) : Color(0xFF787774))),
        ),
      ),
    );
  }

  Future<void> _saveAncestorUpdate(String childId, bool isSire, bool isExternal, Rabbit? selectedHerd, String name, String id, String breed, String color, String reg) async {
    Navigator.pop(context);
    setState(() => _isLoading = true);

    try {
      String finalParentId = id;

      if (!isExternal && selectedHerd != null) {
        finalParentId = selectedHerd.id;
      } else if (isExternal) {
        // Create an external rabbit entry if it doesn't exist
        final existing = await _db.getRabbit(id);
        if (existing == null) {
          final newPedRabbit = Rabbit(
            id: id,
            name: name,
            type: RabbitType.pedigree,
            status: RabbitStatus.active,
            breed: breed,
            color: color,
            registrationNumber: reg,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await _db.insertRabbit(newPedRabbit);
        } else {
          // Update existing external rabbit
          final updated = existing.copyWith(name: name, breed: breed, color: color, registrationNumber: reg);
          await _db.updateRabbit(updated);
        }
      }

      // Link to child
      final child = await _db.getRabbit(childId);
      if (child != null) {
        final updatedChild = isSire ? child.copyWith(sireId: finalParentId) : child.copyWith(damId: finalParentId);
        await _db.updateRabbit(updatedChild);
      }

      await _loadPedigreeData();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pedigree updated successfully'), backgroundColor: Color(0xFF6366F1)));
    } catch (e) {
      print('Error updating ancestor: $e');
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to update pedigree'), backgroundColor: Color(0xFFD44C47)));
    }
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF787774),
          ),
        ),
        SizedBox(height: 6),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Enter $label',
            filled: true,
            fillColor: Color(0xFFF7F7F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFFE9E9E7)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFFE9E9E7)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Color(0xFF6366F1), width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }

  void _showAncestorMenu(PedigreeRabbit? rabbit) {
    if (rabbit == null || rabbit.name == 'Unknown') return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(rabbit.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                      Text(rabbit.id, style: TextStyle(fontSize: 14, color: Color(0xFF787774))),
                    ],
                  ),
                  Spacer(),
                  IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            _buildMenuOption(Icons.camera_alt, 'Change Photo', () {
              Navigator.pop(context);
              _changeProfilePicture(rabbit);
            }),
            _buildMenuOption(Icons.delete_outline, 'Remove from Pedigree', () {
              Navigator.pop(context);
              _confirmRemoveAncestor(rabbit);
            }, isDestructive: true),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemoveAncestor(PedigreeRabbit rabbit) async {
    final all = await _db.getAllRabbits();
    final children = all.where((r) => r.sireId == rabbit.id || r.damId == rabbit.id).toList();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove Ancestor'),
        content: Text('Are you sure you want to remove ${rabbit.name} from the pedigree? This only removes the link, it doesn\'t delete the record.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              for (var child in children) {
                final updated = child.sireId == rabbit.id ? child.copyWith(sireId: '') : child.copyWith(damId: '');
                await _db.updateRabbit(updated);
              }
              await _loadPedigreeData();
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Removed ${rabbit.name} from pedigree')));
            },
            child: Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuOption(IconData icon, String label, VoidCallback onTap, {bool isDestructive = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF7F7F5))),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Color(0xFFD44C47) : Color(0xFF787774),
              size: 22,
            ),
            SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: isDestructive ? Color(0xFFD44C47) : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _sharePedigree() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Share pedigree feature coming soon')),
    );
  }

  void _printPedigree() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Print pedigree feature coming soon')),
    );
  }

  void _exportPDF() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Export PDF feature coming soon')),
    );
  }
}

class TreeConnectorPainter extends CustomPainter {
  final int connections;

  TreeConnectorPainter({required this.connections});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Color(0xFFD1D5DB)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final centerY = size.height / 2;

    if (connections == 2) {
      final parent1Y = size.height * 0.25;
      final parent2Y = size.height * 0.75;

      canvas.drawLine(Offset(0, centerY), Offset(size.width / 2, centerY), paint);
      canvas.drawLine(Offset(size.width / 2, parent1Y), Offset(size.width / 2, parent2Y), paint);
      canvas.drawLine(Offset(size.width / 2, parent1Y), Offset(size.width, parent1Y), paint);
      canvas.drawLine(Offset(size.width / 2, parent2Y), Offset(size.width, parent2Y), paint);
    } else if (connections == 4) {
      final positions = [
        size.height * 0.125,
        size.height * 0.375,
        size.height * 0.625,
        size.height * 0.875,
      ];

      canvas.drawLine(Offset(0, positions[0]), Offset(0, positions[3]), paint);

      canvas.drawLine(Offset(0, positions[0]), Offset(size.width / 2, positions[0]), paint);
      canvas.drawLine(Offset(0, positions[1]), Offset(size.width / 2, positions[1]), paint);
      canvas.drawLine(Offset(size.width / 2, positions[0]), Offset(size.width / 2, positions[1]), paint);

      canvas.drawLine(Offset(0, positions[2]), Offset(size.width / 2, positions[2]), paint);
      canvas.drawLine(Offset(0, positions[3]), Offset(size.width / 2, positions[3]), paint);
      canvas.drawLine(Offset(size.width / 2, positions[2]), Offset(size.width / 2, positions[3]), paint);

      for (var y in positions) {
        canvas.drawLine(Offset(size.width / 2, y), Offset(size.width, y), paint);
      }
    } else if (connections == 8) {
      final positions = List.generate(8, (i) => size.height * ((i + 0.5) / 8));

      canvas.drawLine(Offset(0, positions.first), Offset(0, positions.last), paint);

      for (int group = 0; group < 4; group++) {
        final idx1 = group * 2;
        final idx2 = group * 2 + 1;

        canvas.drawLine(Offset(0, positions[idx1]), Offset(size.width / 2, positions[idx1]), paint);
        canvas.drawLine(Offset(0, positions[idx2]), Offset(size.width / 2, positions[idx2]), paint);
        canvas.drawLine(Offset(size.width / 2, positions[idx1]), Offset(size.width / 2, positions[idx2]), paint);

        canvas.drawLine(Offset(size.width / 2, positions[idx1]), Offset(size.width, positions[idx1]), paint);
        canvas.drawLine(Offset(size.width / 2, positions[idx2]), Offset(size.width, positions[idx2]), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
