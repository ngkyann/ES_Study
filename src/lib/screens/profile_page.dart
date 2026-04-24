import 'package:flutter/material.dart';
import 'package:esstudy/constants/colors.dart';

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
    required this.userPoints, // 👈 thêm
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hồ sơ cá nhân"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
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
                // borderRadius: const BorderRadius.only(
                //   bottomLeft: Radius.circular(30),
                //   bottomRight: Radius.circular(30),
                // ),
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: primaryColor),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    userName, // Hiển thị tên từ Login
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    "@$userId", // Hiển thị ID từ Login
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
                  _infoCard(Icons.alternate_email, "ID người dùng", "@$userId"),
                  _infoCard(Icons.military_tech, "Xếp hạng", "Kim cương"),
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
