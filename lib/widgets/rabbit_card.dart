import 'package:flutter/material.dart';
import 'dart:io';
import '../models/rabbit.dart';

class RabbitCard extends StatelessWidget {
  final Rabbit rabbit;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const RabbitCard({
    Key? key,
    required this.rabbit,
    required this.onTap,
    this.onLongPress,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool hasPhoto = rabbit.photos != null && rabbit.photos!.isNotEmpty && rabbit.photos!.first.isNotEmpty;
    final String? photoPath = hasPhoto ? rabbit.photos!.first : null;
    final bool isPhotoValid = photoPath != null && File(photoPath).existsSync();

    return GestureDetector(
      onTap: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE9E9E7)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // PROFILE PICTURE
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: rabbit.type == RabbitType.doe ? const Color(0xFFF3E8FF) : const Color(0xFFE8F4FA),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: rabbit.type == RabbitType.doe ? const Color(0xFF9C6ADE) : const Color(0xFF2E7BB5),
                  width: 2,
                ),
              ),
              child: isPhotoValid
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.file(
                        File(photoPath!),
                        fit: BoxFit.cover,
                        // ✅ ADD UNIQUE KEY WITH TIMESTAMP
                        key: ValueKey('${rabbit.id}_${photoPath}_${File(photoPath).lastModifiedSync().millisecondsSinceEpoch}'),
                        errorBuilder: (context, error, stackTrace) => _buildDefaultIcon(),
                        // ✅ ADD CACHE OPTIONS
                        cacheWidth: 200,
                        cacheHeight: 200,
                      ),
                    )
                  : _buildDefaultIcon(),
            ),
            const SizedBox(width: 12),

            // RABBIT INFO
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name and ID
                  Row(
                    children: [
                      Text(
                        rabbit.id,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          rabbit.name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1E293B),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Location
                  Row(
                    children: [
                      const Icon(Icons.location_on, size: 12, color: Color(0xFF787774)),
                      const SizedBox(width: 4),
                      Text(
                        '${rabbit.location ?? 'Unassigned'} • ${rabbit.cage ?? '-'}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF787774),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(rabbit.statusColor).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      rabbit.statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(rabbit.statusColor),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Details
                  if (rabbit.statusDetails != null)
                    Row(
                      children: [
                        const Icon(Icons.info_outline, size: 12, color: Color(0xFF9B9A97)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            rabbit.statusDetails!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9B9A97),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.pets, size: 12, color: Color(0xFF9B9A97)),
                        const SizedBox(width: 4),
                        Text(
                          rabbit.breed,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9B9A97),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // THREE DOTS MENU
            GestureDetector(
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(
                  Icons.more_vert,
                  color: Color(0xFF787774),
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🎨 Helper method for default icon
  Widget _buildDefaultIcon() {
    return Icon(
      rabbit.type == RabbitType.doe ? Icons.female : Icons.male,
      color: rabbit.type == RabbitType.doe ? const Color(0xFF9C6ADE) : const Color(0xFF2E7BB5),
      size: 28,
    );
  }
}
