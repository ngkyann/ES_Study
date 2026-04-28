import 'package:flutter/material.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  final String userName;
  final String selectedClass;
  final String userId;
  final String email;

  const SettingsPage({
    super.key,
    required this.userName,
    required this.selectedClass,
    required this.userId,
    required this.email,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Cài đặt",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor, // Sẽ tự động đổi màu khi state thay đổi
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        color: Colors.grey.shade50,
        child: RefreshIndicator(
          color: primaryColor,
          backgroundColor: Colors.white,
          onRefresh: () async {
            await Future.delayed(const Duration(seconds: 1));
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 10),
            children: [
              _buildSectionHeader("Thông tin cá nhân"),
              _buildInfoTile(Icons.person, "Họ và tên", widget.userName),
              _buildInfoTile(Icons.school, "Lớp", widget.selectedClass),
              _buildInfoTile(Icons.email, "Email", widget.email),
              _buildPasswordTile(context),
              const SizedBox(height: 10),

              _buildSectionHeader("Cài đặt giao diện"),
              _buildThemeSelector(), // Giao diện chọn màu
              _buildActionTile(Icons.language, "Ngôn ngữ", "Tiếng Việt"),
              const SizedBox(height: 10),

              _buildSectionHeader("Ứng dụng"),
              _buildActionTile(Icons.privacy_tip, "Chính sách bảo mật", ""),
              _buildActionTile(
                Icons.info,
                "Thông tin phiên bản",
                "Beta 0.5.0",
                onTap: () => _showVersionInfoDialog(context),
              ),
              const SizedBox(height: 30),
              _buildLogoutButton(context),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS ---
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 15, 20, 10),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String subtitle) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: primaryColor),
        title: Text(title, style: const TextStyle(fontSize: 15)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordTile(BuildContext context) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: Icon(Icons.lock, color: primaryColor),
        title: const Text("Mật khẩu", style: TextStyle(fontSize: 15)),
        subtitle: const Text(
          "********",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        trailing: TextButton(
          onPressed: () => _showChangePasswordDialog(context),
          child: Text(
            "Đổi mật khẩu",
            style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile(
    IconData icon,
    String title,
    String trailingText, {
    VoidCallback? onTap,
  }) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 1),
      child: ListTile(
        leading: Icon(icon, color: Colors.black54),
        title: Text(title, style: const TextStyle(fontSize: 15)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              trailingText,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  // 🔥 ĐÃ SỬA: Bảng chọn màu
  Widget _buildThemeSelector() {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 1),
      child: ListTile(
        leading: const Icon(Icons.color_lens, color: Colors.black54),
        title: const Text("Màu sắc chủ đề", style: TextStyle(fontSize: 15)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            children: [
              _buildColorCircle(const Color(0xFF87CEFA)), // Màu xanh mặc định
              _buildColorCircle(Colors.green),
              _buildColorCircle(Colors.orange),
              _buildColorCircle(Colors.purple),
            ],
          ),
        ),
      ),
    );
  }

  // 🔥 ĐÃ SỬA: Logic bấm chọn đổi màu
  Widget _buildColorCircle(Color color) {
    bool isSelected = primaryColor == color;

    return GestureDetector(
      onTap: () async {
        setState(() {
          primaryColor = color;
          themeNotifier.value = color;
        });
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('theme_color', color.value);

        debugPrint("Đã lưu màu: ${color.value}");
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(color: Colors.black45, width: 2)
              : null,
        ),
        child: isSelected
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : null,
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade50,
          foregroundColor: Colors.red,
          padding: const EdgeInsets.symmetric(vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
            side: const BorderSide(color: Colors.red, width: 1),
          ),
        ),
        onPressed: () => _showLogoutDialog(context),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.logout),
            SizedBox(width: 8),
            Text(
              "Đăng xuất",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // --- CÁC HỘP THOẠI DIALOG BÊN DƯỚI GIỮ NGUYÊN (Version, Logout, ChangePassword) ---
  void _showVersionInfoDialog(BuildContext context) {
    final DateTime now = DateTime.now();
    final String todayStr =
        "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}";

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(Icons.info_outline, color: primaryColor, size: 28),
              const SizedBox(width: 10),
              const Text("Thông tin ứng dụng"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Phiên bản: Beta 1.0",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "Cập nhật lần cuối: $todayStr",
                style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
              ),
              const SizedBox(height: 15),
              const Text(
                "Sản phẩm được phát triển nhằm mang lại trải nghiệm học tập tốt nhất cho người dùng.",
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text("Đóng"),
            ),
          ],
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Xác nhận"),
        content: const Text("Bạn muốn đăng xuất?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Huỷ"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              Navigator.of(context).popUntil((route) => route.isFirst);
              await FirebaseAuth.instance.signOut();
            },
            child: const Text("Đăng xuất"),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool obscureOld = true;
    bool obscureNew = true;
    bool obscureConfirm = true;

    showDialog(
      context: context,
      builder: (dialogContext) {
        bool isLoading = false;
        return StatefulBuilder(
          builder: (stateContext, setState) {
            return AlertDialog(
              title: const Text("Đổi mật khẩu"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: oldPasswordController,
                      obscureText: obscureOld,
                      decoration: InputDecoration(
                        labelText: "Mật khẩu cũ",
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureOld
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() => obscureOld = !obscureOld);
                          },
                        ),
                      ),
                    ),
                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: "Mật khẩu mới",
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNew
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() => obscureNew = !obscureNew);
                          },
                        ),
                      ),
                    ),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: "Xác nhận mật khẩu",
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirm
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () {
                            setState(() => obscureConfirm = !obscureConfirm);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text("Hủy"),
                ),
                ElevatedButton(
                  onPressed: isLoading
                      ? null
                      : () async {
                          String oldP = oldPasswordController.text.trim();
                          String newP = newPasswordController.text.trim();
                          String confirmP = confirmPasswordController.text
                              .trim();

                          if (oldP.isEmpty ||
                              newP.isEmpty ||
                              confirmP.isEmpty) {
                            _showSnackBar(
                              context,
                              "Vui lòng nhập đủ thông tin!",
                            );
                            return;
                          }
                          if (newP != confirmP) {
                            _showSnackBar(
                              context,
                              "Mật khẩu xác nhận không khớp!",
                            );
                            return;
                          }

                          setState(() => isLoading = true);
                          try {
                            User? user = FirebaseAuth.instance.currentUser;
                            if (user != null && user.email != null) {
                              AuthCredential credential =
                                  EmailAuthProvider.credential(
                                    email: user.email!,
                                    password: oldP,
                                  );
                              await user.reauthenticateWithCredential(
                                credential,
                              );
                              await user.updatePassword(newP);

                              if (!dialogContext.mounted) return;
                              Navigator.pop(dialogContext);

                              if (!context.mounted) return;
                              _showSnackBar(
                                context,
                                "Đổi mật khẩu thành công!",
                              );
                            }
                          } on FirebaseAuthException catch (e) {
                            String msg = "Lỗi: ${e.message}";
                            if (e.code == 'wrong-password' ||
                                e.code == 'invalid-credential') {
                              msg = "Mật khẩu cũ không đúng!";
                            }
                            if (!context.mounted) return;
                            _showSnackBar(context, msg);
                          } finally {
                            if (stateContext.mounted) {
                              setState(() => isLoading = false);
                            }
                          }
                        },
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("Xác nhận"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
