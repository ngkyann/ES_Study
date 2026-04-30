import 'package:flutter/material.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/screens/settings_page.dart';

class ProfilePage extends StatelessWidget {
  final String userName;
  final String userId;
  final String selectedClass;
  final String email;
  final int userPoints;
  final int userStreak;

  const ProfilePage({
    super.key,
    required this.userName,
    required this.userId,
    required this.selectedClass,
    required this.email,
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
          Padding(
            padding: const EdgeInsets.only(right: 12),
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
                      email: email,
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
                      child: Icon(
                        Icons.person,
                        color: Color(0xFF6366F1),
                        size: 50,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // STREAMBUILDER ĐỂ CẬP NHẬT TÊN REAL-TIME
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        String currentName = userName;
                        if (snapshot.hasData && snapshot.data!.exists) {
                          currentName = snapshot.data!.get('name') ?? userName;
                        }
                        // 🔥 ĐÃ SỬA: Xóa bỏ Row và SizedBox gây lệch, chỉ dùng Text căn giữa
                        return Text(
                          currentName,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      },
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
                            Icons.local_fire_department,
                            color: Colors.orangeAccent,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "Chuỗi $userStreak ngày học",
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
                            DateTime date = (data['createdAt'] as Timestamp)
                                .toDate();
                            joinDateText =
                                "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
                          }
                        }
                        return _infoCard(
                          Icons.calendar_month,
                          "Ngày gia nhập",
                          joinDateText,
                        );
                      },
                    ),

                    // CARD LỚP HỌC
                    StreamBuilder<DocumentSnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(userId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        String currentClass = selectedClass;
                        if (snapshot.hasData && snapshot.data!.exists) {
                          currentClass =
                              snapshot.data!.get('class') ?? selectedClass;
                        }
                        // 🔥 ĐÃ SỬA: Bỏ GestureDetector vì giờ đã chỉnh sửa trong Setting
                        return _infoCard(Icons.school, "Lớp", currentClass);
                      },
                    ),

                    const SizedBox(height: 30),
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
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          trailing: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ),
    );
  }
}
