import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';
import 'package:esstudy/constants/var.dart'; // 🔥 IMPORT BIẾN NGÔN NGỮ

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
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    await notificationsPlugin.initialize(
      settings: const InitializationSettings(
        android: android,
        iOS: ios,
      ),
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint("Notification clicked: ${response.payload}");
      },
    );

    final androidPlugin =
        notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
  }

  Future<void> _scheduleNotification(String title, DateTime dateTime) async {
    bool isVN = languageNotifier.value == "Tiếng Việt"; // 🔥 DỊCH THÔNG BÁO

    await notificationsPlugin.zonedSchedule(
      id: dateTime.millisecondsSinceEpoch ~/ 1000,
      title: isVN ? "📚 Đến giờ học!" : "📚 Time to study!",
      body: title,
      scheduledDate: tz.TZDateTime.from(dateTime, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'study_channel',
          'Study Reminder',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> _addPlan() async {
    TextEditingController titleController = TextEditingController();
    TextEditingController dateController =
        TextEditingController(); // 🆕 Controller nhập ngày
    TextEditingController timeController =
        TextEditingController(); // 🆕 Controller nhập giờ
    TextEditingController taskController = TextEditingController();
    List<String> tasks = [];

    // Gợi ý ngày giờ hiện tại cho user dễ nhập
    DateTime now = DateTime.now();
    dateController.text =
        "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";
    timeController.text =
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isVN =
                languageNotifier.value == "Tiếng Việt"; // 🔥 LẤY NGÔN NGỮ

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(16), // 🆕 Bo góc Dialog cho đẹp
              ),
              title: Text(isVN ? "Tạo kế hoạch" : "Create Plan"),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: InputDecoration(
                          labelText: isVN
                              ? "Tên kế hoạch (VD: Học toán)"
                              : "Plan name (e.g., Math)",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 15),

                      // 🆕 Khung nhập Ngày và Giờ
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: dateController,
                              keyboardType: TextInputType.datetime,
                              decoration: InputDecoration(
                                labelText: isVN
                                    ? "Ngày (DD/MM/YYYY)"
                                    : "Date (DD/MM/YYYY)",
                                hintText: "VD: 25/12/2024",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: timeController,
                              keyboardType: TextInputType.datetime,
                              decoration: InputDecoration(
                                labelText:
                                    isVN ? "Giờ (HH:MM)" : "Time (HH:MM)",
                                hintText: "VD: 14:30",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                isDense: true,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 30),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          isVN ? "Nhiệm vụ cần làm:" : "Tasks to do:",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: taskController,
                              decoration: InputDecoration(
                                hintText:
                                    isVN ? "Nhập nhiệm vụ..." : "Enter task...",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                isDense: true,
                              ),
                              onSubmitted: (_) {
                                if (taskController.text.trim().isNotEmpty) {
                                  setDialogState(() {
                                    tasks.add(taskController.text.trim());
                                    taskController.clear();
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: Icon(Icons.add_circle,
                                color: primaryColor, size: 32),
                            onPressed: () {
                              if (taskController.text.trim().isNotEmpty) {
                                setDialogState(() {
                                  tasks.add(taskController.text.trim());
                                  taskController.clear();
                                });
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (tasks.isNotEmpty)
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: tasks.length,
                            itemBuilder: (context, i) {
                              return ListTile(
                                dense: true,
                                title: Text("- ${tasks[i]}"),
                                trailing: IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle,
                                    color: Colors.red,
                                    size: 20,
                                  ),
                                  onPressed: () =>
                                      setDialogState(() => tasks.removeAt(i)),
                                ),
                              );
                            },
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(isVN ? "Hủy" : "Cancel",
                      style: const TextStyle(color: Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      )),
                  onPressed: () async {
                    if (titleController.text.isEmpty ||
                        dateController.text.isEmpty ||
                        timeController.text.isEmpty ||
                        tasks.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isVN
                              ? "Vui lòng nhập đủ thông tin!"
                              : "Please enter all information!"),
                        ),
                      );
                      return;
                    }

                    DateTime parsedDate;
                    try {
                      // 🆕 Xử lý parse chuỗi ngày (DD/MM/YYYY)
                      List<String> dateParts =
                          dateController.text.trim().split('/');
                      if (dateParts.length != 3) throw Exception();
                      int day = int.parse(dateParts[0]);
                      int month = int.parse(dateParts[1]);
                      int year = int.parse(dateParts[2]);

                      // 🆕 Xử lý parse chuỗi giờ (HH:MM)
                      List<String> timeParts =
                          timeController.text.trim().split(':');
                      if (timeParts.length != 2) throw Exception();
                      int hour = int.parse(timeParts[0]);
                      int minute = int.parse(timeParts[1]);

                      if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
                        throw Exception();
                      }

                      parsedDate = DateTime(year, month, day, hour, minute);

                      if (parsedDate.isBefore(DateTime.now())) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isVN
                                ? "Không thể đặt lịch trong quá khứ!"
                                : "Cannot set a plan in the past!"),
                          ),
                        );
                        return;
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isVN
                              ? "Định dạng ngày/giờ không hợp lệ!"
                              : "Invalid date/time format!"),
                        ),
                      );
                      return;
                    }

                    await FirebaseFirestore.instance.collection('plans').add({
                      'userId': widget.userId,
                      'title': titleController.text,
                      'time': parsedDate,
                      'tasks': tasks,
                      'completedTasks': List.generate(
                        tasks.length,
                        (_) => false,
                      ),
                    });

                    await _scheduleNotification(
                      titleController.text,
                      parsedDate,
                    );
                    if (mounted) Navigator.pop(context);
                  },
                  child: Text(
                    isVN ? "Tạo" : "Create",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 BỌC GIAO DIỆN CHÍNH
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, child) {
        bool isVN = lang == "Tiếng Việt";

        return Scaffold(
          appBar: AppBar(
            title: Text(
              isVN ? "Kế hoạch học tập" : "Study Plan",
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: primaryColor,
            centerTitle: true,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: primaryColor,
            onPressed: _addPlan,
            child: const Icon(Icons.add, color: Colors.white),
          ),
          body: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('plans')
                .where('userId', isEqualTo: widget.userId)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  _cachedDocs == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                    child: Text(isVN
                        ? "Lỗi: ${snapshot.error}"
                        : "Error: ${snapshot.error}"));
              }
              if (snapshot.hasData) _cachedDocs = snapshot.data!.docs;

              final docs = List<QueryDocumentSnapshot>.from(_cachedDocs ?? []);
              if (docs.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () async =>
                      await Future.delayed(const Duration(seconds: 1)),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      const SizedBox(height: 300),
                      Center(
                        child: Text(
                          isVN ? "Chưa có kế hoạch nào" : "No plans yet",
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                );
              }

              docs.sort((a, b) {
                DateTime timeA = (a['time'] as Timestamp).toDate();
                DateTime timeB = (b['time'] as Timestamp).toDate();
                return timeA.compareTo(timeB);
              });

              return RefreshIndicator(
                onRefresh: () async =>
                    await Future.delayed(const Duration(seconds: 1)),
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: docs.length,
                  itemBuilder: (_, index) {
                    final data = docs[index];
                    DateTime time = (data['time'] as Timestamp).toDate();
                    final mapData = data.data() as Map<String, dynamic>;
                    final tasksList = List<String>.from(mapData['tasks'] ?? []);
                    final completedTasks = List<bool>.from(
                      mapData['completedTasks'] ??
                          List.generate(tasksList.length, (_) => false),
                    );
                    final completedCount =
                        completedTasks.where((e) => e).length;

                    return ListTile(
                      leading: Icon(Icons.schedule, color: primaryColor),
                      title: Text(
                        data['title'],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "${time.day.toString().padLeft(2, '0')}/${time.month.toString().padLeft(2, '0')}/${time.year} - ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}\n" +
                            (isVN ? "Tiến độ" : "Progress") +
                            ": $completedCount/${tasksList.length} " +
                            (isVN ? "nhiệm vụ" : "tasks"),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => FirebaseFirestore.instance
                            .collection('plans')
                            .doc(data.id)
                            .delete(),
                      ),
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              title: Text(
                                data['title'],
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold),
                              ),
                              content: SizedBox(
                                width: double.maxFinite,
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: tasksList.length,
                                  itemBuilder: (context, i) {
                                    bool isDone = completedTasks[i];
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8.0,
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            isDone
                                                ? Icons.check_circle
                                                : Icons.radio_button_unchecked,
                                            color: isDone
                                                ? Colors.green
                                                : Colors.grey,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              tasksList[i],
                                              style: TextStyle(
                                                fontSize: 16,
                                                decoration: isDone
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                                color: isDone
                                                    ? Colors.grey
                                                    : Colors.black87,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(isVN ? "Đóng" : "Close"),
                                ),
                              ],
                            );
                          },
                        );
                      },
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
