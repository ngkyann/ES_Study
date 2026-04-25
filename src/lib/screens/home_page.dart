import 'package:flutter/material.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:esstudy/screens/profile_page.dart';
import 'package:esstudy/screens/room_search_page.dart';
import 'package:esstudy/screens/offline_study_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/screens/leaderboard_page.dart'; // Thêm dòng này

// --- MÀN HÌNH CHÍNH ---
class HomePage extends StatefulWidget {
  final String userName;
  final String userId;
  final String selectedClass;

  const HomePage({
    super.key,
    required this.userName,
    required this.userId,
    required this.selectedClass,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int userPoints = 0; // 👈 điểm ban đầu
  bool _isLoadingPoints = true;
  @override
  void initState() {
    super.initState();
    _fetchUserPoints();
  }

  Future<void> _fetchUserPoints() async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (doc.exists && doc.data() != null) {
        setState(() {
          // Lấy giá trị từ Firebase, nếu không có mới dùng 100 làm dự phòng
          userPoints = doc.data()!['points'] ?? 100;
          _isLoadingPoints = false;
        });
      } else {
        // Nếu user chưa có trên DB (lỗi hy hữu), tắt loading và giữ mức 0 hoặc 100
        setState(() => _isLoadingPoints = false);
      }
    } catch (e) {
      debugPrint("Lỗi tải điểm: $e");
      setState(() => _isLoadingPoints = false);
    }
  }

  Future<void> _updatePointsOnFirebase(int additionalPoints) async {
    try {
      // 1. Cập nhật lên Firebase (Cộng dồn số điểm mới vào số cũ)
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId) // Dùng ID của user hiện tại
          .update({
            'points': FieldValue.increment(
              additionalPoints,
            ), // Lệnh chuẩn để cộng dồn
          });

      // 2. Cập nhật giao diện (Local State)
      setState(() {
        userPoints += additionalPoints;
      });

      debugPrint("Cập nhật thành công: +$additionalPoints điểm");
    } catch (e) {
      debugPrint("Lỗi cập nhật điểm: $e");
      // Thông báo cho người dùng nếu cần
    }
  }

  String getGreeting() {
    final now = DateTime.now().toUtc().add(
      const Duration(hours: 7),
    ); // 🇻🇳 GMT+7
    final hour = now.hour;

    if (hour >= 5 && hour < 12) {
      return "Chào buổi sáng";
    } else if (hour >= 12 && hour < 18) {
      return "Chào buổi chiều";
    } else {
      return "Chào buổi tối";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        leadingWidth: 160,
        leading: Container(
          margin: const EdgeInsets.only(left: 16),
          child: Row(
            children: [
              /// 🔥 STREAK
              const Icon(
                Icons.local_fire_department,
                color: Colors.orangeAccent,
              ),
              const SizedBox(width: 4),
              const Text(
                "15", // 👉 sau này có thể làm dynamic
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),

              const SizedBox(width: 12),

              /// 🏆 POINT
              /// 🏆 POINT
              const Icon(Icons.workspace_premium, color: Colors.yellow),
              const SizedBox(width: 4),

              // Thay đổi đoạn Text cũ thành đoạn kiểm tra này:
              _isLoadingPoints
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      "$userPoints",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
            ],
          ),
        ),
        title: const Text("Trang chủ"),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfilePage(
                    userName: widget.userName,
                    userId: widget.userId,
                    selectedClass: widget.selectedClass,
                    userPoints: userPoints, // 👈 truyền
                  ),
                ),
              ),
              child: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: primaryColor),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 30,
                    spreadRadius: 4,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${getGreeting()},",
                    style: const TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  Text(
                    widget.userName, // Hiển thị tên người dùng đã nhập
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text(
                "Bắt đầu học",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            _buildGridMenu(context, [
              _MenuData(Icons.add_home, "Tạo phòng", Colors.orange),
              _MenuData(Icons.menu_book, "Học Offline", Colors.green),

              _MenuData(
                Icons.search,
                "Tìm phòng",
                primaryColor,
                isSearch: true,
              ),
            ]),

            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text(
                "Tiện ích khác",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            _buildGridMenu(context, [
              _MenuData(Icons.event_note, "Kế hoạch", Colors.purple),
              _MenuData(Icons.leaderboard, "Xếp hạng", Colors.redAccent),
              _MenuData(Icons.people, "Bạn bè", Colors.teal),
              _MenuData(Icons.history, "Lịch sử học tập", Colors.blueGrey),
              _MenuData(Icons.bar_chart, "Thống kê", Colors.indigo),
              _MenuData(Icons.settings, "Cài đặt", Colors.grey),
            ]),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildGridMenu(BuildContext context, List<_MenuData> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return InkWell(
          onTap: () async {
            if (items[index].title == "Học Offline") {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const OfflineStudyPage()),
              );
              if (result is int) {
                await _updatePointsOnFirebase(result);
              }
            } else if (items[index].isSearch) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RoomSearchPage()),
              );
            } else if (items[index].title == "Xếp hạng") {
              // 👇 THÊM ĐOẠN NÀY ĐỂ MỞ BẢNG XẾP HẠNG 👇
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LeaderboardPage(currentUserId: widget.userId),
                ),
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: items[index].color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    items[index].icon,
                    color: items[index].color,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  items[index].title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MenuData {
  final IconData icon;
  final String title;
  final Color color;
  final bool isSearch;
  _MenuData(this.icon, this.title, this.color, {this.isSearch = false});
}
