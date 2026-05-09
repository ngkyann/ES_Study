import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter/foundation.dart';


class PlanPage extends StatefulWidget {
  final String userId;
  const PlanPage({super.key, required this.userId});

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  final FlutterLocalNotificationsPlugin notificationsPlugin = FlutterLocalNotificationsPlugin();

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
      settings: InitializationSettings(
        android: android, 
        iOS: ios,
      ), 
      
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint("Notification clicked: ${response.payload}");
      },
    );

    final androidPlugin = notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        
    if (androidPlugin != null) {
      await androidPlugin.requestNotificationsPermission();
    }
  }

  Future<void> _scheduleNotification(String title, DateTime dateTime) async {
  await notificationsPlugin.zonedSchedule(
    // 1. Phải có tên tham số 'id:'
    id: dateTime.millisecondsSinceEpoch ~/ 1000, 
    
    // 2. Tên tham số 'title:' và 'body:'
    title: "📚 Đến giờ học!",
    body: title,
    
    // 3. Tên tham số 'scheduledDate:'
    scheduledDate: tz.TZDateTime.from(dateTime, tz.local),
    
    // 4. Tên tham số 'notificationDetails:'
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
    TextEditingController taskController = TextEditingController();
    DateTime? selectedDate;
    List<String> tasks = [];

    showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text("Tạo Kế Hoạch"),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          labelText: "Tên kế hoạch (VD: Toán 15 phút)",
                        ),
                      ),
                      const SizedBox(height: 15),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                        ),
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

                          setDialogState(() {
                            selectedDate = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                          });
                        },
                        icon: const Icon(Icons.timer, color: Colors.white),
                        label: Text(
                          selectedDate == null
                              ? "Chọn thời gian"
                              : "${selectedDate!.hour}:${selectedDate!.minute.toString().padLeft(2, '0')} - ${selectedDate!.day}/${selectedDate!.month}",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const Divider(height: 30),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          "Nhiệm vụ cần làm:",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: taskController,
                              decoration: const InputDecoration(
                                hintText: "Nhập nhiệm vụ...",
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
                          IconButton(
                            icon: Icon(Icons.add_circle, color: primaryColor),
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
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: tasks.length,
                          itemBuilder: (context, i) {
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
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
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Hủy"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                  ),
                  onPressed: () async {
                    if (titleController.text.isEmpty ||
                        selectedDate == null ||
                        tasks.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Vui lòng nhập đủ thông tin!"),
                        ),
                      );
                      return;
                    }

                    await FirebaseFirestore.instance.collection('plans').add({
                      'userId': widget.userId,
                      'title': titleController.text,
                      'time': selectedDate,
                      'tasks': tasks,
                      'completedTasks': List.generate(
                        tasks.length,
                        (_) => false,
                      ),
                    });

                    await _scheduleNotification(
                      titleController.text,
                      selectedDate!,
                    );
                    if (mounted) Navigator.pop(context);
                  },
                  child: const Text(
                    "Lưu",
                    style: TextStyle(color: Colors.white),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Kế hoạch",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
          if (snapshot.hasError)
            return Center(child: Text("Lỗi: ${snapshot.error}"));
          if (snapshot.hasData) _cachedDocs = snapshot.data!.docs;

          final docs = List<QueryDocumentSnapshot>.from(_cachedDocs ?? []);
          if (docs.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async =>
                  await Future.delayed(const Duration(seconds: 1)),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 300),
                  Center(
                    child: Text(
                      "Chưa có kế hoạch nào",
                      style: TextStyle(color: Colors.grey),
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
                final completedCount = completedTasks.where((e) => e).length;

                return ListTile(
                  leading: Icon(Icons.schedule, color: primaryColor),
                  title: Text(
                    data['title'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    "${time.day}/${time.month}/${time.year} - ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}\nTiến độ: $completedCount/${tasksList.length} nhiệm vụ",
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => FirebaseFirestore.instance
                        .collection('plans')
                        .doc(data.id)
                        .delete(),
                  ),
                  // 🔥 ĐÃ SỬA: Chế độ XEM NHIỆM VỤ (Read-only)
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
                            style: const TextStyle(fontWeight: FontWeight.bold),
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
                              child: const Text("Đóng"),
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
  }
}
