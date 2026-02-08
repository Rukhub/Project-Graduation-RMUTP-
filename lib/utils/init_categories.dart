// Script to initialize default asset categories in Firestore
// Run this once in Firebase Console or via Flutter app initialization

/*
CREATE THESE DOCUMENTS IN FIRESTORE CONSOLE:

Collection: asset_categories

1. Document ID: auto
   Fields:
   - name: "ครุภัณฑ์คอมพิวเตอร์และระบบเครือข่าย"
   - order: 1
   - created_at: (server timestamp)

2. Document ID: auto
   Fields:
   - name: "ครุภัณฑ์สำนักงานและเฟอร์นิเจอร์"
   - order: 2
   - created_at: (server timestamp)

3. Document ID: auto
   Fields:
   - name: "ครุภัณฑ์ไฟฟ้าและเครื่องปรับอากาศ"
   - order: 3
   - created_at: (server timestamp)

4. Document ID: auto
   Fields:
   - name: "ครุภัณฑ์การศึกษาและโสตทัศนูปกรณ์"
   - order: 4
   - created_at: (server timestamp)

5. Document ID: auto
   Fields:
   - name: "เครื่องมือวัดและอุปกรณ์ทางวิศวกรรม"
   - order: 5
   - created_at: (server timestamp)

6. Document ID: auto
   Fields:
   - name: "อุปกรณ์กระจายเสียงและภาพ"
   - order: 6
   - created_at: (server timestamp)
*/

// OR run this function once in your app (add to a debug menu):
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

Future<void> initializeAssetCategories() async {
  final db = FirebaseFirestore.instance;
  final categories = [
    'ครุภัณฑ์คอมพิวเตอร์และระบบเครือข่าย',
    'ครุภัณฑ์สำนักงานและเฟอร์นิเจอร์',
    'ครุภัณฑ์ไฟฟ้าและเครื่องปรับอากาศ',
    'ครุภัณฑ์การศึกษาและโสตทัศนูปกรณ์',
    'เครื่องมือวัดและอุปกรณ์ทางวิศวกรรม',
    'อุปกรณ์กระจายเสียงและภาพ',
  ];

  for (int i = 0; i < categories.length; i++) {
    await db.collection('asset_categories').add({
      'name': categories[i],
      'order': i + 1,
      'created_at': FieldValue.serverTimestamp(),
    });
  }
  debugPrint('✅ Asset categories initialized!');
}
