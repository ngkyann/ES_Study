import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/constants/colors.dart';

class DebugPage extends StatefulWidget {
  const DebugPage({super.key});

  @override
  State<DebugPage> createState() => _DebugPageState();
}

class _DebugPageState extends State<DebugPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    super.dispose();
  }

  // HÀM TẠO TÀI KHOẢN ẢO THEO TÊN VÀ ID
  Future<void> _createFakeUser() async {
    String name = _nameController.text.trim();
    String id = _idController.text.trim();

    if (name.isEmpty || id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Vui lòng nhập đầy đủ Tên và ID!")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final Random random = Random();

      // Random điểm từ 100 đến 1000
      int randomPoints = random.nextInt(901) + 100;

      DocumentReference docRef = firestore.collection('users').doc(id);

      // Khởi tạo một User ảo
      await docRef.set({
        'name': name,
        'id': id,
        'email': '$id@test.com',
        'class': 'Lớp ${random.nextInt(12) + 1}', // Lớp ngẫu nhiên 1 - 12
        'points': randomPoints,
        'coin': random.nextInt(20000),
        'streakCount': random.nextInt(30),
        'avatarUrl': '',
        'bannerUrl': '',
        'ownedEffects': [],
        'activeEffect': '',
        'friends': [],
        'friendRequests': [],
        'createdAt': FieldValue.serverTimestamp(),
        'isFake': true, // 🔥 CỜ ĐÁNH DẤU LÀ ACC ẢO ĐỂ DỄ XÓA
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text("Đã tạo tài khoản ảo '$name' với $randomPoints điểm!"),
              backgroundColor: Colors.green),
        );
        // Xóa form sau khi tạo thành công
        _nameController.clear();
        _idController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // HÀM DỌN DẸP: XÓA TOÀN BỘ TÀI KHOẢN ẢO
  Future<void> _deleteFakeUsers() async {
    setState(() => _isLoading = true);

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;

      // Tìm tất cả các users có cờ isFake = true
      final QuerySnapshot fakeUsersSnap = await firestore
          .collection('users')
          .where('isFake', isEqualTo: true)
          .get();

      if (fakeUsersSnap.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Không có tài khoản ảo nào để xóa.")),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      WriteBatch batch = firestore.batch();
      int deletedCount = 0;

      for (var doc in fakeUsersSnap.docs) {
        batch.delete(doc.reference);
        deletedCount++;

        if (deletedCount % 400 == 0) {
          await batch.commit();
          batch = firestore.batch();
        }
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Đã dọn dẹp sạch sẽ $deletedCount tài khoản ảo!"),
              backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lỗi xóa: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

// 🔥 HÀM CẬP NHẬT TẤT CẢ USERS ĐÃ TẠO THÀNH LỚP 10
  Future<void> _updateAllUsersToClass10() async {
    setState(() => _isLoading = true);

    try {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;

      // Lấy toàn bộ tài khoản đang có trong collection 'users'
      final QuerySnapshot usersSnap = await firestore.collection('users').get();

      if (usersSnap.docs.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Không có tài khoản nào trong database.")),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      WriteBatch batch = firestore.batch();
      int updatedCount = 0;

      for (var doc in usersSnap.docs) {
        // Cập nhật trường class thành 'Lớp 10'
        batch.update(doc.reference, {'class': 'Lớp 10'});
        updatedCount++;

        // Chia nhỏ batch (cứ 400 docs commit 1 lần) để tránh vượt giới hạn 500 của Firebase
        if (updatedCount % 400 == 0) {
          await batch.commit();
          batch = firestore.batch();
        }
      }

      // Commit số lượng tài khoản còn lại
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                "Đã chuyển thành công $updatedCount tài khoản thành 'Lớp 10'!"),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("Lỗi khi cập nhật: $e"),
              backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Công cụ Debug"),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Tạo tài khoản ảo để test tính năng kết bạn hoặc bảng xếp hạng. Điểm (points) sẽ được ngẫu nhiên từ 100 - 1000.",
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: "Tên tài khoản",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: "ID tài khoản (Viết liền, không dấu)",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white),
                onPressed: _isLoading ? null : _createFakeUser,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.rocket_launch),
                label: const Text("TẠO TÀI KHOẢN ẢO",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 30),
            const Divider(),
            const SizedBox(height: 15), // Khoảng cách với nút trên
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white),
                onPressed: _isLoading ? null : _updateAllUsersToClass10,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.edit_calendar),
                label: const Text("CHUYỂN TẤT CẢ THÀNH LỚP 10",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600,
                    foregroundColor: Colors.white),
                onPressed: _isLoading ? null : _deleteFakeUsers,
                icon: _isLoading
                    ? const SizedBox.shrink()
                    : const Icon(Icons.delete_sweep),
                label: const Text("DỌN SẠCH TÀI KHOẢN ẢO",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
