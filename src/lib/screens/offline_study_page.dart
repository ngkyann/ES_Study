import 'dart:async';
import 'package:flutter/material.dart';
import 'package:esstudy/constants/colors.dart';

class OfflineStudyPage extends StatefulWidget {
  const OfflineStudyPage({super.key});

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
    if (controller.text.isNotEmpty) {
      setState(() {
        goals.add(controller.text);
        controller.clear();
      });
    }
  }

  void removeGoal(int index) {
    setState(() {
      goals.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    final plans = timePlans[selectedMinutes]!;

    return Scaffold(
      body: Column(
        children: [
          /// HEADER
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
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
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(width: 10),
                const Text(
                  "Học Offline",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
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
                          items: timePlans.keys.map((e) {
                            return DropdownMenuItem(
                              value: e,
                              child: Text("$e phút"),
                            );
                          }).toList(),
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
                            setState(() {
                              selectedPlanIndex = value!;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  /// 🎯 MỤC TIÊU
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

                  /// ▶️ BUTTON
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => StudySessionPage(
                            plan: plans[selectedPlanIndex],
                            goals: goals,
                          ),
                        ),
                      );

                      if (result != null) {
                        Navigator.pop(context, result); // 👈 trả điểm về Home
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
      child: child,
    );
  }
}

class StudySessionPage extends StatefulWidget {
  final List<int> plan;
  final List<String> goals;

  const StudySessionPage({super.key, required this.plan, required this.goals});

  @override
  State<StudySessionPage> createState() => _StudySessionPageState();
}

class _StudySessionPageState extends State<StudySessionPage> {
  late int totalSeconds;
  int currentSeconds = 0;

  Timer? timer;

  List<bool> done = [];
  Future<bool> _showExitDialog() async {
    return await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text("Cảnh báo"),
            content: const Text(
              "Rời phòng sẽ bị trừ điểm, bạn có chắc muốn rời phòng không?",
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text("Không"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
                onPressed: () {
                  Navigator.pop(context, true);
                },
                child: const Text("Có"),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  void initState() {
    super.initState();

    totalSeconds = widget.plan.fold(0, (sum, e) => sum + e) * 60;

    currentSeconds = totalSeconds;

    done = List.generate(widget.goals.length, (_) => false);

    startTimer();
  }

  @override
  void dispose() {
    timer?.cancel(); // 👈 QUAN TRỌNG
    super.dispose();
  }

  void startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return; // 👈 tránh crash

      if (currentSeconds > 0) {
        setState(() {
          currentSeconds--;
        });
      } else {
        t.cancel();
        showResult();
      }
    });
  }

  void showResult() {
    int completed = done.where((e) => e).length;

    int minutes = totalSeconds ~/ 60;
    int earnedPoints = minutes * 1; // 👈 công thức

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Hoàn thành"),
        content: Text(
          "Bạn đã hoàn thành $completed mục tiêu\n+ $earnedPoints điểm",
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // đóng dialog
              Navigator.pop(context, earnedPoints); // 👈 trả điểm về
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
  Widget build(BuildContext context) {
    double progress = currentSeconds / totalSeconds;

    return WillPopScope(
      onWillPop: () async {
        return await _showExitDialog();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Đang học"),
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              bool exit = await _showExitDialog();
              if (exit) {
                Navigator.pop(context);
              }
            },
          ),
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            /// ⭕ ĐỒNG HỒ TRÒN
            const SizedBox(height: 40),
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 200,
                  height: 200,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 10,
                    color: primaryColor,
                  ),
                ),
                Text(
                  formatTime(currentSeconds),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            /// 🎯 MỤC TIÊU
            Expanded(
              child: ListView.builder(
                itemCount: widget.goals.length,
                itemBuilder: (_, index) {
                  return CheckboxListTile(
                    title: Text(widget.goals[index]),
                    value: done[index],
                    onChanged: (v) {
                      setState(() {
                        done[index] = v!;
                      });
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
