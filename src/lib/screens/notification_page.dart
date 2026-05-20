import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:esstudy/constants/var.dart';

class NotificationPage extends StatefulWidget {
  final String userId;

  const NotificationPage({super.key, required this.userId});

  @override
  State<NotificationPage> createState() => _NotificationPageState();
}

class _NotificationPageState extends State<NotificationPage> {
  @override
  Widget build(BuildContext context) {
    bool isVN = languageNotifier.value == "Tiếng Việt";

    return Scaffold(
      backgroundColor: Colors
          .transparent, // 🔥 QUAN TRỌNG: Làm nền Scaffold trong suốt hoàn toàn
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          isVN ? "Thông báo" : "Notifications",
          style: TextStyle(
              fontWeight: FontWeight.bold,
              color: primaryColor), // Ăn theo màu hệ thống
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: primaryColor), // Ăn theo màu hệ thống
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(
                  sigmaX: 20.0,
                  sigmaY: 20.0), // Hiệu ứng làm mờ giao diện phía dưới
              child: Container(
                color: primaryColor.withOpacity(
                    0.12), // Phủ một lớp màu hệ thống trong suốt siêu nhẹ
              ),
            ),
          ),

          Positioned(
            top: 120,
            left: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withOpacity(0.18),
              ),
            ),
          ),

          // 2. DANH SÁCH THÔNG BÁO ĐÈ LÊN TRÊN LỚP KÍNH
          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('userId', isEqualTo: widget.userId)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined,
                            size: 80, color: primaryColor.withOpacity(0.4)),
                        const SizedBox(height: 16),
                        Text(
                          isVN
                              ? "Không có thông báo nào"
                              : "No notifications yet",
                          style: TextStyle(
                              color: primaryColor.withOpacity(0.7),
                              fontSize: 16,
                              fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  );
                }

                final docs = snapshot.data!.docs;

                return ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;

                    final timestamp = data['createdAt'] as Timestamp?;
                    final dateTime = timestamp?.toDate() ?? DateTime.now();

                    final String dayMonthStr =
                        "${dateTime.day.toString().padLeft(2, '0')}/${dateTime.month.toString().padLeft(2, '0')}";
                    final String hourMinuteStr =
                        "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}";
                    final String contentStr = data['content'] ??
                        (isVN ? "Không có nội dung" : "No content");

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        // Hộp kính màu trắng sữa mỏng giúp đọc text rõ ràng trên nền phức tạp của Home Page
                        color: Colors.white.withOpacity(0.65),
                        borderRadius: BorderRadius.circular(20),
                        // Đường viền mỏng bóng bẩy theo màu hệ thống
                        border: Border.all(
                          color: primaryColor.withOpacity(0.25),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.notifications_active,
                                color: primaryColor,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  RichText(
                                    text: TextSpan(
                                      style: const TextStyle(
                                        fontSize: 15,
                                        color: Colors.black87,
                                        height: 1.3,
                                      ),
                                      children: [
                                        // Phần Ngày/Tháng dạng "DD/MM" màu hệ thống
                                        TextSpan(
                                          text: '"$dayMonthStr"',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: primaryColor),
                                        ),
                                        const TextSpan(text: ' : '),
                                        // Phần Giờ:Phút màu cam nổi bật nhạt
                                        TextSpan(
                                          text: '"$hourMinuteStr"',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: Colors.orangeAccent),
                                        ),
                                        const TextSpan(text: ' : '),
                                        // Nội dung văn bản thông báo
                                        TextSpan(
                                          text: '"$contentStr"',
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w400,
                                              color: Colors.black87),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
