import 'package:flutter/material.dart';
import 'dart:io';
import '../models/rabbit.dart';
import '../services/format_utils.dart';
import '../constants/app_colors.dart';

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

    // Use global palette for the header background
    final Color headerColor = rabbit.type == RabbitType.doe
        ? kPinkWash // Solidifies Doe theme from global constants
        : kBlueWash; // Solidifies Buck theme from global constants

    return GestureDetector(
      onTap: onLongPress,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white, // Kept the full structure color white as requested
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE9E9E7)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2)
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // TOP HEADER SECTION (Colored matching the reference image)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // PROFILE PICTURE (Rounded square as per screenshot)
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: isPhotoValid
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.file(
                        File(photoPath!),
                        fit: BoxFit.cover,
                        key: ValueKey('${rabbit.id}_${photoPath}_${File(photoPath).lastModifiedSync().millisecondsSinceEpoch}'),
                        errorBuilder: (context, error, stackTrace) => _buildDefaultIcon(),
                        cacheWidth: 200,
                      ),
                    )
                        : _buildDefaultIcon(),
                  ),
                  const SizedBox(width: 12),

                  // HEADER INFO: Prefix, Name, Breed, Color
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${rabbit.breederPrefix != null ? '${rabbit.breederPrefix} ' : ''}${rabbit.name}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B),
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${rabbit.breed}${rabbit.color != null ? '\n${rabbit.color}' : ''}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF787774),
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // STATUS BADGE & MENU
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          rabbit.statusText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(rabbit.statusColor),
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      InkWell(
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Icon(Icons.more_vert, color: Color(0xFF787774), size: 20),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // BOTTOM DETAILS SECTION (White background, 2 columns)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Column 1
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Born:', rabbit.dateOfBirth != null ? FormatUtils.formatDate(rabbit.dateOfBirth!) : '-'),
                        const SizedBox(height: 4),
                        _buildInfoRow('Ear #:', rabbit.earNumber ?? rabbit.id),
                        const SizedBox(height: 4),
                        _buildInfoRow('Parents:', (rabbit.sireId != null || rabbit.damId != null) 
                            ? '${rabbit.sireId ?? '?'} x ${rabbit.damId ?? '?'}' 
                            : '-'),
                        const SizedBox(height: 4),
                        _buildInfoRow('Regn:', rabbit.registrationNumber ?? '-'),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Column 2
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildInfoRow('Age:', rabbit.dateOfBirth != null ? rabbit.age : '-'),
                        const SizedBox(height: 4),
                        _buildInfoRow('Weight:', rabbit.weight != null ? FormatUtils.formatWeight(rabbit.weight!) : '-'),
                        const SizedBox(height: 4),
                        if (rabbit.statusDetails != null && rabbit.statusDetails!.isNotEmpty)
                          _buildInfoRow('Note:', rabbit.statusDetails!),
                      ],
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

  Widget _buildDefaultIcon() {
    return Icon(
      rabbit.type == RabbitType.doe ? Icons.female : Icons.male,
      color: rabbit.type == RabbitType.doe ? kFemaleColor : kMaleColor,
      size: 28,
    );
  }

  // Helper widget to align the labels and values perfectly
  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 55, // Fixed width keeps the columns aligned
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF9B9A97),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}