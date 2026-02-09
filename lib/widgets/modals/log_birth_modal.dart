import 'package:flutter/material.dart';
import '../../models/rabbit.dart';
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
  final TextEditingController _totalBornController = TextEditingController();
  final TextEditingController _aliveBornController = TextEditingController();
  final TextEditingController _weightAvgController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime _kindleDate = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _totalBornController.dispose();
    _aliveBornController.dispose();
    _weightAvgController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Log Birth (Kindle)',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Text(
                '${widget.doe.name} (${widget.doe.id})',
                style: TextStyle(fontSize: 14, color: Color(0xFF787774)),
              ),
              SizedBox(height: 24),

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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                onChanged: (value) {
                  // Auto-fill alive if empty
                  if (_aliveBornController.text.isEmpty) {
                    _aliveBornController.text = value;
                  }
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Dead count display (calculated)
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
                            Text(
                              'Dead kits: $dead',
                              style: TextStyle(fontSize: 14, color: Color(0xFFD32F2F)),
                            ),
                          ],
                        ),
                      );
                    }
                    return SizedBox.shrink();
                  },
                ),
              SizedBox(height: 16),

              // Weight Average (Optional)
              Text(
                'Average Kit Weight (optional)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _weightAvgController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  hintText: 'e.g., 0.15',
                  suffixText: 'lbs',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              SizedBox(height: 16),

              // Notes (Optional)
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
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveBirth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0F7B6C),
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text(
                          'Log Birth',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                ),
              ),
              SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
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
    final totalBorn = int.tryParse(_totalBornController.text);
    final aliveBorn = int.tryParse(_aliveBornController.text);

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

    setState(() => _isSaving = true);

    try {
      await SettingsService.instance.init();
      final weaningWeeks = 8;

      await _db.logBirth(widget.doe.id, totalBorn, aliveBorn, _kindleDate, weaningWeeks);

      Navigator.pop(context);
      widget.onComplete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Birth logged: $aliveBorn alive out of $totalBorn'),
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
