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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _buildHeader(context),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _buildActionItems(context),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF5F5F5),
              image: rabbit.photos != null && rabbit.photos!.isNotEmpty
                  ? DecorationImage(
                      image: FileImage(File(rabbit.photos!.first)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: rabbit.photos == null || rabbit.photos!.isEmpty
                ? Icon(
                    rabbit.type == RabbitType.doe ? Icons.female : Icons.male,
                    color: rabbit.type == RabbitType.doe ? const Color(0xFF9C6ADE) : const Color(0xFF2E7BB5),
                    size: 28,
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${rabbit.id} • ${rabbit.name}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Color(rabbit.statusColor).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        rabbit.statusText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(rabbit.statusColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      rabbit.breed,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF787774),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFF787774)),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActionItems(BuildContext context) {
    List<Widget> items = [];

    // DOE-SPECIFIC ACTIONS - Primary action based on status
    if (rabbit.type == RabbitType.doe) {
      final primaryAction = _getPrimaryAction(context);
      if (primaryAction != null) {
        items.add(primaryAction);
      }
    }

    // BUCK-SPECIFIC ACTIONS
    if (rabbit.type == RabbitType.buck) {
      // Active Buck: Primary action is Record Breeding
      if (rabbit.status == RabbitStatus.active) {
        items.add(_buildPrimaryActionItem(
          context,
          icon: Icons.favorite,
          label: 'Record Breeding',
          subtitle: 'Select a doe and log breeding',
          onTap: () => _showLogBreedingFromBuckModal(context),
        ));
        // Toggle to inactive
        items.add(_buildActionItem(
          context,
          icon: Icons.pause_circle_outline,
          iconColor: const Color(0xFFCB8347),
          label: 'Mark as Inactive',
          subtitle: 'Temporarily unavailable for breeding',
          onTap: () => _toggleBuckStatus(context),
        ));
      } else if (rabbit.status == RabbitStatus.inactive) {
        // Inactive Buck: Primary action is Mark as Active, secondary is Record Breeding
        items.add(_buildPrimaryActionItem(
          context,
          icon: Icons.play_circle_outline,
          label: 'Mark as Active',
          subtitle: 'Available for breeding',
          onTap: () => _toggleBuckStatus(context),
        ));
        items.add(_buildActionItem(
          context,
          icon: Icons.favorite_outline,
          iconColor: const Color(0xFF2E7BB5),
          label: 'Record Breeding',
          subtitle: 'Select a doe and log breeding',
          onTap: () => _showLogBreedingFromBuckModal(context),
        ));
      }
    }

    // VIEW PROFILE
    items.add(_buildActionItem(
      context,
      icon: Icons.person_outline,
      iconColor: const Color(0xFF0F7B6C),
      label: 'View Profile',
      subtitle: 'See full details and history',
      onTap: () => _viewProfile(context),
      showArrow: true,
    ));

    // Log Weight
    items.add(_buildActionItem(
      context,
      icon: Icons.monitor_weight_outlined,
      iconColor: const Color(0xFF6B6B6B),
      label: 'Log Weight',
      subtitle: 'Record current weight',
      onTap: () => _showLogWeightModal(context),
    ));

    // Health Record
    items.add(_buildActionItem(
      context,
      icon: Icons.medical_services_outlined,
      iconColor: const Color(0xFF6B6B6B),
      label: 'Health Record',
      subtitle: 'Add health note or treatment',
      onTap: () => _showHealthRecordModal(context),
    ));

    // Move Cage
    items.add(_buildActionItem(
      context,
      icon: Icons.swap_horiz,
      iconColor: const Color(0xFF6B6B6B),
      label: 'Move Cage',
      subtitle: 'Change location',
      onTap: () => _showMoveCageModal(context),
    ));

    // Quarantine (if not already in quarantine)
    if (rabbit.status != RabbitStatus.quarantine) {
      items.add(_buildActionItem(
        context,
        icon: Icons.shield_outlined,
        iconColor: const Color(0xFFCB8347),
        label: 'Add to Quarantine',
        subtitle: 'Isolate for health/observation',
        onTap: () => _showQuarantineModal(context),
      ));
    }

    // Stop Quarantine (if in quarantine)
    if (rabbit.status == RabbitStatus.quarantine) {
      items.add(_buildPrimaryActionItem(
        context,
        icon: Icons.check_circle_outline,
        label: 'Stop Quarantine',
        subtitle: rabbit.daysInQuarantineRemaining != null ? '${rabbit.daysInQuarantineRemaining} days remaining' : 'Release from quarantine',
        onTap: () => _showStopQuarantineModal(context),
      ));
    }

    // Secondary actions based on status
    if (rabbit.status == RabbitStatus.resting && rabbit.type == RabbitType.doe) {
      items.add(_buildActionItem(
        context,
        icon: Icons.favorite_outline,
        iconColor: const Color(0xFF2E7BB5),
        label: 'Open to Breeding',
        subtitle: 'Mark as available for breeding',
        onTap: () => _openToBreeding(context),
      ));
    }

    // Cancel Pregnancy for palpateDue or pregnant does
    if (rabbit.type == RabbitType.doe && (rabbit.status == RabbitStatus.palpateDue || rabbit.status == RabbitStatus.pregnant)) {
      items.add(_buildActionItem(
        context,
        icon: Icons.cancel_outlined,
        iconColor: const Color(0xFFD44C47),
        label: 'Cancel Pregnancy',
        subtitle: 'Remove pregnancy and related tasks',
        onTap: () => _showCancelPregnancyDialog(context),
      ));
    }

    // Growout promotion - Show days remaining AND age
    if (rabbit.status == RabbitStatus.growout) {
      String subtitle = 'Mark as breeding age';
      if (rabbit.daysUntilMature != null && rabbit.daysUntilMature! > 0) {
        subtitle = '${rabbit.daysUntilMature} days remaining • Age: ${rabbit.age}';
      } else {
        subtitle = 'Ready to promote • Age: ${rabbit.age}';
      }
      items.add(_buildActionItem(
        context,
        icon: Icons.arrow_upward,
        iconColor: const Color(0xFF0F7B6C),
        label: 'Promote to Breeder',
        subtitle: subtitle,
        onTap: () => _promoteToBreeder(context),
      ));
    }

    // Archive
    items.add(_buildActionItem(
      context,
      icon: Icons.archive_outlined,
      iconColor: const Color(0xFFD44C47),
      label: 'Archive Rabbit',
      subtitle: 'Sold, deceased, or culled',
      onTap: () => _showArchiveModal(context),
    ));

    return items;
  }

  Widget? _getPrimaryAction(BuildContext context) {
    switch (rabbit.status) {
      case RabbitStatus.open:
        return _buildPrimaryActionItem(
          context,
          icon: Icons.favorite,
          label: 'Log Breeding',
          subtitle: 'Record a breeding event',
          onTap: () => _showLogBreedingModal(context),
        );

      case RabbitStatus.palpateDue:
        return _buildPrimaryActionItem(
          context,
          icon: Icons.pregnant_woman,
          label: 'Confirm Pregnancy',
          subtitle: 'Record palpation result',
          onTap: () => _showConfirmPregnancyModal(context),
        );

      case RabbitStatus.pregnant:
        return _buildPrimaryActionItem(
          context,
          icon: Icons.child_friendly,
          label: 'Log Birth',
          subtitle: 'Record kindle date and kit count',
          onTap: () => _showLogBirthModal(context),
        );

      case RabbitStatus.nursing:
        return _buildPrimaryActionItem(
          context,
          icon: Icons.child_care,
          label: 'Wean Litter',
          subtitle: 'Complete nursing and wean kits',
          onTap: () => _showWeanLitterModal(context),
        );

      default:
        return null;
    }
  }

  Widget _buildPrimaryActionItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: const BoxDecoration(
          color: Color(0xFFF0F7F6),
          border: Border(
            left: BorderSide(color: Color(0xFF0F7B6C), width: 4),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF0F7B6C).withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF0F7B6C), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F7B6C),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF787774),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF0F7B6C)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
    bool showArrow = false,
  }) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9B9A97),
                    ),
                  ),
                ],
              ),
            ),
            if (showArrow) const Icon(Icons.chevron_right, color: Color(0xFFD0D0D0)),
          ],
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
        backgroundColor: Color(0xFF0F7B6C),
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
        backgroundColor: Color(0xFF0F7B6C),
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
          backgroundColor: const Color(0xFF0F7B6C),
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
        title: const Text('Cancel Pregnancy'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to cancel the pregnancy for ${rabbit.name}?',
              style: const TextStyle(fontSize: 14, color: Color(0xFF37352F)),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFFCB8347).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFCB8347), size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will also delete all related tasks (palpation, nest box, kindle, wean)',
                      style: TextStyle(fontSize: 12, color: const Color(0xFFCB8347).withOpacity(0.9)),
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
            child: const Text('Keep Pregnancy', style: TextStyle(color: Color(0xFF787774))),
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
                    content: Text('Pregnancy cancelled for ${rabbit.name}'),
                    backgroundColor: const Color(0xFF0F7B6C),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Cancel Pregnancy', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
