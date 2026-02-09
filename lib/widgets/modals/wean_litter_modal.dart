import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/rabbit.dart';
import '../../services/database_service.dart';

class WeanLitterModal extends StatefulWidget {
  final Rabbit doe;
  final VoidCallback onComplete;

  const WeanLitterModal({
    Key? key,
    required this.doe,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<WeanLitterModal> createState() => _WeanLitterModalState();
}

class _WeanLitterModalState extends State<WeanLitterModal> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _weanedCountController = TextEditingController();
  final TextEditingController _doeCageController = TextEditingController();
  final TextEditingController _litterCageController = TextEditingController();
  int _restingDays = 14;
  bool _isSaving = false;
  String? _doeLocation;
  String? _litterLocation;
  List<String> _locations = []; // List of row names

  @override
  void initState() {
    super.initState();
    _weanedCountController.text = widget.doe.currentLitterSize?.toString() ?? '0';
    _loadBarns();
  }

  Future<void> _loadBarns() async {
    final barns = await _db.getAllBarns();
    // Extract all row names from barns as location options
    List<String> locations = [];
    for (var barn in barns) {
      // The 'rows' field is stored as a JSON string in the database
      final rowsRaw = barn['rows'];
      List<dynamic> rows = [];
      if (rowsRaw is String && rowsRaw.isNotEmpty) {
        try {
          rows = jsonDecode(rowsRaw) as List<dynamic>;
        } catch (e) {
          print('Error decoding barn rows: $e');
        }
      } else if (rowsRaw is List) {
        rows = rowsRaw;
      }

      for (var row in rows) {
        if (row is Map) {
          final rowName = row['name'] as String?;
          if (rowName != null && !locations.contains(rowName)) {
            locations.add(rowName);
          }
        }
      }
    }

    setState(() {
      _locations = locations;
      // Only set location if it exists in the list
      _doeLocation = locations.contains(widget.doe.location) ? widget.doe.location : null;
      _litterLocation = locations.contains(widget.doe.location) ? widget.doe.location : null;
    });
  }

  @override
  void dispose() {
    _weanedCountController.dispose();
    _doeCageController.dispose();
    _litterCageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
                    'Wean Litter',
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
                '${widget.doe.name} (${widget.doe.id}) • ${widget.doe.currentLitterSize ?? 0} kits',
                style: TextStyle(fontSize: 14, color: Color(0xFF787774)),
              ),
              SizedBox(height: 24),

              // Weaned Count
              Text(
                'Kits Weaned',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              TextField(
                controller: _weanedCountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'Number of kits weaned',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              SizedBox(height: 20),

              // Resting Period
              Text(
                'Resting Period (Days)',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Color(0xFFE9E9E7)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.remove),
                      onPressed: () {
                        if (_restingDays > 0) {
                          setState(() => _restingDays--);
                        }
                      },
                    ),
                    Expanded(
                      child: Text(
                        '$_restingDays days',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.add),
                      onPressed: () {
                        setState(() => _restingDays++);
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),

              // Info box
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFFFF3CD),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Color(0xFF856404), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Doe will be marked as "Resting" and available for breeding after $_restingDays days.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF856404)),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 20),

              // Doe Cage Selection
              Text(
                'Move Doe to Cage',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Color(0xFFE9E9E7)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _doeLocation,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                          hintText: 'Location',
                        ),
                        items: _locations.map((location) {
                          return DropdownMenuItem(
                            value: location,
                            child: Text(location, style: TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _doeLocation = value),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _doeCageController,
                      decoration: InputDecoration(
                        hintText: 'Cage ID',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16),

              // Litter Cage Selection
              Text(
                'Move Litter to Cage',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Color(0xFFE9E9E7)),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonFormField<String>(
                        value: _litterLocation,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 12),
                          hintText: 'Location',
                        ),
                        items: _locations.map((location) {
                          return DropdownMenuItem(
                            value: location,
                            child: Text(location, style: TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (value) => setState(() => _litterLocation = value),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _litterCageController,
                      decoration: InputDecoration(
                        hintText: 'Cage ID',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveWean,
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
                      : Text(
                          'Wean Litter',
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

  Future<void> _saveWean() async {
    final weanedCount = int.tryParse(_weanedCountController.text) ?? 0;

    setState(() => _isSaving = true);

    try {
      await _db.weanLitter(widget.doe.id, weanedCount, _restingDays);

      // Move doe to new cage if specified
      if (_doeCageController.text.isNotEmpty || _doeLocation != null) {
        await _db.moveCage(
          widget.doe.id,
          _doeLocation ?? '',
          _doeCageController.text,
        );
      }

      // TODO: Move litter to new cage (requires litter ID)
      // The litter cage info can be stored or handled differently
      // For now, we'll update the litter location in the database
      if (_litterCageController.text.isNotEmpty || _litterLocation != null) {
        await _db.updateLitterLocation(
          widget.doe.id,
          _litterLocation ?? '',
          _litterCageController.text,
        );
      }

      // Call callback FIRST to trigger parent refresh
      widget.onComplete();

      // Then close this modal
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
