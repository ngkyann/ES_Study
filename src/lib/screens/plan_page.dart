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
      // Xin quyền chạy thông báo chính xác khi tắt màn hình (Android 12+)
      await androidPlugin.requestExactAlarmsPermission();
    }
  }

  // 🔥 ĐÃ SỬA: Dùng đúng cú pháp tham số có tên (Named Parameters) của bản mới
  Future<void> _scheduleNotification(
      int notifId, String title, DateTime dateTime) async {
    bool isVN = languageNotifier.value == "Tiếng Việt";

    await notificationsPlugin.zonedSchedule(
      id: notifId,
      title: isVN ? "📚 Đến giờ học!" : "📚 Time to study!",
      body: title,
      scheduledDate: tz.TZDateTime.from(dateTime, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'study_channel',
          'Study Reminder',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          showWhen: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Widget _buildTimeInputField(TextEditingController controller, String label,
      {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 13),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        ),
      ),
    );
  }

  Future<void> _addPlan() async {
    TextEditingController titleController = TextEditingController();
    TextEditingController dayController = TextEditingController();
    TextEditingController monthController = TextEditingController();
    TextEditingController yearController = TextEditingController();
    TextEditingController hourController = TextEditingController();
    TextEditingController minuteController = TextEditingController();
    TextEditingController taskController = TextEditingController();
    List<String> tasks = [];

    // 🔥 BIẾN QUẢN LÝ TRẠNG THÁI LOADING TRÁNH ĐƠ APP
    bool isSubmitting = false;

    DateTime now = DateTime.now();
    dayController.text = now.day.toString().padLeft(2, '0');
    monthController.text = now.month.toString().padLeft(2, '0');
    yearController.text = now.year.toString();
    hourController.text = now.hour.toString().padLeft(2, '0');
    minuteController.text = now.minute.toString().padLeft(2, '0');

    showDialog(
      context: context,
      barrierDismissible: false, // Không cho bấm ra ngoài khi đang xử lý
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isVN = languageNotifier.value == "Tiếng Việt";

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(isVN ? "Tạo kế hoạch" : "Create Plan"),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: titleController,
                        enabled: !isSubmitting, // Khóa khi đang load
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
                      Text(
                        isVN ? "Ngày / Tháng / Năm" : "Day / Month / Year",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.grey),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          _buildTimeInputField(
                              dayController, isVN ? "Ngày" : "DD"),
                          const SizedBox(width: 8),
                          const Text("/",
                              style:
                                  TextStyle(fontSize: 18, color: Colors.grey)),
                          const SizedBox(width: 8),
                          _buildTimeInputField(
                              monthController, isVN ? "Tháng" : "MM"),
                          const SizedBox(width: 8),
                          const Text("/",
                              style:
                                  TextStyle(fontSize: 18, color: Colors.grey)),
                          const SizedBox(width: 8),
                          _buildTimeInputField(
                              yearController, isVN ? "Năm" : "YYYY",
                              flex: 2),
                        ],
                      ),
                      const SizedBox(height: 15),
                      Text(
                        isVN ? "Giờ : Phút" : "Hour : Minute",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Colors.grey),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          _buildTimeInputField(
                              hourController, isVN ? "Giờ" : "HH"),
                          const SizedBox(width: 8),
                          const Text(":",
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(width: 8),
                          _buildTimeInputField(
                              minuteController, isVN ? "Phút" : "MM"),
                          const Spacer(),
                        ],
                      ),
                      const Divider(height: 30),
                      Text(
                        isVN ? "Nhiệm vụ cần làm:" : "Tasks to do:",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: taskController,
                              enabled: !isSubmitting, // Khóa khi đang load
                              decoration: InputDecoration(
                                hintText:
                                    isVN ? "Nhập nhiệm vụ..." : "Enter task...",
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                isDense: true,
                              ),
                              onSubmitted: (_) {
                                if (taskController.text.trim().isNotEmpty &&
                                    !isSubmitting) {
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
                                color:
                                    isSubmitting ? Colors.grey : primaryColor,
                                size: 32),
                            onPressed: isSubmitting
                                ? null
                                : () {
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
                                  icon: Icon(
                                    Icons.remove_circle,
                                    color:
                                        isSubmitting ? Colors.grey : Colors.red,
                                    size: 20,
                                  ),
                                  onPressed: isSubmitting
                                      ? null
                                      : () => setDialogState(
                                          () => tasks.removeAt(i)),
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
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: Text(isVN ? "Hủy" : "Cancel",
                      style: TextStyle(
                          color: isSubmitting
                              ? Colors.grey.shade300
                              : Colors.grey)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      )),
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (titleController.text.isEmpty || tasks.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isVN
                                    ? "Vui lòng nhập tên và nhiệm vụ!"
                                    : "Please enter title and tasks!"),
                              ),
                            );
                            return;
                          }

                          DateTime parsedDate;
                          try {
                            int? day = int.tryParse(dayController.text.trim());
                            int? month =
                                int.tryParse(monthController.text.trim());
                            int? year =
                                int.tryParse(yearController.text.trim());
                            int? hour =
                                int.tryParse(hourController.text.trim());
                            int? minute =
                                int.tryParse(minuteController.text.trim());

                            if (day == null ||
                                month == null ||
                                year == null ||
                                hour == null ||
                                minute == null) {
                              throw Exception("Dữ liệu trống");
                            }

                            if (month < 1 ||
                                month > 12 ||
                                day < 1 ||
                                day > 31 ||
                                hour < 0 ||
                                hour > 23 ||
                                minute < 0 ||
                                minute > 59) {
                              throw Exception("Sai khoảng giá trị");
                            }

                            parsedDate =
                                DateTime(year, month, day, hour, minute);

                            DateTime exactNow = DateTime.now();
                            DateTime currentMinute = DateTime(
                                exactNow.year,
                                exactNow.month,
                                exactNow.day,
                                exactNow.hour,
                                exactNow.minute);

                            if (parsedDate.isBefore(currentMinute)) {
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
                                    ? "Ngày hoặc giờ không hợp lệ!"
                                    : "Invalid date or time!"),
                              ),
                            );
                            return;
                          }

                          // 🔥 BẬT TRẠNG THÁI LOADING (XOAY VÒNG) TẠI ĐÂY
                          setDialogState(() {
                            isSubmitting = true;
                          });

                          try {
                            DocumentReference docRef = await FirebaseFirestore
                                .instance
                                .collection('plans')
                                .add({
                              'userId': widget.userId,
                              'title': titleController.text,
                              'time': parsedDate,
                              'tasks': tasks,
                              'completedTasks': List.generate(
                                tasks.length,
                                (_) => false,
                              ),
                            });

                            // 🔥 LƯU THÔNG BÁO VỚI CẢ 2 NGÔN NGỮ
                            await FirebaseFirestore.instance
                                .collection('notifications')
                                .doc('plan_${docRef.id}')
                                .set({
                              'userId': widget.userId,
                              'content_vn':
                                  "📚 Đến giờ thực hiện kế hoạch: ${titleController.text}",
                              'content_en':
                                  "📚 Time for your plan: ${titleController.text}",
                              'createdAt': Timestamp.fromDate(parsedDate),
                            });

                            // Gọi thông báo chuẩn xác với ID từ Firebase
                            await _scheduleNotification(
                              docRef.id.hashCode,
                              titleController.text,
                              parsedDate,
                            );

                            // Nếu tạo thành công, tắt pop up đi
                            if (mounted) Navigator.pop(context);
                          } catch (e) {
                            // Nếu lỗi Firebase thì báo lỗi và tắt vòng xoay
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                  content: Text(isVN
                                      ? "Đã có lỗi xảy ra!"
                                      : "An error occurred!")),
                            );
                            setDialogState(() {
                              isSubmitting = false;
                            });
                          }
                        },
                  // 🔥 ĐỔI GIAO DIỆN NÚT KHI ĐANG LOADING
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : Text(
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
                          onPressed: () async {
                            // 🔥 ĐÃ SỬA: Hàm hủy thông báo cũng cần khai báo "id:"
                            await notificationsPlugin.cancel(
                                id: data.id.hashCode);

                            await FirebaseFirestore.instance
                                .collection('plans')
                                .doc(data.id)
                                .delete();
                            await FirebaseFirestore.instance
                                .collection('notifications')
                                .doc('plan_${data.id}')
                                .delete();
                          }),
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
