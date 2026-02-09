import 'dart:convert';
import 'package:flutter/material.dart';
import '../../models/rabbit.dart';
import '../../services/database_service.dart';

class StopQuarantineModal extends StatefulWidget {
  final Rabbit rabbit;
  final VoidCallback onComplete;

  const StopQuarantineModal({
    Key? key,
    required this.rabbit,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<StopQuarantineModal> createState() => _StopQuarantineModalState();
}

class _StopQuarantineModalState extends State<StopQuarantineModal> {
  final DatabaseService _db = DatabaseService();
  final TextEditingController _cageController = TextEditingController();

  bool _isSaving = false;
  String? _selectedLocation;
  List<String> _locations = []; // List of row names
  RabbitStatus _newStatus = RabbitStatus.open;

  @override
  void initState() {
    super.initState();
    _loadBarns();
    // Set default status based on rabbit type
    if (widget.rabbit.type == RabbitType.buck) {
      _newStatus = RabbitStatus.active;
    } else if (widget.rabbit.type == RabbitType.doe) {
      _newStatus = RabbitStatus.open;
    } else {
      _newStatus = RabbitStatus.growout;
    }
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
    });
  }

  @override
  void dispose() {
    _cageController.dispose();
    super.dispose();
  }

  Future<void> _stopQuarantine() async {
    setState(() => _isSaving = true);

    try {
      // End quarantine with new cage if specified
      final newCage = _cageController.text.isNotEmpty ? '${_selectedLocation ?? ''} - ${_cageController.text}' : null;

      await _db.endQuarantine(widget.rabbit.id, _newStatus, newCage);

      // Move cage if specified
      if (_cageController.text.isNotEmpty || _selectedLocation != null) {
        await _db.moveCage(
          widget.rabbit.id,
          _selectedLocation ?? '',
          _cageController.text,
        );
      }

      // Cancel any quarantine-related tasks
      await _db.cancelQuarantineTasks(widget.rabbit.id);

      widget.onComplete();
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.rabbit.name} released from quarantine'),
          backgroundColor: Color(0xFF0F7B6C),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
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
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              SizedBox(height: 20),

              // Title
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Color(0xFF0F7B6C).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.check_circle_outline,
                      color: Color(0xFF0F7B6C),
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Stop Quarantine',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          widget.rabbit.name,
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF787774),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),

              // Current quarantine info
              if (widget.rabbit.quarantineReason != null || widget.rabbit.daysInQuarantineRemaining != null)
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.rabbit.quarantineReason != null)
                        Text(
                          'Reason: ${widget.rabbit.quarantineReason}',
                          style: TextStyle(fontSize: 13, color: Color(0xFF856404)),
                        ),
                      if (widget.rabbit.daysInQuarantineRemaining != null)
                        Text(
                          'Days remaining: ${widget.rabbit.daysInQuarantineRemaining}',
                          style: TextStyle(fontSize: 13, color: Color(0xFF856404)),
                        ),
                    ],
                  ),
                ),
              SizedBox(height: 20),

              // New Status Selection
              Text(
                'New Status',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF37352F),
                ),
              ),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Color(0xFFE9E9E7)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonFormField<RabbitStatus>(
                  value: _newStatus,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                  ),
                  items: _getStatusOptions().map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(_getStatusLabel(status)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _newStatus = value);
                  },
                ),
              ),
              SizedBox(height: 20),

              // Move to Cage Section
              Text(
                'Move to Cage',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF37352F),
                ),
              ),
              SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Color(0xFFE9E9E7)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedLocation,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    hintText: 'Select location',
                  ),
                  items: _locations.map((location) {
                    return DropdownMenuItem(
                      value: location,
                      child: Text(location),
                    );
                  }).toList(),
                  onChanged: (value) => setState(() => _selectedLocation = value),
                ),
              ),
              SizedBox(height: 12),
              TextFormField(
                controller: _cageController,
                decoration: InputDecoration(
                  hintText: 'e.g., A-01, Row 1 Cage 3',
                  labelText: 'Cage / Hutch ID',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Color(0xFFE9E9E7)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Color(0xFFE9E9E7)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Color(0xFF0F7B6C), width: 2),
                  ),
                ),
              ),
              SizedBox(height: 24),

              // Save button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _stopQuarantine,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0F7B6C),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isSaving
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          'Release from Quarantine',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }

  List<RabbitStatus> _getStatusOptions() {
    if (widget.rabbit.type == RabbitType.doe) {
      return [
        RabbitStatus.open,
        RabbitStatus.resting
      ];
    } else if (widget.rabbit.type == RabbitType.buck) {
      return [
        RabbitStatus.active,
        RabbitStatus.inactive
      ];
    } else {
      return [
        RabbitStatus.growout,
        RabbitStatus.open,
        RabbitStatus.active
      ];
    }
  }

  String _getStatusLabel(RabbitStatus status) {
    switch (status) {
      case RabbitStatus.open:
        return 'Open (Available for breeding)';
      case RabbitStatus.active:
        return 'Active';
      case RabbitStatus.inactive:
        return 'Inactive';
      case RabbitStatus.resting:
        return 'Resting';
      case RabbitStatus.growout:
        return 'Growout';
      default:
        return status.toString().split('.').last;
    }
  }
}
