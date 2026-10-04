import 'package:flutter/material.dart';
import '../../models/rabbit.dart';
import '../../services/database_service.dart';
import '../../screens/rabbit_detail_screen.dart';
import 'package:rearticle_app/widgets/modals/log_breeding_modal.dart';
import '../modals/confirm_pregnancy_modal.dart';
import '../modals/log_birth_modal.dart';
import '../modals/wean_litter_modal.dart';
import '../modals/log_weight_modal.dart';
import '../modals/health_record_modal.dart';
import '../modals/move_cage_modal.dart';
import '../modals/archive_modal.dart';
import '../modals/quarantine_modal.dart';
import '../modals/stop_quarantine_modal.dart';
import '../modals/log_breeding_from_buck_modal.dart';
import '../purple_dialog.dart';

class RabbitActionSheet extends StatelessWidget {
  final Rabbit rabbit;
  final VoidCallback onActionComplete;

  const RabbitActionSheet({
    Key? key,
    required this.rabbit,
    required this.onActionComplete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDoe = rabbit.type == RabbitType.doe;
    final earNum = rabbit.earNumber?.trim().isNotEmpty == true ? rabbit.earNumber!.trim() : rabbit.id.trim();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top Purple Header Banner (matches Home Log Breeding style)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
              decoration: const BoxDecoration(
                color: Color(0xFFEADBEE),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 2,
                      children: [
                        if ((rabbit.breederPrefix ?? '').trim().isNotEmpty)
                          Text(
                            rabbit.breederPrefix!.trim(),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF787774),
                            ),
                          ),
                        Text(
                          rabbit.name.trim(),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDoe ? const Color(0xFFE04F9F) : const Color(0xFF2196F3),
                          ),
                        ),
                        if (earNum.isNotEmpty)
                          Text(
                            earNum,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF787774),
                            ),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.close_rounded, size: 22, color: Color(0xFF4A3E6D)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFEADBEE),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD4C2E2), width: 1.0),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // 1. Breeding actions: NONE for Resting / Archived
                    if (rabbit.status != RabbitStatus.resting && rabbit.status != RabbitStatus.archived) ...[
                      if (rabbit.status == RabbitStatus.pregnant || rabbit.status == RabbitStatus.palpateDue) ...[
                        _buildOption(
                          'Log Palpation',
                          () => _showConfirmPregnancyModal(context),
                        ),
                        _buildOption(
                          'Log Birth',
                          () => _showLogBirthModal(context),
                        ),
                      ] else ...[
                        _buildOption(
                          'Log Breeding',
                          () => rabbit.type == RabbitType.buck
                              ? _showLogBreedingFromBuckModal(context)
                              : _showLogBreedingModal(context),
                        ),
                      ],
                    ],
                    // 2. Log weight
                    _buildOption(
                      'Log Weight',
                      () => _showLogWeightModal(context),
                    ),
                    // 3. Log Health
                    _buildOption(
                      'Log Health',
                      () => _showHealthRecordModal(context),
                    ),
                    // 4. Move - For a Bred Doe REPLACE with Quarantine
                    if (rabbit.status == RabbitStatus.pregnant || rabbit.status == RabbitStatus.palpateDue)
                      _buildOption(
                        'Quarantine',
                        () => _showQuarantineModal(context),
                      )
                    else
                      _buildOption(
                        'Move',
                        () => _showMoveOptions(context),
                      ),
                    // 5. Cancel Breeding (if Bred)
                    if (rabbit.status == RabbitStatus.pregnant || rabbit.status == RabbitStatus.palpateDue)
                      _buildOption(
                        'Cancel Breeding',
                        () => _showCancelPregnancyDialog(context),
                        isDangerous: true,
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  void _showMoveOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (moveCtx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
                decoration: const BoxDecoration(
                  color: Color(0xFFEADBEE),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Move ${rabbit.name}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF4A3E6D),
                          letterSpacing: -0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(moveCtx),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.close_rounded, size: 22, color: Color(0xFF4A3E6D)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFEADBEE),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD4C2E2), width: 1.0),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      // If resting or quarantine -> Move back to OPEN
                      if (rabbit.status == RabbitStatus.resting || rabbit.status == RabbitStatus.quarantine)
                        _buildOption(
                          'Move to Open',
                          () async {
                            Navigator.pop(moveCtx);
                            Navigator.pop(context);
                            await _moveToOpen(context);
                          },
                        ),
                      if (rabbit.status != RabbitStatus.resting && rabbit.status != RabbitStatus.pregnant && rabbit.status != RabbitStatus.palpateDue)
                        _buildOption(
                          'Resting',
                          () async {
                            Navigator.pop(moveCtx);
                            Navigator.pop(context);
                            await _moveToResting(context);
                          },
                        ),
                      if (rabbit.status != RabbitStatus.quarantine)
                        _buildOption(
                          'Quarantine',
                          () {
                            Navigator.pop(moveCtx);
                            Navigator.pop(context);
                            _showQuarantineModal(context);
                          },
                        ),
                      _buildOption(
                        'Archive',
                        () {
                          Navigator.pop(moveCtx);
                          Navigator.pop(context);
                          _showArchiveModal(context);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _moveToOpen(BuildContext context) async {
    try {
      final db = DatabaseService();
      final newStatus = rabbit.type == RabbitType.buck ? RabbitStatus.active : RabbitStatus.open;
      final updated = rabbit.copyWith(
        status: newStatus,
        quarantineStartDate: null,
        quarantineEndDate: null,
        quarantineReason: null,
      );
      await db.updateRabbit(updated);
      onActionComplete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${rabbit.name} moved to OPEN'),
          backgroundColor: const Color(0xFF7B6BA0),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error moving rabbit: $e'),
          backgroundColor: const Color(0xFFE63946),
        ),
      );
    }
  }

  Future<void> _moveToResting(BuildContext context) async {
    try {
      final db = DatabaseService();
      final updated = rabbit.copyWith(status: RabbitStatus.resting);
      await db.updateRabbit(updated);
      onActionComplete();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${rabbit.name} moved to RESTING'),
          backgroundColor: const Color(0xFF7B6BA0),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error moving rabbit: $e'),
          backgroundColor: const Color(0xFFE63946),
        ),
      );
    }
  }

  Widget _buildOption(String label, VoidCallback onTap, {bool isDangerous = false}) {
    final Color textColor = isDangerous ? const Color(0xFFD94452) : const Color(0xFF463466);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      width: double.infinity,
      child: InkWell(
        onTap: () {
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE5E0F2), width: 0.8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }

  // Navigation to Profile
  void _viewProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RabbitDetailScreen(rabbit: rabbit),
      ),
    );
  }

  // Action handlers
  void _showLogBreedingModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LogBreedingModal(
        doe: rabbit,
        onComplete: onActionComplete,
      ),
    );
  }

  void _showLogBreedingFromBuckModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LogBreedingFromBuckModal(
        buck: rabbit,
        onComplete: onActionComplete,
      ),
    );
  }

  void _showConfirmPregnancyModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => ConfirmPregnancyModal(
        doe: rabbit,
        onComplete: onActionComplete,
      ),
    );
  }

  void _showLogBirthModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (context) => LogBirthModal(
        doe: rabbit,
        onComplete: onActionComplete,
      ),
    );
  }

  void _showWeanLitterModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WeanLitterModal(
        doe: rabbit,
        onComplete: onActionComplete,
      ),
    );
  }

  void _showLogWeightModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LogWeightModal(
        rabbit: rabbit,
        onComplete: onActionComplete,
      ),
    );
  }

  void _showHealthRecordModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => HealthRecordModal(
        rabbit: rabbit,
        onComplete: onActionComplete,
      ),
    );
  }

  void _showMoveCageModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MoveCageModal(
        rabbit: rabbit,
        onComplete: onActionComplete,
      ),
    );
  }

  void _showQuarantineModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuarantineModal(
        rabbit: rabbit,
        onComplete: onActionComplete,
      ),
    );
  }

  void _showStopQuarantineModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StopQuarantineModal(
        rabbit: rabbit,
        onComplete: onActionComplete,
      ),
    );
  }

  void _confirmDeleteRabbit(BuildContext context) async {
    final confirmed = await showBrightPurpleDialog<bool>(
      context: context,
      title: 'Delete Rabbit',
      content:
          'Are you sure you want to permanently delete "${rabbit.name}"? This action cannot be undone.',
      cancelText: 'Cancel',
      confirmText: 'Delete',
      isDestructive: true,
    );

    if (confirmed == true) {
      final db = DatabaseService();
      await db.deleteRabbit(rabbit.id);
      onActionComplete();
      if (context.mounted) {
        Navigator.pop(context); // close action sheet
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${rabbit.name} deleted'),
            backgroundColor: const Color(0xFFD44C47),
          ),
        );
      }
    }
  }

  void _showArchiveModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ArchiveModal(
        rabbit: rabbit,
        onComplete: onActionComplete,
      ),
    );
  }

  Future<void> _openToBreeding(BuildContext context) async {
    final db = DatabaseService();
    await db.markOpenForBreeding(rabbit.id);
    onActionComplete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Marked as open for breeding'),
        backgroundColor: Color(0xFF7B6BA0),
      ),
    );
  }

  Future<void> _promoteToBreeder(BuildContext context) async {
    final db = DatabaseService();
    await db.promoteToBreeder(rabbit.id);
    onActionComplete();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Promoted to breeder'),
        backgroundColor: Color(0xFF7B6BA0),
      ),
    );
  }

  Future<void> _toggleBuckStatus(BuildContext context) async {
    final newStatus = rabbit.status == RabbitStatus.active ? RabbitStatus.inactive : RabbitStatus.active;

    final updatedRabbit = rabbit.copyWith(status: newStatus);

    try {
      await DatabaseService().updateRabbit(updatedRabbit);
      onActionComplete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newStatus == RabbitStatus.active ? '${rabbit.name} marked as ACTIVE' : '${rabbit.name} marked as INACTIVE',
          ),
          backgroundColor: const Color(0xFF7B6BA0),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating status: $e'),
          backgroundColor: const Color(0xFFE63946),
        ),
      );
    }
  }

  void _showCancelPregnancyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Bred Status'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel the bred status for ${rabbit.name}?',
              style: const TextStyle(fontSize: 14, color: Color(0xFF37352F)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFF8B5CF6), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will also delete all related tasks (palpation, nest box, kindle, wean)',
                      style: TextStyle(fontSize: 12, color: const Color(0xFF8B5CF6).withOpacity(0.9)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Status', style: TextStyle(color: Color(0xFF787774))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                final db = DatabaseService();
                await db.cancelPregnancy(rabbit.id);
                onActionComplete();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Bred status cancelled for ${rabbit.name}'),
                    backgroundColor: const Color(0xFF7B6BA0),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: const Color(0xFFE63946),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFD44C47),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Cancel Pregnancy', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
