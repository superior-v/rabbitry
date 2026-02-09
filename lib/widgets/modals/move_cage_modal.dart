import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/rabbit.dart';
import '../../services/database_service.dart';

class MoveCageModal extends StatefulWidget {
  final Rabbit rabbit;
  final VoidCallback onComplete;

  const MoveCageModal({
    Key? key,
    required this.rabbit,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<MoveCageModal> createState() => _MoveCageModalState();
}

class _MoveCageModalState extends State<MoveCageModal> {
  final DatabaseService _db = DatabaseService();
  String? _selectedLocation;
  String? _selectedCage;
  bool _isSaving = false;
  bool _isLoading = true;

  List<String> _locations = []; // List of row names

  @override
  void initState() {
    super.initState();
    _loadBarns();
  }

  Future<void> _loadBarns() async {
    final barns = await _db.getAllBarns();
    // Extract all row names from barns as location options
    List<String> locations = [];
    for (var barn in barns) {
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
      _selectedLocation = locations.contains(widget.rabbit.location) ? widget.rabbit.location : null;
      _selectedCage = widget.rabbit.cage;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
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
                  'Move Cage',
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
              '${widget.rabbit.name} (${widget.rabbit.id})',
              style: TextStyle(fontSize: 14, color: Color(0xFF787774)),
            ),
            if (widget.rabbit.location != null || widget.rabbit.cage != null)
              Text(
                'Current: ${widget.rabbit.location ?? 'N/A'} • ${widget.rabbit.cage ?? 'N/A'}',
                style: TextStyle(fontSize: 12, color: Color(0xFF0F7B6C)),
              ),
            SizedBox(height: 24),

            if (_isLoading)
              Center(child: CircularProgressIndicator())
            else ...[
              // Location Selection
              Text(
                'Location / Barn',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Color(0xFFE9E9E7)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedLocation,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    hintText: 'Select location',
                  ),
                  items: [
                    ..._locations.map((location) {
                      return DropdownMenuItem(
                        value: location,
                        child: Text(location),
                      );
                    }),
                    DropdownMenuItem(
                      value: '__new__',
                      child: Row(
                        children: [
                          Icon(Icons.add, size: 16, color: Color(0xFF0F7B6C)),
                          SizedBox(width: 8),
                          Text('Add New Location', style: TextStyle(color: Color(0xFF0F7B6C))),
                        ],
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == '__new__') {
                      _showAddLocationDialog();
                    } else {
                      setState(() => _selectedLocation = value);
                    }
                  },
                ),
              ),
              SizedBox(height: 20),

              // Cage Input
              Text(
                'Cage / Hutch ID',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 8),
              TextFormField(
                initialValue: _selectedCage,
                decoration: InputDecoration(
                  hintText: 'e.g., A-01, Row 1 Cage 3',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (value) => _selectedCage = value,
              ),
              SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveCage,
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
                          'Move Cage',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                ),
              ),
            ],
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showAddLocationDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add New Location'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'Location name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await _db.insertBarn({
                  'id': 'barn_${DateTime.now().millisecondsSinceEpoch}',
                  'name': controller.text,
                  'type': 'barn',
                  'createdAt': DateTime.now().toIso8601String(),
                });
                Navigator.pop(context);
                await _loadBarns();
                setState(() => _selectedLocation = controller.text);
              }
            },
            child: Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveCage() async {
    if (_selectedLocation == null || _selectedLocation!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please select a location'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _db.moveCage(widget.rabbit.id, _selectedLocation!, _selectedCage ?? '');

      Navigator.pop(context);
      widget.onComplete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Moved to $_selectedLocation • $_selectedCage'),
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
