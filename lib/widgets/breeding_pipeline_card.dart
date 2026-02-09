import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../models/rabbit.dart';

class BreedingPipelineCard extends StatelessWidget {
  final Rabbit rabbit;

  const BreedingPipelineCard({Key? key, required this.rabbit}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFE9E9E7)),
        borderRadius: BorderRadius.circular(12),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  'CURRENT CYCLE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF787774),
                    letterSpacing: 0.5,
                  ),
                ),
                GestureDetector(
                  onTap: () => _showPipelineSettings(context),
                  child: Icon(Icons.settings, color: Color(0xFF787774), size: 18),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: TextStyle(fontSize: 14, color: Color(0xFF787774)),
                    children: [
                      TextSpan(text: 'with '),
                      TextSpan(
                        text: 'Thumper (B-02)',
                        style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF37352F)),
                      ),
                      TextSpan(text: ' • Bred Jan 10'),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                // Progress Bar
                Stack(
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: Color(0xFFE9E9E7),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: 0.45,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: Color(0xFF0F7B6C),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Positioned(
                      left: MediaQuery.of(context).size.width * 0.373,
                      top: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Color(0xFF0F7B6C),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),],
                ),SizedBox(height: 12),
                Text(
                  'Day 14 of 31',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF37352F),
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Kindle expected Feb 10',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF787774),
                  ),
                ),
                SizedBox(height: 24),
                // Milestones
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMilestone(PhosphorIconsDuotone.checkCircle, 'Bred\nJan 10', true, Color(0xFF0F7B6C)),
                    _buildMilestone(PhosphorIconsDuotone.handPointing, 'Palpate\nToday', false, Color(0xFF0F7B6C)),
                    _buildMilestone(PhosphorIconsDuotone.package, 'Nest Box\nFeb 7', false, Color(0xFF9B9A97)),
                    _buildMilestone(PhosphorIconsDuotone.baby, 'Kindle\nFeb 10', false, Color(0xFF9B9A97)),
                  ],
                ),
                SizedBox(height: 24),
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _showPalpationDialog(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF0F7B6C),
                          padding: EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Log Palpation',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _showMarkOpenDialog(context),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(color: Color(0xFFE9E9E7)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          'Not Pregnant',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF787774),
                          ),
                        ),
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

  Widget _buildMilestone(IconData icon, String label, bool completed, Color color) {
    return Column(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: completed ? color.withOpacity(0.1) : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: completed ? color : Color(0xFFE9E9E7),
              width: 2,
            ),
          ),child: Icon(
          icon,
          size: 18,
          color: color,
        ),
        ),
        SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 9,
            height: 1.2,
            color: Color(0xFF787774),
          ),
        ),
      ],
    );
  }


  Widget _buildStatistic(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF37352F),
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Color(0xFF787774),
          ),
        ),
      ],
    );
  }
  void _showPipelineSettings(BuildContext context) {
    bool useDefault = true;
    int palpationDay = 14;
    int nestBoxDay = 28;
    int expectedKindleDay = 31;
    int weaningWeek = 6;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pipeline Settings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF37352F),
                        ),
                      ),
                      Text(
                        'Luna (D-101)',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF787774),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Color(0xFF787774)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 20),
              // Toggle Buttons
              Container(
                decoration: BoxDecoration(
                  color: Color(0xFFF7F7F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => useDefault = true),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: useDefault ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: useDefault
                                ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 3)]
                                : null,
                          ),
                          child: Text(
                            'Use Default',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: useDefault ? FontWeight.w600 : FontWeight.w400,
                              color: Color(0xFF37352F),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setModalState(() => useDefault = false),
                        child: Container(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !useDefault ? Colors.white : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            boxShadow: !useDefault
                                ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 3)]
                                : null,
                          ),
                          child: Text(
                            'Custom',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: !useDefault ? FontWeight.w600 : FontWeight.w400,
                              color: Color(0xFF37352F),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24),
              // TIMING Header
              Text(
                'TIMING',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF787774),
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 16),
              // Settings Items
              _buildTimingItem('Palpation Check', 'Day', '$palpationDay', 'after breeding', !useDefault),
              _buildTimingItem('Nest Box', 'Day', '$nestBoxDay', 'after breeding', !useDefault),
              _buildTimingItem('Expected Kindle', 'Day', '$expectedKindleDay', 'after breeding', !useDefault),
              _buildTimingItem('Weaning', 'Week', '$weaningWeek', 'after kindle', !useDefault),
              SizedBox(height: 24),
              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setModalState(() {
                          useDefault = true;
                          palpationDay = 14;
                          nestBoxDay = 28;
                          expectedKindleDay = 31;
                          weaningWeek = 6;
                        });
                      },
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Color(0xFFE9E9E7)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Restore Defaults',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF787774),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF0F7B6C),
                        padding: EdgeInsets.symmetric(vertical: 14),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        'Save',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimingItem(String title, String unit, String value, String suffix, bool enabled) {
    return Padding(
      padding: EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF37352F),
            ),
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Container(
                width: 70,
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: enabled ? Colors.white : Color(0xFFF7F7F5),
                  border: Border.all(color: Color(0xFFE9E9E7)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  unit,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF787774),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: enabled ? Colors.white : Color(0xFFF7F7F5),
                    border: Border.all(color: Color(0xFFE9E9E7)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 13,
                          color: enabled ? Color(0xFF37352F) : Color(0xFF787774),
                        ),
                      ),
                      SizedBox(width: 4),
                      Text(
                        suffix,
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF787774),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildSettingItem(IconData icon, String label, VoidCallback onTap, {bool isDestructive = false}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Color(0xFFC47070) : Color(0xFF787774),
              size: 24,
            ),
            SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: isDestructive ? Color(0xFFC47070) : Color(0xFF37352F),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPalpationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Log Palpation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Did you feel kits during palpation?',
              style: TextStyle(fontSize: 14, color: Color(0xFF787774)),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showPalpationResultDialog(context, false);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: Color(0xFFE9E9E7)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'No',
                      style: TextStyle(color: Color(0xFF787774)),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _showPalpationResultDialog(context, true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0F7B6C),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Yes', style: TextStyle(color: Colors.white)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showPalpationResultDialog(BuildContext context, bool positive) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              positive ? Icons.check_circle : Icons.info,
              color: positive ? Color(0xFF6B9E78) : Color(0xFFCB8347),
            ),
            SizedBox(width: 8),
            Text(positive ? 'Positive Palpation' : 'Negative Palpation'),
          ],
        ),
        content: Text(
          positive
              ? 'Great! Kits detected. Nest box should be ready by Day 28.'
              : 'No kits detected. Consider marking as open or waiting a few more days.',
          style: TextStyle(fontSize: 14, color: Color(0xFF787774)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK', style: TextStyle(color: Color(0xFF0F7B6C))),
          ),
        ],
      ),
    );
  }

  void _showMarkOpenDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Mark as Open'),
        content: Text(
          'This will end the current breeding cycle. Are you sure?',
          style: TextStyle(fontSize: 14, color: Color(0xFF787774)),
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
                  content: Text('Breeding cycle ended'),
                  backgroundColor: Color(0xFF0F7B6C),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFC47070),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Mark Open', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}