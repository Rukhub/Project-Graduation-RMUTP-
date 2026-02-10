import 'package:flutter/material.dart';

import '../api_service.dart';
import '../services/firebase_service.dart';

class PermanentAssetManagementScreen extends StatelessWidget {
  const PermanentAssetManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isAdmin =
        ApiService().currentUser?['role'] == 'admin' ||
        ApiService().currentUser?['role_num'] == 1;

    if (!isAdmin) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: const Color(0xFF9A2C2C),
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          centerTitle: true,
          title: const Text(
            'กลุ่มสินทรัพย์ถาวร',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
        ),
        body: const Center(child: Text('หน้านี้สำหรับผู้ดูแลระบบเท่านั้น')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: const Color(0xFF9A2C2C),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        title: const Text(
          'กลุ่มสินทรัพย์ถาวร',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF9A2C2C),
        onPressed: () => _showAddDialog(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: FirebaseService().getPermanentAssetsStream(activeOnly: false),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF9A2C2C)),
            );
          }

          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(
              child: Text('ยังไม่มีรายการกลุ่มสินทรัพย์ถาวร'),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final it = items[index];
              final id = (it['permanent_id'] ?? it['id'] ?? '').toString();
              final rawStatus = it['permanent_status'];
              final status = rawStatus is int
                  ? rawStatus
                  : int.tryParse(rawStatus?.toString() ?? '') ?? 2;

              final statusLabel = status == 1 ? 'ห้ามซ้ำ' : 'ซ้ำได้';
              final Color statusColor = status == 1
                  ? const Color(0xFFDC2626)
                  : const Color(0xFF2563EB);

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                color: Colors.white,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  title: Text(
                    id,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      letterSpacing: 0.2,
                    ),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: statusColor.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Text(
                            'รูปแบบ: $statusLabel',
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'แก้ไข',
                        icon: const Icon(Icons.edit),
                        onPressed: () => _showEditDialog(context, it),
                      ),
                      IconButton(
                        tooltip: 'ลบ',
                        icon: const Icon(Icons.delete_outline),
                        color: Colors.red,
                        onPressed: () => _confirmDelete(context, id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmDelete(BuildContext context, String permanentId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ยืนยันการลบ'),
          content: Text(
            'ต้องการลบกลุ่มสินทรัพย์ถาวร "$permanentId" ใช่หรือไม่',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(context);
                final success = await FirebaseService()
                    .deletePermanentAssetGroup(permanentId);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'ลบสำเร็จ'
                          : 'ลบไม่สำเร็จ (อาจมีครุภัณฑ์ใช้งานกลุ่มนี้อยู่)',
                    ),
                    backgroundColor: success ? Colors.green : Colors.red,
                  ),
                );
              },
              child: const Text('ลบ', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showAddDialog(BuildContext context) {
    final TextEditingController idController = TextEditingController();
    int status = 1;
    bool saving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('เพิ่มกลุ่มสินทรัพย์ถาวร'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: idController,
                    decoration: const InputDecoration(
                      labelText: 'Permanent ID',
                      hintText: 'เช่น 120610101',
                      border: OutlineInputBorder(),
                    ),
                    enabled: !saving,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    value: status,
                    decoration: const InputDecoration(
                      labelText: 'รูปแบบการใช้งาน',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('ห้ามซ้ำ')),
                      DropdownMenuItem(value: 2, child: Text('ซ้ำได้')),
                    ],
                    onChanged: saving
                        ? null
                        : (v) {
                            if (v == null) return;
                            setState(() => status = v);
                          },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          final id = idController.text.trim();
                          if (id.isEmpty) return;
                          setState(() => saving = true);

                          final success = await FirebaseService()
                              .addPermanentAssetGroup(
                                permanentId: id,
                                permanentStatus: status,
                              );

                          if (!context.mounted) return;

                          if (success) {
                            Navigator.pop(context);
                          } else {
                            setState(() => saving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'เพิ่มไม่สำเร็จ (อาจมีรหัสนี้อยู่แล้ว)',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9A2C2C),
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'บันทึก',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, Map<String, dynamic> item) {
    final String id = (item['permanent_id'] ?? item['id'] ?? '').toString();
    final rawStatus = item['permanent_status'];
    int status = rawStatus is int
        ? rawStatus
        : int.tryParse(rawStatus?.toString() ?? '') ?? 2;
    bool saving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('แก้ไขกลุ่มสินทรัพย์ถาวร'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: TextEditingController(text: id),
                    decoration: const InputDecoration(
                      labelText: 'Permanent ID',
                      border: OutlineInputBorder(),
                    ),
                    enabled: false,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<int>(
                    value: status,
                    decoration: const InputDecoration(
                      labelText: 'รูปแบบการใช้งาน',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 1, child: Text('ห้ามซ้ำ')),
                      DropdownMenuItem(value: 2, child: Text('ซ้ำได้')),
                    ],
                    onChanged: saving
                        ? null
                        : (v) {
                            if (v == null) return;
                            setState(() => status = v);
                          },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(context),
                  child: const Text('ยกเลิก'),
                ),
                ElevatedButton(
                  onPressed: saving
                      ? null
                      : () async {
                          setState(() => saving = true);
                          final success = await FirebaseService()
                              .updatePermanentAssetGroup(id, {
                                'permanent_status': status,
                              });

                          if (!context.mounted) return;

                          if (success) {
                            Navigator.pop(context);
                          } else {
                            setState(() => saving = false);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'บันทึกไม่สำเร็จ (อาจมีครุภัณฑ์หลายชิ้นใช้กลุ่มนี้อยู่)',
                                ),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF9A2C2C),
                  ),
                  child: saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'บันทึก',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
