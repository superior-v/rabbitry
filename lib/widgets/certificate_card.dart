import 'package:flutter/material.dart';
import '../models/rabbit.dart';

class CertificateCard extends StatelessWidget {
  final Rabbit rabbit;

  const CertificateCard({Key? key, required this.rabbit}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF7F7F5),
            Color(0xFFFFFFFF),
          ],
        ),
        border: Border.all(color: Color(0xFFE9E9E7)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: Color(0xFFE9E9E7)),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFF0F7B6C).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.verified,
                    color: Color(0xFF0F7B6C),
                    size: 24,
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'REGISTRATION CERTIFICATE',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF787774),
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'American Rabbit Breeders Association',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF37352F),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                // Certificate Header
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Color(0xFFE9E9E7)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Rex Rabbit',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F7B6C),
                        ),
                      ),
                      SizedBox(height: 12),
                      _buildCertRow('Name', rabbit.name),
                      _buildCertRow('ID', rabbit.id),
                      _buildCertRow('Registration #', 'RX78901'),
                      _buildCertRow('Color', 'Castor'),
                      _buildCertRow('Born', 'March 15, 2024'),
                      Divider(height: 24),
                      _buildCertRow('Sire', 'Thunder (B-05)'),
                      _buildCertRow('Dam', 'Ruby (D-08)'),
                      Divider(height: 24),
                      _buildCertRow('Breeder', 'Green Valley Rabbitry'),
                      _buildCertRow('Owner', 'Green Valley Rabbitry'),
                      _buildCertRow('Issue Date', 'April 1, 2024'),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                // Awards Section
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Color(0xFFE9E9E7)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.emoji_events, color: Color(0xFFCB8347), size: 20),
                          SizedBox(width: 8),
                          Text(
                            'AWARDS & ACHIEVEMENTS',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF787774),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      _buildAwardItem('Best of Breed', 'State Fair 2025', '1st Place'),
                      _buildAwardItem('Best Opposite Sex', 'County Show 2025', '2nd Place'),
                      _buildAwardItem('Grand Champion', 'Regional Show 2024', 'Winner'),
                    ],
                  ),
                ),
                SizedBox(height: 16),
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _printCertificate(context),
                        icon: Icon(Icons.print, size: 18),
                        label: Text('Print'),
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          side: BorderSide(color: Color(0xFFE9E9E7)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _shareCertificate(context),
                        icon: Icon(Icons.share, size: 18),
                        label: Text('Share'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF0F7B6C),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCertRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF787774),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF37352F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAwardItem(String title, String event, String place) {
    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color(0xFFFFF9E6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFFCB8347).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Color(0xFFCB8347).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.emoji_events, color: Color(0xFFCB8347), size: 16),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF37352F),
                  ),
                ),
                Text(
                  event,
                  style: TextStyle(fontSize: 11, color: Color(0xFF787774)),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Color(0xFFCB8347),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              place,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _printCertificate(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Preparing certificate for printing...'),
        backgroundColor: Color(0xFF0F7B6C),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _shareCertificate(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Sharing certificate...'),
        backgroundColor: Color(0xFF0F7B6C),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}