import 'package:flutter/material.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:esstudy/screens/login_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ES Study',
      debugShowCheckedModeBanner: false,

      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
        scaffoldBackgroundColor: const Color(0xFFF5F9FF),
      ),

      home: const LoginPage(),
    );
  }
}
