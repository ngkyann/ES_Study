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
import 'package:esstudy/screens/friends_page.dart';
import 'package:esstudy/screens/statistics_page.dart';
import 'package:esstudy/screens/create_room_page.dart';
import 'package:esstudy/constants/var.dart'; // 🔥 IMPORT BIẾN NGÔN NGỮ

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
    bool isVN = languageNotifier.value == "Tiếng Việt"; // Kiểm tra ngôn ngữ

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
                  Text(
                    isVN ? "Nhắc nhở học tập" : "Study Reminder",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isVN
                        ? "Chào ${widget.userName}, bạn có các kế hoạch chưa hoàn thành:"
                        : "Hi ${widget.userName}, you have uncompleted plans:",
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
                  child: Text(
                    isVN ? "Đã hiểu, vào học thôi!" : "Got it, let's study!",
                    style: const TextStyle(
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
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(widget.userId);
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

  // Cập nhật hàm chào dựa vào ngôn ngữ
  String getGreeting() {
    final vn = tz.getLocation('Asia/Ho_Chi_Minh');
    final now = tz.TZDateTime.now(vn);
    final hour = now.hour;
    bool isVN = languageNotifier.value == "Tiếng Việt";

    if (hour >= 5 && hour < 12) return isVN ? "Chào buổi sáng" : "Good morning";
    if (hour >= 12 && hour < 18)
      return isVN ? "Chào buổi chiều" : "Good afternoon";
    return isVN ? "Chào buổi tối" : "Good evening";
  }

  // 🔥 Hàm dịch Text Menu mà không ảnh hưởng code logic
  String _getMenuTitle(String id, bool isVN) {
    if (isVN) return id;
    switch (id) {
      case "Tạo phòng học":
        return "Create Room";
      case "Học offline":
        return "Offline Study";
      case "Tìm phòng học":
        return "Search Room";
      case "Kế hoạch học tập":
        return "Study Plan";
      case "Bảng xếp hạng":
        return "Leaderboard";
      case "Bạn bè":
        return "Friends";
      case "Lịch sử học tập":
        return "Study History";
      case "Thành tích học tập":
        return "Achievements";
      case "Trợ lý học tập":
        return "AI Assistant";
      default:
        return id;
    }
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 BỌC ValueListenableBuilder cho toàn bộ trang
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, child) {
        bool isVN = lang == "Tiếng Việt";

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            elevation: 0,
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            leadingWidth: 230,
            leading: Container(
              margin: const EdgeInsets.only(left: 16, top: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      await Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder:
                              (context, animation, secondaryAnimation) =>
                                  ProfilePage(
                            userName: widget.userName,
                            userId: widget.userId,
                            selectedClass: widget.selectedClass,
                            userPoints: userPoints,
                            email: widget.email,
                            userStreak: userStreak,
                          ),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                            const begin = Offset(-1.0, 0.0);
                            const end = Offset.zero;
                            const curve = Curves.easeInOut;

                            var tween = Tween(begin: begin, end: end)
                                .chain(CurveTween(curve: curve));
                            var offsetAnimation = animation.drive(tween);

                            return SlideTransition(
                              position: offsetAnimation,
                              child: child,
                            );
                          },
                          transitionDuration: const Duration(milliseconds: 750),
                        ),
                      );
                      if (mounted) setState(() {});
                    },
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white,
                        child:
                            Icon(Icons.person, color: primaryColor, size: 20),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
            actions: [
              IconButton(
                icon: const Icon(
                  Icons.settings,
                  size: 28,
                  color: Colors.white,
                ),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, secondaryAnimation) =>
                          SettingsPage(
                        userName: widget.userName,
                        selectedClass: widget.selectedClass,
                        userId: widget.userId,
                        email: widget.email,
                      ),
                      transitionsBuilder:
                          (context, animation, secondaryAnimation, child) {
                        const begin = Offset(1.0, 0.0);
                        const end = Offset.zero;
                        const curve = Curves.easeInOut;

                        var tween = Tween(begin: begin, end: end)
                            .chain(CurveTween(curve: curve));
                        var offsetAnimation = animation.drive(tween);

                        return SlideTransition(
                          position: offsetAnimation,
                          child: child,
                        );
                      },
                      transitionDuration: const Duration(milliseconds: 750),
                    ),
                  );
                  if (mounted) setState(() {});
                },
              ),
              const SizedBox(width: 4),
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
                        child: ClipRRect(
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(30),
                            bottomRight: Radius.circular(30),
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                bottom: -50,
                                right: -30,
                                child: Transform.scale(
                                  scaleX: 1.4,
                                  child: Icon(
                                    Icons.cloud,
                                    color: Colors.white.withOpacity(0.32),
                                    size: 180,
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: 10,
                                right: 120,
                                child: Transform.scale(
                                  scaleX: 1.3,
                                  child: Icon(
                                    Icons.cloud,
                                    color: Colors.white.withOpacity(0.28),
                                    size: 90,
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 15,
                                  left: 20,
                                  right: 20,
                                  bottom: 45,
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
                                    const SizedBox(height: 4),
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
                        ),
                      ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Text(
                      isVN ? "Bắt đầu học" : "Start Studying",
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  // Truyền thêm biến isVN vào hàm vẽ Menu
                  _buildGridMenu(
                      context,
                      [
                        MenuData(
                            Icons.add_home, "Tạo phòng học", Colors.orange),
                        MenuData(Icons.menu_book, "Học offline", Colors.green),
                        MenuData(
                          Icons.search,
                          "Tìm phòng học",
                          primaryColor,
                          isSearch: true,
                        ),
                      ],
                      isVN),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Text(
                      isVN ? "Tiện ích khác" : "Other Utilities",
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  _buildGridMenu(
                      context,
                      [
                        MenuData(Icons.event_note, "Kế hoạch học tập",
                            Colors.purple),
                        MenuData(Icons.leaderboard, "Bảng xếp hạng",
                            Colors.redAccent),
                        MenuData(Icons.people, "Bạn bè", Colors.teal),
                        MenuData(
                            Icons.history, "Lịch sử học tập", Colors.blueGrey),
                        MenuData(Icons.emoji_events, "Thành tích học tập",
                            Colors.indigo),
                        MenuData(Icons.smart_toy, "Trợ lý học tập",
                            Colors.blueAccent),
                      ],
                      isVN),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 🔥 Nhận thêm tham số isVN
  Widget _buildGridMenu(BuildContext context, List<MenuData> items, bool isVN) {
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

            // Logic chuyển trang sử dụng nguyên gốc Tiếng Việt để không bị lỗi
            if (item.title == "Tạo phòng học") {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CreateRoomPage(
                    userId: widget.userId,
                    userName: widget.userName,
                    userClass: widget.selectedClass,
                  ),
                ),
              );
              if (mounted) setState(() {});
            } else if (item.title == "Học offline") {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => OfflineStudyPage(userId: widget.userId),
                ),
              );
              if (result is int) await _updateStudyProgress(result);
              if (mounted) setState(() {});
            } else if (item.title == "Trợ lý học tập") {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AIAssistantPage()),
              );
              if (mounted) setState(() {});
            } else if (item.isSearch) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => RoomSearchPage(
                    currentUserId: widget.userId,
                    currentUserName: widget.userName,
                  ),
                ),
              );
              if (mounted) setState(() {});
            } else if (item.title == "Kế hoạch học tập") {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlanPage(userId: widget.userId),
                ),
              );
              if (mounted) setState(() {});
            } else if (item.title == "Bảng xếp hạng") {
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
            } else if (item.title == "Thành tích học tập") {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StatisticsPage(userId: widget.userId),
                ),
              );
              if (mounted) setState(() {});
            } else if (item.title == "Bạn bè") {
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
                  // Dùng hàm dịch tại đây
                  _getMenuTitle(item.title, isVN),
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
