import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class PlanPage extends StatefulWidget {
  final String userId;

  const PlanPage({super.key, required this.userId});

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  List<QueryDocumentSnapshot>? _cachedDocs;

  @override
  void initState() {
    super.initState();
    _initNotification();

    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
  }

  Future<void> _initNotification() async {
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await notificationsPlugin.initialize(settings);
  }

  Future<void> _scheduleNotification(String title, DateTime dateTime) async {
    await notificationsPlugin.zonedSchedule(
      dateTime.millisecondsSinceEpoch ~/ 1000, // ID duy nhất
      "📚 Đến giờ học!",
      title,
      tz.TZDateTime.from(dateTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'study_channel',
          'Study Reminder',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> _addPlan() async {
    TextEditingController titleController = TextEditingController();
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Thêm kế hoạch"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: "Nội dung"),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () async {
                final date = await showDatePicker(
                  context: context,
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2100),
                  initialDate: DateTime.now(),
                );

                if (date == null) return;

                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );

                if (time == null) return;

                selectedDate = DateTime(
                  date.year,
                  date.month,
                  date.day,
                  time.hour,
                  time.minute,
                );
              },
              child: const Text("Chọn ngày giờ"),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Hủy"),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isEmpty || selectedDate == null) return;

              await FirebaseFirestore.instance.collection('plans').add({
                'userId': widget.userId,
                'title': titleController.text,
                'time': selectedDate,
              });

              await _scheduleNotification(titleController.text, selectedDate!);

              Navigator.pop(context);
            },
            child: const Text("Lưu"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Kế hoạch",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        centerTitle: true, // ✅ căn giữa
        iconTheme: const IconThemeData(
          color: Colors.white, // ✅ mũi tên back màu trắng
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: primaryColor,
        onPressed: _addPlan,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('plans')
            .where('userId', isEqualTo: widget.userId)
            .snapshots(), // ❌ bỏ orderBy để tránh lỗi index
        builder: (context, snapshot) {
          // loading lần đầu
          if (snapshot.connectionState == ConnectionState.waiting &&
              _cachedDocs == null) {
            return const Center(child: CircularProgressIndicator());
          }

          // lỗi
          if (snapshot.hasError) {
            return Center(child: Text("Lỗi: ${snapshot.error}"));
          }

          // cập nhật cache nếu có dữ liệu mới
          if (snapshot.hasData) {
            _cachedDocs = snapshot.data!.docs;
          }

          final docs = _cachedDocs ?? [];

          // rỗng
          if (docs.isEmpty) {
            // 🔥 ĐÃ THÊM: Vuốt tải lại khi danh sách trống
            return RefreshIndicator(
              color: primaryColor,
              backgroundColor: Colors.white,
              onRefresh: () async {
                await Future.delayed(const Duration(seconds: 1));
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 300), // Căn giữa dòng chữ
                  Center(
                    child: Text(
                      "Chưa có kế hoạch nào",
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            );
          }

          // sort theo thời gian
          docs.sort((a, b) {
            DateTime timeA = (a['time'] as Timestamp).toDate();
            DateTime timeB = (b['time'] as Timestamp).toDate();
            return timeA.compareTo(timeB);
          });

          // 🔥 ĐÃ THÊM: Vuốt tải lại khi có danh sách
          return RefreshIndicator(
            color: primaryColor,
            backgroundColor: Colors.white,
            onRefresh: () async {
              await Future.delayed(const Duration(seconds: 1));
            },
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(), // Bắt buộc
              itemCount: docs.length,
              itemBuilder: (_, index) {
                final data = docs[index];
                DateTime time = (data['time'] as Timestamp).toDate();

                return ListTile(
                  leading: const Icon(Icons.schedule, color: primaryColor),
                  title: Text(data['title']),
                  subtitle: Text(
                    "${time.day}/${time.month}/${time.year} - ${time.hour}:${time.minute.toString().padLeft(2, '0')}",
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      FirebaseFirestore.instance
                          .collection('plans')
                          .doc(data.id)
                          .delete();
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
