import 'package:flutter/material.dart';
import '../../models/rabbit.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';

class ConfirmPregnancyModal extends StatefulWidget {
  final Rabbit doe;
  final VoidCallback onComplete;

  const ConfirmPregnancyModal({
    Key? key,
    required this.doe,
    required this.onComplete,
  }) : super(key: key);

  @override
  State<ConfirmPregnancyModal> createState() => _ConfirmPregnancyModalState();
}

class _ConfirmPregnancyModalState extends State<ConfirmPregnancyModal> {
  final DatabaseService _db = DatabaseService();
  bool? _isPregnant;
  bool _isSaving = false;

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
                  'Confirm Pregnancy',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Palpation result for ${widget.doe.name} (${widget.doe.id})',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF787774),
              ),
            ),
            SizedBox(height: 24),

            // Pregnancy Options
            Text(
              'Is the doe pregnant?',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            SizedBox(height: 12),

            // Pregnant Option
            _buildOption(
              title: 'Yes, Pregnant',
              subtitle: 'Continue pregnancy pipeline',
              icon: Icons.check_circle,
              color: Color(0xFF0F7B6C),
              isSelected: _isPregnant == true,
              onTap: () => setState(() => _isPregnant = true),
            ),
            SizedBox(height: 12),

            // Not Pregnant Option
            _buildOption(
              title: 'No, Not Pregnant (Open)',
              subtitle: 'Reset to open status',
              icon: Icons.cancel,
              color: Color(0xFFD44C47),
              isSelected: _isPregnant == false,
              onTap: () => setState(() => _isPregnant = false),
            ),
            SizedBox(height: 24),

            // Due Date Preview (if pregnant)
            if (_isPregnant == true && widget.doe.dueDate != null)
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(0xFFEDF3EE),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.calendar_today, color: Color(0xFF0F7B6C)),
                    SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Expected Due Date',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF787774),
                          ),
                        ),
                        Text(
                          '${widget.doe.dueDate!.day}/${widget.doe.dueDate!.month}/${widget.doe.dueDate!.year}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F7B6C),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isPregnant == null || _isSaving ? null : _saveResult,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0F7B6C),
                  padding: EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isSaving
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Confirm',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? color : Color(0xFFE9E9E7),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? color.withOpacity(0.05) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF787774),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected) Icon(Icons.check_circle, color: color),
          ],
        ),
      ),
    );
  }

  Future<void> _saveResult() async {
    if (_isPregnant == null) return;

    setState(() => _isSaving = true);

    try {
      await SettingsService.instance.init();
      final gestationDays = SettingsService.instance.gestationDays;

      await _db.confirmPregnancy(widget.doe.id, _isPregnant!, gestationDays);

      Navigator.pop(context);
      widget.onComplete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isPregnant! ? 'Pregnancy confirmed' : 'Marked as open'),
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
}
