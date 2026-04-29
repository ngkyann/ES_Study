import 'package:flutter/material.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/screens/settings_page.dart';

class ProfilePage extends StatelessWidget {
  final String userName;
  final String userId;
  final String selectedClass;
  final String email; // 🔥 Đã thêm email
  final int userPoints;
  final int userStreak;

  const ProfilePage({
    super.key,
    required this.userName,
    required this.userId,
    required this.selectedClass,
    required this.email, // 🔥 Đã thêm email
    required this.userPoints,
    required this.userStreak,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Hồ sơ cá nhân",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          // 🔥 ĐÃ SỬA: Bọc Padding để đẩy nút vào trong
          Padding(
            padding: const EdgeInsets.only(
              right: 12,
            ), // Bạn có thể tăng số này lên nếu muốn vào sâu hơn
            child: IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SettingsPage(
                      userName: userName,
                      selectedClass: selectedClass,
                      userId: userId,
                      email: email, // Truyền email vào đây
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: primaryColor,
        backgroundColor: Colors.white,
        onRefresh: () async {
          await Future.delayed(const Duration(seconds: 1));
        },
        child: SingleChildScrollView(
          // BẮT BUỘC: Thêm physics để luôn vuốt được dù màn hình ngắn
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 30),
                decoration: BoxDecoration(
                  color: primaryColor,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.25),
                      blurRadius: 25,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.person, color: primaryColor, size: 50),
                    ),
                    const SizedBox(height: 15),
                    Text(
                      userName,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      "@$userId",
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            // 🔥 Thêm const vào Icon
                            Icons.local_fire_department,
                            color: Colors.orangeAccent,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Chuỗi $userStreak ngày học", // 🔥 THAY BẰNG BIẾN userStreak
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _infoCard(
                      Icons.alternate_email,
                      "ID người dùng",
                      "@$userId",
                    ),

                    // TỰ ĐỘNG ĐỒNG BỘ XẾP HẠNG TỪ FIREBASE
                    StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .orderBy('points', descending: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        String rankText = "Đang tải...";
                        if (snapshot.hasData) {
                          final docs = snapshot.data!.docs;
                          int myRank = 0;
                          for (int i = 0; i < docs.length; i++) {
                            if (docs[i].id == userId) {
                              myRank = i + 1;
                              break;
                            }
                          }

                          // Phân loại danh hiệu giống Leaderboard
                          if (myRank == 1) {
                            rankText = "🥇 Hạng 1 (Quán quân)";
                          } else if (myRank >= 2 && myRank <= 10) {
                            rankText = "🥈 Hạng $myRank (Top 10)";
                          } else if (myRank >= 11 && myRank <= 50) {
                            rankText = "🥉 Hạng $myRank (Top 50)";
                          } else if (myRank > 50) {
                            rankText = "Hạng $myRank";
                          } else {
                            rankText = "Chưa xếp hạng";
                          }
                        }
                        return _infoCard(
                          Icons.military_tech,
                          "Xếp hạng",
                          rankText,
                        );
                      },
                    ),

                    _infoCard(
                      Icons.workspace_premium,
                      "Tổng điểm",
                      "$userPoints",
                    ),

                    // TỰ ĐỘNG LẤY NGÀY GIA NHẬP TỪ FIREBASE
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        String joinDateText = "Đang tải...";

                        if (snapshot.hasData && snapshot.data!.exists) {
                          final data =
                              snapshot.data!.data() as Map<String, dynamic>;

                          if (data['createdAt'] != null) {
                            // Ép kiểu Timestamp của Firebase sang DateTime của Dart
                            DateTime date = (data['createdAt'] as Timestamp)
                                .toDate();

                            // Định dạng ngày: DD/MM/YYYY
                            String day = date.day.toString().padLeft(2, '0');
                            String month = date.month.toString().padLeft(
                              2,
                              '0',
                            );
                            String year = date.year.toString();

                            joinDateText = "$day/$month/$year";
                          } else {
                            joinDateText = "Không xác định";
                          }
                        }

                        return _infoCard(
                          Icons.calendar_month,
                          "Ngày gia nhập",
                          joinDateText,
                        );
                      },
                    ),

                    _infoCard(Icons.school, "Lớp hiện tại", selectedClass),
                    const SizedBox(
                      height: 30,
                    ), // Giữ lại khoảng trống nhỏ ở cuối cho đẹp mắt
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoCard(IconData icon, String label, String value) {
    return Card(
      elevation: 0,
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ListTile(
          leading: Icon(icon, color: primaryColor),
          title: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          trailing: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }
}
