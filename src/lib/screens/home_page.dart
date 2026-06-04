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
import 'package:esstudy/constants/var.dart';
import 'package:esstudy/screens/notification_page.dart';
import 'package:esstudy/screens/shop_page.dart';
import 'dart:async';
import 'dart:math';

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

// Clipper hỗ trợ tự vẽ chiếc mũi hình tam giác cho người tuyết
class TriangleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, size.height / 2); // Điểm nhọn của mũi hướng về bên trái
    path.lineTo(size.width, 0); // Góc trên gốc mũi
    path.lineTo(size.width, size.height); // Góc dưới gốc mũi
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class _HomePageState extends State<HomePage> {
  int userPoints = 0;
  int userStreak = 0;
  int userCoins = 0;
  bool _isLoadingData = true;
  String _realEmail = '';
  String _realName = '';
  String _realClass = '';
  int _currentIndex = 1;
  bool _isUpdating = false;

  String _activeEffect = '';
  Map<String, dynamic>? userData;

  StreamSubscription<DocumentSnapshot>? _userSubscription;
  int _unreadNotifCount = 0;
  List<DocumentReference> _unreadNotifRefs = [];
  StreamSubscription<QuerySnapshot>? _notifSubscription;

  @override
  void dispose() {
    _userSubscription?.cancel();
    _notifSubscription?.cancel();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _realEmail = widget.email;
    _realName = widget.userName;
    _realClass = widget.selectedClass;
    _startListeningUserData();
    _listenForUnreadNotifications();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkTodayPlansAndShowPopup();
    });
  }

  void _listenForUnreadNotifications() {
    _notifSubscription = FirebaseFirestore.instance
        .collection('notifications')
        .where('userId', isEqualTo: widget.userId)
        .snapshots()
        .listen((snap) {
      int count = 0;
      List<DocumentReference> unreadRefs = [];
      final now = DateTime.now();

      for (var doc in snap.docs) {
        final data = doc.data();
        final isRead = data['isRead'] ?? false;
        final timestamp = data['createdAt'] as Timestamp?;

        if (!isRead && timestamp != null) {
          if (timestamp.toDate().isBefore(now) ||
              timestamp.toDate().isAtSameMomentAs(now)) {
            count++;
            unreadRefs.add(doc.reference);
          }
        }
      }
      if (mounted) {
        setState(() {
          _unreadNotifCount = count;
          _unreadNotifRefs = unreadRefs;
        });
      }
    });
  }

  void _markAllAsRead() {
    if (_unreadNotifRefs.isEmpty) return;
    final batch = FirebaseFirestore.instance.batch();
    for (var ref in _unreadNotifRefs) {
      batch.update(ref, {'isRead': true});
    }
    batch.commit().catchError((e) => debugPrint("Lỗi update isRead: $e"));
    setState(() {
      _unreadNotifCount = 0;
      _unreadNotifRefs.clear();
    });
  }

  Future<void> _checkTodayPlansAndShowPopup() async {
    bool isVN = languageNotifier.value == "Tiếng Việt";
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
        if (time.isBefore(endOfToday)) todayPlans.add(doc);
      }
      if (todayPlans.isNotEmpty && mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Icon(Icons.auto_awesome, color: primaryColor),
                const SizedBox(width: 10),
                Text(isVN ? "Nhắc nhở học tập" : "Study Reminder",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isVN
                    ? "Chào $_realName, bạn có các kế hoạch chưa hoàn thành:"
                    : "Hi $_realName, you have uncompleted plans:"),
                const SizedBox(height: 15),
                ...todayPlans.map((doc) {
                  DateTime time = (doc['time'] as Timestamp).toDate();
                  String timeStr =
                      "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text("• ${doc['title']} ($timeStr)",
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black87)),
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
                        borderRadius: BorderRadius.circular(12))),
                onPressed: () => Navigator.pop(context),
                child: Text(
                    isVN ? "Đã hiểu, vào học thôi!" : "Got it, let's study!",
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint("Lỗi kiểm tra kế hoạch: $e");
    }
  }

  void _startListeningUserData() {
    try {
      _userSubscription?.cancel();

      _userSubscription = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .snapshots()
          .listen((doc) {
        if (doc.exists && doc.data() != null) {
          final data = doc.data()!;
          int points = data['points'] ?? 100;
          int streak = data['streakCount'] ?? 0;
          int coins = data['coin'] ?? 0;
          String emailFromDb = data['email'] ?? widget.email;
          String nameFromDb = data['name'] ?? widget.userName;
          String classFromDb = data['class'] ?? widget.selectedClass;
          Timestamp? lastStudyTs = data['lastStudyDate'];
          String activeEffectFromDb = data['activeEffect'] ?? '';

          if (lastStudyTs != null && streak > 0) {
            DateTime lastStudy = lastStudyTs.toDate();
            DateTime now = DateTime.now();
            DateTime today = DateTime(now.year, now.month, now.day);
            DateTime lastStudyDay =
                DateTime(lastStudy.year, lastStudy.month, lastStudy.day);
            if (today.difference(lastStudyDay).inDays > 1) {
              streak = 0;
              FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.userId)
                  .update({'streakCount': 0});
            }
          }

          if (!mounted) return;

          if (userPoints == points &&
              userStreak == streak &&
              userCoins == coins &&
              _activeEffect == activeEffectFromDb &&
              _realEmail == emailFromDb &&
              _realName == nameFromDb &&
              _realClass == classFromDb) {
            return;
          }
          setState(() {
            userPoints = points;
            userStreak = streak;
            userCoins = coins;
            _realEmail = emailFromDb;
            _realName = nameFromDb;
            _realClass = classFromDb;
            _activeEffect = activeEffectFromDb;
            _isLoadingData = false;
            userData = data;
          });
        } else {
          if (mounted) setState(() => _isLoadingData = false);
        }
      }, onError: (e) {
        if (mounted) setState(() => _isLoadingData = false);
      });
    } catch (e) {
      if (mounted) setState(() => _isLoadingData = false);
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
          DateTime lastStudyDay =
              DateTime(lastStudy.year, lastStudy.month, lastStudy.day);
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
        'lastStudyDate': Timestamp.fromDate(now)
      }, SetOptions(merge: true));
      setState(() {
        userPoints += additionalPoints;
        userStreak = newStreak;
      });
    } catch (e) {
      debugPrint("Lỗi cập nhật tiến trình: $e");
    }
  }

  void _showEffectOptions() {
    bool isVN = languageNotifier.value == "Tiếng Việt";

    final effects = [
      {
        "id": "cloud",
        "nameVN": "Đám mây",
        "nameEN": "Cloud",
        "icon": Icons.cloud,
        "color": Colors.lightBlue,
      },
      {
        "id": "firework",
        "nameVN": "Pháo hoa",
        "nameEN": "Firework",
        "icon": Icons.celebration,
        "color": Colors.redAccent,
      },
      {
        "id": "snow",
        "nameVN": "Người tuyết",
        "nameEN": "Snow",
        "icon": Icons.ac_unit,
        "color": Colors.cyan,
      },
      {
        "id": "sparkle",
        "nameVN": "Lấp lánh",
        "nameEN": "Sparkle",
        "icon": Icons.auto_awesome,
        "color": Colors.amber,
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: 430,
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(30),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 70,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              Text(
                isVN ? "Kho hiệu ứng của bạn" : "Your Effect Inventory",
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 22),
              Expanded(
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: effects.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.05,
                  ),
                  itemBuilder: (context, index) {
                    final effect = effects[index];

                    final effectId = effect["id"] as String;

                    final ownedEffects =
                        List<String>.from(userData?['ownedEffects'] ?? []);

                    bool owned =
                        effectId == "cloud" || ownedEffects.contains(effectId);

                    bool selected = (effectId == "cloud" &&
                            (_activeEffect == "" ||
                                _activeEffect == "cloud")) ||
                        _activeEffect == effectId;

                    return Opacity(
                      opacity: owned ? 1 : 0.45,
                      child: Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        elevation: selected ? 8 : 2,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: (!owned || _isUpdating)
                              ? null
                              : () async {
                                  setState(() => _isUpdating = true);
                                  try {
                                    await FirebaseFirestore.instance
                                        .collection('users')
                                        .doc(widget.userId)
                                        .update({
                                      'activeEffect':
                                          effectId == "cloud" ? "" : effectId,
                                    });
                                    if (mounted) {
                                      // 2. Lấy tên hiệu ứng theo ngôn ngữ hiện tại
                                      String effectName = isVN
                                          ? effect["nameVN"] as String
                                          : effect["nameEN"] as String;

                                      // 3. Hiển thị thông báo SnackBar
                                      ScaffoldMessenger.of(context)
                                        ..hideCurrentSnackBar()
                                        ..showSnackBar(
                                          SnackBar(
                                            backgroundColor:
                                                primaryColor, // Bạn có thể đổi màu tùy thích
                                            content: Text(
                                              isVN
                                                  ? 'Đã trang bị hiệu ứng: $effectName ✨'
                                                  : 'Equipped effect: $effectName ✨',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            duration:
                                                const Duration(seconds: 2),
                                          ),
                                        );
                                      // 4. Đóng cửa sổ chọn hiệu ứng
                                      Navigator.pop(context);
                                    }
                                  } catch (e) {
                                    debugPrint("Lỗi cập nhật hiệu ứng: $e");
                                  } finally {
                                    if (mounted)
                                      setState(() => _isUpdating = false);
                                  }
                                },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: selected
                                    ? primaryColor
                                    : Colors.grey.shade200,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  effect["icon"] as IconData,
                                  size: 54,
                                  color: effect["color"] as Color,
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  isVN
                                      ? effect["nameVN"] as String
                                      : effect["nameEN"] as String,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                if (selected)
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  )
                                else if (!owned)
                                  Text(
                                    isVN ? "Chưa sở hữu" : "Locked",
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 12,
                                    ),
                                  )
                                else
                                  Text(
                                    isVN ? "Đã sở hữu" : "Owned",
                                    style: const TextStyle(
                                      color: Colors.blue,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _buildDefaultCloud() {
    return [
      StatefulBuilder(
        builder: (context, setStateCloud1) {
          double targetX = 10.0;

          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: -20.0, end: targetX),
            duration: const Duration(seconds: 4),
            curve: Curves.easeInOutSine,
            onEnd: () {
              targetX = targetX == 15.0 ? -15.0 : 15.0;
              (context as Element).markNeedsBuild();
            },
            builder: (context, animValue, child) {
              return Positioned(
                bottom: -50,
                right: -30 + animValue,
                child: Transform.scale(
                  scaleX: 1.4,
                  child: Icon(
                    Icons.cloud,
                    color: Colors.white.withOpacity(0.32),
                    size: 180,
                  ),
                ),
              );
            },
          );
        },
      ),
      StatefulBuilder(
        builder: (context, setStateCloud2) {
          double targetX = 30.0;

          return TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 65.0, end: targetX),
            duration: const Duration(seconds: 5),
            curve: Curves.easeInOutSine,
            onEnd: () {
              targetX = targetX == -20.0 ? 20.0 : -20.0;
              (context as Element).markNeedsBuild();
            },
            builder: (context, animValue, child) {
              return Positioned(
                bottom: 10,
                right: 120 + animValue,
                child: Transform.scale(
                  scaleX: 1.3,
                  child: Icon(
                    Icons.cloud,
                    color: Colors.white.withOpacity(0.28),
                    size: 90,
                  ),
                ),
              );
            },
          );
        },
      ),
    ];
  }

  Widget _buildCustomEffect(String effectStr) {
    if (effectStr == 'firework') {
      return Positioned(
        bottom: -18,
        right: 25,
        child: IgnorePointer(
          ignoring: true,
          child: SizedBox(
            width: 162,
            height: 162,
            child: Stack(
              alignment: Alignment.center,
              children: [
                ...List.generate(18, (index) {
                  final angle = (index * 20) * 3.1415926 / 180;

                  return TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0.2, end: 1),
                    duration: Duration(
                      milliseconds: 900 + (index * 40),
                    ),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(
                          49.5 * value * cos(angle),
                          49.5 * value * sin(angle),
                        ),
                        child: Opacity(
                          opacity: 1 - (value * 0.7),
                          child: Container(
                            width: 7.2,
                            height: 7.2,
                            decoration: BoxDecoration(
                              color: [
                                Colors.redAccent,
                                Colors.orange,
                                Colors.yellow,
                                Colors.blueAccent,
                                Colors.purpleAccent,
                              ][index % 5],
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: [
                                    Colors.redAccent,
                                    Colors.orange,
                                    Colors.yellow,
                                    Colors.blueAccent,
                                    Colors.purpleAccent,
                                  ][index % 5]
                                      .withOpacity(0.8),
                                  blurRadius: 10.8,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
                ...List.generate(12, (index) {
                  final angle = (index * 30) * 3.1415926 / 180;

                  return TweenAnimationBuilder(
                    tween: Tween<double>(begin: 0.1, end: 1),
                    duration: Duration(
                      milliseconds: 700 + (index * 50),
                    ),
                    curve: Curves.easeOut,
                    builder: (context, value, child) {
                      return Transform.translate(
                        offset: Offset(
                          31.5 * value * cos(angle),
                          31.5 * value * sin(angle),
                        ),
                        child: Opacity(
                          opacity: 1 - (value * 0.8),
                          child: Container(
                            width: 5.4,
                            height: 5.4,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withOpacity(0.9),
                                  blurRadius: 9,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                }),
                TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0.4, end: 1.2),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOut,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: 16.2,
                        height: 16.2,
                        decoration: BoxDecoration(
                          color: Colors.yellow,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.yellow.withOpacity(0.9),
                              blurRadius: 22.5,
                              spreadRadius: 3.6,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (effectStr == 'snow') {
      return Positioned(
        bottom: -10,
        right: 20,
        child: IgnorePointer(
          ignoring: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 30,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                width: 18,
                height: 14,
                color: Colors.black87,
              ),
              Container(
                width: 45,
                height: 45,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black12,
                        blurRadius: 4,
                        offset: Offset(2, 2))
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 14,
                      left: 12,
                      child: Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                              color: Colors.black, shape: BoxShape.circle)),
                    ),
                    Positioned(
                      top: 14,
                      right: 12,
                      child: Container(
                          width: 4,
                          height: 4,
                          decoration: const BoxDecoration(
                              color: Colors.black, shape: BoxShape.circle)),
                    ),
                    Positioned(
                      top: 18,
                      child: Transform.rotate(
                        angle: -0.2,
                        child: ClipPath(
                          clipper: TriangleClipper(),
                          child: Container(
                            width: 12,
                            height: 6,
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -4),
                child: Container(
                  width: 36,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.redAccent,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -6),
                child: Container(
                  width: 65,
                  height: 65,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(2, 2))
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                          3,
                          (index) => Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 3.0),
                                child: Container(
                                  width: 5,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                      color: Colors.black87,
                                      shape: BoxShape.circle),
                                ),
                              )),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (effectStr == 'sparkle') {
      const int starCount = 9;

      return Positioned.fill(
        child: IgnorePointer(
          ignoring: true,
          child: Stack(
            children: List.generate(starCount, (index) {
              final double dx = (index * 37.0 + 100) %
                  (MediaQuery.of(context).size.width - 40);
              final double dy = (index * 19.0 + 20) % 110;

              final int baseDuration = 800 + (index * 150);

              return Positioned(
                left: dx,
                top: dy,
                child: StatefulBuilder(
                  builder: (context, setStateBuilder) {
                    double targetValue = 1.0;

                    return TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0.1, end: targetValue),
                      duration: Duration(milliseconds: baseDuration),
                      curve: Curves.easeInOutSine,
                      onEnd: () {
                        targetValue = targetValue == 1.0 ? 0.1 : 1.0;
                        (context as Element).markNeedsBuild();
                      },
                      builder: (context, value, child) {
                        return Opacity(
                          opacity: value.clamp(0.1, 0.9),
                          child: Transform.scale(
                            scale: value,
                            child: Icon(
                              Icons.auto_awesome,
                              color: Colors.amber.withOpacity(0.95),
                              size: 20 + (index % 4) * 8.0,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              );
            }),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  String getGreeting() {
    final vn = tz.getLocation('Asia/Ho_Chi_Minh');
    final now = tz.TZDateTime.now(vn);
    final hour = now.hour;
    bool isVN = languageNotifier.value == "Tiếng Việt";
    if (hour >= 5 && hour < 12) return isVN ? "Chào buổi sáng" : "Good morning";
    if (hour >= 12 && hour < 18) {
      return isVN ? "Chào buổi chiều" : "Good afternoon";
    }
    return isVN ? "Chào buổi tối" : "Good evening";
  }

  Route slidePageRoute(Widget page) {
    // 1. Khởi tạo vị trí bắt đầu mặc định (Trượt từ phải qua trái)
    Offset begin = const Offset(1.0, 0.0);

    // 2. Dùng if-else để bắt các trang muốn trượt từ trái qua phải
    if (page is CreateRoomPage ||
        page is PlanPage ||
        page is HistoryPage ||
        page is ProfilePage) {
      begin = const Offset(-1.0, 0.0); // Đổi hướng: Bắt đầu từ rìa trái (-1.0)
    }
    // Các trang còn lại (OfflineStudyPage, RoomSearchPage, LeaderboardPage,
    // StatisticsPage, FriendsPage, AIAssistantPage) sẽ tự động dùng mặc định (1.0)

    return PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const end = Offset.zero;

        final tween = Tween(
          begin: begin,
          end: end,
        ).chain(
          CurveTween(curve: Curves.easeOutCubic),
        );

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
    );
  }

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
      case "Thành tích":
        return "Achievements";
      case "Trợ lý học tập":
        return "AI Assistant";
      default:
        return id;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, child) {
        bool isVN = lang == "Tiếng Việt";

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: null,
          body: AnimatedSlideIndexedStack(
            index: _currentIndex,
            children: [
              // TAB 0: CỬA HÀNG VẬT PHẨM
              ShopPage(userId: widget.userId),

              // TAB 1: TRANG CHỦ
              Scaffold(
                backgroundColor: Colors.grey.shade50,
                appBar: AppBar(
                  elevation: 0,
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  leadingWidth: 290,
                  leading: _buildAppBarLeading(),
                  actions: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.notifications_none,
                              size: 28, color: Colors.white),
                          onPressed: () {
                            _markAllAsRead();

                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                opaque: false,
                                barrierDismissible: true,
                                pageBuilder:
                                    (context, animation, secondaryAnimation) =>
                                        NotificationPage(userId: widget.userId),
                                transitionsBuilder: (context, animation,
                                    secondaryAnimation, child) {
                                  return FadeTransition(
                                      opacity: animation, child: child);
                                },
                              ),
                            );
                          },
                        ),
                        if (_unreadNotifCount > 0)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Container(
                              padding: const EdgeInsets.all(1.5),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: primaryColor,
                                  width: 1.2,
                                ),
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 16,
                                minHeight: 16,
                              ),
                              child: Text(
                                _unreadNotifCount > 99
                                    ? "99+"
                                    : '$_unreadNotifCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
                body: _buildHomeContent(isVN),
              ),

              // TAB 2: CÀI ĐẶT
              SettingsPage(
                userName: _realName,
                selectedClass: _realClass,
                userId: widget.userId,
                email: _realEmail,
              ),
            ],
          ),
          bottomNavigationBar: _buildBottomTab(isVN),
        );
      },
    );
  }

  Widget _buildAppBarLeading() {
    return Container(
      margin: const EdgeInsets.only(left: 16, top: 10),
      child: Row(
        children: [
          StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.userId)
                  .snapshots(),
              builder: (context, snapshot) {
                String? currentAvatarUrl;
                if (snapshot.hasData && snapshot.data!.exists) {
                  currentAvatarUrl = (snapshot.data!.data()
                      as Map<String, dynamic>)['avatarUrl'];
                }
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      slidePageRoute(
                        ProfilePage(
                          userName: _realName,
                          userId: widget.userId,
                          selectedClass: _realClass,
                          userPoints: userPoints,
                          userCoins: userCoins,
                          email: _realEmail,
                          userStreak: userStreak,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2)),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white,
                      backgroundImage: (currentAvatarUrl != null &&
                              currentAvatarUrl.isNotEmpty)
                          ? NetworkImage(currentAvatarUrl)
                          : null,
                      child: (currentAvatarUrl == null ||
                              currentAvatarUrl.isEmpty)
                          ? Icon(Icons.person, color: primaryColor, size: 20)
                          : null,
                    ),
                  ),
                );
              }),
          const SizedBox(width: 10),
          const Icon(Icons.local_fire_department,
              color: Colors.orangeAccent, size: 20),
          const SizedBox(width: 2),
          _isLoadingData
              ? const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: Colors.white))
              : Text("$userStreak",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(width: 10),
          const Icon(Icons.workspace_premium, color: Colors.yellow, size: 20),
          const SizedBox(width: 2),
          _isLoadingData
              ? const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: Colors.white))
              : Text("$userPoints",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(width: 10),
          const Icon(Icons.monetization_on,
              color: Colors.amberAccent, size: 20),
          const SizedBox(width: 2),
          _isLoadingData
              ? const SizedBox(
                  width: 10,
                  height: 10,
                  child: CircularProgressIndicator(
                      strokeWidth: 1.5, color: Colors.white))
              : Text("$userCoins",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildHomeContent(bool isVN) {
    return RefreshIndicator(
      color: primaryColor,
      backgroundColor: Colors.white,
      displacement: 50,
      strokeWidth: 3,
      onRefresh: () async {
        _startListeningUserData();
        await Future.delayed(const Duration(milliseconds: 1000));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          children: [
            _buildCloudHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(isVN ? "Bắt đầu học" : "Start Studying",
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold))),
            ),
            _buildGridMenu(
                context,
                [
                  MenuData(Icons.add_home, "Tạo phòng học", Colors.orange),
                  MenuData(Icons.menu_book, "Học offline", Colors.green),
                  MenuData(Icons.search, "Tìm phòng học", primaryColor,
                      isSearch: true),
                ],
                isVN),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(isVN ? "Tiện ích khác" : "Other Utilities",
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold))),
            ),
            _buildGridMenu(
                context,
                [
                  MenuData(Icons.event_note, "Kế hoạch học tập", Colors.purple),
                  MenuData(
                      Icons.leaderboard, "Bảng xếp hạng", Colors.redAccent),
                  MenuData(Icons.people, "Bạn bè", Colors.teal),
                  MenuData(Icons.history, "Lịch sử học tập", Colors.blueGrey),
                  MenuData(Icons.emoji_events, "Thành tích", Colors.indigo),
                  MenuData(
                      Icons.smart_toy, "Trợ lý học tập", Colors.blueAccent),
                ],
                isVN),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildCloudHeader() {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -500,
          left: 0,
          right: 0,
          height: 500,
          child: Container(color: primaryColor),
        ),
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: _showEffectOptions,
          onLongPress: _showEffectOptions,
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
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
                  if (_activeEffect == '' || _activeEffect == 'cloud')
                    ..._buildDefaultCloud()
                  else
                    _buildCustomEffect(_activeEffect),
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
                          _realName,
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
        ),
      ],
    );
  }

  Widget _buildBottomTab(bool isVN) {
    return Container(
      height: 70,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(35),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 15,
              offset: const Offset(0, 5))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTabItem(
              0, Icons.shopping_cart_outlined, isVN ? "Shop" : "Shop"),
          _buildTabItem(1, Icons.home_rounded, isVN ? "Chính" : "Home"),
          _buildTabItem(
              2, Icons.settings_outlined, isVN ? "Cài đặt" : "Settings"),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index, IconData icon, String label) {
    bool isSelected = _currentIndex == index;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (_currentIndex == index) return;

        setState(() {
          _currentIndex = index;
        });
      },
      child: AnimatedScale(
        scale: isSelected ? 1.25 : 1.0,
        duration: const Duration(milliseconds: 250),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? primaryColor : Colors.grey,
              size: isSelected ? 30 : 26,
            ),
            if (isSelected)
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
              )
          ],
        ),
      ),
    );
  }

  // Hàm build lưới menu - Chỉ cập nhật phần đổ bóng cho các nút
  Widget _buildGridMenu(BuildContext context, List<MenuData> items, bool isVN) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      clipBehavior: Clip.none,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 0.9),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];

        return Container(
          decoration: BoxDecoration(
            // 1. ĐÃ XÓA color: Colors.white ở đây
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 18,
                offset: const Offset(0, 8),
                spreadRadius: -2,
              ),
            ],
          ),
          child: Material(
            // 2. CHUYỂN màu trắng vào đây để làm nền chuẩn cho InkWell
            color: Colors.white,
            // 3. Thêm bo góc cho Material để nó khớp với viền bóng đổ
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              splashColor: item.color.withOpacity(0.12),
              highlightColor: item.color.withOpacity(0.06),
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
                // ... (Giữ nguyên toàn bộ logic onTap cũ của bạn) ...
                if (item.title == "Tạo phòng học") {
                  await Navigator.push(
                    context,
                    slidePageRoute(
                      CreateRoomPage(
                        userId: widget.userId,
                        userName: _realName,
                        userClass: _realClass,
                      ),
                    ),
                  );
                } else if (item.title == "Học offline") {
                  final result = await Navigator.push(
                    context,
                    slidePageRoute(
                      OfflineStudyPage(userId: widget.userId),
                    ),
                  );
                  if (result is int) await _updateStudyProgress(result);
                } else if (item.title == "Trợ lý học tập") {
                  await Navigator.push(
                    context,
                    slidePageRoute(
                      AIAssistantPage(userId: widget.userId),
                    ),
                  );
                } else if (item.title == "Tìm phòng học") {
                  await Navigator.push(
                    context,
                    slidePageRoute(
                      RoomSearchPage(
                        currentUserId: widget.userId,
                        currentUserName: _realName,
                      ),
                    ),
                  );
                } else if (item.title == "Kế hoạch học tập") {
                  await Navigator.push(
                    context,
                    slidePageRoute(
                      PlanPage(userId: widget.userId),
                    ),
                  );
                } else if (item.title == "Bảng xếp hạng") {
                  await Navigator.push(
                    context,
                    slidePageRoute(
                      LeaderboardPage(currentUserId: widget.userId),
                    ),
                  );
                } else if (item.title == "Lịch sử học tập") {
                  await Navigator.push(
                    context,
                    slidePageRoute(
                      HistoryPage(userId: widget.userId),
                    ),
                  );
                } else if (item.title == "Thành tích") {
                  await Navigator.push(
                    context,
                    slidePageRoute(
                      StatisticsPage(userId: widget.userId),
                    ),
                  );
                } else if (item.title == "Bạn bè") {
                  await Navigator.push(
                    context,
                    slidePageRoute(
                      FriendsPage(
                        currentUserId: widget.userId,
                        currentUserName: _realName,
                      ),
                    ),
                  );
                }
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                          color: item.color.withOpacity(0.1),
                          shape: BoxShape.circle),
                      child: Icon(item.icon, color: item.color, size: 30)),
                  const SizedBox(height: 8),
                  Text(_getMenuTitle(item.title, isVN),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class AnimatedSlideIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;

  const AnimatedSlideIndexedStack({
    super.key,
    required this.index,
    required this.children,
  });

  @override
  State<AnimatedSlideIndexedStack> createState() =>
      _AnimatedSlideIndexedStackState();
}

class _AnimatedSlideIndexedStackState extends State<AnimatedSlideIndexedStack>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late int _currentIndex;
  late int _previousIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.index;
    _previousIndex = widget.index;
    // Khởi tạo controller quản lý thời gian trượt (có thể chỉnh milliseconds tùy ý)
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(AnimatedSlideIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index) {
      _previousIndex = oldWidget.index;
      _currentIndex = widget.index;
      // Kích hoạt animation chạy từ đầu mỗi khi đổi tab
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(widget.children.length, (index) {
        final child = widget.children[index];
        final isCurrent = index == _currentIndex;
        final isPrevious = index == _previousIndex;

        if (!isCurrent && !isPrevious) {
          return Offstage(offstage: true, child: child);
        }

        final bool isSlidingLeft = _currentIndex > _previousIndex;

        if (isCurrent) {
          // Trang MỚI: Vẫn trượt vào bình thường
          return SlideTransition(
            position: Tween<Offset>(
              begin: Offset(isSlidingLeft ? 1.0 : -1.0, 0.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _controller,
              curve: Curves.easeOutCubic,
            )),
            child: child,
          );
        } else if (isPrevious) {
          // 🔥 Trang CŨ: Bọc thêm IgnorePointer để vô hiệu hóa hoàn toàn cảm ứng
          return IgnorePointer(
            ignoring: true, // Khóa click, vuốt... vào trang cũ
            child: FadeTransition(
              opacity: Tween<double>(
                begin: 1.0,
                end: 0.0,
              ).animate(CurvedAnimation(
                parent: _controller,
                curve: Curves.easeOutCubic,
              )),
              // Vẫn giữ trượt nhẹ (0.3) để tạo chiều sâu
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: Offset.zero,
                  end: Offset(isSlidingLeft ? -0.3 : 0.3, 0.0),
                ).animate(CurvedAnimation(
                  parent: _controller,
                  curve: Curves.easeOutCubic,
                )),
                child: child,
              ),
            ),
          );
        }

        return const SizedBox.shrink();
      }),
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
