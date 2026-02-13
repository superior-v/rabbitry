import 'package:flutter/material.dart';
import '../models/rabbit.dart';

class NotesCard extends StatefulWidget {
  final Rabbit rabbit;

  const NotesCard({Key? key, required this.rabbit}) : super(key: key);

  @override
  State<NotesCard> createState() => _NotesCardState();
}

class _NotesCardState extends State<NotesCard> {
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.rabbit.notes ?? '');
  }

  bool _isEditing = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFE9E9E7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFFF7F7F5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'NOTES',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF787774),
                    letterSpacing: 0.5,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isEditing = !_isEditing;
                    });
                  },
                  child: Text(
                    _isEditing ? 'Done' : 'Edit',
                    style: TextStyle(
                      fontSize: 12,
                      color: _isEditing ? Color(0xFF0F7B6C) : Color(0xFF787774),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: _isEditing
                ? TextField(
                    controller: _notesController,
                    maxLines: 10,
                    decoration: InputDecoration(
                      hintText: 'Add notes about this rabbit...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Color(0xFFE9E9E7)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Color(0xFF0F7B6C), width: 2),
                      ),
                    ),
                  )
                : Text(
                    _notesController.text.isEmpty ? 'No notes yet. Tap Edit to add notes.' : _notesController.text,
                    style: TextStyle(
                      fontSize: 14,
                      color: _notesController.text.isEmpty ? Color(0xFF9B9A97) : Color(0xFF37352F),
                      height: 1.5,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}
