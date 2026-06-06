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
import 'package:esstudy/constants/var.dart';
import 'package:esstudy/screens/note_page.dart';

final GlobalKey<NavigatorState> globalNavigatorKey =
    GlobalKey<NavigatorState>();

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
          navigatorKey: globalNavigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'ES Study',
          theme: ThemeData(primaryColor: currentPrimaryColor),
          builder: (context, child) {
            return StreamBuilder<User?>(
              stream: FirebaseAuth.instance.authStateChanges(),
              builder: (context, authSnapshot) {
                bool isLoggedIn = false;
                if (authSnapshot.hasData && authSnapshot.data != null) {
                  final user = authSnapshot.data!;
                  if (user.email != null) {
                    if (user.email!.endsWith('@esstudy.com') ||
                        user.emailVerified) {
                      isLoggedIn = true;
                    }
                  }
                }

                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 500),
                    child: Stack(
                      children: [
                        if (child != null) child,

                        // 🔥 Thay thế bằng Widget Bong Bóng toàn cục tự custom
                        if (isLoggedIn)
                          GlobalDraggableBubble(userId: authSnapshot.data!.uid),
                      ],
                    ),
                  ),
                );
              },
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

                if (!user.emailVerified) {
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

// ============================================================================
// 🔥 WIDGET ĐỘC LẬP: BONG BÓNG GHI CHÚ KÉO THẢ TOÀN CỤC
// ============================================================================
class GlobalDraggableBubble extends StatefulWidget {
  final String userId;
  const GlobalDraggableBubble({super.key, required this.userId});

  @override
  State<GlobalDraggableBubble> createState() => _GlobalDraggableBubbleState();
}

class _GlobalDraggableBubbleState extends State<GlobalDraggableBubble> {
  // Dùng biến nullable để thiết lập vị trí mặc định lần đầu khởi động
  double? bubbleX;
  double? bubbleY;

  // 🔥 THÊM MỚI: Biến kiểm soát trạng thái hiển thị của bong bóng
  bool _isVisible = true;

  @override
  Widget build(BuildContext context) {
    // 🔥 THÊM MỚI: Nếu đang mở Note thì ẩn bong bóng hoàn toàn
    if (!_isVisible) return const SizedBox.shrink();

    final screenSize = MediaQuery.of(context).size;

    // Tính toán chiều rộng thực tế của khung App (bị giới hạn tối đa 500 bởi ConstrainedBox)
    final double appWidth = screenSize.width > 500 ? 500 : screenSize.width;

    // Thiết lập vị trí mặc định (Góc dưới bên phải)
    if (bubbleX == null || bubbleX! > appWidth) {
      bubbleX = appWidth - 75;
    }
    if (bubbleY == null || bubbleY! > screenSize.height) {
      bubbleY = screenSize.height - 180;
    }

    return Positioned(
      left: bubbleX,
      top: bubbleY,
      child: GestureDetector(
        onPanUpdate: (details) {
          setState(() {
            bubbleX = (bubbleX! + details.delta.dx);
            bubbleY = (bubbleY! + details.delta.dy);

            // Chặn biên an toàn để bong bóng không bay ra ngoài appWidth (500)
            if (bubbleX! < 0) bubbleX = 0;
            if (bubbleX! > appWidth - 55) bubbleX = appWidth - 55;
            if (bubbleY! < 40) bubbleY = 40;
            if (bubbleY! > screenSize.height - 140) {
              bubbleY = screenSize.height - 140;
            }
          });
        },
        // 🔥 ĐÃ SỬA: Chuyển hàm thành async để chờ hộp thoại đóng lại
        onTap: () async {
          // 1. Ẩn bong bóng đi trước khi mở Note
          setState(() {
            _isVisible = false;
          });

          // 2. Dùng await để code "đứng chờ" ở đây cho đến khi người dùng tắt QuickNoteDialog
          await showDialog(
            context: globalNavigatorKey.currentContext!,
            barrierDismissible: true,
            builder: (context) => QuickNoteDialog(
              userId: widget.userId,
              isVN: languageNotifier.value == "Tiếng Việt",
            ),
          );

          // 3. Sau khi hộp thoại Note bị tắt, khôi phục lại bong bóng
          if (mounted) {
            setState(() {
              _isVisible = true;
            });
          }
        },
        child: Material(
          elevation: 5,
          shape: const CircleBorder(),
          color: Colors.transparent,
          child: Container(
            width: 55,
            height: 55,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [primaryColor, primaryColor.withOpacity(0.85)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(
              Icons.sticky_note_2_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
        ),
      ),
    );
  }
}
