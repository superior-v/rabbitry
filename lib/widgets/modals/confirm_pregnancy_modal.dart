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
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
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
                  'Palpation result for ${widget.doe.name} (${widget.doe.id})',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF616161),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Color(0xFF424242), size: 24),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Purple Container holding options
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFD6CDEC).withOpacity(0.6),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              children: [
                _buildOption(
                  title: 'Yes, Bred',
                  isYes: true,
                  isSelected: _isPregnant == true,
                  onTap: () => setState(() => _isPregnant = true),
                ),
                const SizedBox(height: 10),
                _buildOption(
                  title: 'No, Not Bred',
                  isYes: false,
                  isSelected: _isPregnant == false,
                  onTap: () => setState(() => _isPregnant = false),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 52,
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
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Confirm',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildOption({
    required String title,
    required bool isYes,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final activeBorderColor = isYes ? const Color(0xFF7B6BA0) : const Color(0xFFD9534F);
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeBorderColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isYes ? Icons.check_circle : Icons.cancel,
              color: isYes ? const Color(0xFF7B6BA0) : const Color(0xFFD9534F),
              size: 28,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF212121),
                ),
              ),
            ),
            if (isYes && isSelected)
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
      final gestationDays = SettingsService.instance.gestationDays;

      await _db.confirmPregnancy(widget.doe.id, _isPregnant!, gestationDays);

      Navigator.pop(context);
      widget.onComplete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isPregnant! ? 'Bred status confirmed' : 'Marked as open'),
          backgroundColor: Color(0xFF7B6BA0),
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
