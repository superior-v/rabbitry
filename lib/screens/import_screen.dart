import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import '../models/rabbit.dart';
import '../services/database_service.dart';


class ImportScreen extends StatefulWidget {
  const ImportScreen({Key? key}) : super(key: key);

  @override
  _ImportScreenState createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  bool _isImporting = false;
  String? _statusMessage;
  int _importCount = 0;
  int _errorCount = 0;

  Future<void> _pickAndImport() async {
    setState(() {
      _isImporting = true;
      _statusMessage = 'Selecting file...';
      _importCount = 0;
      _errorCount = 0;
    });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.single.path == null) {
        setState(() {
          _isImporting = false;
          _statusMessage = 'Import cancelled';
        });
        return;
      }

      final file = File(result.files.single.path!);
      final input = file.openRead();
      final fields = await input
          .transform(utf8.decoder)
          .transform(const CsvToListConverter())
          .toList();

      if (fields.isEmpty) {
        setState(() {
          _isImporting = false;
          _statusMessage = 'CSV file is empty';
        });
        return;
      }

      // Assume first row is header if it contains known keywords
      int startIndex = 0;
      final header = fields[0].map((e) => e.toString().toLowerCase()).toList();
      if (header.contains('name') || header.contains('breed')) {
        startIndex = 1;
      }

      final db = DatabaseService();
      final baseTs = DateTime.now().millisecondsSinceEpoch;

      for (int i = startIndex; i < fields.length; i++) {
        final row = fields[i];
        if (row.length < 2) continue; // Skip empty/invalid rows

        try {
          // Simplified mapping: name, type, breed, dob, sex, location, cage, color, weight, status
          // Expecting headers: name (0), type (1), breed (2), dob (3), sex (4), location (5), cage (6), color (7), weight (8), status (9)
          
          final name = row.length > 0 ? row[0]?.toString() ?? 'Unnamed' : 'Unnamed';
          final typeStr = row.length > 1 ? row[1]?.toString().toLowerCase() ?? 'doe' : 'doe';
          final breed = row.length > 2 ? row[2]?.toString() ?? 'Unknown' : 'Unknown';
          final dobStr = row.length > 3 ? row[3]?.toString() : null;
          // sex (index 4) inferred from type - not a direct Rabbit field
          final location = row.length > 5 ? row[5]?.toString() : null;
          final cage = row.length > 6 ? row[6]?.toString() : null;
          final color = row.length > 7 ? row[7]?.toString() : null;
          final weight = row.length > 8 ? double.tryParse(row[8]?.toString() ?? '') : null;
          final statusStr = row.length > 9 ? row[9]?.toString().toLowerCase() ?? 'open' : 'open';

          DateTime? dob;
          if (dobStr != null && dobStr.isNotEmpty) {
            dob = DateTime.tryParse(dobStr);
          }

          RabbitType type = RabbitType.doe;
          if (typeStr.contains('buck')) type = RabbitType.buck;
          else if (typeStr.contains('kit')) type = RabbitType.kit;

          RabbitStatus status = RabbitStatus.open;
          if (statusStr.contains('pregnant')) status = RabbitStatus.pregnant;
          else if (statusStr.contains('nursing')) status = RabbitStatus.nursing;
          else if (statusStr.contains('resting')) status = RabbitStatus.resting;
          else if (statusStr.contains('growout')) status = RabbitStatus.growout;
          else if (statusStr.contains('archived')) status = RabbitStatus.archived;

          final rabbit = Rabbit(
            id: '${baseTs + i}',
            name: name,
            type: type,
            breed: breed,
            dateOfBirth: dob,
            location: location,
            cage: cage,
            color: color,
            weight: weight,
            status: status,
            photos: [],
          );


          await db.insertRabbit(rabbit);
          _importCount++;
        } catch (e) {
          _errorCount++;
          print('Error importing row $i: $e');
        }
      }

      setState(() {
        _isImporting = false;
        _statusMessage = 'Import completed: $_importCount successful, $_errorCount failed';
      });
    } catch (e) {
      setState(() {
        _isImporting = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Rabbits CSV'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
      ),
      backgroundColor: const Color(0xFFF8F7FF),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE9E9E7)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.upload_file, size: 64, color: Color(0xFF7B6BA0)),
                  const SizedBox(height: 16),
                  const Text(
                    'Upload your CSV file',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Format: name, type, breed, dob, sex, location, cage, color, weight, status',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: _isImporting ? null : _pickAndImport,
                    icon: _isImporting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.file_open),
                    label: Text(_isImporting ? 'Importing...' : 'Select CSV File'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7B6BA0),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
            if (_statusMessage != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _errorCount > 0 ? Colors.red.shade50 : Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _errorCount > 0 ? Colors.red.shade100 : Colors.green.shade100,
                  ),
                ),
                child: Text(
                  _statusMessage!,
                  style: TextStyle(
                    color: _errorCount > 0 ? Colors.red.shade900 : Colors.green.shade900,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
            const Spacer(),
            const Text(
              'Tips: Dates should be in YYYY-MM-DD format. Sex should be "male" or "female". Type should be "doe", "buck", or "kit".',
              style: TextStyle(fontSize: 12, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
