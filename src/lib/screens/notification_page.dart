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

    Color darkerPrimary = Color.lerp(primaryColor, primaryColor, 0.4)!;

    final List<Shadow> outlineStyle = [
      Shadow(offset: const Offset(-1.2, -1.2), color: darkerPrimary),
      Shadow(offset: const Offset(1.2, -1.2), color: darkerPrimary),
      Shadow(offset: const Offset(1.2, 1.2), color: darkerPrimary),
      Shadow(offset: const Offset(-1.2, 1.2), color: darkerPrimary),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          isVN ? "Thông báo" : "Notifications",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: outlineStyle, // Áp dụng viền cho tiêu đề
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          Container(
            color: primaryColor.withOpacity(0.3),
          ),
          Positioned(
            top: 100,
            left: -50,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    primaryColor.withOpacity(0.6),
                    primaryColor.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 150,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.purple.withOpacity(0.5),
                    Colors.purple.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 400,
            right: -30,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.teal.withOpacity(0.5),
                    Colors.teal.withOpacity(0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 30.0, sigmaY: 30.0),
              child: Container(
                color: Colors.white.withOpacity(0.03),
              ),
            ),
          ),
          SafeArea(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('userId', isEqualTo: widget.userId)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 80,
                          color: Colors.white,
                          shadows: outlineStyle, // Áp dụng viền cho Icon trống
                        ),
                        const SizedBox(height: 16),
                        Text(
                          isVN
                              ? "Không có thông báo nào"
                              : "No notifications yet",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            shadows:
                                outlineStyle, // Áp dụng viền cho Text trống
                          ),
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
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.15),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Icon chuông trang trí nhỏ hiệu ứng neon nhẹ
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.notifications_active,
                                  color: Colors.amberAccent,
                                  size: 20,
                                  shadows:
                                      outlineStyle, // Áp dụng viền cho Icon chuông
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Nội dung thông báo hiển thị đúng format yêu cầu
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    RichText(
                                      text: TextSpan(
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Colors.white,
                                          height: 1.3,
                                          shadows:
                                              outlineStyle, // 🔥 Áp dụng viền cho TOÀN BỘ TextSpan bên trong
                                        ),
                                        children: [
                                          // Phần Ngày/Tháng (In đậm nổi bật)
                                          TextSpan(
                                            text: '"$dayMonthStr"',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.cyanAccent),
                                          ),
                                          const TextSpan(text: ' : '),
                                          // Phần Giờ:Phút (In đậm nổi bật)
                                          TextSpan(
                                            text: '"$hourMinuteStr"',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: Colors.orangeAccent),
                                          ),
                                          const TextSpan(text: ' : '),
                                          // Phần nội dung thông báo thông thường
                                          TextSpan(
                                            text: '"$contentStr"',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w400,
                                                color: Colors.white),
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
