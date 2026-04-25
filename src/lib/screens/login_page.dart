import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:esstudy/constants/colors.dart';
import 'package:esstudy/screens/home_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _obscureText = true;
  bool _isLogin = true;
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

  // --- LOGIC XỬ LÝ FIREBASE ---
  Future<void> _handleAuth() async {
    final String id = _idController.text.trim();
    final String password = _passwordController.text.trim();

    if (id.isEmpty || password.isEmpty) {
      _showMessage("Vui lòng nhập ID và Mật khẩu!");
      return;
    }

    // Hiệu ứng chờ (Loading)
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Tham chiếu đến collection "users" trên Firestore
      final usersRef = FirebaseFirestore.instance.collection('users');

      if (_isLogin) {
        // --- ĐĂNG NHẬP ---
        final doc = await usersRef.doc(id).get();

        if (doc.exists) {
          final userData = doc.data() as Map<String, dynamic>;
          if (userData['password'] == password) {
            Navigator.pop(context); // Tắt loading
            _showMessage("Chào mừng trở lại, ${userData['name']}!");

            _navigateToHome(
              userData['name'],
              userData['id'],
              userData['class'],
              userData['email'],
            );
          } else {
            Navigator.pop(context);
            _showMessage("Mật khẩu không chính xác!");
          }
        } else {
          Navigator.pop(context);
          _showMessage("Tài khoản ID này không tồn tại!");
        }
      } else {
        // --- ĐĂNG KÝ ---
        if (_nameController.text.isEmpty || _selectedClass == null) {
          Navigator.pop(context);
          _showMessage("Vui lòng điền đầy đủ thông tin đăng ký!");
          return;
        }

        final doc = await usersRef.doc(id).get();
        if (doc.exists) {
          Navigator.pop(context);
          _showMessage("ID này đã có người sử dụng!");
        } else {
          // Lưu dữ liệu lên Firestore
          await usersRef.doc(id).set({
            'name': _nameController.text.trim(),
            'id': id,
            'email': _emailController.text.trim(),
            'password': password, // Lưu ý: Thực tế nên mã hóa mật khẩu
            'class': _selectedClass,
            'points': 100,
            'createdAt': FieldValue.serverTimestamp(),
          });

          Navigator.pop(context);
          _showMessage("Đăng ký thành công!");
          setState(() => _isLogin = true); // Chuyển sang màn hình đăng nhập
        }
      }
    } catch (e) {
      Navigator.pop(context);
      _showMessage("Lỗi kết nối Firebase: $e");
    }
  }

  void _navigateToHome(String name, String id, String className, String email) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => HomePage(
          userName: name,
          userId: id,
          selectedClass: className,
          email: email,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Phần giao diện giữ nguyên cấu trúc cũ của bạn
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(24.0),
        alignment: Alignment.center,
        child: SingleChildScrollView(
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
                "ID người dùng (Ví dụ: @hocsinh123)",
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
                        _obscureText ? Icons.visibility_off : Icons.visibility,
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
                        .map((s) => DropdownMenuItem(value: s, child: Text(s)))
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
                    onPressed: _handleAuth, // Gọi hàm xử lý Firebase
                    child: Text(
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
