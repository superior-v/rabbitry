import 'package:flutter/material.dart';
import '../models/rabbit.dart';

class PedigreeInlineCard extends StatefulWidget {
  final Rabbit rabbit;

  const PedigreeInlineCard({Key? key, required this.rabbit}) : super(key: key);

  @override
  State<PedigreeInlineCard> createState() => _PedigreeInlineCardState();
}

class _PedigreeInlineCardState extends State<PedigreeInlineCard> {
  int selectedGenerations = 3;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFFE9E9E7)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                  'PEDIGREE',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF787774),
                    letterSpacing: 0.5,
                  ),
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showFullPedigree(context),
                      child: Row(
                        children: [
                          Icon(Icons.download, size: 14, color: Color(0xFF787774)),
                          SizedBox(width: 4),
                          Text(
                            'Export',
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
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Dropdown for generations
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Color(0xFFE9E9E7)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButton<int>(
                    value: selectedGenerations,
                    underline: SizedBox(),
                    isDense: true,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(value: 3, child: Text('3 Generations')),
                      DropdownMenuItem(value: 4, child: Text('4 Generations')),
                      DropdownMenuItem(value: 5, child: Text('5 Generations')),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedGenerations = value ?? 3;
                      });
                    },
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF37352F),
                    ),
                  ),
                ),
                SizedBox(height: 20),

                // SUBJECT Section
                Text(
                  'SUBJECT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF787774),
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 8),
                _buildSubjectCard(
                  widget.rabbit.name,
                  widget.rabbit.id,
                  widget.rabbit.breed,
                  widget.rabbit.color ?? 'Unknown',
                ),

                SizedBox(height: 24),

                // PARENTS Section
                Text(
                  'PARENTS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF787774),
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildParentCard(
                        'Unknown Sire',
                        '--',
                        widget.rabbit.breed,
                        true,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildParentCard(
                        'Unknown Dam',
                        '--',
                        widget.rabbit.breed,
                        false,
                      ),
                    ),
                  ],
                ),

                SizedBox(height: 24),

                // GRANDPARENTS Section
                Text(
                  'GRANDPARENTS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF787774),
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 12),

                // Parent labels
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Sire\'s parents',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9B9A97),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Dam\'s parents',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9B9A97),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),

                // First row of grandparents (Zeus and Thunder)
                Row(
                  children: [
                    Expanded(
                      child: _buildGrandparentCard('Unknown', '--', true),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _buildGrandparentCard('Unknown', '--', true),
                    ),
                  ],
                ),
                SizedBox(height: 8),

                // Second row of grandparents (Athena and Add button)
                Row(
                  children: [
                    Expanded(
                      child: _buildGrandparentCard('Unknown', '--', false),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          // Add grandparent functionality
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Add grandparent'),
                              backgroundColor: Color(0xFF0F7B6C),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                        child: Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: Color(0xFFE9E9E7),
                              width: 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add, size: 16, color: Color(0xFF9B9A97)),
                                SizedBox(width: 6),
                                Text(
                                  'Add',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF9B9A97),
                                  ),
                                ),
                              ],
                            ),
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

  Widget _buildSubjectCard(String name, String id, String breed, String color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Color(0xFF0F7B6C), width: 2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF37352F),
            ),
          ),
          SizedBox(height: 4),
          Text(
            id,
            style: TextStyle(
              fontSize: 13,
              color: Color(0xFF787774),
            ),
          ),
          SizedBox(height: 4),
          Text(
            '$breed • $color',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF9B9A97),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParentCard(String name, String id, String breed, bool isMale) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: isMale ? Color(0xFF2E7BB5) : Color(0xFF9C6ADE),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF37352F),
            ),
          ),
          SizedBox(height: 4),
          Text(
            id,
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF787774),
            ),
          ),
          SizedBox(height: 4),
          Text(
            breed,
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF9B9A97),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGrandparentCard(String name, String id, bool isMale) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: isMale ? Color(0xFF2E7BB5).withOpacity(0.3) : Color(0xFF9C6ADE).withOpacity(0.3),
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF37352F),
            ),
          ),
          SizedBox(height: 4),
          Text(
            id,
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF787774),
            ),
          ),
        ],
      ),
    );
  }

  void _showFullPedigree(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.rabbit.name} Pedigree',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '$selectedGenerations Generations',
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF787774),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.print),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Preparing pedigree for printing...'),
                          backgroundColor: Color(0xFF0F7B6C),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.share),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Sharing pedigree...'),
                          backgroundColor: Color(0xFF0F7B6C),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Full pedigree view with same layout
                    Text(
                      'SUBJECT',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF787774),
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 8),
                    _buildSubjectCard(
                      widget.rabbit.name,
                      widget.rabbit.id,
                      widget.rabbit.breed,
                      widget.rabbit.color ?? 'Unknown',
                    ),
                    SizedBox(height: 24),

                    Text(
                      'PARENTS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF787774),
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildParentCard('Unknown Sire', '--', widget.rabbit.breed, true)),
                        SizedBox(width: 12),
                        Expanded(child: _buildParentCard('Unknown Dam', '--', widget.rabbit.breed, false)),
                      ],
                    ),
                    SizedBox(height: 24),

                    Text(
                      'GRANDPARENTS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF787774),
                        letterSpacing: 0.5,
                      ),
                    ),
                    SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Sire\'s parents',
                            style: TextStyle(fontSize: 11, color: Color(0xFF9B9A97)),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Dam\'s parents',
                            style: TextStyle(fontSize: 11, color: Color(0xFF9B9A97)),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildGrandparentCard('Unknown', '--', true)),
                        SizedBox(width: 12),
                        Expanded(child: _buildGrandparentCard('Unknown', '--', true)),
                      ],
                    ),
                    SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildGrandparentCard('Unknown', '--', false)),
                        SizedBox(width: 12),
                        Expanded(child: _buildGrandparentCard('Unknown', '--', false)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
