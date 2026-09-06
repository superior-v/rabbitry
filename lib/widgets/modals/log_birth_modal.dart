import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/rabbit.dart';
import '../../models/litter.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
import '../../services/app_event_service.dart';
import '../../constants/app_colors.dart';

class LogBirthModal extends StatefulWidget {
  final Rabbit doe;
  final Litter? existingLitter;
  final VoidCallback onComplete;

  const LogBirthModal({
    Key? key,
    required this.doe,
    this.existingLitter,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<LogBirthModal> createState() => _LogBirthModalState();
}

class _LogBirthModalState extends State<LogBirthModal> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _litterIdController = TextEditingController();
  final TextEditingController _totalBornController = TextEditingController();
  final TextEditingController _aliveBornController = TextEditingController();
  final TextEditingController _weightAvgController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _colorsProducedController = TextEditingController();
  final TextEditingController _patternsProducedController = TextEditingController();
  final TextEditingController _bucksProducedController = TextEditingController();
  final TextEditingController _doesProducedController = TextEditingController();
  final TextEditingController _peanutsProducedController = TextEditingController();
  DateTime _kindleDate = DateTime.now();
  bool _isSaving = false;
  bool _isMissedLitter = false;
  String? _buckName;

  // ✅ Step management
  int _currentStep = 1; // 1 = Basic info, 2 = Kit details
  List<Map<String, dynamic>> _kitDetails = [];

  // ✅ Color options
  List<String> get _colorOptions {
    final colors = SettingsService.instance.colors;
    if (!colors.contains('Unknown')) {
      return [...colors, 'Unknown'];
    }
    return colors;
  }

  @override
  void initState() {
    super.initState();
    _buckName = null;
    if (widget.doe.lastBreedBuckId != null) {
      _db.getRabbit(widget.doe.lastBreedBuckId!).then((buck) {
        if (buck != null && mounted) {
          setState(() {
            _buckName = buck.name;
          });
        }
      });
    }
    if (widget.existingLitter != null) {
      final l = widget.existingLitter!;
      _litterIdController.text = l.id;
      _kindleDate = l.dob ?? DateTime.now();
      // Use stored aliveKits / totalKits fields (fallback to computed counts)
      final aliveCount = l.aliveKits ?? l.totalKitsCount;
      final totalCount = l.totalKits ?? (aliveCount + (l.deadKits ?? 0));
      _aliveBornController.text = aliveCount.toString();
      _totalBornController.text = totalCount.toString();
      _notesController.text = l.notes ?? '';
      _colorsProducedController.text = l.colorsProduced ?? '';
      _patternsProducedController.text = l.patternsProduced ?? '';
      _bucksProducedController.text = l.maleCount.toString();
      _doesProducedController.text = l.femaleCount.toString();
      
      // Only include non-archived kits in the editable detail list
      final activeKits = l.kits.where((k) => !k.isArchived).toList();
      // Calculate weight avg from active kits
      if (activeKits.isNotEmpty) {
        double totalW = activeKits.fold(0.0, (sum, k) => sum + k.weight);
        _weightAvgController.text = (totalW / activeKits.length).toStringAsFixed(1);
        
        // Populate kit details for step 2 (only active kits)
        _kitDetails = activeKits.map((k) => {
          'id': k.id,
          'sex': k.sex,
          'color': k.color,
          'weight': k.weight,
          'status': k.status,
          'imagePath': k.imagePath,
        }).toList();
      }
    } else {
      _loadNextLitterId();
    }
  }

  Future<void> _loadNextLitterId() async {
    final nextId = await _db.getNextLitterId();
    setState(() {
      _litterIdController.text = nextId;
    });
  }

  @override
  void dispose() {
    _litterIdController.dispose();
    _totalBornController.dispose();
    _aliveBornController.dispose();
    _weightAvgController.dispose();
    _notesController.dispose();
    _colorsProducedController.dispose();
    _patternsProducedController.dispose();
    _bucksProducedController.dispose();
    _doesProducedController.dispose();
    _peanutsProducedController.dispose();
    super.dispose();
  }

  void _adjustKitDetailsToMatchAliveBorn() {
    final aliveBorn = int.tryParse(_aliveBornController.text) ?? 0;
    final avgWeight = double.tryParse(_weightAvgController.text) ?? 0.0;

    if (_kitDetails.length < aliveBorn) {
      final startCount = _kitDetails.length;
      final newKits = List.generate(
        aliveBorn - startCount,
        (index) => {
          'id': 'K-${startCount + index + 1}',
          'sex': 'U',
          'color': 'Unknown',
          'weight': avgWeight,
          'status': 'Nursing',
        },
      );
      _kitDetails.addAll(newKits);
    } else if (_kitDetails.length > aliveBorn) {
      _kitDetails = _kitDetails.sublist(0, aliveBorn);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: const BoxDecoration(
              color: kLilacLight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: kLilac, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'LOG BIRTH',
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kLilacText, letterSpacing: 0.5),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${widget.doe.name} (${widget.doe.id})',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kLilacText),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: kLilacText),
                      onPressed: () => Navigator.pop(context),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        _buckName != null
                            ? 'Sire: $_buckName'
                            : (widget.doe.lastBreedBuckId != null ? 'Sire: ${widget.doe.lastBreedBuckId}' : 'Sire: Unknown'),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kLilacText),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Birth Date: ${DateFormat('MM/dd/yyyy').format(_kindleDate)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kLilacText),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Content
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
              child: _currentStep == 1 ? _buildStep1() : _buildStep2(),
            ),
          ),
          // Bottom buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: _buildBottomButtons(),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Row 1: Litter ID & Birth Date
        Row(
          children: [
            Expanded(
              child: _buildOutlinedField(
                label: 'Litter ID',
                controller: _litterIdController,
                prefixIcon: Icons.tag,
                textColor: kNeutral500,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDatePickerField(
                label: 'Birth Date',
                value: _kindleDate,
                onTap: () => _selectDate(context),
                textColor: kNeutral500,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (!_isMissedLitter) ...[
          // Row 2: Kits Born & Kits Alive
          Row(
            children: [
              Expanded(
                child: _buildOutlinedField(
                  label: 'Kits Born',
                  controller: _totalBornController,
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    if (_aliveBornController.text.isEmpty) {
                      _aliveBornController.text = value;
                    }
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOutlinedField(
                  label: 'Kits Alive',
                  controller: _aliveBornController,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Row 3: Does & Bucks
          Row(
            children: [
              Expanded(
                child: _buildOutlinedField(
                  label: 'Does',
                  controller: _doesProducedController,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOutlinedField(
                  label: 'Bucks',
                  controller: _bucksProducedController,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Purple Container Card for Colors, Patterns, Peanuts, Notes, Avg Weight
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: kLilacWash,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kLilacLight),
            ),
            child: Column(
              children: [
                _buildOutlinedField(
                  label: 'Colors',
                  controller: _colorsProducedController,
                ),
                const SizedBox(height: 10),
                _buildOutlinedField(
                  label: 'Patterns',
                  controller: _patternsProducedController,
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildOutlinedField(
                        label: 'Peanuts',
                        controller: _peanutsProducedController,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildOutlinedField(
                        label: 'Avg Kit Weight',
                        controller: _weightAvgController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                _buildOutlinedField(
                  label: 'Notes',
                  controller: _notesController,
                  maxLines: 1,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],

        // Missed Litter Toggle
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: kLilacWash,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kLilacLight),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Missed Litter', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kLilacText)),
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: _isMissedLitter,
                  activeColor: const Color(0xFF7B6BA0),
                  onChanged: (val) {
                    setState(() {
                      _isMissedLitter = val;
                      if (val) {
                        _totalBornController.text = '0';
                        _aliveBornController.text = '0';
                      }
                    });
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  // ✅ Helper widgets for the new themed layout
  Widget _buildOutlinedField({
    required String label,
    required TextEditingController controller,
    String? hint,
    IconData? prefixIcon,
    TextInputType? keyboardType,
    int maxLines = 1,
    Function(String)? onChanged,
    Color textColor = kNeutral900,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Color(0xFF7B6BA0), fontWeight: FontWeight.w700, fontSize: 16),
        hintText: hint,
        hintStyle: const TextStyle(color: kNeutral400, fontWeight: FontWeight.w400),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: const Color(0xFF7B6BA0), size: 18) : null,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacLight)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF7B6BA0), width: 1.5)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
    Color textColor = kNeutral900,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF7B6BA0), fontWeight: FontWeight.w700, fontSize: 16),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacLight)),
          filled: true,
          fillColor: Colors.white,
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, color: Color(0xFF7B6BA0), size: 18),
            const SizedBox(width: 8),
            Text(
              DateFormat('MM-dd-yyyy').format(value),
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Color(0xFFF7EDE3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Color(0xFF7B6BA0).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: Color(0xFF7B6BA0), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Add details for each kit. You can skip and update later.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF7B6BA0)),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        ..._kitDetails.asMap().entries.map((entry) {
          final index = entry.key;
          final kit = entry.value;
          return _buildKitCard(index, kit);
        }).toList(),
        SizedBox(height: 20),
      ],
    );
  }

  Widget _buildKitCard(int index, Map<String, dynamic> kit) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Color(0xFFF7F7F5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Color(0xFFE9E9E7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF7B6BA0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Kit ${kit['id']}',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
          SizedBox(height: 16),

          // Sex selector
          Text('Sex', style: TextStyle(fontSize: 13, color: Color(0xFF787774))),
          SizedBox(height: 8),
          Row(
            children: [
              _buildSexChip('M', 'Male', kit['sex'] == 'M', () {
                setState(() => _kitDetails[index]['sex'] = 'M');
              }),
              SizedBox(width: 8),
              _buildSexChip('F', 'Female', kit['sex'] == 'F', () {
                setState(() => _kitDetails[index]['sex'] = 'F');
              }),
              SizedBox(width: 8),
              _buildSexChip('U', 'Unknown', kit['sex'] == 'U', () {
                setState(() => _kitDetails[index]['sex'] = 'U');
              }),
            ],
          ),
          SizedBox(height: 16),

          // Color dropdown
          Text('Color', style: TextStyle(fontSize: 13, color: Color(0xFF787774))),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              border: Border.all(color: Color(0xFFE2E8F0)),
              borderRadius: BorderRadius.circular(12),
              color: Colors.white,
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: kit['color'],
                items: _colorOptions.map((color) {
                  return DropdownMenuItem(value: color, child: Text(color));
                }).toList(),
                onChanged: (value) {
                  setState(() => _kitDetails[index]['color'] = value);
                },
              ),
            ),
          ),
          SizedBox(height: 16),

          // Weight
          Text('Weight (g)', style: TextStyle(fontSize: 13, color: Color(0xFF787774))),
          SizedBox(height: 8),
          TextField(
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: 'e.g., 50',
              hintStyle: const TextStyle(color: Color(0xFFCCCBC8)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE9E9E7))),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            controller: TextEditingController(text: kit['weight'].toString()),
            onChanged: (value) {
              _kitDetails[index]['weight'] = double.tryParse(value) ?? 0.0;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSexChip(String val, String label, bool isActive, VoidCallback onTap) {
    Color activeBg = val == 'M' ? kBlueDeep : (val == 'F' ? kPinkDeep : const Color(0xFF7B6BA0));
    Color activeText = Colors.white;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: isActive ? activeBg : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isActive ? activeBg : kNeutral300),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? activeText : kNeutral600,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomButtons() {
    if (_currentStep == 1) {
      return Row(
        children: [
          Expanded(
            flex: 2,
            child: OutlinedButton(
              onPressed: _isMissedLitter ? null : _validateAndProceed,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: kLilac, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text(
                'Add Kit Details',
                style: TextStyle(color: kLilacText, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.5),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveBirth,
              style: ElevatedButton.styleFrom(
                backgroundColor: kLilacLight,
                foregroundColor: kLilacText,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kLilacText))
                  : const Text('SAVE', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.5, color: kLilacText)),
            ),
          ),
        ],
      );
    } else {
      return Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => setState(() => _currentStep = 1),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: const BorderSide(color: kLilac, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text(
                'Back',
                style: TextStyle(color: kLilacText, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.5),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveBirth,
              style: ElevatedButton.styleFrom(
                backgroundColor: kLilacLight,
                foregroundColor: kLilacText,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: kLilacText))
                  : const Text('LOG BIRTH', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 0.5, color: kLilacText)),
            ),
          ),
        ],
      );
    }
  }

  void _validateAndProceed() {
    final totalBorn = int.tryParse(_totalBornController.text);
    final aliveBorn = int.tryParse(_aliveBornController.text);

    if (_litterIdController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter a Litter ID'), backgroundColor: Colors.red),
      );
      return;
    }

    if (totalBorn == null || aliveBorn == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please enter valid numbers'), backgroundColor: Colors.red),
      );
      return;
    }

    if (aliveBorn > totalBorn) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Alive kits cannot exceed total born'), backgroundColor: Colors.red),
      );
      return;
    }

    _adjustKitDetailsToMatchAliveBorn();
    setState(() => _currentStep = 2);
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _kindleDate,
      firstDate: DateTime.now().subtract(Duration(days: 7)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _kindleDate = picked);
    }
  }

  Future<void> _saveBirth() async {
    final totalBorn = int.tryParse(_totalBornController.text) ?? 0;
    final aliveBorn = int.tryParse(_aliveBornController.text) ?? 0;

    setState(() => _isSaving = true);

    try {
      await SettingsService.instance.init();
      final weaningWeeks = 8;

      _adjustKitDetailsToMatchAliveBorn();

      if (widget.existingLitter != null) {
        // Build updated active kits from the detail form
        final updatedActiveKits = _kitDetails.map((k) => Kit(
          id: k['id'] ?? '',
          sex: k['sex'] ?? 'U',
          color: k['color'] ?? 'Unknown',
          weight: (k['weight'] as num?)?.toDouble() ?? 0.0,
          status: k['status'] ?? 'Nursing',
          imagePath: k['imagePath'] as String?,
        )).toList();

        // Preserve archived kits (sold, butchered, dead) that were filtered out
        final archivedKits = widget.existingLitter!.kits
            .where((k) => k.isArchived)
            .toList();

        // Combine: updated active kits + archived kits preserved
        final allKits = [...updatedActiveKits, ...archivedKits];

        // Prepare updated litter object
        final updatedLitter = widget.existingLitter!.copyWith(
          dob: _kindleDate,
          notes: _notesController.text,
          totalKits: int.tryParse(_totalBornController.text) ?? 0,
          aliveKits: int.tryParse(_aliveBornController.text) ?? 0,
          kits: allKits,
          colorsProduced: _colorsProducedController.text,
          patternsProduced: _patternsProducedController.text,
          bucksProduced: int.tryParse(_bucksProducedController.text) ?? 0,
          doesProduced: int.tryParse(_doesProducedController.text) ?? 0,
          deadKits: (int.tryParse(_totalBornController.text) ?? 0) - (int.tryParse(_aliveBornController.text) ?? 0),
        );
        await _db.updateLitter(updatedLitter);
      } else {
        await _db.logBirth(
          widget.doe.id,
          totalBorn,
          aliveBorn,
          _kindleDate,
          weaningWeeks,
          litterId: _litterIdController.text.trim(),
          kits: _kitDetails,
          missedLitter: _isMissedLitter,
          colorsProduced: _colorsProducedController.text,
          patternsProduced: _patternsProducedController.text,
          bucksProduced: int.tryParse(_bucksProducedController.text),
          doesProduced: int.tryParse(_doesProducedController.text),
          peanutsProduced: int.tryParse(_peanutsProducedController.text),
        );
      }

      notifyDataChanged();
      Navigator.pop(context);
      widget.onComplete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.existingLitter != null 
            ? 'Litter ${_litterIdController.text} updated successfully'
            : 'Birth logged: ${_litterIdController.text} with $aliveBorn kits'),
          backgroundColor: kPinkDeep,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }
}
