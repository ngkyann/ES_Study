import 'dart:async';
import 'dart:math'; // 🔥 ĐÃ THÊM thư viện toán học để random
import 'package:flutter/material.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class OfflineStudyPage extends StatefulWidget {
  final String userId;
  const OfflineStudyPage({super.key, required this.userId});

  @override
  State<OfflineStudyPage> createState() => _OfflineStudyPageState();
}

class _OfflineStudyPageState extends State<OfflineStudyPage> {
  int selectedMinutes = 30;
  final Map<int, List<List<int>>> timePlans = {
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
      [30, 5, 30, 5, 20],
    ],
    120: [
      [45, 10, 45, 10, 10],
      [60, 10, 50],
    ],
  };

  int selectedPlanIndex = 0;
  String? selectedFirebasePlanId;
  String selectedPlanTitle = "Học tự do";

  // Dữ liệu gốc từ Firebase
  List<String> allTasksFromFirebase = [];
  List<bool> allStatusFromFirebase = [];

  // Dữ liệu lọc (chỉ những cái chưa xong) để đưa vào phòng
  List<String> filteredGoals = [];
  List<int> originalIndices = [];

  @override
  Widget build(BuildContext context) {
    final plans = timePlans[selectedMinutes]!;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Học Offline",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
                      const Text(
                        "Thời gian học",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      DropdownButton<int>(
                        value: selectedMinutes,
                        isExpanded: true,
                        items: timePlans.keys
                            .map(
                              (e) => DropdownMenuItem(
                                value: e,
                                child: Text("$e phút"),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() {
                          selectedMinutes = value!;
                          selectedPlanIndex = 0;
                        }),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Chế độ nghỉ giải lao",
                        style: TextStyle(fontWeight: FontWeight.bold),
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
                      const Text(
                        "Chọn Kế hoạch",
                        style: TextStyle(fontWeight: FontWeight.bold),
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
                            DateTime time = (doc['time'] as Timestamp).toDate();
                            return time.isBefore(now) ||
                                time.isAtSameMomentAs(now);
                          }).toList();

                          return DropdownButton<String?>(
                            value: selectedFirebasePlanId,
                            isExpanded: true,
                            hint: const Text("Chọn kế hoạch..."),
                            items: [
                              const DropdownMenuItem(
                                value: null,
                                child: Text("Học tự do"),
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

                                  for (
                                    int i = 0;
                                    i < allTasksFromFirebase.length;
                                    i++
                                  ) {
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
                          "Còn ${filteredGoals.length} nhiệm vụ chưa xong:",
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
                        const Padding(
                          padding: EdgeInsets.only(top: 8.0),
                          child: Text(
                            "🎉 Tuyệt vời! Bạn đã hoàn thành hết mục tiêu của kế hoạch này.",
                            style: TextStyle(color: Colors.green, fontSize: 13),
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
                  onPressed:
                      (selectedFirebasePlanId != null && filteredGoals.isEmpty)
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
                          if (result != null) Navigator.pop(context, result);
                        },
                  child: const Text(
                    "Bắt đầu học",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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

  // 🔥 BIẾN ANTI-AFK (Chống treo máy)
  final Random _random = Random();
  int _maxAfkChecks = 0;
  int _afkCheckCount = 0;
  int _secondsSinceLastAfk = 0;
  int _nextAfkTargetSeconds = 0;
  bool _showAfkBubble = false;
  int _afkTimeoutSeconds = 300; // 5 phút đếm ngược
  double _bubbleX = 0.5; // Tỷ lệ vị trí ngang (0.0 -> 1.0)
  double _bubbleY = 0.5; // Tỷ lệ vị trí dọc (0.0 -> 1.0)
  bool _isAfkDialogOpen = false; // Tránh lỗi kẹt Dialog khi hết giờ

  @override
  void initState() {
    super.initState();
    sessions = widget.plan;
    currentSeconds = sessions[0] * 60;
    sessionDone = List.generate(widget.goalsForRoom.length, (_) => false);

    // 🔥 CẤU HÌNH ANTI-AFK
    int totalMinutes = widget.plan.fold(0, (a, b) => a + b);
    _maxAfkChecks = totalMinutes ~/ 15;
    if (_maxAfkChecks > 0) {
      _nextAfkTargetSeconds = _random.nextInt(121) + 780;
    }
    // _maxAfkChecks = 10;
    // if (_maxAfkChecks > 0) {
    //   _nextAfkTargetSeconds = 1;
    // }
    _initNotification();
    startTimer();
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;

      // 🔥 LOGIC CHỐNG AFK ĐƯỢC CHẠY MỖI GIÂY
      if (_showAfkBubble) {
        setState(() {
          _afkTimeoutSeconds--;
        });
        if (_afkTimeoutSeconds <= 0) {
          t.cancel();
          _failAfkCheck(); // Phạt ngay lập tức
          return;
        }
      } else if (_afkCheckCount < _maxAfkChecks && !isBreak) {
        _secondsSinceLastAfk++;
        if (_secondsSinceLastAfk >= _nextAfkTargetSeconds) {
          _triggerAfkBubble();
        }
      }

      // Logic đếm giờ chính
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

  // Bật bong bóng AFK
  void _triggerAfkBubble() {
    setState(() {
      _showAfkBubble = true;
      _afkTimeoutSeconds = 300; // Reset lại 5 phút
      _bubbleX = _random.nextDouble(); // Vị trí ngẫu nhiên
      _bubbleY = _random.nextDouble();
      _afkCheckCount++;
      _secondsSinceLastAfk = 0;
      _nextAfkTargetSeconds =
          _random.nextInt(121) + 780; // Random lần tiếp theo
    });
    try {
      player.play(AssetSource('sounds/ting.mp3')); // Kêu Ting phát cho tỉnh
    } catch (_) {}
  }

  // Hàm Phạt khi hết 5 phút không phản hồi
  void _failAfkCheck() {
    if (_isAfkDialogOpen) {
      Navigator.pop(
        context,
      ); // Tự động đóng Dialog nếu đang gõ dở nhưng hết giờ
    }
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text("Phiên học bị hủy"),
          ],
        ),
        content: const Text(
          "Bạn đã treo máy quá 5 phút mà không phản hồi bong bóng điểm danh. Phiên học đã bị hủy và không được lưu lại để đảm bảo tính công bằng.",
          style: TextStyle(fontSize: 15),
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
                Navigator.pop(context); // Đóng bảng thông báo
                Navigator.pop(context); // Thoát khỏi trang học
              },
              child: const Text(
                "Đã hiểu",
                style: TextStyle(
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

  // Khi bấm vào bong bóng
  void _onBubbleTap() {
    final TextEditingController afkController = TextEditingController();
    _isAfkDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false, // Bắt buộc phải trả lời
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.mark_chat_unread, color: primaryColor),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                "Báo cáo tiến độ!",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Chào bạn! Bạn đang học gì thế? Ghi chú lại một chút nhé để chứng minh bạn vẫn đang tập trung!",
            ),
            const SizedBox(height: 15),
            TextField(
              controller: afkController,
              autofocus: true,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: "Ví dụ: Đang giải toán...",
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
                  const SnackBar(
                    content: Text(
                      "Ôi chúa ơi! Bạn lười quá, gõ ít nhất 1 chữ đi nào!",
                    ),
                  ),
                );
              }
            },
            child: const Text(
              "Tiếp tục học",
              style: TextStyle(color: Colors.white),
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

    List<bool> updatedStatus = List.from(widget.allStatus);
    List<String> finishedTasks = [];

    for (int i = 0; i < sessionDone.length; i++) {
      if (sessionDone[i] == true) {
        int originalIdx = widget.originalIndices[i];
        updatedStatus[originalIdx] = true;
        finishedTasks.add(widget.goalsForRoom[i]);
      }
    }

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

    int completedCount = sessionDone.where((e) => e).length;
    _showResult(completedCount, widget.goalsForRoom.length, minutes);
  }

  void _showResult(int completedTasks, int totalTasks, int minutes) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Hoàn thành! 🎉", textAlign: TextAlign.center),
        content: Text(
          "Bạn đã hoàn thành $completedTasks/$totalTasks nhiệm vụ.\nTiến độ đã được cập nhật vào Kế hoạch.\n\n🎁 Thưởng: +$minutes điểm",
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
                Navigator.pop(context, minutes);
              },
              child: const Text(
                "Tuyệt vời!",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _showExitWarning() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text("Thoát phiên học?"),
          ],
        ),
        content: const Text(
          "Phiên học đang diễn ra. Nếu thoát ngang, mọi tiến trình và điểm số của buổi này sẽ không được lưu lại.\n\nBạn có chắc chắn muốn thoát?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Ở lại", style: TextStyle(color: Colors.grey)),
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
            child: const Text("Thoát", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return confirm ?? false;
  }

  @override
  Widget build(BuildContext context) {
    double progress = sessions.isEmpty
        ? 0
        : currentSeconds /
              (sessions[currentIndex.clamp(0, sessions.length - 1)] * 60);

    // Kích thước an toàn cho Bong bóng
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final double safeLeft = 20 + _bubbleX * (screenWidth - 100);
    final double safeTop = 100 + _bubbleY * (screenHeight - 250);

    Widget mainBody = Column(
      children: [
        const SizedBox(height: 20),
        Text(
          isBreak ? "Giải lao ☕" : "Đang học 📚",
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
                  decoration: sessionDone[i]
                      ? TextDecoration.lineThrough
                      : null,
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
        // 🔥 ĐÃ THÊM: Stack để đè Bong bóng AFK lên giao diện chính
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
                      // Đồng hồ đếm ngược nhỏ màu đỏ
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
                      // Bong bóng tròn
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
  }

  Future<void> _initNotification() async {}

  @override
  void dispose() {
    timer?.cancel();
    player.dispose();
    super.dispose();
  }
}
