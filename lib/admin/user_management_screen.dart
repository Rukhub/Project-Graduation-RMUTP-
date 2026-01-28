import 'package:flutter/material.dart';
import '../data_service.dart';
import '../api_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _pendingUsers = [];
  List<Map<String, dynamic>> _allUsers = [];
  bool _isLoading = true;

  // Search & Filter State
  String _searchQuery = '';
  String _selectedRoleFilter = 'All'; // All, Admin, Checker, User

  // Selection Mode State
  final Set<int> _selectedUserIds = {};
  bool get _hasSelection => _selectedUserIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    // เรียกใช้ API จริงของโบ แทน Mock Data
    final pending = await ApiService().getPendingUsersFromAPI();
    final all = await ApiService().getAllUsersFromAPI();

    setState(() {
      _pendingUsers = pending;
      _allUsers = all;
      _isLoading = false;
    });
  }

  Future<void> _changeUserRole(
    int userId,
    String currentRole,
    String userName,
  ) async {
    // Show dialog to select new role
    String? newRole = await showDialog<String>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: Text('เปลี่ยนตำแหน่งของ $userName'),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'admin'),
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
              onPressed: () => Navigator.pop(context, 'checker'),
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
              onPressed: () => Navigator.pop(context, 'user'),
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
      // Call API
      final result = await ApiService().changeUserRoleAPI(userId, newRole);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'ดำเนินการเสร็จสิ้น'),
            backgroundColor: result['success'] == true
                ? Colors.green
                : Colors.red,
          ),
        );
      }

      if (result['success'] == true) {
        _loadUsers();
      }
    }
  }

  Future<void> _approveUser(int userId, String name) async {
    // เรียกใช้ API จริงของโบ
    final result = await ApiService().approveUserAPI(userId);

    if (result['success'] == true) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('อนุมัติ $name เรียบร้อยแล้ว'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _loadUsers();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'เกิดข้อผิดพลาด'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _approveAllUsers() async {
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
      // เรียกใช้ API จริงของโบ
      final result = await ApiService().approveAllUsersAPI();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'ดำเนินการเสร็จสิ้น'),
            backgroundColor: result['success'] == true
                ? Colors.green
                : Colors.red,
          ),
        );
      }
      setState(() => _selectedUserIds.clear());
      _loadUsers();
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
      final result = await ApiService().approveSelectedUsersAPI(
        _selectedUserIds.toList(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'ดำเนินการเสร็จสิ้น'),
            backgroundColor: result['success'] == true
                ? Colors.green
                : Colors.red,
          ),
        );
      }
      setState(() => _selectedUserIds.clear());
      _loadUsers();
    }
  }

  void _toggleUserSelection(int userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  Future<void> _deleteUser(int userId, String name) async {
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
      // Call DataService for delete operation
      // Keeping original logic as requested by user flow requirements
      bool success = await DataService().deleteUser(userId);
      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('ลบผู้ใช้สำเร็จ'),
              backgroundColor: Colors.red,
            ),
          );
        }
        _loadUsers();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'จัดการผู้ใช้งาน',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF9A2C2C),
        iconTheme: const IconThemeData(color: Colors.white),
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
        // Action Buttons Row
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Approve All Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _approveAllUsers,
                  icon: const Icon(
                    Icons.done_all,
                    color: Colors.white,
                    size: 20,
                  ),
                  label: Text(
                    'อนุมัติทั้งหมด (${_pendingUsers.length})',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              // Approve Selected Button (แสดงเมื่อมีการเลือก)
              if (_hasSelection) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _approveSelectedUsers,
                    icon: const Icon(
                      Icons.check_box,
                      color: Colors.white,
                      size: 20,
                    ),
                    label: Text(
                      'อนุมัติที่เลือก (${_selectedUserIds.length})',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade600,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
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
              final userId = user['user_id'];
              final isSelected = _selectedUserIds.contains(userId);

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
                  onTap: () => _toggleUserSelection(userId),
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
                      user['fullname'] ?? 'Unknown',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.blue.shade900 : Colors.black,
                      ),
                    ),
                    subtitle: Text(
                      user['email'] ?? '',
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
                          onChanged: (value) => _toggleUserSelection(userId),
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
                              _approveUser(user['user_id'], user['fullname']),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.cancel,
                            color: Colors.red,
                            size: 28,
                          ),
                          tooltip: 'ปฏิเสธ',
                          onPressed: () =>
                              _deleteUser(user['user_id'], user['fullname']),
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
      final name = (user['fullname'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      final role = (user['role'] ?? 'user').toString().toLowerCase();

      final matchesSearch =
          name.contains(_searchQuery.toLowerCase()) ||
          email.contains(_searchQuery.toLowerCase());
      final matchesFilter =
          _selectedRoleFilter == 'All' ||
          (_selectedRoleFilter == 'Admin' && role == 'admin') ||
          (_selectedRoleFilter == 'Checker' && role == 'checker') ||
          (_selectedRoleFilter == 'User' && role == 'user');

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
                    bool isApproved = user['is_approved'] == 1;
                    String role = user['role'] ?? 'user';

                    // 🔒 Check if this is the current logged-in user
                    final currentUserId = ApiService().currentUser?['user_id'];
                    final isCurrentUser = currentUserId == user['user_id'];

                    // Determine Icon & Color based on Role
                    IconData roleIcon = Icons.person;
                    Color roleColor = Colors.grey;
                    if (role == 'admin') {
                      roleIcon = Icons.admin_panel_settings;
                      roleColor = Colors.red;
                    } else if (role == 'checker') {
                      roleIcon = Icons.verified_user;
                      roleColor = Colors.blue;
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
                          user['fullname'] ?? 'Unknown',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user['email'] ?? ''),
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
                                    role.toUpperCase(),
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
                                  content: Text('⚠️ คุณไม่สามารถแก้ไขบัญชีของตัวเองได้'),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              return;
                            }

                            if (value == 'delete') {
                              _deleteUser(user['user_id'], user['fullname']);
                            } else if (value == 'change_role') {
                              _changeUserRole(
                                user['user_id'],
                                role,
                                user['fullname'],
                              );
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
                                    color: isCurrentUser ? Colors.grey : Colors.blue,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isCurrentUser 
                                        ? 'เปลี่ยนตำแหน่ง (ไม่สามารถเปลี่ยนตัวเองได้)'
                                        : 'เปลี่ยนตำแหน่ง',
                                    style: TextStyle(
                                      color: isCurrentUser ? Colors.grey : Colors.black,
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
                                    color: isCurrentUser ? Colors.grey : Colors.red,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    isCurrentUser 
                                        ? 'ลบผู้ใช้ (ไม่สามารถลบตัวเองได้)'
                                        : 'ลบผู้ใช้',
                                    style: TextStyle(
                                      color: isCurrentUser ? Colors.grey : Colors.red,
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
