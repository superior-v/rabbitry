import 'package:flutter/material.dart';
import '../../models/rabbit.dart';
import '../../models/litter.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';

class LogBirthModal extends StatefulWidget {
  final Rabbit doe;
  final VoidCallback onComplete;

  const LogBirthModal({
    Key? key,
    required this.doe,
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
  DateTime _kindleDate = DateTime.now();
  bool _isSaving = false;

  // ✅ Step management
  int _currentStep = 1; // 1 = Basic info, 2 = Kit details
  List<Map<String, dynamic>> _kitDetails = [];

  // ✅ Color options
  final List<String> _colorOptions = [
    'Black',
    'White',
    'Castor',
    'Broken',
    'Blue',
    'Chinchilla',
    'Chocolate',
    'Opal',
    'Orange',
    'Fawn',
    'Red',
    'Sable',
    'Unknown'
  ];

  @override
  void initState() {
    super.initState();
    _loadNextLitterId();
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
                      _currentStep == 1 ? 'Log Birth (Kindle)' : 'Kit Details',
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
        SizedBox(height: 16),

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
            suffixText: 'g',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
            color: Color(0xFFF0FDF4),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Color(0xFF0F7B6C).withOpacity(0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Color(0xFF0F7B6C), size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Add details for each kit. You can skip and update later.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF0F7B6C)),
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
                  color: Color(0xFF0F7B6C),
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
            decoration: InputDecoration(
              hintText: 'e.g., 50',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Color(0xFF0F7B6C) : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Color(0xFF0F7B6C) : Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
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
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Color(0xFFE2E8F0)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _validateAndProceed,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0F7B6C),
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Next: Add Kit Details', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
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
                backgroundColor: Color(0xFF0F7B6C),
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

      await _db.logBirth(
        widget.doe.id,
        totalBorn,
        aliveBorn,
        _kindleDate,
        weaningWeeks,
        litterId: _litterIdController.text.trim(),
        kits: _kitDetails,
      );

      Navigator.pop(context);
      widget.onComplete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Birth logged: ${_litterIdController.text} with $aliveBorn kits'),
          backgroundColor: Color(0xFF0F7B6C),
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
