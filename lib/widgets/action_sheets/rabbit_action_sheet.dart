import 'package:flutter/material.dart';
import 'dart:io';
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE5FA),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      rabbit.fullName.isNotEmpty ? rabbit.fullName : rabbit.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1C1C1E),
                        letterSpacing: -0.5,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF8E8E93)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF4F0FA),
                  borderRadius: BorderRadius.circular(16),
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
                    // 4. Move - Resting Quarantine or Archive (or Open)
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
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDE5FA),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Move ${rabbit.name}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1C1C1E),
                          letterSpacing: -0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF8E8E93)),
                      onPressed: () => Navigator.pop(moveCtx),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F0FA),
                    borderRadius: BorderRadius.circular(16),
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
                      if (rabbit.status != RabbitStatus.resting)
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

  void _confirmDeleteRabbit(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Rabbit'),
        content: Text(
          'Are you sure you want to permanently delete "${rabbit.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Color(0xFF787774))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx); // close dialog
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
            },
            child: const Text('Delete', style: TextStyle(color: Color(0xFFD44C47), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
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
