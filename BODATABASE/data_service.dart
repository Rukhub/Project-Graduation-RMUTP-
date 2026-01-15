// ตัวอย่างการแก้ไข krupan_room.dart

@override
void initState() {
  super.initState();
  _loadData();
}

void _loadData() async {
  // เปลี่ยนจาก sync เป็น async
  final equipments = await DataService().getEquipmentsInRoomAsync(widget.roomName);
  setState(() {
    equipmentList = equipments;
  });
}

// ในส่วนอื่นๆ ที่ต้องโหลดข้อมูลใหม่ ให้เรียก _loadData() แทน
// ตัวอย่าง:
void _showDeleteConfirmation(int index, String id) {
  showDialog(
    context: context,
    builder: (context) {
      return AlertDialog(
        // ... dialog content
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () async {
              await DataService().deleteEquipment(widget.roomName, id);
              await _loadData(); // โหลดข้อมูลใหม่
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('ลบ $id สำเร็จ'),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            child: const Text('ลบ'),
          ),
        ],
      );
    },
  );
}
