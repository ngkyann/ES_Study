import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:esstudy/constants/var.dart';

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
  String _selectedLanguage = "Tiếng Việt";

  late String _currentUserName;
  late String _currentClass;

  Color _selectedColor = const Color(0xFF87CEFA);
  Color _customColor = const Color(0xFF87CEFA);
  bool _isCustomActive = false;

  @override
  void initState() {
    super.initState();
    _currentUserName = widget.userName;
    _currentClass = widget.selectedClass;
    _selectedLanguage = languageNotifier.value;

    _selectedColor = primaryColor;

    List<Color> defaultColors = [
      const Color(0xFF87CEFA),
      Colors.black,
      Colors.green,
      const Color.fromARGB(255, 255, 125, 165),
    ];

    bool isDefaultColor =
        defaultColors.any((c) => c.value == primaryColor.value);

    if (!isDefaultColor) {
      _customColor = primaryColor;
      _isCustomActive = true;
    } else {
      _isCustomActive = false;
    }
  }

  Future<void> _updateUserData(String field, String newValue) async {
    bool isVN = languageNotifier.value == "Tiếng Việt";
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({field: newValue});
      if (mounted) {
        _showSnackBar(
            context, isVN ? "Cập nhật thành công!" : "Update successful!");
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(context, isVN ? "Lỗi cập nhật: $e" : "Update error: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, child) {
        bool isVN = lang == "Tiếng Việt";

        return Scaffold(
          appBar: AppBar(
            title: Text(
              isVN ? "Cài đặt" : "Settings",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: primaryColor,
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
                  _buildSectionHeader(isVN
                      ? "ThôngConfig báo cá nhân"
                      : "Personal Information"),
                  _buildInfoTile(
                    Icons.person,
                    isVN ? "Họ và tên" : "Full Name",
                    _currentUserName,
                    onTap: () => _showEditNameDialog(context),
                  ),
                  _buildInfoTile(
                    Icons.school,
                    isVN ? "Lớp" : "Class",
                    isVN
                        ? _currentClass
                        : _currentClass.replaceFirst('Lớp', 'Class'),
                    onTap: () => _showEditClassDialog(context),
                  ),
                  _buildInfoTile(
                    Icons.email,
                    "Email",
                    widget.email,
                  ),
                  _buildPasswordTile(context, isVN),
                  const SizedBox(height: 10),
                  _buildSectionHeader(
                      isVN ? "Cài đặt giao diện" : "Appearance Settings"),
                  _buildThemeSelector(isVN),
                  _buildActionTile(
                    Icons.language,
                    isVN ? "Ngôn ngữ" : "Language",
                    _selectedLanguage == "Tiếng Việt"
                        ? "Tiếng Việt"
                        : "English",
                    onTap: () => _showLanguageDialog(context),
                  ),
                  const SizedBox(height: 10),
                  _buildSectionHeader(isVN ? "Ứng dụng" : "App"),
                  _buildActionTile(
                    Icons.privacy_tip,
                    isVN ? "Chính sách bảo mật" : "Privacy Policy",
                    "",
                    onTap: () => _showPrivacyPolicyDialog(context),
                  ),
                  _buildActionTile(
                    Icons.info,
                    isVN ? "Thông tin phiên bản" : "Version Info",
                    "V 1.2.1",
                    onTap: () => _showVersionInfoDialog(context),
                  ),
                  const SizedBox(height: 30),
                  _buildLogoutButton(context, isVN),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

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

  Widget _buildInfoTile(
    IconData icon,
    String title,
    String subtitle, {
    VoidCallback? onTap,
  }) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 1),
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
        trailing: onTap != null
            ? const Icon(Icons.edit, color: Colors.grey, size: 20)
            : null,
        onTap: onTap,
      ),
    );
  }

  Widget _buildPasswordTile(BuildContext context, bool isVN) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: Icon(Icons.lock, color: primaryColor),
        title: Text(isVN ? "Mật khẩu" : "Password",
            style: const TextStyle(fontSize: 15)),
        subtitle: const Text(
          "********",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        trailing: TextButton(
          onPressed: () => _showChangePasswordDialog(context),
          child: Text(
            isVN ? "Đổi mật khẩu" : "Change Password",
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

  void _showColorPickerDialog() {
    Color tempColor = _customColor;
    bool isVN = languageNotifier.value == "Tiếng Việt";

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: Text(isVN ? 'Chọn màu sắc' : 'Select Color'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  height: 50,
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    color: tempColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: tempColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      isVN ? "Màu hiển thị thử" : "Preview Color",
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(blurRadius: 2, color: Colors.black45)],
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: double.maxFinite,
                  height: MediaQuery.of(context).size.height * 0.4,
                  child: SingleChildScrollView(
                    child: ColorPicker(
                      pickerColor: tempColor,
                      onColorChanged: (color) {
                        setDialogState(() => tempColor = color);
                      },
                      pickerAreaHeightPercent: 0.7,
                      enableAlpha: false,
                      displayThumbColor: true,
                      pickerAreaBorderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(isVN ? 'Hủy' : 'Cancel',
                    style: const TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: tempColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  _applyNewColor(tempColor);
                  setState(() {
                    _customColor = tempColor;
                    _isCustomActive = true;
                  });
                  Navigator.pop(context);
                },
                child: Text(isVN ? 'Xong' : 'Done'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _applyNewColor(Color color) async {
    setState(() {
      _selectedColor = color;
      primaryColor = color;
      themeNotifier.value = color;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_color', color.value);
  }

  Widget _buildColorOption(Color color, {bool isRainbow = false}) {
    bool isSelected = (_selectedColor.value == color.value) && !isRainbow;
    if (isRainbow) isSelected = _isCustomActive;

    return GestureDetector(
      onTap: () {
        if (isRainbow) {
          _applyNewColor(_customColor);
          setState(() => _isCustomActive = true);
          _showColorPickerDialog();
        } else {
          _applyNewColor(color);
          setState(() => _isCustomActive = false);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? primaryColor : Colors.transparent,
            width: 2,
          ),
        ),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isRainbow
                ? const SweepGradient(
                    colors: [
                      Colors.red,
                      Colors.yellow,
                      Colors.green,
                      Colors.blue,
                      Colors.red,
                    ],
                  )
                : null,
            color: isRainbow ? null : color,
          ),
          child: isRainbow
              ? const Icon(Icons.add, size: 18, color: Colors.white)
              : (isSelected
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : null),
        ),
      ),
    );
  }

  Widget _buildThemeSelector(bool isVN) {
    return Container(
      color: Colors.white,
      margin: const EdgeInsets.only(bottom: 1),
      child: ListTile(
        leading: const Icon(Icons.color_lens, color: Colors.black54),
        title: Text(isVN ? "Màu sắc chủ đề" : "Theme Color",
            style: const TextStyle(fontSize: 15)),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            children: [
              _buildColorOption(const Color(0xFF87CEFA)),
              _buildColorOption(Colors.black),
              _buildColorOption(Colors.green),
              _buildColorOption(const Color.fromARGB(255, 255, 125, 165)),
              _buildColorOption(_customColor, isRainbow: true),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, bool isVN) {
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
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout),
            const SizedBox(width: 8),
            Text(
              isVN ? "Đăng xuất" : "Logout",
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // 🔥 ĐÃ SỬA LỖI ĐĂNG XUẤT TẠI ĐÂY
  void _showLogoutDialog(BuildContext context) {
    bool isVN = languageNotifier.value == "Tiếng Việt";

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.logout, color: Colors.redAccent, size: 28),
              const SizedBox(width: 10),
              Text(
                isVN ? "Đăng xuất" : "Logout",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          content: Text(
            isVN
                ? "Bạn có chắc chắn muốn đăng xuất khỏi tài khoản này không?"
                : "Are you sure you want to log out of this account?",
            style: const TextStyle(
                color: Colors.black54, fontSize: 15, height: 1.4),
          ),
          actionsPadding:
              const EdgeInsets.only(bottom: 15, right: 15, left: 15),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                isVN ? "Hủy" : "Cancel",
                style: const TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              ),
              onPressed: () async {
                try {
                  // Đóng hộp thoại popup
                  Navigator.pop(dialogContext);

                  // 1. Pop lùi lại về trang gốc (Trang do main.dart quản lý)
                  Navigator.of(context).popUntil((route) => route.isFirst);

                  // 2. Thực hiện đăng xuất -> main.dart sẽ bắt được sự kiện và tự cập nhật ra màn hình Đăng Nhập
                  await FirebaseAuth.instance.signOut();
                } catch (e) {
                  if (!context.mounted) return;
                  _showSnackBar(
                    context,
                    isVN ? "Lỗi khi đăng xuất: $e" : "Logout error: $e",
                  );
                }
              },
              child: Text(
                isVN ? "Đăng xuất" : "Logout",
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showEditNameDialog(BuildContext context) {
    bool isVN = languageNotifier.value == "Tiếng Việt";
    final TextEditingController controller = TextEditingController(
      text: _currentUserName,
    );
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(isVN ? "Đổi Họ và tên" : "Change Full Name"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: isVN ? "Nhập tên mới" : "Enter new name",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(isVN ? "Hủy" : "Cancel",
                style: const TextStyle(color: Colors.grey)),
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
              if (controller.text.trim().isNotEmpty) {
                String newName = controller.text.trim();
                await _updateUserData('name', newName);
                setState(() => _currentUserName = newName);
              }
              if (mounted) Navigator.pop(dialogContext);
            },
            child: Text(isVN ? "Lưu" : "Save"),
          ),
        ],
      ),
    );
  }

  void _showEditClassDialog(BuildContext context) {
    bool isVN = languageNotifier.value == "Tiếng Việt";
    String tempClass = _currentClass;
    final List<String> classes = List.generate(
      12,
      (index) => 'Lớp ${index + 1}',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            title: Text(isVN ? "Chọn Lớp" : "Select Class"),
            content: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              value: classes.contains(tempClass) ? tempClass : classes.first,
              items: classes.map((c) {
                String displayTxt = isVN ? c : c.replaceFirst('Lớp', 'Class');
                return DropdownMenuItem(value: c, child: Text(displayTxt));
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setDialogState(() => tempClass = val);
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(isVN ? "Hủy" : "Cancel",
                    style: const TextStyle(color: Colors.grey)),
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
                  await _updateUserData('class', tempClass);
                  setState(() => _currentClass = tempClass);
                  if (mounted) Navigator.pop(dialogContext);
                },
                child: Text(isVN ? "Lưu" : "Save"),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    bool isVN = languageNotifier.value == "Tiếng Việt";
    final List<String> options = ["Tiếng Việt", "Tiếng Anh"];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(Icons.language, color: primaryColor),
              const SizedBox(width: 10),
              Text(isVN ? "Chọn ngôn ngữ" : "Select Language"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((lang) {
              String displayName;
              if (lang == "Tiếng Việt") {
                displayName = isVN ? "Tiếng Việt" : "Vietnamese";
              } else {
                displayName = isVN ? "Tiếng Anh" : "English";
              }

              return RadioListTile<String>(
                title: Text(displayName),
                value: lang,
                groupValue: _selectedLanguage,
                activeColor: primaryColor,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) async {
                  if (value != null) {
                    setState(() => _selectedLanguage = value);

                    languageNotifier.value = value;
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('app_language', value);

                    if (context.mounted) Navigator.pop(dialogContext);
                  }
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showPrivacyPolicyDialog(BuildContext context) {
    bool isVN = languageNotifier.value == "Tiếng Việt";
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(Icons.privacy_tip, color: primaryColor),
              const SizedBox(width: 10),
              Text(isVN ? "Chính sách bảo mật" : "Privacy Policy"),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isVN ? "1. Thu thập dữ liệu" : "1. Data Collection",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  isVN
                      ? "Ứng dụng chỉ lưu trữ các thông tin cơ bản như họ tên, email, lớp và lịch sử học tập của bạn để phục vụ việc đồng bộ tiến trình.\n"
                      : "The app only stores basic information such as your name, email, class, and study history to synchronize your progress.\n",
                ),
                Text(
                  isVN ? "2. Sử dụng thông tin" : "2. Information Usage",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  isVN
                      ? "Dữ liệu của bạn được sử dụng để xếp hạng trên leaderboard, cập nhật thống kê và cá nhân hóa trải nghiệm trợ lý ảo AI.\n"
                      : "Your data is used to rank on the leaderboard, update statistics, and personalize the AI assistant experience.\n",
                ),
                Text(
                  isVN ? "3. Chia sẻ dữ liệu" : "3. Data Sharing",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  isVN
                      ? "Chúng tôi cam kết KHÔNG bán, cho thuê hay chia sẻ thông tin cá nhân của bạn cho bất kỳ bên thứ ba nào với mục đích thương mại.\n"
                      : "We are committed to NOT selling, renting, or sharing your personal information with any third party for commercial purposes.\n",
                ),
                Text(
                  isVN ? "4. Quyền của người dùng" : "4. User Rights",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  isVN
                      ? "Bạn hoàn toàn có quyền xóa tài khoản và mọi dữ liệu liên quan bất cứ lúc nào."
                      : "You have the full right to delete your account and all related data at any time.",
                ),
              ],
            ),
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
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(isVN ? "Đã hiểu" : "Understood"),
            ),
          ],
        );
      },
    );
  }

  void _showVersionInfoDialog(BuildContext context) {
    bool isVN = languageNotifier.value == "Tiếng Việt";
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
              Text(isVN ? "Thông tin ứng dụng" : "App Information"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isVN ? "Phiên bản: V 1.2.1" : "Version: V 1.2.1",
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                isVN
                    ? "Cập nhật lần cuối: 19/05/2026"
                    : "Last updated: 19/05/2026",
                style: TextStyle(color: Colors.grey.shade700, fontSize: 15),
              ),
              const SizedBox(height: 15),
              Text(
                isVN
                    ? "Sản phẩm được phát triển nhằm mang lại trải nghiệm học tập tốt nhất cho người dùng."
                    : "This product was developed to provide the best study experience for users.",
                style: const TextStyle(
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
              child: Text(isVN ? "Đóng" : "Close"),
            ),
          ],
        );
      },
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    bool isVN = languageNotifier.value == "Tiếng Việt";
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
              title: Text(isVN ? "Đổi mật khẩu" : "Change Password"),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: oldPasswordController,
                      obscureText: obscureOld,
                      decoration: InputDecoration(
                        labelText: isVN ? "Mật khẩu cũ" : "Old password",
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureOld
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () =>
                              setState(() => obscureOld = !obscureOld),
                        ),
                      ),
                    ),
                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: isVN ? "Mật khẩu mới" : "New password",
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNew
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () =>
                              setState(() => obscureNew = !obscureNew),
                        ),
                      ),
                    ),
                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText:
                            isVN ? "Xác nhận mật khẩu" : "Confirm password",
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirm
                                ? Icons.visibility_off
                                : Icons.visibility,
                          ),
                          onPressed: () =>
                              setState(() => obscureConfirm = !obscureConfirm),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    isVN ? "Hủy" : "Cancel",
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isLoading
                      ? null
                      : () async {
                          String oldP = oldPasswordController.text.trim();
                          String newP = newPasswordController.text.trim();
                          String confirmP =
                              confirmPasswordController.text.trim();

                          if (oldP.isEmpty ||
                              newP.isEmpty ||
                              confirmP.isEmpty) {
                            _showSnackBar(
                              context,
                              isVN
                                  ? "Vui lòng nhập đủ thông tin!"
                                  : "Please enter all information!",
                            );
                            return;
                          }
                          if (newP != confirmP) {
                            _showSnackBar(
                              context,
                              isVN
                                  ? "Mật khẩu xác nhận không khớp!"
                                  : "Passwords do not match!",
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
                                isVN
                                    ? "Đổi mật khẩu thành công!"
                                    : "Password changed successfully!",
                              );
                            }
                          } on FirebaseAuthException catch (e) {
                            String msg = "Error: ${e.message}";
                            if (e.code == 'wrong-password' ||
                                e.code == 'invalid-credential') {
                              msg = isVN
                                  ? "Mật khẩu cũ không đúng!"
                                  : "Incorrect old password!";
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
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(isVN ? "Xác nhận" : "Confirm"),
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
