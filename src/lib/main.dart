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
import 'package:esstudy/constants/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:esstudy/screens/note_page.dart';
import 'package:esstudy/constants/var.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  String savedLanguage = prefs.getString('app_language') ?? "Tiếng Việt";
  languageNotifier.value = savedLanguage;
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
                constraints: const BoxConstraints(maxWidth: 500),
                child: child,
              ),
            );
          },
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

                if (user.email == null) {
                  FirebaseAuth.instance.signOut();
                  return const LoginPage();
                }

                // --- 1. TÀI KHOẢN HỆ THỐNG CŨ (EMAIL ẢO) ---
                if (user.email!.endsWith('@esstudy.com')) {
                  final String docId = user.email!.split('@')[0];
                  return FutureBuilder<DocumentSnapshot>(
                    future: FirebaseFirestore.instance
                        .collection('users')
                        .doc(docId)
                        .get(),
                    builder: (context, userSnapshot) {
                      if (userSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Scaffold(
                            body: Center(child: CircularProgressIndicator()));
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
                        email: data['email'] ?? user.email!,
                      );
                    },
                  );
                }

                // --- 2. TÀI KHOẢN MỚI (EMAIL THẬT) ---
                if (!user.emailVerified) {
                  // Đã đăng nhập nhưng chưa kích hoạt -> Giữ lại ở trang Login
                  return const LoginPage();
                }

                return FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('users')
                      .where('email', isEqualTo: user.email)
                      .limit(1)
                      .get(),
                  builder: (context, querySnapshot) {
                    if (querySnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Scaffold(
                          body: Center(child: CircularProgressIndicator()));
                    }

                    if (querySnapshot.hasData &&
                        querySnapshot.data!.docs.isNotEmpty) {
                      final data = querySnapshot.data!.docs.first.data()
                          as Map<String, dynamic>;
                      final docId = querySnapshot.data!.docs.first.id;
                      return HomePage(
                        userName: data['name'] ?? "",
                        userId: data['id'] ?? docId,
                        selectedClass: data['class'] ?? "",
                        email: data['email'] ?? user.email!,
                      );
                    }

                    // Không tìm thấy trong Database thì đăng xuất
                    FirebaseAuth.instance.signOut();
                    return const LoginPage();
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
