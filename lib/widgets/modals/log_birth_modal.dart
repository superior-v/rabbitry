import 'package:flutter/material.dart';
import '../../models/rabbit.dart';
import '../../models/litter.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
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
    if (widget.existingLitter != null) {
      final l = widget.existingLitter!;
      _litterIdController.text = l.id;
      _kindleDate = l.dob ?? DateTime.now();
      _aliveBornController.text = l.totalKitsCount.toString();
      _totalBornController.text = (l.totalKitsCount + (l.deadKits ?? 0)).toString();
      _notesController.text = l.notes ?? '';
      _colorsProducedController.text = l.colorsProduced ?? '';
      _patternsProducedController.text = l.patternsProduced ?? '';
      _bucksProducedController.text = l.maleCount.toString();
      _doesProducedController.text = l.femaleCount.toString();
      
      // Calculate weight avg from kits if possible
      if (l.kits.isNotEmpty) {
        double totalW = 0;
        for (var k in l.kits) totalW += k.weight;
        _weightAvgController.text = (totalW / l.kits.length).toStringAsFixed(1);
        
        // Populate kit details for step 2
        _kitDetails = l.kits.map((k) => {
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

  void _initializeKitDetails() {
    final aliveBorn = int.tryParse(_aliveBornController.text) ?? 0;
    final avgWeight = double.tryParse(_weightAvgController.text) ?? 0.0;

    _kitDetails = List.generate(
        aliveBorn,
        (index) => {
              'id': 'K-${index + 1}',
              'sex': 'U', // Unknown
              'color': 'Unknown',
              'weight': avgWeight,
              'status': 'Nursing',
            });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: const BoxDecoration(
              color: kLilacWash,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: kLilacLight, width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.existingLitter != null 
                          ? (_currentStep == 1 ? 'Edit Birth Info' : 'Edit Kit Details')
                          : (_currentStep == 1 ? 'Log Birth (Kindle)' : 'Kit Details'),
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kLilacDeep, letterSpacing: -0.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.doe.name} • ${widget.doe.id}',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kLilacText),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: kLilacDeep),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: _currentStep == 1 ? _buildStep1() : _buildStep2(),
            ),
          ),

          // Bottom buttons
          Padding(
            padding: EdgeInsets.all(20),
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
                hint: 'e.g., L-011',
                prefixIcon: Icons.tag,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildDatePickerField(
                label: 'Birth Date',
                value: _kindleDate,
                onTap: () => _selectDate(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

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
                    Text('Doe did not successfully kindle', style: TextStyle(fontSize: 12, color: kNeutral600)),
                  ],
                ),
              ),
              Transform.scale(
                scale: 0.8,
                child: Switch(
                  value: _isMissedLitter,
                  activeColor: kLilacDeep,
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
        const SizedBox(height: 16),

        // Row 2: Total Born & Alive Kits
        Row(
          children: [
            Expanded(
              child: _buildOutlinedField(
                label: 'Total Kits Born',
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
                label: 'Alive Kits',
                controller: _aliveBornController,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Dead count alert
        if (_totalBornController.text.isNotEmpty && _aliveBornController.text.isNotEmpty)
          Builder(
            builder: (context) {
              final total = int.tryParse(_totalBornController.text) ?? 0;
              final alive = int.tryParse(_aliveBornController.text) ?? 0;
              final dead = total - alive;
              if (dead > 0) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kPinkWash,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kPinkLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: kPinkDeep, size: 18),
                      const SizedBox(width: 8),
                      Text('Dead kits reported: $dead', style: const TextStyle(fontSize: 12, color: kPinkDeep, fontWeight: FontWeight.w600)),
                    ],
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),

        // Summary Fields (Optional)
        if (!_isMissedLitter) ...[
          const Text('Litter Summary (optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kNeutral600, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildOutlinedField(
                  label: 'Bucks',
                  controller: _bucksProducedController,
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildOutlinedField(
                  label: 'Does',
                  controller: _doesProducedController,
                  keyboardType: TextInputType.number,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildOutlinedField(
            label: 'Colors Produced',
            controller: _colorsProducedController,
            hint: 'e.g., Black, Blue, Broken',
          ),
          const SizedBox(height: 12),
          _buildOutlinedField(
            label: 'Patterns Produced',
            controller: _patternsProducedController,
            hint: 'e.g., Solid',
          ),
          const SizedBox(height: 12),
          
          // Peanuts
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Peanuts Produced', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kNeutral700)),
              Container(
                decoration: BoxDecoration(color: kLilacWash, borderRadius: BorderRadius.circular(10), border: Border.all(color: kLilacLight)),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove, size: 18, color: kLilacDeep),
                      onPressed: () {
                         final current = int.tryParse(_peanutsProducedController.text) ?? 0;
                         if (current > 0) _peanutsProducedController.text = (current - 1).toString();
                         setState(() {});
                      },
                    ),
                    SizedBox(width: 20, child: Center(child: Text(_peanutsProducedController.text.isEmpty ? '0' : _peanutsProducedController.text, style: const TextStyle(fontWeight: FontWeight.w800, color: kLilacDeep)))),
                    IconButton(
                      icon: const Icon(Icons.add, size: 18, color: kLilacDeep),
                      onPressed: () {
                         final current = int.tryParse(_peanutsProducedController.text) ?? 0;
                         _peanutsProducedController.text = (current + 1).toString();
                         setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],

        // Weight & Notes
        _buildOutlinedField(
          label: 'Avg Kit Weight (g)',
          controller: _weightAvgController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          hint: 'e.g., 50',
        ),
        const SizedBox(height: 12),
        _buildOutlinedField(
          label: 'Notes (optional)',
          controller: _notesController,
          hint: 'Any observations...',
          maxLines: 2,
        ),
        const SizedBox(height: 20),
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
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      onChanged: onChanged,
      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kNeutral900),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: kLilacDeep, fontWeight: FontWeight.w700, fontSize: 14),
        hintText: hint,
        hintStyle: const TextStyle(color: kNeutral400, fontWeight: FontWeight.w400),
        prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: kLilacDeep, size: 18) : null,
        floatingLabelBehavior: FloatingLabelBehavior.always,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacLight)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacDeep, width: 1.5)),
        filled: true,
        fillColor: Colors.white,
      ),
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required DateTime value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: kLilacDeep, fontWeight: FontWeight.w700, fontSize: 14),
          floatingLabelBehavior: FloatingLabelBehavior.always,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: kLilacLight)),
          filled: true,
          fillColor: Colors.white,
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_rounded, color: kLilacDeep, size: 18),
            const SizedBox(width: 8),
            Text(
              '${value.day}/${value.month}/${value.year}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kNeutral900),
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
              const Icon(Icons.info_outline, color: kLilacDeep, size: 20),
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
                  color: kLilacDeep,
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
    Color activeBg = val == 'M' ? kBlueDeep : (val == 'F' ? kPinkDeep : kLilacDeep);
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
                side: const BorderSide(color: kLilacLight, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text(
                'Add Kit Details',
                style: TextStyle(color: kLilacDeep, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveBirth,
              style: ElevatedButton.styleFrom(
                backgroundColor: kLilacDeep,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5)),
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
                side: const BorderSide(color: kLilacLight, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: const Text(
                'Back',
                style: TextStyle(color: kLilacDeep, fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveBirth,
              style: ElevatedButton.styleFrom(
                backgroundColor: kLilacDeep,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              child: _isSaving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Log Birth', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 0.5)),
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

    _initializeKitDetails();
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

      if (widget.existingLitter != null) {
        // Prepare updated litter object
        final updatedLitter = widget.existingLitter!.copyWith(
          dob: _kindleDate,
          notes: _notesController.text,
          totalKits: int.tryParse(_totalBornController.text) ?? 0,
          aliveKits: int.tryParse(_aliveBornController.text) ?? 0,
          kits: _kitDetails.map((k) => Kit(
            id: k['id'],
            sex: k['sex'],
            color: k['color'],
            weight: k['weight'],
            status: k['status'],
          )).toList(),
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
