import 'package:flutter/material.dart';
import '../models/rabbit.dart';
import '../services/database_service.dart';
import '../screens/rabbit_detail_screen.dart';

class ParentageCard extends StatefulWidget {
  final Rabbit rabbit;

  const ParentageCard({Key? key, required this.rabbit}) : super(key: key);

  @override
  State<ParentageCard> createState() => _ParentageCardState();
}

class _ParentageCardState extends State<ParentageCard> {
  Rabbit? _sireRabbit;
  Rabbit? _damRabbit;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadParents();
  }

  Future<void> _loadParents() async {
    final db = DatabaseService();

    // Load sire if sireId exists
    if (widget.rabbit.sireId != null && widget.rabbit.sireId!.isNotEmpty) {
      _sireRabbit = await db.getRabbit(widget.rabbit.sireId!);
    }

    // Load dam if damId exists
    if (widget.rabbit.damId != null && widget.rabbit.damId!.isNotEmpty) {
      _damRabbit = await db.getRabbit(widget.rabbit.damId!);
    }

    if (mounted) {
      setState(() {
        _loading = false;
      });
    }
  }

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
                  'PARENTAGE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF787774),
                    letterSpacing: 0.5,
                  ),
                ),
                GestureDetector(
                  onTap: () => _showEditParentageDialog(context),
                  child: Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF787774),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: _loading
                ? Center(child: CircularProgressIndicator(strokeWidth: 2))
                : Row(
                    children: [
                      Expanded(
                        child: _buildParentBox(
                          context,
                          'Sire',
                          _sireRabbit?.name ?? widget.rabbit.sireId ?? 'Unknown',
                          _sireRabbit?.id ?? widget.rabbit.sireId ?? '-',
                          true,
                          _sireRabbit,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: _buildParentBox(
                          context,
                          'Dam',
                          _damRabbit?.name ?? widget.rabbit.damId ?? 'Unknown',
                          _damRabbit?.id ?? widget.rabbit.damId ?? '-',
                          false,
                          _damRabbit,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildParentBox(BuildContext context, String label, String name, String id, bool isMale, Rabbit? parentRabbit) {
    final bool parentExists = parentRabbit != null;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFFF7F7F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isMale ? Color(0xFF2E7BB5) : Color(0xFF9C6ADE),
                ),
              ),
              SizedBox(width: 4),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF787774),
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: Icon(
                  isMale ? Icons.male : Icons.female,
                  size: 20,
                  color: isMale ? Color(0xFF2E7BB5) : Color(0xFF9C6ADE),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF37352F),
                      ),
                    ),
                    Text(
                      id,
                      style: TextStyle(fontSize: 11, color: Color(0xFF787774)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          // Only show "View Profile" link if parent exists in database
          if (parentExists)
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RabbitDetailScreen(rabbit: parentRabbit),
                  ),
                );
              },
              child: Row(
                children: [
                  Icon(Icons.arrow_forward, size: 12, color: Color(0xFF0F7B6C)),
                  SizedBox(width: 4),
                  Text(
                    'View Profile',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF0F7B6C),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              'Not in herd',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF9B9A97),
                fontStyle: FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  void _showEditParentageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Parentage'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Sire ID',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFF0F7B6C), width: 2),
                ),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              decoration: InputDecoration(
                labelText: 'Dam ID',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFF0F7B6C), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Color(0xFF787774))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Parentage updated'),
                  backgroundColor: Color(0xFF0F7B6C),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFF0F7B6C),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Save', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
