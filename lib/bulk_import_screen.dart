import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'api_service.dart';
import 'app_drawer.dart';
import 'services/firebase_service.dart';

class BulkImportScreen extends StatefulWidget {
  const BulkImportScreen({super.key});

  @override
  State<BulkImportScreen> createState() => _BulkImportScreenState();
}

class _BulkImportScreenState extends State<BulkImportScreen> {
  // Step: 0 = pick file, 1 = preview, 2 = importing/results
  int _currentStep = 0;

  String? _fileName;
  List<Map<String, String>> _parsedRows = [];
  List<Map<String, dynamic>> _validationResults = [];
  List<Map<String, dynamic>> _importResults = [];

  bool _isValidating = false;
  bool _isImporting = false;
  int _importProgress = 0;
  int _importTotal = 0;

  // Expected column headers
  static const _expectedHeaders = [
    'asset_id',
    'asset_name',
    'asset_type',
    'permanent_id',
    'price',
    'location_id',
    'purchase_date',
  ];

  // --- File Picking & CSV Parsing ---

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      String csvString;

      if (file.bytes != null) {
        csvString = utf8.decode(file.bytes!, allowMalformed: true);
      } else if (file.path != null) {
        csvString = await File(file.path!).readAsString();
      } else {
        _showError('ไม่สามารถอ่านไฟล์ได้');
        return;
      }

      final csvTable = const CsvToListConverter(eol: '\n').convert(csvString);

      if (csvTable.isEmpty) {
        _showError('ไฟล์ CSV ว่างเปล่า');
        return;
      }

      // Parse headers (first row)
      final headers = csvTable.first
          .map((e) => e.toString().trim().toLowerCase())
          .toList();

      // Validate required headers
      final missingHeaders = <String>[];
      for (final h in ['asset_id', 'asset_name', 'permanent_id']) {
        if (!headers.contains(h)) {
          missingHeaders.add(h);
        }
      }

      if (missingHeaders.isNotEmpty) {
        _showError(
          'ไฟล์ CSV ขาดคอลัมน์: ${missingHeaders.join(', ')}\n\nคอลัมน์ที่ต้องมี: ${_expectedHeaders.join(', ')}',
        );
        return;
      }

      // Parse data rows
      final rows = <Map<String, String>>[];
      for (int i = 1; i < csvTable.length; i++) {
        final csvRow = csvTable[i];
        if (csvRow.every((cell) => cell.toString().trim().isEmpty)) continue;

        final rowMap = <String, String>{};
        for (int j = 0; j < headers.length && j < csvRow.length; j++) {
          rowMap[headers[j]] = csvRow[j].toString().trim();
        }
        rows.add(rowMap);
      }

      if (rows.isEmpty) {
        _showError('ไม่พบข้อมูลในไฟล์ CSV (มีแค่ header)');
        return;
      }

      setState(() {
        _fileName = file.name;
        _parsedRows = rows;
        _currentStep = 1;
        _validationResults = [];
        _importResults = [];
      });

      // Auto-validate
      _validateRows();
    } catch (e) {
      _showError('เกิดข้อผิดพลาดในการอ่านไฟล์: $e');
    }
  }

  // --- Validation ---

  Future<void> _validateRows() async {
    setState(() => _isValidating = true);

    final permanentSnapshot = await FirebaseService()
        .getPermanentAssetsStream(activeOnly: false)
        .first;
    final validPermanentIds = <String>{};
    for (final doc in permanentSnapshot) {
      final id = doc['permanent_id']?.toString() ?? doc['id']?.toString() ?? '';
      if (id.isNotEmpty) validPermanentIds.add(id);
    }

    final results = <Map<String, dynamic>>[];
    final seenAssetIds = <String>{};

    for (int i = 0; i < _parsedRows.length; i++) {
      final row = _parsedRows[i];
      final assetId = (row['asset_id'] ?? '').trim();
      final assetName = (row['asset_name'] ?? '').trim();
      final permanentId = (row['permanent_id'] ?? '').trim();

      String? error;

      if (assetId.isEmpty) {
        error = 'รหัสครุภัณฑ์ว่าง';
      } else if (assetName.isEmpty) {
        error = 'ชื่อครุภัณฑ์ว่าง';
      } else if (permanentId.isEmpty) {
        error = 'กลุ่มสินทรัพย์ถาวรว่าง';
      } else if (seenAssetIds.contains(assetId)) {
        error = 'รหัสซ้ำในไฟล์ CSV';
      } else if (!validPermanentIds.contains(permanentId)) {
        error = 'กลุ่มสินทรัพย์ "$permanentId" ไม่พบ';
      }

      seenAssetIds.add(assetId);

      results.add({
        'row': i + 1,
        'asset_id': assetId,
        'asset_name': assetName,
        'valid': error == null,
        'error': error,
      });
    }

    setState(() {
      _validationResults = results;
      _isValidating = false;
    });
  }

  // --- Import ---

  Future<void> _startImport() async {
    final validCount = _validationResults
        .where((r) => r['valid'] == true)
        .length;
    if (validCount == 0) {
      _showError('ไม่มีรายการที่ถูกต้องให้นำเข้า');
      return;
    }

    // Confirm dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.upload_file, color: Color(0xFF9A2C2C), size: 28),
            SizedBox(width: 10),
            Text(
              'ยืนยันการนำเข้า',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'ต้องการนำเข้าครุภัณฑ์ $validCount รายการ?',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9A2C2C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('นำเข้า', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() {
      _currentStep = 2;
      _isImporting = true;
      _importProgress = 0;
      _importTotal = _parsedRows.length;
    });

    final currentUser = ApiService().currentUser;

    final results = await FirebaseService().addAssetBulk(
      rows: _parsedRows,
      createdId: currentUser?['uid']?.toString(),
      createdBy: currentUser?['fullname']?.toString(),
      onProgress: (current, total) {
        if (mounted) {
          setState(() {
            _importProgress = current;
            _importTotal = total;
          });
        }
      },
    );

    if (mounted) {
      setState(() {
        _importResults = results;
        _isImporting = false;
      });
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'ข้อผิดพลาด',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(message, style: const TextStyle(fontSize: 15)),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF9A2C2C),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(context),
            child: const Text('ตกลง', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _reset() {
    setState(() {
      _currentStep = 0;
      _fileName = null;
      _parsedRows = [];
      _validationResults = [];
      _importResults = [];
      _isValidating = false;
      _isImporting = false;
      _importProgress = 0;
      _importTotal = 0;
    });
  }

  // === BUILD ===

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: const Color(0xFF9A2C2C),
        elevation: 0,
        leading: IconButton(
          icon: const CircleAvatar(
            backgroundColor: Colors.white,
            radius: 18,
            child: Icon(
              Icons.arrow_back_ios_new,
              size: 16,
              color: Color(0xFF9A2C2C),
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        actions: [
          Builder(
            builder: (context) {
              return IconButton(
                tooltip: 'เมนู',
                icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                onPressed: () => Scaffold.of(context).openDrawer(),
              );
            },
          ),
        ],
        title: const Text(
          'นำเข้าครุภัณฑ์ (CSV)',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        toolbarHeight: 80,
      ),
      body: Column(
        children: [
          // Step indicator
          _buildStepIndicator(),
          // Content
          Expanded(
            child: _currentStep == 0
                ? _buildPickFileStep()
                : _currentStep == 1
                ? _buildPreviewStep()
                : _buildResultStep(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9A2C2C), Color(0xFF7A2222)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          _buildStepCircle(0, 'เลือกไฟล์'),
          _buildStepLine(0),
          _buildStepCircle(1, 'ตรวจสอบ'),
          _buildStepLine(1),
          _buildStepCircle(2, 'ผลลัพธ์'),
        ],
      ),
    );
  }

  Widget _buildStepCircle(int step, String label) {
    final isActive = _currentStep >= step;
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isActive
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: isActive && _currentStep > step
                  ? const Icon(Icons.check, color: Color(0xFF9A2C2C), size: 20)
                  : Text(
                      '${step + 1}',
                      style: TextStyle(
                        color: isActive
                            ? const Color(0xFF9A2C2C)
                            : Colors.white70,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white60,
              fontSize: 12,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepLine(int afterStep) {
    final isActive = _currentStep > afterStep;
    return Container(
      width: 30,
      height: 3,
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  // === STEP 0: Pick File ===

  Widget _buildPickFileStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 30),
          // Main icon
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF9A2C2C).withValues(alpha: 0.15),
                  const Color(0xFF9A2C2C).withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.upload_file_rounded,
              size: 72,
              color: Color(0xFF9A2C2C),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'นำเข้าครุภัณฑ์จากไฟล์ CSV',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'เตรียมไฟล์ CSV จาก Excel แล้ว Import ทีเดียว\nไม่ต้องเพิ่มทีละชิ้น!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey.shade600,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          // Pick file button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _pickFile,
              icon: const Icon(Icons.folder_open, color: Colors.white),
              label: const Text(
                'เลือกไฟล์ CSV',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF9A2C2C),
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 3,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // CSV format guide
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: const Color(0xFF9A2C2C),
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'รูปแบบไฟล์ CSV',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildFormatRow(
                  'asset_id *',
                  'รหัสครุภัณฑ์ เช่น 140695-25',
                  true,
                ),
                _buildFormatRow(
                  'asset_name *',
                  'ชื่อครุภัณฑ์ เช่น เครื่องปรับอากาศ',
                  true,
                ),
                _buildFormatRow(
                  'asset_type',
                  'ประเภท เช่น ครุภัณฑ์สำนักงาน',
                  false,
                ),
                _buildFormatRow(
                  'permanent_id *',
                  'กลุ่มสินทรัพย์ถาวร เช่น 1206010101',
                  true,
                ),
                _buildFormatRow('price', 'ราคา เช่น 20000', false),
                _buildFormatRow('location_id', 'รหัสห้อง เช่น LOC001', false),
                _buildFormatRow(
                  'purchase_date',
                  'วันที่ซื้อ YYYY-MM-DD',
                  false,
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'ตัวอย่าง:\nasset_id,asset_name,asset_type,permanent_id,price,location_id,purchase_date\n140695-25,เครื่องปรับอากาศ,ครุภัณฑ์สำนักงาน,1206010101,20000,LOC001,2024-01-15',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatRow(String field, String desc, bool required) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: required
                  ? const Color(0xFF9A2C2C).withValues(alpha: 0.12)
                  : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              field,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: required
                    ? const Color(0xFF9A2C2C)
                    : Colors.grey.shade700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              desc,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  // === STEP 1: Preview ===

  Widget _buildPreviewStep() {
    if (_isValidating) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFF9A2C2C)),
            SizedBox(height: 16),
            Text('กำลังตรวจสอบข้อมูล...', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }

    final validCount = _validationResults
        .where((r) => r['valid'] == true)
        .length;
    final errorCount = _validationResults
        .where((r) => r['valid'] != true)
        .length;

    return Column(
      children: [
        // Summary bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          color: Colors.white,
          child: Row(
            children: [
              Icon(Icons.description, color: const Color(0xFF9A2C2C), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$_fileName — ${_parsedRows.length} รายการ',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              _buildCountBadge(validCount, Colors.green, Icons.check_circle),
              const SizedBox(width: 8),
              if (errorCount > 0)
                _buildCountBadge(errorCount, Colors.red, Icons.error),
            ],
          ),
        ),
        const Divider(height: 1),

        // Data table
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: _validationResults.length,
            itemBuilder: (context, index) {
              final result = _validationResults[index];
              final row = _parsedRows[index];
              final isValid = result['valid'] == true;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isValid
                        ? Colors.green.withValues(alpha: 0.3)
                        : Colors.red.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  leading: CircleAvatar(
                    radius: 20,
                    backgroundColor: isValid
                        ? Colors.green.withValues(alpha: 0.15)
                        : Colors.red.withValues(alpha: 0.15),
                    child: Icon(
                      isValid ? Icons.check : Icons.close,
                      color: isValid ? Colors.green : Colors.red,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    result['asset_id']?.toString().isNotEmpty == true
                        ? result['asset_id']
                        : '(ไม่มีรหัส)',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        row['asset_name'] ?? '',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      if (!isValid)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '❌ ${result['error']}',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  trailing: Text(
                    '#${result['row']}',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                  ),
                ),
              );
            },
          ),
        ),

        // Bottom actions
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.arrow_back, size: 18),
                  label: const Text('เลือกไฟล์ใหม่'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF9A2C2C),
                    side: const BorderSide(color: Color(0xFF9A2C2C)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _reset,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  icon: const Icon(
                    Icons.cloud_upload,
                    color: Colors.white,
                    size: 20,
                  ),
                  label: Text(
                    'นำเข้า $validCount รายการ',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: validCount > 0
                        ? const Color(0xFF9A2C2C)
                        : Colors.grey,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                  onPressed: validCount > 0 ? _startImport : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCountBadge(int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // === STEP 2: Results ===

  Widget _buildResultStep() {
    if (_isImporting) {
      final progress = _importTotal > 0 ? _importProgress / _importTotal : 0.0;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 8,
                        color: const Color(0xFF9A2C2C),
                        backgroundColor: Colors.grey.shade200,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}%',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF9A2C2C),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'กำลังนำเข้าข้อมูล...',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                '$_importProgress / $_importTotal รายการ',
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
            ],
          ),
        ),
      );
    }

    // Show results
    final successCount = _importResults
        .where((r) => r['success'] == true)
        .length;
    final failCount = _importResults.where((r) => r['success'] != true).length;

    return Column(
      children: [
        // Summary card
        Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: failCount == 0
                  ? [const Color(0xFF4CAF50), const Color(0xFF388E3C)]
                  : [const Color(0xFFFF9800), const Color(0xFFE65100)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(
                failCount == 0 ? Icons.celebration : Icons.info_outline,
                color: Colors.white,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                failCount == 0 ? 'นำเข้าสำเร็จทั้งหมด!' : 'นำเข้าเสร็จสิ้น',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildResultStat('สำเร็จ', successCount, Colors.white),
                  const SizedBox(width: 32),
                  _buildResultStat('ล้มเหลว', failCount, Colors.white),
                ],
              ),
            ],
          ),
        ),

        // Result list
        if (_importResults.isNotEmpty)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _importResults.length,
              itemBuilder: (context, index) {
                final r = _importResults[index];
                final success = r['success'] == true;

                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: success
                          ? Colors.green.shade100
                          : Colors.red.shade100,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        success ? Icons.check_circle : Icons.cancel,
                        color: success ? Colors.green : Colors.red,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              r['asset_id'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            if (!success && r['error'] != null)
                              Text(
                                r['error'],
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 12,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Text(
                        '#${r['row']}',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

        // Bottom action
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 10,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('นำเข้าไฟล์ใหม่'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF9A2C2C),
                    side: const BorderSide(color: Color(0xFF9A2C2C)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _reset,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.home, color: Colors.white, size: 18),
                  label: const Text(
                    'กลับหน้าหลัก',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9A2C2C),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResultStat(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            color: color,
            fontSize: 32,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 14),
        ),
      ],
    );
  }
}
