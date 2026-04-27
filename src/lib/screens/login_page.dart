import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _obscureText = true;
  bool _isLogin = true;
  bool _isLoading = false; // 🔥 ĐÃ THÊM: Biến quản lý vòng xoay loading
  String? _selectedClass;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final List<String> _classes = List.generate(
    12,
    (index) => 'Lớp ${index + 1}',
  );

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  // --- LOGIC XỬ LÝ FIREBASE ĐÃ SỬA LỖI ĐỨNG MÁY ---
  // --- LOGIC XỬ LÝ FIREBASE ĐÃ THÊM THÔNG BÁO LỖI CHI TIẾT ---
  Future<void> _handleAuth() async {
    final String id = _idController.text.trim();
    final String password = _passwordController.text.trim();
    final String email = _emailController.text.trim();

    // 1. Bắt lỗi để trống ngay từ đầu
    if (id.isEmpty || password.isEmpty) {
      _showMessage("Vui lòng nhập ID và Mật khẩu!");
      return;
    }

    // 🔥 Bật loading
    setState(() {
      _isLoading = true;
    });

    try {
      final auth = FirebaseAuth.instance;
      // Tạo email giả từ ID để dùng cho hệ thống Auth
      final fakeEmail = "$id@esstudy.com";

      if (_isLogin) {
        // ================= ĐĂNG NHẬP =================
        await auth.signInWithEmailAndPassword(
          email: fakeEmail,
          password: password,
        );
        // Không cần làm gì thêm, main.dart sẽ tự chuyển tab
      } else {
        // ================= ĐĂNG KÝ =================
        if (_nameController.text.isEmpty || _selectedClass == null) {
          setState(() => _isLoading = false);
          _showMessage("Vui lòng điền đầy đủ thông tin (Họ tên, Lớp)!");
          return;
        }

        // Bắt lỗi mật khẩu ngắn trước khi gọi lên Firebase cho mượt
        if (password.length < 6) {
          setState(() => _isLoading = false);
          _showMessage("Mật khẩu phải có ít nhất 6 ký tự!");
          return;
        }

        // Tạo App ngầm để đăng ký
        final FirebaseApp tempApp = await Firebase.initializeApp(
          name: 'tempRegister',
          options: Firebase.app().options,
        );

        try {
          await FirebaseAuth.instanceFor(
            app: tempApp,
          ).createUserWithEmailAndPassword(
            email: fakeEmail,
            password: password,
          );
        } finally {
          await tempApp.delete();
        }

        // Lưu vào Firestore
        await FirebaseFirestore.instance.collection('users').doc(id).set({
          'name': _nameController.text.trim(),
          'id': id,
          'email': email, // Email thật (nếu có)
          'class': _selectedClass,
          'points': 100,
          'createdAt': FieldValue.serverTimestamp(),
        });

        if (!mounted) return;

        setState(() {
          _isLoading = false;
          _isLogin = true;
          _idController.text = id;
          _passwordController.text = password;
        });

        _showMessage("Đăng ký thành công! Vui lòng nhấn Đăng nhập.");
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      // 🔥 BỘ LỌC THÔNG BÁO LỖI FIREBASE CHUẨN XÁC
      String errorMessage = "Đã xảy ra lỗi, vui lòng thử lại!";

      switch (e.code) {
        case 'invalid-credential': // Lỗi mới của Firebase khi sai ID hoặc Pass
        case 'wrong-password': // Lỗi cũ (phòng hờ)
        case 'user-not-found': // Lỗi cũ (phòng hờ)
          errorMessage = "ID hoặc mật khẩu không chính xác!";
          break;
        case 'email-already-in-use':
          errorMessage = "ID này đã được sử dụng. Vui lòng chọn ID khác!";
          break;
        case 'weak-password':
          errorMessage = "Mật khẩu quá yếu! Vui lòng đặt mật khẩu dài hơn.";
          break;
        case 'invalid-email':
          errorMessage =
              "ID không hợp lệ (không được chứa khoảng trắng hoặc ký tự đặc biệt)!";
          break;
        case 'network-request-failed':
          errorMessage = "Lỗi kết nối mạng. Vui lòng kiểm tra lại Internet!";
          break;
        case 'too-many-requests':
          errorMessage = "Bạn đã nhập sai quá nhiều lần. Vui lòng thử lại sau!";
          break;
        default:
          errorMessage = "Lỗi hệ thống: ${e.message}";
      }

      _showMessage(errorMessage);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage("Lỗi không xác định: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(24.0),
        alignment: Alignment.center,
        // 🔥 ĐÃ THÊM: RefreshIndicator để vuốt tải lại trang
        child: RefreshIndicator(
          color: primaryColor,
          backgroundColor: Colors.white,
          onRefresh: () async {
            // Giả lập thời gian load 1 giây
            await Future.delayed(const Duration(seconds: 1));
            setState(() {}); // Làm mới giao diện
          },
          child: SingleChildScrollView(
            // 🔥 BẮT BUỘC: Thêm physics để luôn vuốt được dù nội dung ngắn
            physics: const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                const Icon(Icons.auto_stories, size: 80, color: primaryColor),
                const SizedBox(height: 10),
                Text(
                  _isLogin ? "ĐĂNG NHẬP" : "ĐĂNG KÝ",
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 40),

                if (!_isLogin) ...[
                  _buildTextField("Họ và tên", Icons.person, _nameController),
                  const SizedBox(height: 16),
                ],

                _buildTextField(
                  "ID người dùng",
                  Icons.alternate_email,
                  _idController,
                ),
                const SizedBox(height: 16),

                if (!_isLogin) ...[
                  _buildTextField("Email/Gmail", Icons.email, _emailController),
                  const SizedBox(height: 16),
                ],

                Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _passwordController,
                    obscureText: _obscureText,
                    decoration: InputDecoration(
                      labelText: 'Mật khẩu',
                      prefixIcon: const Icon(Icons.lock),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureText
                              ? Icons.visibility_off
                              : Icons.visibility,
                        ),
                        onPressed: () =>
                            setState(() => _obscureText = !_obscureText),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                if (!_isLogin) ...[
                  Container(
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: 'Chọn lớp',
                        prefixIcon: const Icon(Icons.school),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      value: _selectedClass,
                      items: _classes
                          .map(
                            (s) => DropdownMenuItem(value: s, child: Text(s)),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _selectedClass = val),
                    ),
                  ),
                  const SizedBox(height: 30),
                ],

                if (_isLogin) const SizedBox(height: 14),

                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.4),
                        blurRadius: 15,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      onPressed: _isLoading ? null : _handleAuth,
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2.5,
                              ),
                            )
                          : Text(
                              _isLogin ? "ĐĂNG NHẬP" : "ĐĂNG KÝ",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                TextButton(
                  onPressed: () {
                    setState(() {
                      _isLogin = !_isLogin;
                    });
                  },
                  child: Text(
                    _isLogin
                        ? "Chưa có tài khoản? Đăng ký ngay"
                        : "Đã có tài khoản? Đăng nhập",
                    style: const TextStyle(
                      fontSize: 16,
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    IconData icon,
    TextEditingController? controller,
  ) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
