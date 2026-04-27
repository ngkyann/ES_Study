import 'dart:async';
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
  List<String> goals = [];
  final TextEditingController controller = TextEditingController();

  void addGoal() {
    if (controller.text.trim().isNotEmpty) {
      setState(() {
        goals.add(controller.text.trim());
        controller.clear();
      });
    }
  }

  void removeGoal(int index) {
    setState(() => goals.removeAt(index));
  }

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
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
        ),
      ),
      body: SafeArea(
        // 🔥 ĐÃ THÊM: RefreshIndicator cho trang Học Offline
        child: RefreshIndicator(
          color: primaryColor,
          backgroundColor: Colors.white,
          onRefresh: () async {
            // Giả lập thời gian load để hiện vòng xoay
            await Future.delayed(const Duration(seconds: 1));
            setState(() {}); // Cập nhật lại giao diện nếu cần
          },
          child: SingleChildScrollView(
            // 🔥 BẮT BUỘC: Thêm physics để màn hình ngắn vẫn vuốt được
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
                        onChanged: (value) {
                          setState(() {
                            selectedMinutes = value!;
                            selectedPlanIndex = 0;
                          });
                        },
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "Chế độ học",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      DropdownButton<int>(
                        value: selectedPlanIndex,
                        isExpanded: true,
                        items: List.generate(plans.length, (index) {
                          return DropdownMenuItem(
                            value: index,
                            child: Text(plans[index].join(" - ")),
                          );
                        }),
                        onChanged: (value) {
                          setState(() => selectedPlanIndex = value!);
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                /// GOALS
                _buildCard(
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text(
                            "Mục tiêu",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: addGoal,
                          ),
                        ],
                      ),
                      TextField(
                        controller: controller,
                        decoration: const InputDecoration(
                          hintText: "Nhập mục tiêu...",
                        ),
                      ),
                      const SizedBox(height: 10),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: goals.length,
                        itemBuilder: (_, index) {
                          return ListTile(
                            title: Text(goals[index]),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: () => removeGoal(index),
                            ),
                          );
                        },
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
                  onPressed: () async {
                    if (goals.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Hãy thêm ít nhất 1 mục tiêu"),
                        ),
                      );
                      return;
                    }

                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => StudySessionPage(
                          plan: plans[selectedPlanIndex],
                          goals: goals,
                          userId: widget.userId,
                        ),
                      ),
                    );

                    if (result != null) {
                      Navigator.pop(context, result);
                    }
                  },
                  child: const Text(
                    "Bắt đầu",
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
  final List<String> goals;
  final String userId;

  const StudySessionPage({
    super.key,
    required this.plan,
    required this.goals,
    required this.userId,
  });

  @override
  State<StudySessionPage> createState() => _StudySessionPageState();
}

class _StudySessionPageState extends State<StudySessionPage> {
  late List<int> sessions;
  int currentIndex = 0;
  int currentSeconds = 0;

  Timer? timer;
  List<bool> done = [];

  bool isBreak = false;

  final player = AudioPlayer();
  final notifications = FlutterLocalNotificationsPlugin();

  Future<bool> _confirmExit() async {
    return await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text("Thoát phiên học?"),
            content: const Text(
              "Bạn có chắc muốn rời phòng không? Tiến trình sẽ không được lưu và sẽ không có điểm cộng thêm.",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Ở lại"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  "Thoát",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  void initState() {
    super.initState();

    sessions = widget.plan;
    currentSeconds = sessions[0] * 60;

    done = List.generate(widget.goals.length, (_) => false);

    _initNotification();
    startTimer();
  }

  Future<void> _initNotification() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    await notifications.initialize(
      const InitializationSettings(android: android),
    );
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;

      if (currentSeconds > 0) {
        setState(() => currentSeconds--);
        return;
      }

      currentIndex++;

      // ✅ hết session
      if (currentIndex >= sessions.length) {
        t.cancel();
        saveHistory();
        showResult();
        return;
      }

      setState(() {
        isBreak = currentIndex % 2 == 1;
        currentSeconds = sessions[currentIndex] * 60;
      });

      // ⚠️ âm thanh tạm (chưa có file)
      try {
        player.play(AssetSource('sounds/ting.mp3'));
      } catch (_) {}

      notifications.show(
        0,
        "Nhắc nhở",
        isBreak ? "Đến giờ nghỉ!" : "Tiếp tục học!",
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'study',
            'study',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    });
  }

  Future<void> saveHistory() async {
    await FirebaseFirestore.instance.collection('study_history').add({
      'userId': widget.userId,
      'time': DateTime.now(),
      'goals': widget.goals,
      'completed': done.where((e) => e).length,
      'total': widget.goals.length,
      'minutes': sessions.fold(0, (a, b) => a + b),
    });
  }

  void showResult() {
    int completed = done.where((e) => e).length;
    int minutes = sessions.fold(0, (a, b) => a + b);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Hoàn thành! 🎉", textAlign: TextAlign.center),
        content: Text(
          "Bạn đã hoàn thành $completed mục tiêu\nvà nhận được +$minutes điểm",
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

  String formatTime(int sec) {
    int m = sec ~/ 60;
    int s = sec % 60;
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    timer?.cancel();
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double progress = sessions.isEmpty
        ? 0
        : currentSeconds /
              (sessions[currentIndex.clamp(0, sessions.length - 1)] * 60);

    return WillPopScope(
      onWillPop: _confirmExit,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Phiên học"),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (await _confirmExit()) {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: Column(
          children: [
            const SizedBox(height: 40),

            Text(
              isBreak ? "Giải lao ☕" : "Đang học 📚",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isBreak ? Colors.orange : primaryColor,
              ),
            ),
            const SizedBox(height: 30),

            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 220,
                  height: 220,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 12,
                    backgroundColor: Colors.grey.shade200,
                    color: isBreak ? Colors.orange : primaryColor,
                  ),
                ),
                Text(
                  formatTime(currentSeconds),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 40),

            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(30),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                // 🔥 ĐÃ THÊM: RefreshIndicator cho danh sách mục tiêu
                child: RefreshIndicator(
                  color: primaryColor,
                  backgroundColor: Colors.white,
                  onRefresh: () async {
                    await Future.delayed(const Duration(seconds: 1));
                    setState(() {});
                  },
                  child: ListView.builder(
                    // 🔥 BẮT BUỘC: Thêm physics
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: widget.goals.length,
                    itemBuilder: (_, i) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: CheckboxListTile(
                          title: Text(
                            widget.goals[i],
                            style: TextStyle(
                              decoration: done[i]
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: done[i] ? Colors.grey : Colors.black,
                            ),
                          ),
                          activeColor: primaryColor,
                          value: done[i],
                          onChanged: (v) {
                            setState(() => done[i] = v!);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
