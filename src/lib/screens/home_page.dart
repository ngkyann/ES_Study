import 'package:flutter/material.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:esstudy/screens/profile_page.dart';
import 'package:esstudy/screens/room_search_page.dart';
import 'package:esstudy/screens/offline_study_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/screens/leaderboard_page.dart';
import 'package:esstudy/screens/settings_page.dart';
import 'package:esstudy/screens/plan_page.dart';
import 'package:esstudy/screens/history_page.dart';
import 'package:timezone/timezone.dart' as tz;

class HomePage extends StatefulWidget {
  final String userName;
  final String userId;
  final String selectedClass;
  final String email;
  const HomePage({
    super.key,
    required this.userName,
    required this.userId,
    required this.selectedClass,
    required this.email,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int userPoints = 0;
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
          userPoints = doc.data()!['points'] ?? 100;
          _isLoadingPoints = false;
        });
      } else {
        setState(() => _isLoadingPoints = false);
      }
    } catch (e) {
      debugPrint("Lỗi tải điểm: $e");
      setState(() => _isLoadingPoints = false);
    }
  }

  Future<void> _updatePointsOnFirebase(int additionalPoints) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({'points': FieldValue.increment(additionalPoints)});
      setState(() => userPoints += additionalPoints);
      debugPrint("Cập nhật thành công: +$additionalPoints điểm");
    } catch (e) {
      debugPrint("Lỗi cập nhật điểm: $e");
    }
  }

  String getGreeting() {
    final vn = tz.getLocation('Asia/Ho_Chi_Minh');
    final now = tz.TZDateTime.now(vn);
    final hour = now.hour;

    if (hour >= 5 && hour < 12) return "Chào buổi sáng";
    if (hour >= 12 && hour < 18) return "Chào buổi chiều";
    return "Chào buổi tối";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          Colors.grey.shade50, // Đồng bộ nền xám để bóng đổ hiển thị đẹp
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        leadingWidth: 160,
        leading: Container(
          margin: const EdgeInsets.only(left: 16),
          child: Row(
            children: [
              const Icon(
                Icons.local_fire_department,
                color: Colors.orangeAccent,
              ),
              const SizedBox(width: 4),
              const Text(
                "15",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.workspace_premium, color: Colors.yellow),
              const SizedBox(width: 4),
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
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            "Trang chủ",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfilePage(
                      userName: widget.userName,
                      userId: widget.userId,
                      selectedClass: widget.selectedClass,
                      userPoints: userPoints,
                    ),
                  ),
                );
              },
              child: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: primaryColor),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: primaryColor,
        backgroundColor: Colors.white,
        onRefresh: () async {
          setState(() => _isLoadingPoints = true);
          await _fetchUserPoints();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 🔥 ĐÃ FIX: Thủ thuật lấp đầy khoảng trắng bằng Stack khi vuốt
              Stack(
                clipBehavior: Clip.none,
                children: [
                  // Miếng dán tàng hình vươn lên 500px để lấp khoảng hở khi vuốt
                  Positioned(
                    top: -500,
                    left: 0,
                    right: 0,
                    height: 500,
                    child: Container(color: primaryColor),
                  ),
                  // Giao diện Header bo tròn gốc của bạn
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
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "${getGreeting()},",
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          widget.userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Padding(
                padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
                child: Text(
                  "Bắt đầu học",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              _buildGridMenu(context, [
                MenuData(Icons.add_home, "Tạo phòng", Colors.orange),
                MenuData(Icons.menu_book, "Học Offline", Colors.green),
                MenuData(
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
                MenuData(Icons.event_note, "Kế hoạch", Colors.purple),
                MenuData(Icons.leaderboard, "Xếp hạng", Colors.redAccent),
                MenuData(Icons.people, "Bạn bè", Colors.teal),
                MenuData(Icons.history, "Lịch sử học tập", Colors.blueGrey),
                MenuData(Icons.bar_chart, "Thống kê", Colors.indigo),
                MenuData(Icons.settings, "Cài đặt", Colors.grey),
              ]),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGridMenu(BuildContext context, List<MenuData> items) {
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
        final item = items[index];
        return InkWell(
          onTap: () async {
            await Future.delayed(const Duration(milliseconds: 50));
            if (!context.mounted) return;

            if (item.title == "Học Offline") {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OfflineStudyPage(userId: widget.userId),
                ),
              );
              // Nếu hoàn thành và được cộng điểm, tự động tải lại điểm luôn
              if (result is int) await _updatePointsOnFirebase(result);
            } else if (item.isSearch) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RoomSearchPage()),
              );
            } else if (item.title == "Kế hoạch") {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlanPage(userId: widget.userId),
                ),
              );
            } else if (item.title == "Xếp hạng") {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LeaderboardPage(currentUserId: widget.userId),
                ),
              );
            } else if (item.title == "Lịch sử học tập") {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HistoryPage(userId: widget.userId),
                ),
              );
            } else if (item.title == "Cài đặt") {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsPage(
                    userName: widget.userName,
                    selectedClass: widget.selectedClass,
                    userId: widget.userId,
                    email: widget.email,
                  ),
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
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, color: item.color, size: 30),
                ),
                const SizedBox(height: 8),
                Text(
                  item.title,
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

class MenuData {
  final IconData icon;
  final String title;
  final Color color;
  final bool isSearch;
  MenuData(this.icon, this.title, this.color, {this.isSearch = false});
}
