import 'package:flutter/material.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- TRANG CÁ NHÂN (Hiển thị dữ liệu động) ---
class ProfilePage extends StatelessWidget {
  final String userName;
  final String userId;
  final String selectedClass;
  final int userPoints;

  const ProfilePage({
    super.key,
    required this.userName,
    required this.userId,
    required this.selectedClass,
    required this.userPoints,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hồ sơ cá nhân"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      // 🔥 ĐÃ THÊM: RefreshIndicator bao bọc bên ngoài
      body: RefreshIndicator(
        color: primaryColor,
        backgroundColor: Colors.white,
        onRefresh: () async {
          // Giả lập thời gian tải 1 giây để hiện vòng xoay mượt mà
          await Future.delayed(const Duration(seconds: 1));
        },
        child: SingleChildScrollView(
          // 🔥 BẮT BUỘC: Thêm physics để luôn vuốt được dù màn hình ngắn
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
                    const CircleAvatar(
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
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.local_fire_department,
                            color: Colors.orangeAccent,
                          ),
                          SizedBox(width: 8),
                          Text(
                            "Chuỗi 15 ngày học",
                            style: TextStyle(
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

                    // 🔥 TỰ ĐỘNG ĐỒNG BỘ XẾP HẠNG TỪ FIREBASE
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
                            rankText = "Hạng 1 (Quán quân)";
                          } else if (myRank >= 2 && myRank <= 10) {
                            rankText = "Hạng $myRank (Top 10)";
                          } else if (myRank >= 11 && myRank <= 50) {
                            rankText = "Hạng $myRank (Top 50)";
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
                    _infoCard(
                      Icons.calendar_month,
                      "Ngày gia nhập",
                      "24/04/2026",
                    ),
                    _infoCard(Icons.school, "Lớp hiện tại", selectedClass),
                    const SizedBox(height: 30),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.edit),
                      label: const Text("Chỉnh sửa thông tin"),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                        side: const BorderSide(color: primaryColor),
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
