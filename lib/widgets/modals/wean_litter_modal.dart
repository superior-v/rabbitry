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

  Widget _buildRabbitHeaderWidget() {
    final prefix = (widget.doe.breederPrefix ?? '').trim();
    final name = widget.doe.name.trim();
    final ear = (widget.doe.earNumber?.trim().isNotEmpty == true
            ? widget.doe.earNumber!.trim()
            : (widget.doe.id.length >= 6 ? widget.doe.id.substring(0, 6) : widget.doe.id).trim())
        .toUpperCase();
    final isArchived = widget.doe.status == RabbitStatus.archived;
    final nameColor = isArchived ? const Color(0xFFF48FB1) : const Color(0xFFE04F9F);

    return Text.rich(
      TextSpan(
        children: [
          if (prefix.isNotEmpty)
            TextSpan(
              text: '$prefix ',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF787774),
              ),
            ),
          TextSpan(
            text: name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: nameColor,
            ),
          ),
          if (ear.isNotEmpty && !name.toUpperCase().endsWith(ear))
            TextSpan(
              text: ' $ear',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF787774),
              ),
            ),
          if (widget.doe.currentLitterSize != null)
            TextSpan(
              text: ' • ${widget.doe.currentLitterSize} kits',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF787774),
              ),
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
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
                    'Wean Litter',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              _buildRabbitHeaderWidget(),
              const SizedBox(height: 24),

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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                  borderRadius: BorderRadius.circular(12),
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
                  borderRadius: BorderRadius.circular(12),
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
                        borderRadius: BorderRadius.circular(12),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                        borderRadius: BorderRadius.circular(12),
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
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                    backgroundColor: const Color(0xFFE6BEFE),
                    foregroundColor: const Color(0xFF4A3E6D),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4A3E6D)),
                          ),
                        )
                      : const Text(
                          'Wean Litter',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF4A3E6D),
                          ),
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
