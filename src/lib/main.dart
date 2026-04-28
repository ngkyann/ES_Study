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
      
      // --- PHẦN FIX BUILDER ---
      builder: (context, child) {
        return Scaffold(
          // QUAN TRỌNG: Ngăn bàn phím đẩy toàn bộ các trang bên dưới lên
          resizeToAvoidBottomInset: false, 
          body: Stack(
            children: [
              child!, 
              // Bong bóng AI sẽ luôn nằm trên cùng của mọi Page
              const AIAssistantFAB(), 
            ],
          ),
        );
      },
      // -------------------------

      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, authSnapshot) {
          if (authSnapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (authSnapshot.hasData && authSnapshot.data != null) {
            final user = authSnapshot.data!;

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
                if (userSnapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                  // Tránh gọi signOut trực tiếp trong build, nhưng tạm chấp nhận với logic hiện tại của bạn
                  Future.microtask(() => FirebaseAuth.instance.signOut());
                  return const LoginPage();
                }

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

          return const LoginPage();
        },
      ),
    );
  }
}