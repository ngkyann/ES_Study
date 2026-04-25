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
    1: [
      [1],
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
      body: SafeArea(
        child: Column(
          children: [
            /// HEADER
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 35, 20, 16),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    "Học Offline",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
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
                      child: const Text("Bắt đầu"),
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

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                child: const Text("Thoát"),
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
      builder: (_) => AlertDialog(
        title: const Text("Hoàn thành"),
        content: Text("Hoàn thành $completed mục tiêu\n+ $minutes điểm"),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, minutes);
            },
            child: const Text("OK"),
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
          title: const Text("Đang học"),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isBreak ? "Giải lao ☕" : "Đang học 📚",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isBreak ? Colors.orange : primaryColor,
              ),
            ),
            const SizedBox(height: 20),

            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    color: isBreak ? Colors.orange : primaryColor,
                  ),
                ),
                Text(
                  formatTime(currentSeconds),
                  style: const TextStyle(fontSize: 32),
                ),
              ],
            ),

            const SizedBox(height: 20),

            Expanded(
              child: ListView.builder(
                itemCount: widget.goals.length,
                itemBuilder: (_, i) {
                  return CheckboxListTile(
                    title: Text(widget.goals[i]),
                    value: done[i],
                    onChanged: (v) {
                      setState(() => done[i] = v!);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
