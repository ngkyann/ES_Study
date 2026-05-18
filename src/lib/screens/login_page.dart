import 'dart:ui'; // Dùng cho hiệu ứng Blur nếu cần
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:esstudy/constants/var.dart'; // 🔥 IMPORT BIẾN NGÔN NGỮ

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  // --- CÁC BIẾN TRẠNG THÁI UI & LOGIC ---
  bool _obscureText = true;
  bool _isLogin = true; // Trạng thái Đăng nhập / Đăng ký
  bool _isLoading = false;
  String? _selectedClass;

  // --- CONTROLLER CHO CÁC Ô NHẬP LIỆU ---
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _idFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

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
    _nameFocus.dispose();
    _idFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // Hàm hiển thị thông báo SnackBar chuẩn UI mới
  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: Colors.white,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 14),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.redAccent : Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(15),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // --- LOGIC XỬ LÝ QUÊN MẬT KHẨU (Chuẩn Firebase) ---
  Future<void> _showForgotPasswordDialog() async {
    final TextEditingController resetEmailController = TextEditingController();
    bool isSending = false;
    bool isVN = languageNotifier.value == "Tiếng Việt"; // 🔥 Lấy ngôn ngữ

    // Lấy Email hiện tại ở ô nhập nếu user đã gõ
    if (_idController.text.isNotEmpty && _idController.text.contains('@')) {
      resetEmailController.text = _idController.text;
    }

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.lock_reset, color: primaryColor, size: 28),
                  const SizedBox(width: 10),
                  Text(
                    isVN ? "Quên mật khẩu?" : "Forgot Password?",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isVN
                        ? "Nhập ID hoặc Email tài khoản của bạn. Chúng tôi sẽ gửi một liên kết an toàn để bạn đặt lại mật khẩu mới qua Email."
                        : "Enter your ID or Email. We will send a secure link to reset your password via Email.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.black54, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  _buildClassicTextField(
                    isVN ? "ID hoặc Email của bạn" : "Your ID or Email",
                    Icons.alternate_email,
                    resetEmailController,
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
              actionsPadding:
                  const EdgeInsets.only(bottom: 15, right: 15, left: 15),
              actionsAlignment: MainAxisAlignment.center,
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    isVN ? "Hủy" : "Cancel",
                    style: const TextStyle(
                        color: Colors.grey, fontWeight: FontWeight.w600),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shadowColor: primaryColor.withOpacity(0.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  onPressed: isSending
                      ? null
                      : () async {
                          final inputText = resetEmailController.text.trim();
                          if (inputText.isEmpty) {
                            _showMessage(isVN
                                ? "Vui lòng nhập ID/Email!"
                                : "Please enter ID/Email!");
                            return;
                          }

                          String targetEmail = inputText;
                          // Nếu user nhập ID (không chứa @), chuyển thành fakeEmail
                          if (!inputText.contains('@')) {
                            targetEmail = "$inputText@esstudy.com";
                          }

                          setStateDialog(() => isSending = true);
                          try {
                            await FirebaseAuth.instance
                                .sendPasswordResetEmail(email: targetEmail);
                            if (context.mounted) {
                              Navigator.pop(context); // Tắt popup
                              _showMessage(
                                  isVN
                                      ? "Đã gửi link khôi phục mật khẩu. Vui lòng kiểm tra hộp thư Email của bạn!"
                                      : "Password recovery link sent. Please check your Email inbox!",
                                  isError: false);
                            }
                          } catch (e) {
                            setStateDialog(() => isSending = false);
                            _showMessage(isVN
                                ? "Không tìm thấy tài khoản với thông tin này hoặc Lỗi hệ thống."
                                : "Account not found or System Error.");
                          }
                        },
                  child: isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          isVN ? "Gửi khôi phục" : "Send Recovery",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- LOGIC XỬ LÝ ĐĂNG NHẬP / ĐĂNG KÝ ---
  Future<void> _handleAuth() async {
    final String id = _idController.text.trim();
    final String password = _passwordController.text.trim();
    final String email = _emailController.text.trim();
    bool isVN = languageNotifier.value == "Tiếng Việt"; // 🔥 Lấy ngôn ngữ

    if (id.isEmpty || password.isEmpty) {
      _showMessage(isVN
          ? "Vui lòng nhập ID và Mật khẩu!"
          : "Please enter ID and Password!");
      return;
    }

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
      } else {
        // ================= ĐĂNG KÝ =================
        if (_nameController.text.isEmpty || _selectedClass == null) {
          setState(() => _isLoading = false);
          _showMessage(isVN
              ? "Vui lòng điền đầy đủ thông tin!"
              : "Please fill in all information!");
          return;
        }

        if (password.length < 6 && password.isNotEmpty) {
          setState(() => _isLoading = false);
          _showMessage(isVN
              ? "Mật khẩu phải có ít nhất 6 ký tự!"
              : "Password must be at least 6 characters!");
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
          'email': email,
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

        _showMessage(
            isVN
                ? "Đăng ký thành công! Vui lòng nhấn Đăng nhập."
                : "Registration successful! Please tap Login.",
            isError: false);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      String errorMessage = isVN
          ? "Đã xảy ra lỗi, vui lòng thử lại!"
          : "An error occurred, please try again!";

      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          errorMessage = isVN
              ? "ID hoặc mật khẩu không chính xác!"
              : "Incorrect ID or password!";
          break;
        case 'email-already-in-use':
          errorMessage = isVN
              ? "ID này đã được sử dụng. Vui lòng chọn ID khác!"
              : "This ID is already in use. Please choose another one!";
          break;
        case 'weak-password':
          errorMessage = isVN ? "Mật khẩu quá yếu!" : "Password is too weak!";
          break;
        case 'invalid-email':
          errorMessage = isVN ? "ID không hợp lệ!" : "Invalid ID!";
          break;
        case 'too-many-requests':
          errorMessage = isVN
              ? "Quá nhiều lần thử sai. Thử lại sau!"
              : "Too many failed attempts. Try again later!";
          break;
        default:
          errorMessage = isVN ? "Lỗi: ${e.message}" : "Error: ${e.message}";
      }

      _showMessage(errorMessage);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(isVN ? "Lỗi không xác định: $e" : "Unknown error: $e");
    }
  }

  // =========================================================================
  // --- VẼ LẠI UI (BUILD) ---
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

    // 🔥 BỌC TÒAN BỘ GIAO DIỆN VỚI ValueListenableBuilder
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, child) {
        bool isVN = lang == "Tiếng Việt";

        return Scaffold(
          backgroundColor: const Color(0xFFFBFDFF),
          body: Stack(
            children: [
              Positioned(
                top: -50,
                left: -50,
                child: CircleAvatar(
                  radius: 80,
                  backgroundColor: primaryColor.withOpacity(0.05),
                ),
              ),
              Positioned(
                bottom: -screenWidth * 0.3,
                right: -screenWidth * 0.2,
                child: Icon(Icons.school,
                    size: screenWidth * 0.8,
                    color: primaryColor.withOpacity(0.03)),
              ),
              RefreshIndicator(
                color: primaryColor,
                backgroundColor: Colors.white,
                displacement: 60,
                onRefresh: () async {
                  await Future.delayed(const Duration(milliseconds: 800));
                  if (mounted) setState(() {});
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 30.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: screenHeight),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: screenHeight * 0.12),

                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: primaryColor.withOpacity(0.15),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.menu_book_rounded,
                              size: 70,
                              color: primaryColor,
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // 🔥 DỊCH TIÊU ĐỀ
                        Center(
                          child: Text(
                            _isLogin
                                ? (isVN ? "ĐĂNG NHẬP" : "LOGIN")
                                : (isVN ? "ĐĂNG KÝ" : "REGISTER"),
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: primaryColor,
                            ),
                          ),
                        ),

                        const SizedBox(height: 35),

                        if (!_isLogin) ...[
                          _buildClassicTextField(
                            isVN ? "Họ và tên" : "Full Name",
                            Icons.person_outline_rounded,
                            _nameController,
                            focusNode: _nameFocus,
                          ),
                          const SizedBox(height: 18),
                        ],

                        _buildClassicTextField(
                          isVN ? "ID người dùng" : "User ID",
                          Icons.alternate_email_rounded,
                          _idController,
                          focusNode: _idFocus,
                          keyboardType: TextInputType.visiblePassword,
                          textInputAction: _isLogin
                              ? TextInputAction.done
                              : TextInputAction.next,
                          onSubmitted: (_) => _isLogin ? _handleAuth() : null,
                        ),

                        const SizedBox(height: 18),

                        if (!_isLogin) ...[
                          _buildClassicTextField(
                            isVN ? "Email/Gmail" : "Email/Gmail",
                            Icons.email_outlined,
                            _emailController,
                            focusNode: _emailFocus,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 18),
                        ],

                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: _passwordFocus.hasFocus
                                    ? primaryColor.withOpacity(0.10)
                                    : Colors.black.withOpacity(0.03),
                                blurRadius: _passwordFocus.hasFocus ? 16 : 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: TextField(
                            controller: _passwordController,
                            focusNode: _passwordFocus,
                            obscureText: _obscureText,
                            textInputAction: _isLogin
                                ? TextInputAction.done
                                : TextInputAction.next,
                            onSubmitted: (_) => _isLogin ? _handleAuth() : null,
                            style: const TextStyle(
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                            decoration: InputDecoration(
                              labelText:
                                  isVN ? "Mật khẩu" : "Password", // 🔥 Dịch
                              floatingLabelBehavior: FloatingLabelBehavior.auto,
                              labelStyle: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 15,
                              ),
                              floatingLabelStyle: TextStyle(
                                color: primaryColor,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              prefixIcon: Padding(
                                padding: const EdgeInsets.only(
                                  left: 10,
                                  right: 5,
                                ),
                                child: Icon(
                                  Icons.lock_outline_rounded,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 22),
                              filled: true,
                              fillColor: Colors.white,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(30),
                                borderSide: BorderSide.none,
                              ),
                              suffixIcon: Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: IconButton(
                                  icon: Icon(
                                    _obscureText
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                    color: Colors.grey.shade400,
                                  ),
                                  onPressed: () => setState(
                                    () => _obscureText = !_obscureText,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        if (_isLogin)
                          Align(
                            alignment: Alignment.centerRight,
                            child: Container(
                              margin: const EdgeInsets.only(top: 10, right: 10),
                              child: InkWell(
                                onTap: _showForgotPasswordDialog,
                                borderRadius: BorderRadius.circular(10),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 5, vertical: 2),
                                  child: Text(
                                    isVN
                                        ? 'Quên mật khẩu?'
                                        : 'Forgot password?', // 🔥 Dịch
                                    style: const TextStyle(
                                      color: Color(0xFFA6E0FF),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 18),

                        if (!_isLogin) ...[
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: DropdownButtonFormField<String>(
                              decoration: InputDecoration(
                                hintText: isVN
                                    ? 'Chọn lớp'
                                    : 'Select class', // 🔥 Dịch
                                hintStyle: TextStyle(
                                    color: Colors.grey.shade400, fontSize: 15),
                                prefixIcon: Padding(
                                  padding:
                                      const EdgeInsets.only(left: 10, right: 5),
                                  child: Icon(Icons.school_outlined,
                                      color: Colors.grey.shade500),
                                ),
                                contentPadding:
                                    const EdgeInsets.symmetric(vertical: 18),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(30),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              icon: Padding(
                                padding: const EdgeInsets.only(right: 15),
                                child: Icon(Icons.keyboard_arrow_down_rounded,
                                    color: Colors.grey.shade400),
                              ),
                              style: const TextStyle(
                                  fontSize: 15, color: Colors.black87),
                              value: _selectedClass,
                              // 🔥 ĐÃ CẬP NHẬT: Dịch Lớp -> Class khi hiển thị
                              items: _classes.map((s) {
                                String displayTxt =
                                    isVN ? s : s.replaceFirst('Lớp', 'Class');
                                return DropdownMenuItem(
                                    value: s, child: Text(displayTxt));
                              }).toList(),
                              onChanged: (val) =>
                                  setState(() => _selectedClass = val),
                            ),
                          ),
                          const SizedBox(height: 35),
                        ],

                        if (_isLogin) const SizedBox(height: 35),

                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: primaryColor.withOpacity(0.35),
                                blurRadius: 15,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(30),
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
                                      _isLogin
                                          ? (isVN ? "ĐĂNG NHẬP" : "LOGIN")
                                          : (isVN ? "ĐĂNG KÝ" : "REGISTER"),
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 30),

                        Center(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _isLogin = !_isLogin;
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              child: Text(
                                _isLogin
                                    ? (isVN
                                        ? "Chưa có tài khoản? Đăng ký ngay"
                                        : "Don't have an account? Register now")
                                    : (isVN
                                        ? "Đã có tài khoản? Đăng nhập"
                                        : "Already have an account? Login"),
                                style: TextStyle(
                                  fontSize: 15,
                                  color: primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),

                        SizedBox(height: screenHeight * 0.05),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildClassicTextField(
    String label,
    IconData icon,
    TextEditingController? controller, {
    FocusNode? focusNode,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction? textInputAction,
    ValueChanged<String>? onSubmitted,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: (focusNode?.hasFocus ?? false)
                ? primaryColor.withOpacity(0.10)
                : Colors.black.withOpacity(0.03),
            blurRadius: (focusNode?.hasFocus ?? false) ? 16 : 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: keyboardType,
        textInputAction: textInputAction ?? TextInputAction.next,
        onSubmitted: onSubmitted,
        style: const TextStyle(
          fontSize: 15,
          color: Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: label,
          floatingLabelBehavior: FloatingLabelBehavior.auto,
          labelStyle: TextStyle(
            color: Colors.grey.shade400,
            fontSize: 15,
          ),
          floatingLabelStyle: TextStyle(
            color: primaryColor,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(
              left: 10,
              right: 5,
            ),
            child: Icon(
              icon,
              color: Colors.grey.shade500,
              size: 22,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 22),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
