import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:esstudy/constants/var.dart'; // 🔥 Import biến ngôn ngữ

DateTime parseTime(dynamic timeField) {
  try {
    if (timeField == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (timeField is Timestamp) return timeField.toDate();
    if (timeField is int) return DateTime.fromMillisecondsSinceEpoch(timeField);
    if (timeField is String) {
      final asInt = int.tryParse(timeField);
      if (asInt != null) return DateTime.fromMillisecondsSinceEpoch(asInt);
      return DateTime.parse(timeField);
    }
  } catch (_) {}
  return DateTime.fromMillisecondsSinceEpoch(0);
}

class HistoryPage extends StatelessWidget {
  final String userId;

  const HistoryPage({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, child) {
        bool isVN = lang == "Tiếng Việt";

        return Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: Text(
              isVN ? "Lịch sử học tập" : "Study History",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('study_history')
                .where('userId', isEqualTo: userId)
                .orderBy('time', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      isVN
                          ? "Lỗi khi tải lịch sử: ${snapshot.error}"
                          : "Error loading history: ${snapshot.error}",
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return Center(
                  child: Text(isVN
                      ? "Chưa có lịch sử học tập, hãy cố gắng thêm!"
                      : "No study history yet, keep trying!"),
                );
              }

              final docs = snapshot.data!.docs;

              return RefreshIndicator(
                color: primaryColor,
                backgroundColor: Colors.white,
                onRefresh: () async {
                  await Future.delayed(const Duration(seconds: 1));
                },
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final Map<String, dynamic> data =
                        (docs[index].data() as Map<String, dynamic>?) ?? {};

                    final DateTime time = parseTime(data['time']);
                    final completed = data['completed'] ?? 0;
                    final total = data['total'] ?? 0;
                    final minutes = data['minutes'] ?? 0;
                    final planTitle = data['planTitle'] ??
                        (isVN ? "Học tự do" : "Free Study");

                    final timeText = time.millisecondsSinceEpoch > 0
                        ? "${time.day}/${time.month}/${time.year}"
                        : (isVN ? "Ngày không xác định" : "Unknown date");

                    return Card(
                      child: ListTile(
                        leading: Icon(Icons.history, color: primaryColor),
                        title: Text(
                          planTitle,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          isVN
                              ? "Hoàn thành $completed/$total - $minutes phút\n$timeText"
                              : "Completed $completed/$total - $minutes mins\n$timeText",
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                        isThreeLine: true,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  HistoryDetailPage(data: data),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class HistoryDetailPage extends StatelessWidget {
  final Map<String, dynamic> data;

  const HistoryDetailPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, child) {
        bool isVN = lang == "Tiếng Việt";

        final DateTime time = parseTime(data['time']);

        final List<dynamic> finishedTasks =
            data.containsKey('completedGoalsList')
                ? List<dynamic>.from(data['completedGoalsList'])
                : (data['goals'] is List
                    ? List<dynamic>.from(data['goals'])
                    : <dynamic>[]);

        final int completed = data['completed'] ?? 0;
        final int total = data['total'] ?? 0;
        final int minutes = data['minutes'] ?? 0;
        final planTitle =
            data['planTitle'] ?? (isVN ? "Học tự do" : "Free Study");

        final timeText = time.millisecondsSinceEpoch > 0
            ? "${time.day}/${time.month}/${time.year}"
            : (isVN ? "Không xác định" : "Unknown");

        return Scaffold(
          appBar: AppBar(
            centerTitle: true,
            title: Text(
              isVN ? "Chi tiết buổi học" : "Session Details",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
          ),
          body: RefreshIndicator(
            color: primaryColor,
            backgroundColor: Colors.white,
            onRefresh: () async {
              await Future.delayed(const Duration(seconds: 1));
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isVN ? "Kế hoạch: $planTitle" : "Plan: $planTitle",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isVN ? "Ngày: $timeText" : "Date: $timeText",
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    isVN
                        ? "Thời gian học: $minutes phút"
                        : "Study time: $minutes mins",
                    style: const TextStyle(fontSize: 16),
                  ),
                  Text(
                    isVN
                        ? "Tiến độ nhiệm vụ: $completed / $total"
                        : "Task progress: $completed / $total",
                    style: const TextStyle(fontSize: 16),
                  ),
                  const Divider(height: 40),
                  Text(
                    isVN ? "Nhiệm vụ đã hoàn thành" : "Completed Tasks",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  if (finishedTasks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: Text(
                          isVN
                              ? "Chưa có nhiệm vụ nào được hoàn thành trong phiên này"
                              : "No tasks completed during this session",
                          style: const TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: finishedTasks.length,
                      itemBuilder: (_, i) {
                        return ListTile(
                          leading: const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                          ),
                          title: Text(finishedTasks[i].toString()),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
