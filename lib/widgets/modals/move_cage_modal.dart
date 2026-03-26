import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/barn.dart';
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

  List<Barn> _barns = [];

  // Map row name → barn name for display
  Map<String, String> _rowToBarn = {};

  @override
  void initState() {
    super.initState();
    _loadBarns();
  }

  Future<void> _loadBarns() async {
    final barnsData = await _db.getAllBarns();
    final barns = barnsData.map((b) => Barn.fromMap(b)).toList();

    final rowToBarn = <String, String>{};
    for (var barn in barns) {
      for (var row in barn.rows) {
        rowToBarn[row.name] = barn.name;
      }
    }

    setState(() {
      _barns = barns;
      _rowToBarn = rowToBarn;
      _selectedLocation = rowToBarn.containsKey(widget.rabbit.location) ? widget.rabbit.location : null;
      _selectedCage = widget.rabbit.cage;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Move Cage',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${widget.rabbit.name} (${widget.rabbit.id})',
              style: const TextStyle(fontSize: 14, color: Color(0xFF787774)),
            ),
            if (widget.rabbit.location != null || widget.rabbit.cage != null)
              Text(
                'Current: ${widget.rabbit.location ?? 'N/A'} • ${widget.rabbit.cage ?? 'N/A'}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF6366F1)),
              ),
            const SizedBox(height: 24),

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              // Location Selection
              const Text(
                'Location / Barn',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 10),

              // Show barns grouped with rows
              Container(
                constraints: const BoxConstraints(maxHeight: 260),
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE9E9E7)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: ListView(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    children: [
                      ..._barns.map((barn) => _buildBarnGroup(barn)),
                      // Add New Location button
                      InkWell(
                        onTap: _showAddLocationDialog,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            children: const [
                              Icon(Icons.add_circle_outline, size: 18, color: Color(0xFF6366F1)),
                              SizedBox(width: 10),
                              Text(
                                'Add New Location',
                                style: TextStyle(
                                  color: Color(0xFF6366F1),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Cage Input
              const Text(
                'Cage / Hutch ID',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextFormField(
                initialValue: _selectedCage,
                decoration: InputDecoration(
                  hintText: 'e.g., A-01, Row 1 Cage 3',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onChanged: (value) => _selectedCage = value,
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveCage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text(
                          'Move Cage',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                        ),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildBarnGroup(Barn barn) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Barn header
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFFF7F7F5),
          child: Text(
            barn.name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Color(0xFF787774),
              letterSpacing: 0.3,
            ),
          ),
        ),
        // Rows under this barn
        if (barn.rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              'No rows yet',
              style: TextStyle(fontSize: 13, color: Colors.grey[400], fontStyle: FontStyle.italic),
            ),
          ),
        ...barn.rows.map((row) {
          final isSelected = _selectedLocation == row.name;
          return InkWell(
            onTap: () {
              setState(() => _selectedLocation = row.name);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFE6F7F4) : Colors.white,
                border: const Border(bottom: BorderSide(color: Color(0xFFF0F0EE))),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    size: 20,
                    color: isSelected ? const Color(0xFF6366F1) : const Color(0xFFCCCCCC),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      row.name,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected ? const Color(0xFF6366F1) : const Color(0xFF37352F),
                      ),
                    ),
                  ),
                  if (row.cages.isNotEmpty)
                    Text(
                      '${row.cages.length} cages',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF787774)),
                    ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  void _showAddLocationDialog() {
    String? selectedBarnId;
    final rowController = TextEditingController();
    final barnController = TextEditingController();
    bool isNewBarn = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Add New Location', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Choose barn
              const Text('Barn', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: const Color(0xFFE9E9E7)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: DropdownButtonFormField<String>(
                  value: selectedBarnId,
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    hintText: 'Select barn',
                    hintStyle: TextStyle(fontSize: 14),
                  ),
                  isExpanded: true,
                  items: [
                    ..._barns.map((b) => DropdownMenuItem(
                          value: b.id,
                          child: Text(b.name),
                        )),
                    const DropdownMenuItem(
                      value: '__new_barn__',
                      child: Text('+ Create New Barn', style: TextStyle(color: Color(0xFF6366F1), fontWeight: FontWeight.w600)),
                    ),
                  ],
                  onChanged: (val) {
                    setDialogState(() {
                      if (val == '__new_barn__') {
                        isNewBarn = true;
                        selectedBarnId = null;
                      } else {
                        isNewBarn = false;
                        selectedBarnId = val;
                      }
                    });
                  },
                ),
              ),
              if (isNewBarn) ...[
                const SizedBox(height: 12),
                const Text('New Barn Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: barnController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'e.g., Barn 3',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // Row name
              const Text('Row / Location Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              TextField(
                controller: rowController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'e.g., Row 5',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF6366F1), width: 2),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF787774))),
            ),
            ElevatedButton(
              onPressed: () async {
                final rowName = rowController.text.trim();
                if (rowName.isEmpty) return;

                if (isNewBarn) {
                  // Create new barn with the row
                  final barnName = barnController.text.trim();
                  if (barnName.isEmpty) return;
                  final newBarn = Barn(
                    id: 'barn_${DateTime.now().millisecondsSinceEpoch}',
                    name: barnName,
                    rows: [
                      BarnRow(name: rowName, cages: [])
                    ],
                  );
                  await _db.insertBarn(newBarn.toMap());
                } else if (selectedBarnId != null) {
                  // Add row to existing barn
                  final barn = _barns.firstWhere((b) => b.id == selectedBarnId);
                  final updatedRows = [
                    ...barn.rows,
                    BarnRow(name: rowName, cages: [])
                  ];
                  final updatedBarn = Barn(
                    id: barn.id,
                    name: barn.name,
                    rows: updatedRows,
                    notes: barn.notes,
                    createdAt: barn.createdAt,
                  );
                  await _db.updateBarn(updatedBarn.toMap());
                } else {
                  return; // No barn selected
                }

                Navigator.pop(ctx);
                await _loadBarns();
                setState(() => _selectedLocation = rowName);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Add', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveCage() async {
    if (_selectedLocation == null || _selectedLocation!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location'), backgroundColor: Colors.red),
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
          backgroundColor: const Color(0xFF6366F1),
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
