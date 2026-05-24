import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/constants/var.dart'; // 🔥 IMPORT BIẾN NGÔN NGỮ

class OfflineStudyPage extends StatefulWidget {
  final String userId;
  const OfflineStudyPage({super.key, required this.userId});

  @override
  State<OfflineStudyPage> createState() => _OfflineStudyPageState();
}

class _OfflineStudyPageState extends State<OfflineStudyPage> {
  int selectedMinutes = 30;
  final Map<int, List<List<int>>> timePlans = {
    1: [
      [1],
    ],
    15: [
      [15],
    ],
    30: [
      [15, 5, 10],
      [30],
    ],
    45: [
      [20, 5, 20],
      [15, 5, 15, 5, 5],
    ],
    60: [
      [25, 5, 25, 5],
      [30, 5, 25],
    ],
    90: [
      [45, 5, 40],
      [30, 5, 30, 5, 20],
    ],
    120: [
      [30, 10, 40, 10, 30],
      [45, 10, 45, 10, 10],
      [60, 10, 50],
    ],
  };

  int selectedPlanIndex = 0;
  String? selectedFirebasePlanId;
  String selectedPlanTitle =
      languageNotifier.value == "Tiếng Việt" ? "Học tự do" : "Free study";

  List<String> allTasksFromFirebase = [];
  List<bool> allStatusFromFirebase = [];

  List<String> filteredGoals = [];
  List<int> originalIndices = [];

  @override
  Widget build(BuildContext context) {
    final plans = timePlans[selectedMinutes]!;

    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, child) {
        bool isVN = lang == "Tiếng Việt";

        return Scaffold(
          appBar: AppBar(
            title: Text(
              isVN ? "Học offline" : "Offline Study",
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: SafeArea(
            child: RefreshIndicator(
              onRefresh: () async => setState(() {}),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isVN ? "Thời gian học" : "Study Duration",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          DropdownButton<int>(
                            value: selectedMinutes,
                            isExpanded: true,
                            items: timePlans.keys
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(isVN ? "$e phút" : "$e mins"),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) => setState(() {
                              selectedMinutes = value!;
                              selectedPlanIndex = 0;
                            }),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            isVN ? "Chế độ học tập" : "Study Mode",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          DropdownButton<int>(
                            value: selectedPlanIndex,
                            isExpanded: true,
                            items: List.generate(
                              plans.length,
                              (index) => DropdownMenuItem(
                                value: index,
                                child: Text(plans[index].join(" - ")),
                              ),
                            ),
                            onChanged: (value) =>
                                setState(() => selectedPlanIndex = value!),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isVN ? "Chọn kế hoạch" : "Select Plan",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 10),
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('plans')
                                .where('userId', isEqualTo: widget.userId)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const LinearProgressIndicator();
                              }
                              final docs = snapshot.data!.docs;
                              final now = DateTime.now();
                              final validDocs = docs.where((doc) {
                                DateTime time =
                                    (doc['time'] as Timestamp).toDate();
                                return time.isBefore(now) ||
                                    time.isAtSameMomentAs(now);
                              }).toList();

                              return DropdownButton<String?>(
                                value: selectedFirebasePlanId,
                                isExpanded: true,
                                hint: Text(isVN
                                    ? "Chọn kế hoạch..."
                                    : "Select a plan..."),
                                items: [
                                  DropdownMenuItem(
                                    value: null,
                                    child:
                                        Text(isVN ? "Học tự do" : "Free Study"),
                                  ),
                                  ...validDocs.map(
                                    (doc) => DropdownMenuItem(
                                      value: doc.id,
                                      child: Text(doc['title']),
                                    ),
                                  ),
                                ],
                                onChanged: (val) {
                                  setState(() {
                                    selectedFirebasePlanId = val;
                                    filteredGoals = [];
                                    originalIndices = [];
                                    if (val != null) {
                                      final doc = validDocs.firstWhere(
                                        (d) => d.id == val,
                                      );
                                      final data =
                                          doc.data() as Map<String, dynamic>;
                                      selectedPlanTitle = data['title'];
                                      allTasksFromFirebase = List<String>.from(
                                        data['tasks'] ?? [],
                                      );
                                      allStatusFromFirebase = List<bool>.from(
                                        data['completedTasks'] ??
                                            List.generate(
                                              allTasksFromFirebase.length,
                                              (_) => false,
                                            ),
                                      );

                                      for (int i = 0;
                                          i < allTasksFromFirebase.length;
                                          i++) {
                                        if (allStatusFromFirebase[i] == false) {
                                          filteredGoals.add(
                                            allTasksFromFirebase[i],
                                          );
                                          originalIndices.add(i);
                                        }
                                      }
                                    }
                                  });
                                },
                              );
                            },
                          ),
                          if (filteredGoals.isNotEmpty) ...[
                            const SizedBox(height: 10),
                            Text(
                              isVN
                                  ? "Còn ${filteredGoals.length} nhiệm vụ chưa xong:"
                                  : "Remaining ${filteredGoals.length} unfinished tasks:",
                              style: const TextStyle(
                                color: Colors.blueGrey,
                                fontSize: 12,
                              ),
                            ),
                            ...filteredGoals.map(
                              (g) => Text(
                                "• $g",
                                style: const TextStyle(fontSize: 13),
                              ),
                            ),
                          ] else if (selectedFirebasePlanId != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(
                                isVN
                                    ? "🎉 Tuyệt vời! Bạn đã hoàn thành hết mục tiêu của kế hoạch này."
                                    : "🎉 Awesome! You have completed all goals for this plan.",
                                style: const TextStyle(
                                    color: Colors.green, fontSize: 13),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        minimumSize: const Size(double.infinity, 55),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: (selectedFirebasePlanId != null &&
                              filteredGoals.isEmpty)
                          ? null
                          : () async {
                              final result = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => StudySessionPage(
                                    plan: plans[selectedPlanIndex],
                                    goalsForRoom: filteredGoals,
                                    originalIndices: originalIndices,
                                    allStatus: allStatusFromFirebase,
                                    userId: widget.userId,
                                    planId: selectedFirebasePlanId,
                                    planTitle: selectedPlanTitle,
                                  ),
                                ),
                              );
                              if (result != null)
                                Navigator.pop(context, result);
                            },
                      child: Text(
                        isVN ? "Bắt đầu học" : "Start Studying",
                        style:
                            const TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}

class StudySessionPage extends StatefulWidget {
  final List<int> plan;
  final List<String> goalsForRoom;
  final List<int> originalIndices;
  final List<bool> allStatus;
  final String userId;
  final String? planId;
  final String planTitle;

  const StudySessionPage({
    super.key,
    required this.plan,
    required this.goalsForRoom,
    required this.originalIndices,
    required this.allStatus,
    required this.userId,
    this.planId,
    required this.planTitle,
  });

  @override
  State<StudySessionPage> createState() => _StudySessionPageState();
}

class _StudySessionPageState extends State<StudySessionPage> {
  late List<int> sessions;
  int currentIndex = 0;
  int currentSeconds = 0;
  Timer? timer;
  List<bool> sessionDone = [];
  bool isBreak = false;
  final player = AudioPlayer();
  final notifications = FlutterLocalNotificationsPlugin();

  final Random _random = Random();
  int _maxAfkChecks = 0;
  int _afkCheckCount = 0;
  int _secondsSinceLastAfk = 0;
  int _nextAfkTargetSeconds = 0;
  bool _showAfkBubble = false;
  int _afkTimeoutSeconds = 300;
  double _bubbleX = 0.5;
  double _bubbleY = 0.5;
  bool _isAfkDialogOpen = false;

  @override
  void initState() {
    super.initState();
    sessions = widget.plan;
    currentSeconds = sessions[0] * 60;
    sessionDone = List.generate(widget.goalsForRoom.length, (_) => false);

    int totalMinutes = widget.plan.fold(0, (a, b) => a + b);
    _maxAfkChecks = totalMinutes ~/ 15;
    if (_maxAfkChecks > 0) {
      _nextAfkTargetSeconds = _random.nextInt(121) + 780;
    }
    debugPrint(
        "🤖 [Anti-AFK]: Lần điểm danh tiếp theo sẽ xuất hiện sau $_nextAfkTargetSeconds giây nữa!");
    _initNotification();
    startTimer();
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;

      if (_showAfkBubble) {
        setState(() {
          _afkTimeoutSeconds--;
        });
        if (_afkTimeoutSeconds <= 0) {
          t.cancel();
          _failAfkCheck();
          return;
        }
      } else if (_afkCheckCount < _maxAfkChecks && !isBreak) {
        _secondsSinceLastAfk++;
        if (_secondsSinceLastAfk >= _nextAfkTargetSeconds) {
          _triggerAfkBubble();
        }
      }

      if (currentSeconds > 0) {
        setState(() => currentSeconds--);
        return;
      }
      currentIndex++;
      if (currentIndex >= sessions.length) {
        t.cancel();
        _finishStudySession();
        return;
      }
      setState(() {
        isBreak = currentIndex % 2 == 1;
        currentSeconds = sessions[currentIndex] * 60;
      });
      try {
        player.play(AssetSource('sounds/ting.mp3'));
      } catch (_) {}
    });
  }

  void _triggerAfkBubble() {
    setState(() {
      _showAfkBubble = true;
      _afkTimeoutSeconds = 300;
      _bubbleX = _random.nextDouble();
      _bubbleY = _random.nextDouble();
      _afkCheckCount++;
      _secondsSinceLastAfk = 0;
      _nextAfkTargetSeconds = _random.nextInt(121) + 780;
    });
    try {
      player.play(AssetSource('sounds/ting.mp3'));
    } catch (_) {}
  }

  void _failAfkCheck() {
    bool isVN = languageNotifier.value == "Tiếng Việt";
    if (_isAfkDialogOpen) {
      Navigator.pop(context);
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text(isVN ? "Phiên học bị hủy" : "Session Cancelled"),
          ],
        ),
        content: Text(
          isVN
              ? "Bạn đã treo máy quá 5 phút mà không phản hồi bong bóng điểm danh. Phiên học đã bị hủy và không được lưu lại để đảm bảo tính công bằng."
              : "You have been AFK for over 5 minutes without responding to the check-in bubble. The session has been cancelled and will not be saved to ensure fairness.",
          style: const TextStyle(fontSize: 15),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: Text(
                isVN ? "Đã hiểu" : "Got it",
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onBubbleTap() {
    bool isVN = languageNotifier.value == "Tiếng Việt";
    final TextEditingController afkController = TextEditingController();
    _isAfkDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.mark_chat_unread, color: primaryColor),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isVN ? "Báo cáo tiến độ!" : "Progress Report!",
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isVN
                  ? "Chào bạn! Bạn đang học gì thế? Ghi chú lại một chút nhé để chứng minh bạn vẫn đang tập trung!"
                  : "Hi there! What are you studying? Leave a quick note to prove you're still focused!",
            ),
            const SizedBox(height: 15),
            TextField(
              controller: afkController,
              autofocus: true,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: isVN
                    ? "Ví dụ: Đang giải toán..."
                    : "Example: Solving math...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              if (afkController.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                setState(() {
                  _showAfkBubble = false;
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isVN
                          ? "Ôi chúa ơi! Bạn lười quá, gõ ít nhất 1 chữ đi nào!"
                          : "Oh my! You're so lazy, type at least one word!",
                    ),
                  ),
                );
              }
            },
            child: Text(
              isVN ? "Tiếp tục học" : "Continue Studying",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    ).then((_) {
      _isAfkDialogOpen = false;
    });
  }

  Future<void> _finishStudySession() async {
    int minutes = sessions.fold(0, (a, b) => a + b);

    // Tính toán coin (1 nửa số phút/điểm, làm tròn lên)
    int earnedCoins = (minutes / 2.0).round();

    List<bool> updatedStatus = List.from(widget.allStatus);
    List<String> finishedTasks = [];

    for (int i = 0; i < sessionDone.length; i++) {
      if (sessionDone[i] == true) {
        int originalIdx = widget.originalIndices[i];
        updatedStatus[originalIdx] = true;
        finishedTasks.add(widget.goalsForRoom[i]);
      }
    }

    // Lưu lịch sử học
    await FirebaseFirestore.instance.collection('study_history').add({
      'userId': widget.userId,
      'time': DateTime.now(),
      'planTitle': widget.planTitle,
      'goals': widget.goalsForRoom,
      'completedGoalsList': finishedTasks,
      'completed': sessionDone.where((e) => e).length,
      'total': widget.goalsForRoom.length,
      'minutes': minutes,
    });

    // Cập nhật tiến độ kế hoạch
    if (widget.planId != null) {
      bool isAllFinished = updatedStatus.every((status) => status == true);
      if (isAllFinished) {
        await FirebaseFirestore.instance
            .collection('plans')
            .doc(widget.planId)
            .delete();
      } else {
        await FirebaseFirestore.instance
            .collection('plans')
            .doc(widget.planId)
            .update({'completedTasks': updatedStatus});
      }
    }

    // Cập nhật số Coin VÀ ĐIỂM vào tài khoản
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId)
        .set({
      'coin': FieldValue.increment(earnedCoins),
      'points':
          FieldValue.increment(minutes), // 🔥 ĐÃ BỔ SUNG: Cộng điểm học tập
    }, SetOptions(merge: true));

    // 🔥 THÊM MỚI: Bắn thông báo về bảng notifications để hiển thị bên NotificationPage
    await FirebaseFirestore.instance.collection('notifications').add({
      'userId': widget.userId,
      'content_vn':
          "🎉 Tuyệt vời! Bạn vừa hoàn thành phiên học Offline dài $minutes phút. Nhận được +$minutes điểm và +$earnedCoins coin",
      'content_en':
          "🎉 Awesome! You finished a $minutes-minute Offline session. Earned +$minutes points and +$earnedCoins coins",
      'createdAt': FieldValue.serverTimestamp(),
    });

    int completedCount = sessionDone.where((e) => e).length;

    // Hiển thị Popup kết quả
    _showResult(
        completedCount, widget.goalsForRoom.length, minutes, earnedCoins);
  }

  // 🔥 CẬP NHẬT: Nhận thêm tham số earnedCoins để hiển thị
  void _showResult(
      int completedTasks, int totalTasks, int minutes, int earnedCoins) {
    bool isVN = languageNotifier.value == "Tiếng Việt";
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isVN ? "Hoàn thành! 🎉" : "Completed! 🎉",
            textAlign: TextAlign.center),
        content: Text(
          isVN
              // 🔥 CẬP NHẬT: Thêm dòng thông báo nhận Coin
              ? "Bạn đã hoàn thành $completedTasks/$totalTasks nhiệm vụ.\nTiến độ đã được cập nhật vào Kế hoạch.\n\n🎁 Thưởng: +$minutes điểm & +$earnedCoins coin"
              : "You have completed $completedTasks/$totalTasks tasks.\nProgress has been updated to your Plan.\n\n🎁 Reward: +$minutes points & +$earnedCoins coins",
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(
                    context, minutes); // Trả số phút (điểm) về trang chủ
              },
              child: Text(
                isVN ? "Tuyệt vời!" : "Awesome!",
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showExitWarning() async {
    bool isVN = languageNotifier.value == "Tiếng Việt";
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text(isVN ? "Thoát phiên học?" : "Exit session?"),
          ],
        ),
        content: Text(
          isVN
              ? "Phiên học đang diễn ra. Nếu thoát ngang, mọi tiến trình và điểm số của buổi này sẽ không được lưu lại.\n\nBạn có chắc chắn muốn thoát?"
              : "The session is ongoing. If you exit now, all progress and points for this session will not be saved.\n\nAre you sure you want to exit?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(isVN ? "Ở lại" : "Stay",
                style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              timer?.cancel();
              Navigator.pop(context, true);
            },
            child: Text(isVN ? "Thoát" : "Exit",
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return confirm ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, child) {
        bool isVN = lang == "Tiếng Việt";

        double progress = sessions.isEmpty
            ? 0
            : currentSeconds /
                (sessions[currentIndex.clamp(0, sessions.length - 1)] * 60);

        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final double safeLeft = 20 + _bubbleX * (screenWidth - 100);
        final double safeTop = 100 + _bubbleY * (screenHeight - 250);

        Widget mainBody = Column(
          children: [
            const SizedBox(height: 20),
            Text(
              isBreak
                  ? (isVN ? "Giải lao ☕" : "Break ☕")
                  : (isVN ? "Đang học 📚" : "Studying 📚"),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isBreak ? Colors.orange : primaryColor,
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 180,
                    height: 180,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 10,
                      color: isBreak ? Colors.orange : primaryColor,
                    ),
                  ),
                  Text(
                    "${(currentSeconds ~/ 60).toString().padLeft(2, '0')}:${(currentSeconds % 60).toString().padLeft(2, '0')}",
                    style: const TextStyle(
                      fontSize: 35,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: widget.goalsForRoom.length,
                itemBuilder: (_, i) => CheckboxListTile(
                  title: Text(
                    widget.goalsForRoom[i],
                    style: TextStyle(
                      decoration:
                          sessionDone[i] ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  value: sessionDone[i],
                  onChanged: (v) => setState(() => sessionDone[i] = v!),
                ),
              ),
            ),
          ],
        );

        return WillPopScope(
          onWillPop: _showExitWarning,
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                widget.planTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
            ),
            body: Stack(
              children: [
                mainBody,
                if (_showAfkBubble)
                  Positioned(
                    left: safeLeft,
                    top: safeTop,
                    child: GestureDetector(
                      onTap: _onBubbleTap,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withOpacity(0.4),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              "${_afkTimeoutSeconds ~/ 60}:${(_afkTimeoutSeconds % 60).toString().padLeft(2, '0')}",
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: primaryColor,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.5),
                                  blurRadius: 15,
                                  spreadRadius: 4,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.mark_chat_unread,
                              color: Colors.white,
                              size: 35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _initNotification() async {}

  @override
  void dispose() {
    timer?.cancel();
    player.dispose();
    super.dispose();
  }
}
