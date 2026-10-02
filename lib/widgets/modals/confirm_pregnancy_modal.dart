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
          // Header banner (matches LogBirthModal)
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
            decoration: const BoxDecoration(
              color: Color(0xFFEADBEE),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Log Palpation',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF4A3E6D),
                        letterSpacing: 0.3,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close_rounded, color: Color(0xFF4A3E6D), size: 24),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _formatDoeHeader(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4A3E6D),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatBuckHeader(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4A3E6D),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(left: 42),
                        child: Text(
                          _formattedBredDate,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF4A3E6D),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Content Box Style (matches LogBirthModal)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kLilacWash,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kLilacLight),
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
          ),
          const SizedBox(height: 20),

          // Confirm Button
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isPregnant == null || _isSaving ? null : _saveResult,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7B6BA0),
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
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Confirm Palpation',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
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
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF7B6BA0) : const Color(0xFFE5DEEC),
            width: isSelected ? 2 : 1,
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
              size: 28,
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
                      fontSize: 15,
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
                size: 22,
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
