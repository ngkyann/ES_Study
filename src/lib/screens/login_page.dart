import 'dart:ui'; // Dùng cho hiệu ứng Blur nếu cần
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
                  const Text(
                    "Quên mật khẩu?",
                    style: TextStyle(
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
                  const Text(
                    "Nhập ID hoặc Email tài khoản của bạn. Chúng tôi sẽ gửi một liên kết an toàn để bạn đặt lại mật khẩu mới qua Email.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.black54, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  _buildClassicTextField(
                    "ID hoặc Email của bạn",
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
                  child: const Text(
                    "Hủy",
                    style: TextStyle(
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
                            _showMessage("Vui lòng nhập ID/Email!");
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
                                  "Đã gửi link khôi phục mật khẩu. Vui lòng kiểm tra hộp thư Email của bạn!",
                                  isError: false);
                            }
                          } catch (e) {
                            setStateDialog(() => isSending = false);
                            _showMessage(
                                "Không tìm thấy tài khoản với thông tin này hoặc Lỗi hệ thống.");
                          }
                        },
                  child: isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : const Text(
                          "Gửi khôi phục",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- 🔥 GIỮ NGUYÊN HOÀN TOÀN LOGIC XỬ LÝ FIREBASE CŨ CỦA BẠN ---
  Future<void> _handleAuth() async {
    final String id = _idController.text.trim();
    final String password = _passwordController.text.trim();
    final String email = _emailController.text.trim();

    if (id.isEmpty || password.isEmpty) {
      _showMessage("Vui lòng nhập ID và Mật khẩu!");
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
          _showMessage("Vui lòng điền đầy đủ thông tin!");
          return;
        }

        if (password.length < 6 && password.isNotEmpty) {
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

        _showMessage("Đăng ký thành công! Vui lòng nhấn Đăng nhập.",
            isError: false);
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      String errorMessage = "Đã xảy ra lỗi, vui lòng thử lại!";

      switch (e.code) {
        case 'invalid-credential':
        case 'wrong-password':
        case 'user-not-found':
          errorMessage = "ID hoặc mật khẩu không chính xác!";
          break;
        case 'email-already-in-use':
          errorMessage = "ID này đã được sử dụng. Vui lòng chọn ID khác!";
          break;
        case 'weak-password':
          errorMessage = "Mật khẩu quá yếu!";
          break;
        case 'invalid-email':
          errorMessage = "ID không hợp lệ!";
          break;
        case 'too-many-requests':
          errorMessage = "Quá nhiều lần thử sai. Thử lại sau!";
          break;
        default:
          errorMessage = "Lỗi: ${e.message}";
      }

      _showMessage(errorMessage);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage("Lỗi không xác định: $e");
    }
  }

  // =========================================================================
  // --- 🔥 VẼ LẠI UI (BUILD) THEO PHONG CÁCH "UI CŨ" + CHÈN QUÊN MẬT KHẨU ---
  // =========================================================================
  @override
  Widget build(BuildContext context) {
    // Lấy kích thước màn hình để tính toán tỷ lệ bố cục
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor:
          const Color(0xFFFBFDFF), // Màu nền trắng xanh nhẹ nhàng của UI cũ
      body: Stack(
        children: [
          // 1. Phông nền trang trí (Optional - có thể thêm gradient ẩn phía sau)
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
                size: screenWidth * 0.8, color: primaryColor.withOpacity(0.03)),
          ),

          // 2. Nội dung chính nằm trong RefreshIndicator & ScrollView
          RefreshIndicator(
            color: primaryColor,
            backgroundColor: Colors.white,
            displacement: 60, // Đẩy vị trí vòng xoay xuống chút
            onRefresh: () async {
              await Future.delayed(const Duration(milliseconds: 800));
              if (mounted) setState(() {});
            },
            child: SingleChildScrollView(
              physics:
                  const AlwaysScrollableScrollPhysics(), // Đảm bảo luôn vuốt được
              padding: const EdgeInsets.symmetric(horizontal: 30.0),
              child: ConstrainedBox(
                // Đảm bảo Column con luôn có chiều cao ít nhất bằng màn hình
                constraints: BoxConstraints(minHeight: screenHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment
                      .center, // Căn giữa Column theo chiều dọc
                  crossAxisAlignment: CrossAxisAlignment
                      .stretch, // Dãn đều Column theo chiều ngang
                  children: [
                    // --- 🔥 THAY ĐỔI  bố cục HEADER THEO UI CŨ ---
                    SizedBox(
                        height: screenHeight * 0.12), // Khoảng trống trên cùng

                    // ICON LOGO: Dùng Book Icon của UI cũ (Hình 2)
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
                          Icons
                              .menu_book_rounded, // Icon sách nghệ thuật hơn Icons.auto_stories
                          size: 70,
                          color: primaryColor, // Màu xanh nhạt của UI cũ
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),

                    // TIÊU ĐỀ "ĐĂNG NHẬP" / "ĐĂNG KÝ" (UI Cũ - Hình 2)
                    Center(
                      child: Text(
                        _isLogin ? "ĐĂNG NHẬP" : "ĐĂNG KÝ",
                        style: TextStyle(
                          fontSize: 26, // Kích thước chữ chuẩn UI cũ
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2, // Giãn chữ chút cho sang
                          color: primaryColor, // Màu xanh nhạt
                        ),
                      ),
                    ),

                    const SizedBox(
                        height: 35), // Khoảng trống lớn trước Form nhập liệu

                    // --- FORM NHẬP LIỆU (VẼ THEO STYLE UI CŨ - BO GÓC LỚN, SHADOW NHẸ) ---

                    if (!_isLogin) ...[
                      // Trường Họ và Tên (Chỉ hiện khi Đăng ký)
                      _buildClassicTextField(
                        "Họ và tên",
                        Icons.person_outline_rounded,
                        _nameController,
                        focusNode: _nameFocus,
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Trường ID NGƯỜI DÙNG (Style UI Cũ - Dùng Icon @ chuẩn hơn alternate_email)
                    _buildClassicTextField(
                      "ID người dùng",
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
                      // Trường Email/Gmail (Chỉ hiện khi Đăng ký)
                      _buildClassicTextField(
                        "Email/Gmail",
                        Icons.email_outlined,
                        _emailController,
                        focusNode: _emailFocus,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 18),
                    ],

                    // Trường MẬT KHẨU
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
                          labelText: "Mật khẩu",
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

                    // 🔥 --- THÊM: NÚT QUÊN MẬT KHẨU --- 🔥
                    // Đặt ngay dưới ô Mật khẩu, căn phải chuẩn Ảnh 1 bạn gửi
                    if (_isLogin)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          margin: const EdgeInsets.only(top: 10, right: 10),
                          child: InkWell(
                            onTap: _showForgotPasswordDialog,
                            borderRadius: BorderRadius.circular(10),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              child: Text(
                                'Quên mật khẩu?',
                                style: TextStyle(
                                  color: Color(
                                      0xFFA6E0FF), // Màu xanh rất nhạt như Ảnh 1 bạn gửi
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    const SizedBox(height: 18), // Khoảng trống nhỏ trước ô Lớp

                    if (!_isLogin) ...[
                      // Trường chọn lớp (Chỉ hiện khi Đăng ký - Style UI Cũ)
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
                            hintText: 'Chọn lớp',
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
                          items: _classes
                              .map(
                                (s) =>
                                    DropdownMenuItem(value: s, child: Text(s)),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedClass = val),
                        ),
                      ),
                      const SizedBox(
                          height:
                              35), // Khoảng trống lớn trước nút Login khi Đăng ký
                    ],

                    // Tăng thêm khoảng cách nếu ở màn hình Đăng nhập
                    if (_isLogin) const SizedBox(height: 35),

                    // --- NÚT ĐĂNG NHẬP / ĐĂNG KÝ (STYLE UI CŨ - BO GÓC LỚN, MÀU XANH NHẠT) ---
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(
                            30), // Bo góc lớn 30 giống UI cũ
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(
                                0.35), // Shadow màu xanh lan tỏa giống UI cũ
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 56, // Chiều cao nút lớn chuẩn UI cũ
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                primaryColor, // Màu xanh nhạt chuẩn UI cũ
                            foregroundColor: Colors.white,
                            elevation:
                                0, // Tắt elevation mặc định vì đã dùng BoxShadow
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
                                  _isLogin ? "ĐĂNG NHẬP" : "ĐĂNG KÝ",
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.1,
                                  ),
                                ),
                        ),
                      ),
                    ),

                    const SizedBox(
                        height: 30), // Khoảng trống trước TextButton chuyển đổi

                    // --- NÚT CHUYỂN ĐỔI CHẾ ĐỘ ĐĂNG KÝ / ĐĂNG NHẬP (STYLE UI CŨ - MÀU XANH) ---
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
                                ? "Chưa có tài khoản? Đăng ký ngay"
                                : "Đã có tài khoản? Đăng nhập",
                            style: TextStyle(
                              fontSize: 15,
                              color: primaryColor, // Màu xanh nhạt UI cũ
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(
                        height: screenHeight * 0.05), // Khoảng trống dưới cùng
                  ],
                ),
              ),
            ),
          ),

          // 3. Hiển thị Loading Overlay nếu cần (Tùy chọn cho UX chuyên nghiệp hơn)
          // if (_isLoading)
          //   Container(
          //     color: Colors.black.withOpacity(0.3),
          //     child: Center(child: CircularProgressIndicator(color: primaryColor)),
          //   ),
        ],
      ),
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
