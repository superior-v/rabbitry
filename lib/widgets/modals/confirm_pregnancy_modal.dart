import 'package:flutter/material.dart';
import '../../models/rabbit.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
import '../../services/format_utils.dart';
import '../../constants/app_colors.dart';

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
  bool? _isPregnant = true;
  bool _isSaving = false;
  Rabbit? _buck;
  String? _buckName;

  @override
  void initState() {
    super.initState();
    if (widget.doe.lastBreedBuckId != null && widget.doe.lastBreedBuckId!.isNotEmpty) {
      _db.getRabbit(widget.doe.lastBreedBuckId!).then((b) {
        if (b != null && mounted) {
          setState(() {
            _buck = b;
            _buckName = b.fullName.isNotEmpty ? b.fullName : b.name;
          });
        }
      });
    }
  }

  String _formatDoeHeader() {
    final prefix = (widget.doe.breederPrefix ?? '').trim();
    final name = widget.doe.name.trim();
    final ear = (widget.doe.earNumber?.trim().isNotEmpty == true
            ? widget.doe.earNumber!.trim()
            : widget.doe.id.trim())
        .toUpperCase();

    final namePart = prefix.isNotEmpty ? '$prefix $name' : name;
    if (ear.isNotEmpty && !namePart.toUpperCase().endsWith(ear)) {
      return '$namePart $ear';
    }
    return namePart;
  }

  String _formatBuckHeader() {
    if (_buck != null) {
      final prefix = (_buck!.breederPrefix ?? '').trim();
      final name = _buck!.name.trim();
      final ear = (_buck!.earNumber?.trim().isNotEmpty == true
              ? _buck!.earNumber!.trim()
              : _buck!.id.trim())
          .toUpperCase();
      final namePart = prefix.isNotEmpty ? '$prefix $name' : name;
      if (ear.isNotEmpty && !namePart.toUpperCase().endsWith(ear)) {
        return '$namePart $ear';
      }
      return namePart;
    }

    final fallbackName = (_buckName ?? widget.doe.lastBreedBuckId ?? 'Unknown Sire').trim();
    final buckId = (widget.doe.lastBreedBuckId ?? '').trim();
    if (buckId.isNotEmpty && !fallbackName.toUpperCase().contains(buckId.toUpperCase())) {
      return '$fallbackName ${buckId.toUpperCase()}';
    }
    return fallbackName;
  }

  String get _formattedBredDate {
    final date = widget.doe.lastBreedDate;
    if (date != null) {
      return FormatUtils.formatDate(date);
    }
    return FormatUtils.formatDate(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header banner (matches Consistency.jpg & task modals)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            decoration: const BoxDecoration(
              color: kLilacLight,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(bottom: BorderSide(color: kLilac, width: 1)),
            ),
            child: Column(
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4A3E6D).withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Log Palpation',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4A3E6D),
                        letterSpacing: -0.3,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close_rounded, color: Color(0xFF4A3E6D), size: 20),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Doe & Sire Info
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: kLilacWash,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kLilacLight),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _formatDoeHeader(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF55555C),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatBuckHeader(),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF55555C),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formattedBredDate,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4A3E6D),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Options matching Consistency.jpg New Task dropdown style
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kLilacLight),
              ),
              child: Column(
                children: [
                  _buildOption(
                    title: 'Yes, Bred',
                    subtitle: 'Continue gestation pipeline',
                    isYes: true,
                    isSelected: _isPregnant == true,
                    isAlt: false,
                    onTap: () => setState(() => _isPregnant = true),
                  ),
                  const SizedBox(height: 8),
                  _buildOption(
                    title: 'No, Not Bred (Open)',
                    subtitle: 'Reset to open status',
                    isYes: false,
                    isSelected: _isPregnant == false,
                    isAlt: true,
                    onTap: () => setState(() => _isPregnant = false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Confirm Button matching Consistency.jpg bottom Save Button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isPregnant == null || _isSaving ? null : _saveResult,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE6BEFE),
                  foregroundColor: const Color(0xFF4A3E6D),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
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
                        'Confirm Palpation',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF4A3E6D),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOption({
    required String title,
    required String subtitle,
    required bool isYes,
    required bool isSelected,
    required bool isAlt,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFF6F0FD)
              : (isAlt ? const Color(0xFFF9F7FC) : Colors.white),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? const Color(0xFF8B5CF6) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFF94A3B8),
                  width: isSelected ? 5.5 : 1.5,
                ),
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? const Color(0xFF4A3E6D) : const Color(0xFF3A3A3C),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF787774),
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
            content: Text(_isPregnant! ? 'Palpation logged: Confirmed bred' : 'Palpation logged: Marked as open'),
            backgroundColor: const Color(0xFF7B6BA0),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
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
