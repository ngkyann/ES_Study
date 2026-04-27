import 'package:flutter/material.dart';
import 'package:esstudy/screens/login_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:esstudy/timezone_helper.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/screens/home_page.dart';
import 'widgets/ai_assistant_fab.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  vn = tz.getLocation('Asia/Ho_Chi_Minh');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ES Study',
      
      // --- PHẦN THÊM MỚI (Vỏ bọc AI) ---
      builder: (context, child) {
        return Scaffold(
          body: Stack(
            children: [
              child!, // Giữ nguyên toàn bộ logic Home/Login bên dưới
              const AIAssistantFAB(), // Chèn thêm bong bóng AI lên trên cùng
            ],
          ),
        );
      },
      // --------------------------------

      // LOGIC CŨ GIỮ NGUYÊN 100%
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnapshot) {
          // 1. Chờ kiểm tra trạng thái đăng nhập
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // 2. Nếu đã đăng nhập (Auth thành công)
          if (authSnapshot.hasData && authSnapshot.data != null) {
            final user = authSnapshot.data!;

            // Kiểm tra email phòng hờ lúc signOut bị null giữa chừng
            if (user.email == null || !user.email!.contains('@')) {
              return const LoginPage();
            }

            final String docId = user.email!.split('@')[0];

            return StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(docId)
                  .snapshots(),
              builder: (context, userSnapshot) {
                // Nếu đang chờ dữ liệu Firestore
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                // Nếu KHÔNG có dữ liệu
                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  FirebaseAuth.instance.signOut();
                  return const LoginPage();
                }

                // Có dữ liệu rồi mới vào Home
                final data = userSnapshot.data!.data() as Map<String, dynamic>;
                return HomePage(
                  userName: data['name'] ?? "",
                  userId: data['id'] ?? docId,
                  selectedClass: data['class'] ?? "",
                  email: data['email'] ?? "",
                );
              },
            );
          }

          // 3. Nếu chưa đăng nhập
          return const LoginPage();
        },
      ),
    );
  }
}