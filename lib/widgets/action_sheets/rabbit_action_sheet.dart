import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/rabbit.dart';
import '../../services/database_service.dart';
import '../../services/settings_service.dart';
import '../../services/app_event_service.dart';
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
    final bool isQuarantined = rabbit.status == RabbitStatus.quarantine ||
        !rabbit.activeInRabbitry ||
        (rabbit.quarantineEndDate != null && DateTime.now().isBefore(rabbit.quarantineEndDate!));

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
                  children: isQuarantined
                      ? [
                          _buildOption(
                            'Log Breeding',
                            () => rabbit.type == RabbitType.buck
                                ? _showLogBreedingFromBuckModal(context)
                                : _showLogBreedingModal(context),
                          ),
                          _buildOption(
                            'Log Weight',
                            () => _showLogWeightModal(context),
                          ),
                          _buildOption(
                            'Log Health',
                            () => _showHealthRecordModal(context),
                          ),
                          _buildOption(
                            'Move to Active',
                            () => _moveToOpen(context),
                          ),
                          _buildOption(
                            'Archive',
                            () => _showArchiveModal(context),
                          ),
                        ]
                      : [
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
                          // Options below Log Health
                          if (rabbit.status == RabbitStatus.pregnant || rabbit.status == RabbitStatus.palpateDue) ...[
                            _buildOption(
                              'Quarantine',
                              () => _showQuarantineModal(context),
                            ),
                            _buildOption(
                              'Archive',
                              () => _showArchiveModal(context),
                            ),
                            _buildOption(
                              'Cancel Breeding',
                              () => _showCancelPregnancyDialog(context),
                              isDangerous: true,
                            ),
                          ] else if (rabbit.status == RabbitStatus.resting) ...[
                            _buildOption(
                              rabbit.type == RabbitType.buck ? 'Move to Active' : 'Move to Open',
                              () => _moveToOpen(context),
                            ),
                            _buildOption(
                              'Quarantine',
                              () => _showQuarantineModal(context),
                            ),
                            _buildOption(
                              'Archive',
                              () => _showArchiveModal(context),
                            ),
                          ] else ...[
                            // OPEN, NURSING, Active Bucks, etc.
                            if (rabbit.type != RabbitType.buck)
                              _buildOption(
                                'Move to Resting',
                                () => _moveToResting(context),
                              ),
                            _buildOption(
                              'Quarantine',
                              () => _showQuarantineModal(context),
                            ),
                            _buildOption(
                              'Archive',
                              () => _showArchiveModal(context),
                            ),
                          ],
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
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          const Text(
                            'Move',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF4A3E6D),
                              letterSpacing: -0.5,
                            ),
                          ),
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
                              color: rabbit.type == RabbitType.doe ? const Color(0xFFE04F9F) : const Color(0xFF2196F3),
                            ),
                          ),
                          if ((rabbit.earNumber?.trim().isNotEmpty == true ? rabbit.earNumber!.trim() : rabbit.id.trim()).isNotEmpty)
                            Text(
                              (rabbit.earNumber?.trim().isNotEmpty == true ? rabbit.earNumber!.trim() : rabbit.id.trim()),
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
                      // If resting or quarantine -> Move back to Active
                      if (rabbit.status == RabbitStatus.resting || rabbit.status == RabbitStatus.quarantine || !rabbit.activeInRabbitry)
                        _buildOption(
                          'Move to Active',
                          () async {
                            Navigator.pop(moveCtx);
                            Navigator.pop(context);
                            await _moveToOpen(context);
                          },
                        ),
                      if (rabbit.type != RabbitType.buck && rabbit.status != RabbitStatus.resting && rabbit.status != RabbitStatus.pregnant && rabbit.status != RabbitStatus.palpateDue)
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

  Future<RabbitStatus> _resolveActiveStatus(DatabaseService db) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (rabbit.type == RabbitType.doe) {
      // 1. Check active breeding (Bred / Palpate Due)
      if (rabbit.dueDate != null) {
        final dueDate = rabbit.dueDate!;
        final dueDay = DateTime(dueDate.year, dueDate.month, dueDate.day);
        final isUpcomingDue = !today.isAfter(dueDay.add(const Duration(days: 5)));
        final isRecentlyBred =
            rabbit.lastBreedDate == null || today.difference(rabbit.lastBreedDate!).inDays <= 38;
        final notYetKindled = rabbit.kindleDate == null ||
            rabbit.lastBreedDate == null ||
            rabbit.kindleDate!.isBefore(rabbit.lastBreedDate!);
        if (isUpcomingDue && isRecentlyBred && notYetKindled) {
          if (rabbit.palpationResult == null &&
              rabbit.palpationDate != null &&
              SettingsService.instance.palpationEnabled) {
            return RabbitStatus.palpateDue;
          }
          return RabbitStatus.pregnant;
        }
      }

      // 2. Check active nursing litter (Nursing)
      final litters = await db.getLitters();
      final doeLitters = litters.where((l) => l.doeId == rabbit.id).toList();
      for (final litter in doeLitters) {
        final s = litter.status.toLowerCase().trim();
        if (s.contains('archived') || s.contains('weaned') || s.contains('missed') || s.contains('died')) {
          continue;
        }
        if (litter.ageDays >= 49) continue;
        final hasActiveKits = litter.kits.any((k) {
          final ks = k.status.toLowerCase().trim();
          return ks != 'dead' &&
              ks != 'died' &&
              ks != 'deceased' &&
              ks != 'fostered' &&
              ks != 'archived' &&
              ks != 'sold' &&
              ks != 'butchered' &&
              ks != 'cull' &&
              ks != 'weaned';
        });
        final aliveCount = litter.aliveKits ?? 0;
        final totalCount = litter.totalKits ?? 0;
        if ((litter.kits.isNotEmpty && hasActiveKits) ||
            aliveCount > 0 ||
            totalCount > 0 ||
            s == 'nursing') {
          return RabbitStatus.nursing;
        }
      }
      if (rabbit.currentLitterSize != null &&
          rabbit.currentLitterSize! > 0 &&
          (rabbit.kindleDate == null || now.difference(rabbit.kindleDate!).inDays < 49)) {
        return RabbitStatus.nursing;
      }
    }

    // 3. Check Grow-Out (< 5 months old or previously growout)
    bool isUnderFiveMonths = false;
    if (rabbit.dateOfBirth != null) {
      final dob = rabbit.dateOfBirth!;
      final fiveMonthsDate = DateTime(dob.year, dob.month + 5, dob.day);
      isUnderFiveMonths = now.isBefore(fiveMonthsDate);
    }
    final prefs = await SharedPreferences.getInstance();
    final savedStatusStr = prefs.getString('pre_quarantine_status_${rabbit.id}');
    if (isUnderFiveMonths || (rabbit.dateOfBirth == null && savedStatusStr == RabbitStatus.growout.toString())) {
      return RabbitStatus.growout;
    }

    // 4. Default active adult status
    return rabbit.type == RabbitType.buck ? RabbitStatus.active : RabbitStatus.open;
  }

  Future<void> _moveToOpen(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    try {
      final db = DatabaseService();
      final newStatus = await _resolveActiveStatus(db);
      await db.endQuarantine(rabbit.id, newStatus, null);
      await db.cancelQuarantineTasks(rabbit.id);
      notifyDataChanged();
      onActionComplete();
      messenger.showSnackBar(
        SnackBar(
          content: Text('${rabbit.name} moved to Active'),
          backgroundColor: const Color(0xFF7B6BA0),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error moving rabbit: $e'),
          backgroundColor: const Color(0xFFE63946),
        ),
      );
    }
  }

  Future<void> _moveToResting(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    try {
      final db = DatabaseService();
      final updated = rabbit.copyWith(status: RabbitStatus.resting);
      await db.updateRabbit(updated);
      onActionComplete();
      messenger.showSnackBar(
        SnackBar(
          content: Text('${rabbit.name} moved to RESTING'),
          backgroundColor: const Color(0xFF7B6BA0),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
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
  Future<void> _openActionModal(
    BuildContext sheetContext,
    Widget Function(VoidCallback complete) builder, {
    bool enableDrag = true,
  }) async {
    bool didComplete = false;
    await showModalBottomSheet(
      context: sheetContext,
      isScrollControlled: true,
      enableDrag: enableDrag,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => builder(() {
        didComplete = true;
        onActionComplete();
      }),
    );
    if (didComplete && sheetContext.mounted) {
      Navigator.pop(sheetContext);
    }
  }

  void _showLogBreedingModal(BuildContext context) {
    _openActionModal(
      context,
      (complete) => LogBreedingModal(
        doe: rabbit,
        onComplete: complete,
      ),
    );
  }

  void _showLogBreedingFromBuckModal(BuildContext context) {
    _openActionModal(
      context,
      (complete) => LogBreedingFromBuckModal(
        buck: rabbit,
        onComplete: complete,
      ),
    );
  }

  void _showConfirmPregnancyModal(BuildContext context) {
    _openActionModal(
      context,
      (complete) => ConfirmPregnancyModal(
        doe: rabbit,
        onComplete: complete,
      ),
      enableDrag: false,
    );
  }

  void _showLogBirthModal(BuildContext context) {
    _openActionModal(
      context,
      (complete) => LogBirthModal(
        doe: rabbit,
        onComplete: complete,
      ),
      enableDrag: false,
    );
  }

  void _showWeanLitterModal(BuildContext context) {
    _openActionModal(
      context,
      (complete) => WeanLitterModal(
        doe: rabbit,
        onComplete: complete,
      ),
    );
  }

  void _showLogWeightModal(BuildContext context) {
    _openActionModal(
      context,
      (complete) => LogWeightModal(
        rabbit: rabbit,
        onComplete: complete,
      ),
    );
  }

  void _showHealthRecordModal(BuildContext context) {
    _openActionModal(
      context,
      (complete) => HealthRecordModal(
        rabbit: rabbit,
        onComplete: complete,
      ),
    );
  }

  void _showMoveCageModal(BuildContext context) {
    _openActionModal(
      context,
      (complete) => MoveCageModal(
        rabbit: rabbit,
        onComplete: complete,
      ),
    );
  }

  void _showQuarantineModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => QuarantineModal(
        rabbit: rabbit,
        onComplete: () {
          if (context.mounted) {
            Navigator.pop(context);
          }
          onActionComplete();
        },
      ),
    );
  }

  void _showStopQuarantineModal(BuildContext context) {
    _openActionModal(
      context,
      (complete) => StopQuarantineModal(
        rabbit: rabbit,
        onComplete: complete,
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
      builder: (modalCtx) => ArchiveModal(
        rabbit: rabbit,
        onComplete: () {
          if (context.mounted) {
            Navigator.pop(context);
          }
          onActionComplete();
        },
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

  void _showCancelPregnancyDialog(BuildContext actionSheetContext) {
    showDialog(
      context: actionSheetContext,
      builder: (dialogCtx) => AlertDialog(
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
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Keep Status', style: TextStyle(color: Color(0xFF787774))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              if (actionSheetContext.mounted) {
                Navigator.pop(actionSheetContext);
              }
              try {
                final db = DatabaseService();
                await db.cancelPregnancy(rabbit.id);
                onActionComplete();
                ScaffoldMessenger.of(actionSheetContext).showSnackBar(
                  SnackBar(
                    content: Text('Bred status cancelled for ${rabbit.name}'),
                    backgroundColor: const Color(0xFF7B6BA0),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(actionSheetContext).showSnackBar(
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
