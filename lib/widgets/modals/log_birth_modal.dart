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
          Padding(
            padding: EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.existingLitter != null 
                        ? (_currentStep == 1 ? 'Edit Birth Info' : 'Edit Kit Details')
                        : (_currentStep == 1 ? 'Log Birth (Kindle)' : 'Kit Details'),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${widget.doe.name} (${widget.doe.id}) • Step $_currentStep of 2',
                      style: TextStyle(fontSize: 14, color: Color(0xFF787774)),
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 20),
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
        // ✅ Litter ID
        Text(
          'Litter ID',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8),
        TextField(
          controller: _litterIdController,
          decoration: InputDecoration(
            hintText: 'e.g., L-001',
            hintStyle: TextStyle(color: Color(0xFFCCCBC8)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFFE9E9E7))),
            prefixIcon: Icon(Icons.tag, color: Color(0xFF787774)),
          ),
        ),
        SizedBox(height: 20),

        // Kindle Date
        Text(
          'Birth Date',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8),
        InkWell(
          onTap: () => _selectDate(context),
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(color: Color(0xFFE9E9E7)),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: Color(0xFF787774)),
                SizedBox(width: 12),
                Text('${_kindleDate.day}/${_kindleDate.month}/${_kindleDate.year}'),
              ],
            ),
          ),
        ),
        SizedBox(height: 20),

        // Missed Litter Toggle
        SwitchListTile(
          title: Text('Missed Litter', style: TextStyle(fontWeight: FontWeight.w600)),
          subtitle: Text('Enable if the doe did not successfully kindle'),
          value: _isMissedLitter,
          onChanged: (val) {
            setState(() {
              _isMissedLitter = val;
              if (val) {
                _totalBornController.text = '0';
                _aliveBornController.text = '0';
              }
            });
          },
          contentPadding: EdgeInsets.zero,
          activeColor: kPinkDeep,
        ),
        SizedBox(height: 16),

        // Total Born
        Text(
          'Total Kits Born',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8),
        TextField(
          controller: _totalBornController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Enter total kits',
            hintStyle: TextStyle(color: Color(0xFFCCCBC8)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFFE9E9E7))),
          ),
          onChanged: (value) {
            if (_aliveBornController.text.isEmpty) {
              _aliveBornController.text = value;
            }
            setState(() {});
          },
        ),
        SizedBox(height: 20),

        // Alive Born
        Text(
          'Alive Kits',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8),
        TextField(
          controller: _aliveBornController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText: 'Enter alive kits',
            hintStyle: TextStyle(color: Color(0xFFCCCBC8)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFFE9E9E7))),
          ),
          onChanged: (_) => setState(() {}),
        ),
        SizedBox(height: 16),

        // Dead count display
        if (_totalBornController.text.isNotEmpty && _aliveBornController.text.isNotEmpty)
          Builder(
            builder: (context) {
              final total = int.tryParse(_totalBornController.text) ?? 0;
              final alive = int.tryParse(_aliveBornController.text) ?? 0;
              final dead = total - alive;
              if (dead > 0) {
                return Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFEBEE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Color(0xFFD32F2F), size: 20),
                      SizedBox(width: 8),
                      Text('Dead kits: $dead', style: TextStyle(fontSize: 14, color: Color(0xFFD32F2F))),
                    ],
                  ),
                );
              }
              return SizedBox.shrink();
            },
          ),
        if (!_isMissedLitter) SizedBox(height: 16),

        // Summary Fields
        if (!_isMissedLitter) ...[
          Text('Litter Summary (optional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _bucksProducedController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Bucks',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _doesProducedController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Does',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          TextField(
            controller: _colorsProducedController,
            decoration: InputDecoration(
              labelText: 'Colors Produced',
              labelStyle: TextStyle(color: Color(0xFFCCCBC8)),
              hintText: 'e.g., Black, Blue, Broken',
              hintStyle: TextStyle(color: Color(0xFFCCCBC8)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFFE9E9E7))),
            ),
          ),
          SizedBox(height: 12),
          TextField(
            controller: _patternsProducedController,
            decoration: InputDecoration(
              labelText: 'Patterns Produced',
              labelStyle: TextStyle(color: Color(0xFFBBB9B2), fontSize: 13),
              hintText: 'e.g., Solid',
              hintStyle: TextStyle(color: Color(0xFFCCCBC8)),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFFE9E9E7))),
            ),
          ),
          SizedBox(height: 12),
          // Peanuts
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Peanuts Produced', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              Container(
                decoration: BoxDecoration(color: Color(0xFFF7F7F5), borderRadius: BorderRadius.circular(10)),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove, size: 18),
                      onPressed: () {
                         final current = int.tryParse(_peanutsProducedController.text) ?? 0;
                         if (current > 0) _peanutsProducedController.text = (current - 1).toString();
                         setState(() {});
                      },
                    ),
                    SizedBox(child: Text(_peanutsProducedController.text.isEmpty ? '0' : _peanutsProducedController.text, style: TextStyle(fontWeight: FontWeight.bold))),
                    IconButton(
                      icon: Icon(Icons.add, size: 18),
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
          SizedBox(height: 16),
        ],

        // Weight Average
        Text(
          'Average Kit Weight (optional)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8),
        TextField(
          controller: _weightAvgController,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: 'e.g., 50',
            hintStyle: TextStyle(color: Color(0xFFCCCBC8)),
            suffixText: 'g',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFFE9E9E7))),
          ),
        ),
        SizedBox(height: 16),

        // Notes
        Text(
          'Notes (optional)',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        SizedBox(height: 8),
        TextField(
          controller: _notesController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: 'Any observations about the birth...',
            hintStyle: TextStyle(color: Color(0xFFCCCBC8)),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Color(0xFFE9E9E7))),
          ),
        ),
        SizedBox(height: 20),
      ],
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
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Color(0xFF6366F1).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: kPinkDeep, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Add details for each kit. You can skip and update later.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6366F1)),
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
                  color: kPinkDeep,
                  borderRadius: BorderRadius.circular(8),
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
              borderRadius: BorderRadius.circular(8),
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

  Widget _buildSexChip(String value, String label, bool isSelected, VoidCallback onTap) {
    Color activeColor = kNeutral700;
    if (value == 'M') activeColor = kMaleColor;
    if (value == 'F') activeColor = kFemaleColor;
    if (value == 'U') activeColor = kLilacDeep;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? activeColor : Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Color(0xFF64748B),
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
                padding: EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Add Kit Details', style: TextStyle(color: kPinkDeep, fontWeight: FontWeight.w600)),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveBirth,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPinkDeep,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
                padding: EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Back', style: TextStyle(color: Color(0xFF64748B))),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSaving ? null : _saveBirth,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPinkDeep,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: _isSaving
                  ? SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('Log Birth', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
