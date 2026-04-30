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
  String? selectedFirebasePlanId;
  String selectedPlanTitle = "Học tự do";

  // Dữ liệu gốc từ Firebase
  List<String> allTasksFromFirebase = [];
  List<bool> allStatusFromFirebase = [];

  // Dữ liệu lọc (chỉ những cái chưa xong) để đưa vào phòng
  List<String> filteredGoals = [];
  List<int> originalIndices = []; // Lưu lại vị trí gốc để cập nhật đúng mục

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

  @override
  void initState() {
    super.initState();
    sessions = widget.plan;
    currentSeconds = sessions[0] * 60;
    sessionDone = List.generate(widget.goalsForRoom.length, (_) => false);
    _initNotification();
    startTimer();
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
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

  // 🔥 ĐÃ THÊM: Hàm hiển thị cảnh báo khi thoát ngang
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
              timer?.cancel(); // Dừng bộ đếm thời gian
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

    // 🔥 ĐÃ THÊM: Bọc Scaffold trong WillPopScope để chặn nút Back
    return WillPopScope(
      onWillPop: _showExitWarning,
      child: Scaffold(
        appBar: AppBar(
          // 🔥 ĐÃ SỬA: Chỉnh Text màu trắng in đậm
          title: Text(
            widget.planTitle,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: primaryColor,
          foregroundColor:
              Colors.white, // Đảm bảo mũi tên Back cũng là màu trắng
        ),
        body: Column(
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
        ),
      ),
    );
  }

  Future<void> _initNotification() async {} // Giữ nguyên code thông báo của bạn

  @override
  void dispose() {
    timer?.cancel();
    player.dispose();
    super.dispose();
  }
}
