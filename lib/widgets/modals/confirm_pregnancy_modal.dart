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
  bool? _isPregnant = true; // Default to 'Yes, Bred' as selected in screenshot
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final doeIdentifier = widget.doe.earNumber != null && widget.doe.earNumber!.isNotEmpty
        ? widget.doe.earNumber!
        : (widget.doe.id.length >= 6 ? widget.doe.id.substring(0, 6) : widget.doe.id);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with X
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    'Palpation result for ${widget.doe.name} ($doeIdentifier)',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6E6D7A),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF2C2C2E), size: 26),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Purple Container holding options
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFD6C8EE),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                children: [
                  _buildOption(
                    title: 'Yes, Bred',
                    subtitle: 'Continue gestation pipeline',
                    isYes: true,
                    isSelected: _isPregnant == true,
                    onTap: () => setState(() => _isPregnant = true),
                  ),
                  const SizedBox(height: 12),
                  _buildOption(
                    title: 'No, Not Bred (Open)',
                    subtitle: 'Reset to open status',
                    isYes: false,
                    isSelected: _isPregnant == false,
                    onTap: () => setState(() => _isPregnant = false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Confirm Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isPregnant == null || _isSaving ? null : _saveResult,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B6BA0),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Confirm',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOption({
    required String title,
    required String subtitle,
    required bool isYes,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF7B6BA0) : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              isYes ? Icons.check_circle : Icons.cancel,
              color: isYes ? const Color(0xFF7B6BA0) : const Color(0xFFD9534F),
              size: 30,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2C2C2E),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF787774),
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(
                Icons.check_circle,
                color: Color(0xFF7B6BA0),
                size: 24,
              ),
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
      final gestationDays = widget.doe.customGestationDay ?? SettingsService.instance.gestationDays;

      await _db.confirmPregnancy(widget.doe.id, _isPregnant!, gestationDays);

      if (mounted) {
        Navigator.pop(context);
        widget.onComplete();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isPregnant! ? 'Bred status confirmed' : 'Marked as open'),
            backgroundColor: const Color(0xFF7B6BA0),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

