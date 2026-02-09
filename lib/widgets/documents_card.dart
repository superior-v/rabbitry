import 'package:flutter/material.dart';
import '../models/rabbit.dart';

class DocumentsCard extends StatelessWidget {
  final Rabbit rabbit;

  const DocumentsCard({Key? key, required this.rabbit}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFE9E9E7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(0xFFF7F7F5),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'DOCUMENTS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF787774),
                    letterSpacing: 0.5,
                  ),
                ),
                GestureDetector(
                  onTap: () => _showUploadDialog(context),
                  child: Row(
                    children: [
                      Icon(Icons.upload_file, size: 16, color: Color(0xFF787774)),
                      SizedBox(width: 4),
                      Text(
                        'Upload',
                        style: TextStyle(
                          fontSize: 12,
                          color: Color(0xFF787774),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildDocumentItem(
            context,
            Icons.picture_as_pdf,
            'Registration Papers',
            'PDF • 2.4 MB',
            'Jan 15, 2025',
            Color(0xFFC47070),
          ),
          _buildDocumentItem(
            context,
            Icons.picture_as_pdf,
            'Pedigree Certificate',
            'PDF • 1.8 MB',
            'Mar 20, 2024',
            Color(0xFFC47070),
          ),
          _buildDocumentItem(
            context,
            Icons.image,
            'Show Photos',
            'JPG • 3.2 MB',
            'Sep 10, 2025',
            Color(0xFF5B8AD0),
          ),
          _buildDocumentItem(
            context,
            Icons.description,
            'Health Records',
            'PDF • 1.1 MB',
            'Dec 5, 2025',
            Color(0xFFC47070),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentItem(
      BuildContext context,
      IconData icon,
      String name,
      String details,
      String date,
      Color color,
      ) {
    return InkWell(
      onTap: () => _showDocumentOptions(context, name),
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFF7F7F5))),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF37352F),
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    details,
                    style: TextStyle(fontSize: 12, color: Color(0xFF787774)),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  date,
                  style: TextStyle(fontSize: 11, color: Color(0xFF9B9A97)),
                ),
                SizedBox(height: 4),
                Icon(Icons.more_vert, size: 16, color: Color(0xFF9B9A97)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showUploadDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Upload Document',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            _buildUploadOption(context, Icons.camera_alt, 'Take Photo', () {
              Navigator.pop(context);
            }),
            _buildUploadOption(context, Icons.photo_library, 'Choose from Gallery', () {
              Navigator.pop(context);
            }),
            _buildUploadOption(context, Icons.insert_drive_file, 'Choose File', () {
              Navigator.pop(context);
            }),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadOption(BuildContext context, IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: Color(0xFF787774), size: 24),
            SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(fontSize: 15, color: Color(0xFF37352F)),
            ),
          ],
        ),
      ),
    );
  }

  void _showDocumentOptions(BuildContext context, String docName) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      docName,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            _buildDocOption(ctx, Icons.visibility, 'View', () {}),
            _buildDocOption(ctx, Icons.share, 'Share', () {}),
            _buildDocOption(ctx, Icons.download, 'Download', () {}),
            _buildDocOption(ctx, Icons.edit, 'Rename', () {}),
            Divider(),
            _buildDocOption(ctx, Icons.delete_outline, 'Delete', () {}, isDestructive: true),
            SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildDocOption(BuildContext context, IconData icon, String label, VoidCallback onTap, {bool isDestructive = false}) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Icon(
              icon,
              color: isDestructive ? Color(0xFFC47070) : Color(0xFF787774),
              size: 24,
            ),
            SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                color: isDestructive ? Color(0xFFC47070) : Color(0xFF37352F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}