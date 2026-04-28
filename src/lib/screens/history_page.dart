import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/constants/colors.dart';

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
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Lịch sử học tập",
          style: TextStyle(fontWeight: FontWeight.bold),
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
                  "Lỗi khi tải lịch sử: ${snapshot.error}\n\nNếu lỗi nói requires an index, tạo composite index: userId ASC, time DESC.",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("Chưa có lịch sử học tập"));
          }

          final docs = snapshot.data!.docs;

          // 🔥 ĐÃ THÊM: RefreshIndicator để vuốt tải lại
          return RefreshIndicator(
            color: primaryColor,
            backgroundColor: Colors.white,
            onRefresh: () async {
              await Future.delayed(const Duration(seconds: 1));
            },
            child: ListView.builder(
              // 🔥 BẮT BUỘC: Thêm physics để luôn vuốt được
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

                final timeText = time.millisecondsSinceEpoch > 0
                    ? "${time.day}/${time.month}/${time.year}"
                    : "Ngày không xác định";

                return Card(
                  child: ListTile(
                    leading: Icon(Icons.history, color: primaryColor),
                    title: Text("Hoàn thành $completed/$total mục tiêu"),
                    subtitle: Text("$timeText - $minutes phút"),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HistoryDetailPage(data: data),
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
  }
}

class HistoryDetailPage extends StatelessWidget {
  final Map<String, dynamic> data;

  const HistoryDetailPage({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final DateTime time = parseTime(data['time']);

    final List<dynamic> goals = (data['goals'] is List)
        ? List<dynamic>.from(data['goals'])
        : <dynamic>[];
    final int completed = data['completed'] ?? 0;
    final int total = data['total'] ?? 0;
    final int minutes = data['minutes'] ?? 0;

    final timeText = time.millisecondsSinceEpoch > 0
        ? "${time.day}/${time.month}/${time.year}"
        : "Không xác định";

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: const Text(
          "Chi tiết buổi học",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      // 🔥 ĐÃ THÊM: RefreshIndicator để vuốt tải lại
      body: RefreshIndicator(
        color: primaryColor,
        backgroundColor: Colors.white,
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
        },
        child: SingleChildScrollView(
          // 🔥 BẮT BUỘC: Thêm physics
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Ngày: $timeText",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              Text("Thời gian học: $minutes phút"),
              Text("Hoàn thành: $completed / $total mục tiêu"),
              const SizedBox(height: 20),
              const Text(
                "Danh sách mục tiêu",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              // Đã đổi Expanded thành cấu trúc phù hợp với SingleChildScrollView
              if (goals.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(child: Text("Không có mục tiêu")),
                )
              else
                ListView.builder(
                  shrinkWrap: true, // Ép ListView ôm gọn nội dung
                  physics:
                      const NeverScrollableScrollPhysics(), // Tắt cuộn bên trong để nhường cho cuộn bên ngoài
                  itemCount: goals.length,
                  itemBuilder: (_, i) {
                    return ListTile(
                      leading: const Icon(
                        Icons.check_circle_outline,
                        color: Colors.green,
                      ),
                      title: Text(goals[i].toString()),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
