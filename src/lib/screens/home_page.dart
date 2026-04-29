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
import 'package:esstudy/screens/ai_assistant_page.dart';
import 'package:esstudy/screens/friends_page.dart'; // 🔥 ĐÃ THÊM IMPORT NÀY
import 'package:esstudy/screens/statistics_page.dart'; // Đổi đường dẫn theo dự án của bạn

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
  int userStreak = 0;
  bool _isLoadingData = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTodayPlansAndShowPopup();
    });
  }

  Future<void> _checkTodayPlansAndShowPopup() async {
    try {
      final now = DateTime.now();
      final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

      final snapshot = await FirebaseFirestore.instance
          .collection('plans')
          .where('userId', isEqualTo: widget.userId)
          .get();

      List<QueryDocumentSnapshot> todayPlans = [];

      for (var doc in snapshot.docs) {
        DateTime time = (doc['time'] as Timestamp).toDate();
        if (time.isBefore(endOfToday)) {
          todayPlans.add(doc);
        }
      }

      if (todayPlans.isNotEmpty && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: Row(
                children: [
                  Icon(Icons.auto_awesome, color: primaryColor),
                  const SizedBox(width: 10),
                  const Text(
                    "Nhắc nhở học tập",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Chào ${widget.userName}, bạn có các kế hoạch chưa hoàn thành:",
                  ),
                  const SizedBox(height: 15),
                  ...todayPlans.map((doc) {
                    DateTime time = (doc['time'] as Timestamp).toDate();
                    String timeStr =
                        "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        "• ${doc['title']} ($timeStr)",
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    );
                  }),
                ],
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    minimumSize: const Size(double.infinity, 45),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text(
                    "Đã hiểu, vào học thôi!",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      debugPrint("Lỗi kiểm tra kế hoạch: $e");
    }
  }

  Future<void> _fetchUserData() async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        int points = data['points'] ?? 100;
        int streak = data['streakCount'] ?? 0;
        Timestamp? lastStudyTs = data['lastStudyDate'];

        if (lastStudyTs != null && streak > 0) {
          DateTime lastStudy = lastStudyTs.toDate();
          DateTime now = DateTime.now();
          DateTime today = DateTime(now.year, now.month, now.day);
          DateTime lastStudyDay = DateTime(
            lastStudy.year,
            lastStudy.month,
            lastStudy.day,
          );

          if (today.difference(lastStudyDay).inDays > 1) {
            streak = 0;
            FirebaseFirestore.instance
                .collection('users')
                .doc(widget.userId)
                .update({'streakCount': 0});
          }
        }

        setState(() {
          userPoints = points;
          userStreak = streak;
          _isLoadingData = false;
        });
      } else {
        setState(() => _isLoadingData = false);
      }
    } catch (e) {
      setState(() => _isLoadingData = false);
    }
  }

  Future<void> _updateStudyProgress(int additionalPoints) async {
    try {
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId);
      final doc = await userRef.get();

      int newStreak = 1;
      DateTime now = DateTime.now();
      DateTime today = DateTime(now.year, now.month, now.day);

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        int currentStreak = data['streakCount'] ?? 0;
        Timestamp? lastStudyTs = data['lastStudyDate'];

        if (lastStudyTs != null) {
          DateTime lastStudy = lastStudyTs.toDate();
          DateTime lastStudyDay = DateTime(
            lastStudy.year,
            lastStudy.month,
            lastStudy.day,
          );
          int difference = today.difference(lastStudyDay).inDays;

          if (difference == 0) {
            newStreak = currentStreak;
          } else if (difference == 1) {
            newStreak = currentStreak + 1;
          } else {
            newStreak = 1;
          }
        }
      }

      await userRef.set({
        'points': FieldValue.increment(additionalPoints),
        'streakCount': newStreak,
        'lastStudyDate': Timestamp.fromDate(now),
      }, SetOptions(merge: true));

      setState(() {
        userPoints += additionalPoints;
        userStreak = newStreak;
      });
    } catch (e) {
      debugPrint("Lỗi cập nhật tiến trình: $e");
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
      backgroundColor: Colors.grey.shade50,
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
              _isLoadingData
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      "$userStreak",
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
              const SizedBox(width: 12),
              const Icon(Icons.workspace_premium, color: Colors.yellow),
              const SizedBox(width: 4),
              _isLoadingData
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
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProfilePage(
                      userName: widget.userName,
                      userId: widget.userId,
                      selectedClass: widget.selectedClass,
                      userPoints: userPoints,
                      email: widget.email,
                      userStreak: userStreak,
                    ),
                  ),
                );
                if (mounted) setState(() {});
              },
              child: CircleAvatar(
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
          setState(() => _isLoadingData = true);
          await _fetchUserData();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    top: -500,
                    left: 0,
                    right: 0,
                    height: 500,
                    child: Container(color: primaryColor),
                  ),
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
                MenuData(Icons.smart_toy, "Trợ lý ảo", Colors.blueAccent),
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
              if (result is int) await _updateStudyProgress(result);
              if (mounted) setState(() {});
            } else if (item.title == "Trợ lý ảo") {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AIAssistantPage()),
              );
              if (mounted) setState(() {});
            } else if (item.isSearch) {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RoomSearchPage()),
              );
              if (mounted) setState(() {});
            } else if (item.title == "Kế hoạch") {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlanPage(userId: widget.userId),
                ),
              );
              if (mounted) setState(() {});
            } else if (item.title == "Xếp hạng") {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LeaderboardPage(currentUserId: widget.userId),
                ),
              );
              if (mounted) setState(() {});
            } else if (item.title == "Lịch sử học tập") {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HistoryPage(userId: widget.userId),
                ),
              );
              if (mounted) setState(() {});
            } else if (item.title == "Thống kê") {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StatisticsPage(userId: widget.userId),
                ),
              );
              if (mounted) setState(() {});
            } else if (item.title == "Cài đặt") {
              await Navigator.push(
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
              if (mounted) setState(() {});
            } else if (item.title == "Bạn bè") {
              // 🔥 KÍCH HOẠT NÚT BẠN BÈ TẠI ĐÂY
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => FriendsPage(
                    currentUserId: widget.userId,
                    currentUserName: widget.userName,
                  ),
                ),
              );
              if (mounted) setState(() {});
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
