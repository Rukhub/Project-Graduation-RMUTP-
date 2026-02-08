import 'package:flutter/material.dart';
import '../api_service.dart';
import '../services/firebase_service.dart';
import '../app_drawer.dart';
import '../models/user_model.dart';
import 'dart:async';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<UserModel> _pendingUsers = [];
  List<UserModel> _allUsers = [];
  bool _isLoading = true;
  StreamSubscription? _usersSubscription;

  // Search & Filter State
  String _searchQuery = '';
  String _selectedRoleFilter = 'All'; // All, Admin, Checker, User

  // Selection Mode State (Change to String for UID)
  final Set<String> _selectedUserIds = {};
  bool get _hasSelection => _selectedUserIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _listenToUsers();
  }

  @override
  void dispose() {
    _usersSubscription?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  void _listenToUsers() {
    _usersSubscription = FirebaseService().getUsersStream().listen((users) {
      if (mounted) {
        setState(() {
          _pendingUsers = users.where((u) => !u.isApproved).toList();
          _allUsers = users;
          _isLoading = false;
        });
      }
    });
  }

  Future<void> _changeUserRole(
    String uid,
    int currentRole,
    String userName,
  ) async {
    // Show dialog to select new role
    int? newRole = await showDialog<int>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text('เปลี่ยนตำแหน่งของ $userName'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 1),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.admin_panel_settings, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Admin (ผู้ดูแลระบบ)', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(
                context,
                2,
              ), // Keep checker as 2 if needed or 0/1
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.verified_user, color: Colors.blue),
                    SizedBox(width: 10),
                    Text(
                      'Checker (ผู้ตรวจสอบ)',
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 0),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.grey),
                    SizedBox(width: 10),
                    Text('User (ผู้ใช้ทั่วไป)', style: TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );

    if (newRole != null && newRole != currentRole) {
      // Call FirebaseService
      final success = await FirebaseService().updateUserRole(uid, newRole);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'เปลี่ยนตำแหน่งเรียบร้อยแล้ว' : 'เกิดข้อผิดพลาด',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approveUser(String uid, String name) async {
    // เรียกใช้ FirebaseService
    final success = await FirebaseService().approveUser(uid);

    if (success) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('อนุมัติ $name เรียบร้อยแล้ว'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เกิดข้อผิดพลาดในการอนุมัติ'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approveAllUsers() async {
    if (_pendingUsers.isEmpty) return;

    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('ยืนยันการอนุมัติทั้งหมด'),
            content: Text(
              'คุณต้องการอนุมัติผู้ใช้ทั้งหมด ${_pendingUsers.length} คนใช่หรือไม่?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: const Text(
                  'อนุมัติทั้งหมด',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      final uids = _pendingUsers.map((u) => u.uid).toList();
      final success = await FirebaseService().approveMultipleUsers(uids);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'อนุมัติเรียบร้อยแล้ว' : 'เกิดข้อผิดพลาด'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
      setState(() => _selectedUserIds.clear());
    }
  }

  Future<void> _approveSelectedUsers() async {
    if (_selectedUserIds.isEmpty) return;

    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('ยืนยันการอนุมัติที่เลือก'),
            content: Text(
              'คุณต้องการอนุมัติผู้ใช้ที่เลือก ${_selectedUserIds.length} คนใช่หรือไม่?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                child: const Text(
                  'อนุมัติ',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      final success = await FirebaseService().approveMultipleUsers(
        _selectedUserIds.toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'อนุมัติเรียบร้อยแล้ว' : 'เกิดข้อผิดพลาด'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
      setState(() => _selectedUserIds.clear());
    }
  }

  Future<void> _deleteAllPendingUsers() async {
    if (_pendingUsers.isEmpty) return;

    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('ยืนยันลบทั้งหมด'),
            content: Text(
              'คุณต้องการลบ/ปฏิเสธผู้ใช้ที่รออนุมัติทั้งหมด ${_pendingUsers.length} คนใช่หรือไม่?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text(
                  'ลบทั้งหมด',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      // Delete all pending users
      for (var user in _pendingUsers) {
        await FirebaseService().deleteUser(user.uid);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ลบรายการที่รออนุมัติทั้งหมดแล้ว'),
            backgroundColor: Colors.green,
          ),
        );
      }
      setState(() => _selectedUserIds.clear());
    }
  }

  Future<void> _deleteSelectedUsers() async {
    if (_selectedUserIds.isEmpty) return;

    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('ยืนยันลบที่เลือก'),
            content: Text(
              'คุณต้องการลบ/ปฏิเสธผู้ใช้ที่เลือก ${_selectedUserIds.length} คนใช่หรือไม่?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ยกเลิก'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                ),
                child: const Text(
                  'ลบที่เลือก',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      for (var uid in _selectedUserIds) {
        await FirebaseService().deleteUser(uid);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ลบผู้ใช้ที่เลือกเรียบร้อยแล้ว'),
            backgroundColor: Colors.green,
          ),
        );
      }
      setState(() => _selectedUserIds.clear());
    }
  }

  void _showManagementOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'ตัวเลือกการจัดการ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF9A2C2C),
                ),
              ),
              const SizedBox(height: 20),

              // Approve Selected
              if (_hasSelection)
                ListTile(
                  leading: const Icon(
                    Icons.check_circle_outline,
                    color: Colors.blue,
                  ),
                  title: Text(
                    'อนุมัติที่เลือก (${_selectedUserIds.length})',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _approveSelectedUsers();
                  },
                ),

              // Delete Selected
              if (_hasSelection)
                ListTile(
                  leading: const Icon(
                    Icons.delete_sweep,
                    color: Colors.redAccent,
                  ),
                  title: Text(
                    'ลบ/ปฏิเสธ ที่เลือก (${_selectedUserIds.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteSelectedUsers();
                  },
                ),

              if (_hasSelection) const Divider(),

              // Delete All
              ListTile(
                leading: const Icon(Icons.delete_forever, color: Colors.red),
                title: const Text('ลบทั้งหมด (ล้างรายการ)'),
                subtitle: Text(
                  'ลบผู้ใช้รออนุมัติทั้งหมด ${_pendingUsers.length} คน',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _deleteAllPendingUsers();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _toggleUserSelection(String uid) {
    setState(() {
      if (_selectedUserIds.contains(uid)) {
        _selectedUserIds.remove(uid);
      } else {
        _selectedUserIds.add(uid);
      }
    });
  }

  Future<void> _deleteUser(String uid, String name) async {
    bool confirm =
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('ยืนยันการลบ'),
            content: Text('คุณต้องการลบผู้ใช้ "$name" ใช่หรือไม่?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('ยกเลิก'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ลบ', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (confirm) {
      bool success = await FirebaseService().deleteUser(uid);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ลบผู้ใช้สำเร็จ'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text(
          'จัดการผู้ใช้งาน',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF9A2C2C),
        iconTheme: const IconThemeData(color: Colors.white),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Builder(
            builder: (context) {
              return IconButton(
                tooltip: 'เมนู',
                icon: const Icon(Icons.menu, color: Colors.white, size: 28),
                onPressed: () {
                  Scaffold.of(context).openDrawer();
                },
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('รออนุมัติ'),
                  if (_pendingUsers.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_pendingUsers.length}',
                        style: const TextStyle(
                          color: Color(0xFF9A2C2C),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Tab(text: 'ทั้งหมด'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                // Pending Tab
                _buildPendingList(),
                // All Users Tab
                _buildAllUsersList(),
              ],
            ),
    );
  }

  Widget _buildPendingList() {
    if (_pendingUsers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              size: 80,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 16),
            Text(
              'ไม่มีผู้ใช้รออนุมัติ',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Approve All Button (Primary Action)
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _approveAllUsers,
                  icon: const Icon(Icons.done_all, color: Colors.white),
                  label: Text(
                    'อนุมัติทั้งหมด (${_pendingUsers.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    // shadowColor: Colors.green.withOpacity(0.4),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Options Button (Secondary Action)
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.shade200,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  onPressed: _showManagementOptions,
                  icon: const Icon(Icons.tune, color: Color(0xFF9A2C2C)),
                  tooltip: 'ตัวเลือกจัดการ',
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        // User List
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _pendingUsers.length,
            itemBuilder: (context, index) {
              final user = _pendingUsers[index];
              final uid = user.uid;
              final isSelected = _selectedUserIds.contains(uid);

              return Card(
                elevation: isSelected ? 6 : 3,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: isSelected
                      ? BorderSide(color: Colors.blue.shade400, width: 2)
                      : BorderSide.none,
                ),
                color: isSelected ? Colors.blue.shade50 : Colors.white,
                child: InkWell(
                  onTap: () => _toggleUserSelection(uid),
                  borderRadius: BorderRadius.circular(12),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          backgroundColor: isSelected
                              ? Colors.blue.shade100
                              : Colors.orange.shade100,
                          child: Icon(
                            Icons.person,
                            color: isSelected
                                ? Colors.blue.shade700
                                : Colors.orange.shade700,
                          ),
                        ),
                        if (isSelected)
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.check,
                                size: 12,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Text(
                      user.fullname,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.blue.shade900 : Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      user.email,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.blue.shade700
                            : Colors.grey.shade600,
                      ),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Checkbox for selection
                        Checkbox(
                          value: isSelected,
                          onChanged: (value) => _toggleUserSelection(uid),
                          activeColor: Colors.blue,
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 28,
                          ),
                          tooltip: 'อนุมัติ',
                          onPressed: () =>
                              _approveUser(user.uid, user.fullname),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.cancel,
                            color: Colors.red,
                            size: 28,
                          ),
                          tooltip: 'ปฏิเสธ',
                          onPressed: () => _deleteUser(user.uid, user.fullname),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAllUsersList() {
    // 1. Filter logic
    final filteredUsers = _allUsers.where((user) {
      final name = user.fullname.toLowerCase();
      final email = user.email.toLowerCase();
      final role = user.role;

      final matchesSearch =
          name.contains(_searchQuery.toLowerCase()) ||
          email.contains(_searchQuery.toLowerCase());
      final matchesFilter =
          _selectedRoleFilter == 'All' ||
          (_selectedRoleFilter == 'Admin' && role == 1) ||
          (_selectedRoleFilter == 'Checker' && role == 2) ||
          (_selectedRoleFilter == 'User' && role == 0);

      return matchesSearch && matchesFilter;
    }).toList();

    return Column(
      children: [
        // 2. Search Bar & Filter Chips
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.white,
          child: Column(
            children: [
              // Search Bar
              TextField(
                decoration: InputDecoration(
                  hintText: 'ค้นหาชื่อ หรือ อีเมล...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              ),
              const SizedBox(height: 12),
              // Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['All', 'Admin', 'Checker', 'User'].map((filter) {
                    final isSelected = _selectedRoleFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() => _selectedRoleFilter = filter);
                          }
                        },
                        selectedColor: const Color(0xFF9A2C2C),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : Colors.black,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),

        // 3. User List
        Expanded(
          child: filteredUsers.isEmpty
              ? Center(
                  child: Text(
                    'ไม่พบผู้ใช้งาน',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredUsers.length,
                  itemBuilder: (context, index) {
                    final user = filteredUsers[index];
                    bool isApproved = user.isApproved;
                    int role = user.role;

                    // 🔒 Check if this is the current logged-in user
                    final currentUid = ApiService().currentUser?['uid'];
                    final isCurrentUser = currentUid == user.uid;

                    // Determine Icon & Color based on Role
                    IconData roleIcon = Icons.person;
                    Color roleColor = Colors.grey;
                    String roleLabel = 'User';

                    if (role == 1) {
                      roleIcon = Icons.admin_panel_settings;
                      roleColor = Colors.red;
                      roleLabel = 'Admin';
                    } else if (role == 2) {
                      roleIcon = Icons.verified_user;
                      roleColor = Colors.blue;
                      roleLabel = 'Checker';
                    }

                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: roleColor.withValues(alpha: 0.1),
                          child: Icon(roleIcon, color: roleColor),
                        ),
                        title: Text(
                          user.fullname,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.email),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                // Role Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: roleColor.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: roleColor.withValues(alpha: 0.3),
                                    ),
                                  ),
                                  child: Text(
                                    roleLabel.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: roleColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                // Status Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isApproved
                                        ? Colors.green.shade50
                                        : Colors.orange.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isApproved
                                          ? Colors.green.shade200
                                          : Colors.orange.shade200,
                                    ),
                                  ),
                                  child: Text(
                                    isApproved ? 'Active' : 'Pending',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isApproved
                                          ? Colors.green
                                          : Colors.orange,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            // 🔒 Prevent self-modification
                            if (isCurrentUser) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '⚠️ คุณไม่สามารถแก้ไขบัญชีของตัวเองได้',
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            if (value == 'delete') {
                              _deleteUser(user.uid, user.fullname);
                            } else if (value == 'change_role') {
                              _changeUserRole(user.uid, role, user.fullname);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'change_role',
                              enabled: !isCurrentUser,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.manage_accounts,
                                    size: 18,
                                    color: isCurrentUser
                                        ? Colors.grey
                                        : Colors.blue,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isCurrentUser
                                        ? 'เปลี่ยนตำแหน่ง (ไม่สามารถเปลี่ยนตัวเองได้)'
                                        : 'เปลี่ยนตำแหน่ง',
                                    style: TextStyle(
                                      color: isCurrentUser
                                          ? Colors.grey
                                          : Colors.black,
                                      fontSize: isCurrentUser ? 12 : 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              enabled: !isCurrentUser,
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.delete,
                                    size: 18,
                                    color: isCurrentUser
                                        ? Colors.grey
                                        : Colors.red,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isCurrentUser
                                        ? 'ลบผู้ใช้ (ไม่สามารถลบตัวเองได้)'
                                        : 'ลบผู้ใช้',
                                    style: TextStyle(
                                      color: isCurrentUser
                                          ? Colors.grey
                                          : Colors.red,
                                      fontSize: isCurrentUser ? 12 : 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
