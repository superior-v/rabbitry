import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/rabbit.dart';
import '../services/database_service.dart';
import '../constants/app_colors.dart';
import 'package:intl/intl.dart';

class NotesCard extends StatefulWidget {
  final Rabbit rabbit;
  const NotesCard({Key? key, required this.rabbit}) : super(key: key);

  @override
  State<NotesCard> createState() => _NotesCardState();
}

class _NotesCardState extends State<NotesCard> {
  final DatabaseService _db = DatabaseService();
  late final TextEditingController _notesController;
  String _lastSavedTime = DateFormat('h:mm a').format(DateTime.now());

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.rabbit.notes ?? '');
  }

  Future<void> _saveNotes() async {
    final updatedRabbit = widget.rabbit.copyWith(notes: _notesController.text);
    await _db.updateRabbit(updatedRabbit);
    widget.rabbit.notes = _notesController.text;
    
    if (mounted) {
      setState(() {
        _lastSavedTime = DateFormat('h:mm a').format(DateTime.now());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), // Dismiss keyboard on tap outside
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kNeutral200),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Text(
                'NOTES',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF4F4F56),
                  letterSpacing: 0.8,
                ),
              ),
            ),

            // Note Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFAFA),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kNeutral100),
                ),
                child: TextField(
                  controller: _notesController,
                  maxLines: 8,
                  onChanged: (val) {
                    setState(() {}); // Update entry count live
                    _saveNotes();
                  },
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF374151),
                    height: 1.6,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Add notes here...',
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 14, color: kPinkDeep.withOpacity(0.6)),
                  const SizedBox(width: 6),
                  Text(
                    'Auto-saved • $_lastSavedTime',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: kNeutral400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}
