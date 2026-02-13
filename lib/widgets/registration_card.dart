import 'package:flutter/material.dart';
import '../models/rabbit.dart';

class RegistrationCard extends StatefulWidget {
  final Rabbit rabbit;

  const RegistrationCard({Key? key, required this.rabbit}) : super(key: key);

  @override
  State<RegistrationCard> createState() => _RegistrationCardState();
}

class _RegistrationCardState extends State<RegistrationCard> {
  List<bool> gcLegs = [
    false,
    false,
    false
  ];

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
                  'REGISTRATION',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF787774),
                    letterSpacing: 0.5,
                  ),
                ),
                GestureDetector(
                  onTap: _showEditRegistrationDialog,
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
          _buildInfoRow('Registration #', widget.rabbit.registrationNumber ?? 'Not set'),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'GC Legs',
                  style: TextStyle(fontSize: 14, color: Color(0xFF787774)),
                ),
                Row(
                  children: [
                    ...List.generate(3, (index) {
                      return Padding(
                        padding: EdgeInsets.only(left: index > 0 ? 4 : 0),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              gcLegs[index] = !gcLegs[index];
                            });
                          },
                          child: _buildGCLeg(gcLegs[index]),
                        ),
                      );
                    }),
                    SizedBox(width: 8),
                    Text(
                      '${gcLegs.where((leg) => leg).length}/3',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF787774),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF7F7F5))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Color(0xFF787774)),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Color(0xFF37352F),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGCLeg(bool earned) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: earned ? Color(0xFF0F7B6C) : null,
        border: earned ? null : Border.all(color: Color(0xFFE9E9E7), width: 2),
      ),
      child: earned ? Icon(Icons.check, size: 8, color: Colors.white) : null,
    );
  }

  void _showEditRegistrationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Edit Registration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: InputDecoration(
                labelText: 'Registration Number',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Color(0xFF0F7B6C), width: 2),
                ),
              ),
            ),
            SizedBox(height: 16),
            Text(
              'GC Legs',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (index) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            gcLegs[index] = !gcLegs[index];
                          });
                        },
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: gcLegs[index] ? Color(0xFF0F7B6C) : Color(0xFFF7F7F5),
                            border: Border.all(
                              color: gcLegs[index] ? Color(0xFF0F7B6C) : Color(0xFFE9E9E7),
                              width: 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: gcLegs[index] ? Colors.white : Color(0xFF787774),
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        gcLegs[index] ? 'Earned' : 'Pending',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF787774),
                        ),
                      ),
                    ],
                  ),
                );
              }),
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
                  content: Text('Registration updated'),
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
