import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

enum UserFilterStatus { all, active, banned }

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  List<Map<String, dynamic>> _users = [];
  List<Map<String, dynamic>> _filteredUsers = [];

  // 當前選取的分類標籤
  UserFilterStatus _selectedFilter = UserFilterStatus.all;

  @override
  void initState() {
    super.initState();
    _fetchAdminUsers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 抓取真實用戶清單
  Future<void> _fetchAdminUsers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String url = '${ApiConfig.baseUrl}members/admin-users/';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        setState(() {
          _users = List<Map<String, dynamic>>.from(data);
          _applyFilters();
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = '載入失敗 (狀態碼: ${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('抓取後台用戶錯誤: $e');
      setState(() {
        _errorMessage = '連線伺服器失敗，請確認後端已啟動';
        _isLoading = false;
      });
    }
  }

  // 統一過濾邏輯：同時結合「狀態分類」與「搜尋關鍵字」
  void _applyFilters() {
    final query = _searchController.text.trim().toLowerCase();

    setState(() {
      _filteredUsers = _users.where((user) {
        final bool isActive = user['isActive'] == true;

        // 1. 狀態篩選
        if (_selectedFilter == UserFilterStatus.active && !isActive)
          return false;
        if (_selectedFilter == UserFilterStatus.banned && isActive)
          return false;

        // 2. 關鍵字搜尋
        if (query.isNotEmpty) {
          final name = (user['name'] ?? '').toString().toLowerCase();
          final email = (user['email'] ?? '').toString().toLowerCase();
          return name.contains(query) || email.contains(query);
        }

        return true;
      }).toList();
    });
  }

  // 搜尋字串變更
  void _onSearchChanged(String query) {
    _applyFilters();
  }

  // 切換分類標籤
  void _onFilterChanged(UserFilterStatus status) {
    setState(() {
      _selectedFilter = status;
    });
    _applyFilters();
  }

  // 呼叫後端 API 切換用戶啟用/停權
  Future<void> _toggleUserStatus(
      int userId, int index, String userName, bool currentActive) async {
    final String actionText = currentActive ? '停用' : '啟用';
    String selectedReason = '多次違反社群規範';
    final List<String> banReasons = [
      '多次違反社群規範',
      '發布不當或騷擾言論',
      '惡意檢舉與刷屏行為',
      '涉及商業廣告或詐騙',
      '其他違規事項',
    ];

    // 跳出確認對話框（停用時可選取停權原因）
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Text('確認$actionText？',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('您確定要將用戶「$userName」變更為【$actionText】狀態嗎？'),
                  if (currentActive) ...[
                    const SizedBox(height: 16),
                    const Text(
                      '停用原因：',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedReason,
                          isExpanded: true,
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black87),
                          items: banReasons.map((reason) {
                            return DropdownMenuItem(
                              value: reason,
                              child: Text(reason),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() {
                                selectedReason = val;
                              });
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('取消', style: TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogCtx, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentActive
                        ? Colors.redAccent
                        : const Color(0xFF0FB862),
                    foregroundColor: Colors.white,
                  ),
                  child: Text('確定$actionText'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    final String url = '${ApiConfig.baseUrl}members/$userId/toggle-status/';

    try {
      final response = await http.post(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final bool newActive = data['isActive'];

        // 更新資料庫回傳的真實狀態
        final userInOriginal = _users.firstWhere(
          (u) => u['id'] == userId,
          orElse: () => {},
        );
        if (userInOriginal.isNotEmpty) {
          userInOriginal['isActive'] = newActive;
        }

        // 重新套用過濾
        _applyFilters();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('已成功將 $userName 變更為 ${newActive ? "已啟用" : "已停用"}'),
              backgroundColor:
                  newActive ? const Color(0xFF0FB862) : Colors.black87,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('變更失敗 (狀態碼: ${response.statusCode})')),
          );
        }
      }
    } catch (e) {
      debugPrint('切換狀態錯誤: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('網路連線異常，無法變更狀態')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildSearchBarCard(),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildFilterChips(),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildUserListCard(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // 狀態分類按鈕區
  Widget _buildFilterChips() {
    final int totalCount = _users.length;
    final int activeCount = _users.where((u) => u['isActive'] == true).length;
    final int bannedCount = _users.where((u) => u['isActive'] == false).length;

    return Row(
      children: [
        _buildChipItem(
          label: '全部 ($totalCount)',
          status: UserFilterStatus.all,
        ),
        const SizedBox(width: 8),
        _buildChipItem(
          label: '正常啟用 ($activeCount)',
          status: UserFilterStatus.active,
          activeColor: const Color(0xFF0FB862),
        ),
        const SizedBox(width: 8),
        _buildChipItem(
          label: '已停權 ($bannedCount)',
          status: UserFilterStatus.banned,
          activeColor: Colors.redAccent,
        ),
      ],
    );
  }

  Widget _buildChipItem({
    required String label,
    required UserFilterStatus status,
    Color activeColor = Colors.black,
  }) {
    final bool isSelected = _selectedFilter == status;

    return GestureDetector(
      onTap: () => _onFilterChanged(status),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.shade300,
            width: 1.2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF4B5563),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBarCard() {
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: _onSearchChanged,
          decoration: const InputDecoration(
            icon: Icon(Icons.search, color: Colors.grey, size: 20),
            hintText: '依姓名或電子信箱搜尋用戶',
            hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildUserListCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_outline,
                        size: 22, color: Colors.black),
                    const SizedBox(width: 8),
                    Text(
                      '用戶管理 (${_filteredUsers.length})',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: _fetchAdminUsers,
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
            color: const Color(0xFFFAFAFA),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '用戶資訊',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5A6A80),
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  '狀態 (點擊切換)',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF5A6A80),
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(32.0),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else if (_filteredUsers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Center(
                child: Text(
                  '查無符合條件的用戶資料',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredUsers.length,
              separatorBuilder: (context, index) =>
                  const Divider(height: 1, color: Color(0xFFF0F0F0)),
              itemBuilder: (context, index) {
                final user = _filteredUsers[index];
                final int userId = user['id'];
                final String name = user['name']?.toString().isNotEmpty == true
                    ? user['name'].toString()
                    : '未設定名稱';
                final String email =
                    user['email']?.toString().isNotEmpty == true
                        ? user['email'].toString()
                        : '無 Email';
                final bool isActive = user['isActive'] == true;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 14.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              email,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () =>
                            _toggleUserStatus(userId, index, name, isActive),
                        child: _buildStatusBadge(isActive),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isActive) {
    if (isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F8F0),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF6CE0A1)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline,
                size: 14, color: Color(0xFF0FB862)),
            SizedBox(width: 4),
            Text(
              '已啟用',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0FB862),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cancel_outlined, size: 14, color: Color(0xFF6B7280)),
            SizedBox(width: 4),
            Text(
              '已停權',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }
  }
}
