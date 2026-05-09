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
// Đã gỡ import ai_assistant_fab.dart
import 'package:esstudy/constants/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  int? savedColorValue = prefs.getInt('theme_color');

  if (savedColorValue != null) {
    primaryColor = Color(savedColorValue);
    themeNotifier.value = primaryColor;
  }
  tz.initializeTimeZones();
  vn = tz.getLocation('Asia/Ho_Chi_Minh');
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: themeNotifier,
      builder: (context, currentPrimaryColor, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'ES Study',
          theme: ThemeData(primaryColor: currentPrimaryColor),
          builder: (context, child) {
            return Center(
              child: ConstrainedBox(
                // Giới hạn chiều rộng tối đa là 500 pixel (chuẩn kích thước điện thoại to)
                constraints: const BoxConstraints(maxWidth: 500),
                child: child,
              ),
            );
          },
          // --- ĐÃ DỌN DẸP builder: Không còn Stack và FAB ở đây nữa ---
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
                    if (userSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
                      FirebaseAuth.instance.signOut();
                      return const LoginPage();
                    }

                    final data =
                        userSnapshot.data!.data() as Map<String, dynamic>;
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
      },
    );
  }
}
