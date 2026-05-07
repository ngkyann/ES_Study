import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

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

  // 🔥 ĐÃ THÊM: Biến State cục bộ để cập nhật giao diện ngay khi sửa xong
  late String _currentUserName;
  late String _currentClass;
  // 1. Khai báo các biến trạng thái trong State của ông
  Color _selectedColor = const Color(0xFF87CEFA); // Màu đang dùng hiện tại
  Color _customColor = const Color(
    0xFF87CEFA,
  ); // Màu người dùng tự chọn (mặc định xanh nhạt)
  bool _isCustomActive = false; // Kiểm tra xem có đang dùng màu custom không

  @override
  void initState() {
    super.initState();
    _currentUserName = widget.userName;
    _currentClass = widget.selectedClass;
  }

  // --- HÀM CẬP NHẬT FIREBASE ---
  Future<void> _updateUserData(String field, String newValue) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .update({field: newValue});
      if (mounted) {
        _showSnackBar(context, "Cập nhật thành công!");
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar(context, "Lỗi cập nhật: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Cài đặt",
          style: TextStyle(fontWeight: FontWeight.bold),
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
              _buildSectionHeader("Thông tin cá nhân"),
              // 🔥 ĐÃ SỬA: Thêm sự kiện onTap để sửa Tên
              _buildInfoTile(
                Icons.person,
                "Họ và tên",
                _currentUserName,
                onTap: () => _showEditNameDialog(context),
              ),
              // 🔥 ĐÃ SỬA: Thêm sự kiện onTap để sửa Lớp
              _buildInfoTile(
                Icons.school,
                "Lớp",
                _currentClass,
                onTap: () => _showEditClassDialog(context),
              ),
              _buildInfoTile(
                Icons.email,
                "Email",
                widget.email,
              ), // Email thường không cho sửa
              _buildPasswordTile(context),
              const SizedBox(height: 10),

              _buildSectionHeader("Cài đặt giao diện"),
              _buildThemeSelector(),
              _buildActionTile(
                Icons.language,
                "Ngôn ngữ",
                _selectedLanguage,
                onTap: () => _showLanguageDialog(context),
              ),
              const SizedBox(height: 10),

              _buildSectionHeader("Ứng dụng"),
              _buildActionTile(
                Icons.privacy_tip,
                "Chính sách bảo mật",
                "",
                onTap: () => _showPrivacyPolicyDialog(context),
              ),
              _buildActionTile(
                Icons.info,
                "Thông tin phiên bản",
                "Beta 0.8.0",
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

  // 🔥 ĐÃ SỬA: Thêm onTap và Icon chỉnh sửa
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

  void _showColorPickerDialog() {
    // Tạo một biến tạm để lưu màu trong lúc đang kéo (không trigger setState toàn app)
    Color tempColor = _customColor;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        // Dùng StatefulBuilder để chỉ update nội dung trong Dialog
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ), // Bo góc Dialog
            title: const Text('Chọn màu sắc'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // --- KHUNG TEST MÀU (PREVIEW BOX) ---
                Container(
                  width: double.infinity,
                  height: 50,
                  margin: const EdgeInsets.only(bottom: 15),
                  decoration: BoxDecoration(
                    color: tempColor,
                    borderRadius: BorderRadius.circular(
                      12,
                    ), // Bo góc khung test
                    border: Border.all(color: Colors.grey.shade300),
                    boxShadow: [
                      BoxShadow(
                        color: tempColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      "Màu hiển thị thử",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [Shadow(blurRadius: 2, color: Colors.black45)],
                      ),
                    ),
                  ),
                ),

                // --- BẢNG CHỌN MÀU ---
                SizedBox(
                  width: double.maxFinite,
                  height: MediaQuery.of(context).size.height * 0.4,
                  child: SingleChildScrollView(
                    child: ColorPicker(
                      pickerColor: tempColor,
                      onColorChanged: (color) {
                        // Chỉ cập nhật trạng thái bên trong Dialog, không gây lag App ngoài
                        setDialogState(() => tempColor = color);
                      },
                      pickerAreaHeightPercent: 0.7,
                      enableAlpha: false,
                      displayThumbColor: true,
                      // Bo góc cho vùng chọn màu (tùy thuộc vào phiên bản thư viện)
                      pickerAreaBorderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hủy', style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      tempColor, // Nút "Xong" có màu đang chọn luôn
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () {
                  // CHỈ ĐỒNG BỘ KHI CLICK "XONG"
                  _applyNewColor(tempColor);
                  setState(() {
                    _customColor = tempColor;
                    _isCustomActive = true;
                  });
                  Navigator.pop(context);
                },
                child: const Text('Xong'),
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
      primaryColor = color; // Biến global của ông

      // Đã bỏ dòng if (themeNotifier != null) đi vì nó luôn đúng
      themeNotifier.value =
          color; // Báo cho ValueListenableBuilder đổi màu toàn app
    });

    // Lưu vào máy để lần sau mở app vẫn còn
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_color', color.value);
  }

  Widget _buildColorOption(Color color, {bool isRainbow = false}) {
    // Check xem màu này có đang được chọn không
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
            color: isSelected
                ? primaryColor
                : Colors.transparent, // Dùng primaryColor làm viền
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
              _buildColorOption(const Color(0xFF87CEFA)), // Xanh dương nhạt
              _buildColorOption(Colors.black), // Đen
              _buildColorOption(Colors.green), // Xanh lá
              _buildColorOption(_customColor, isRainbow: true), // Nút cầu vồng
            ],
          ),
        ),
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

  // --- CÁC HỘP THOẠI ĐỔI THÔNG TIN CÁ NHÂN ---

  // 🔥 ĐÃ THÊM: Hộp thoại sửa tên
  void _showEditNameDialog(BuildContext context) {
    final TextEditingController controller = TextEditingController(
      text: _currentUserName,
    );
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Đổi Họ và tên"),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: "Nhập tên mới",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
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
            child: const Text("Lưu"),
          ),
        ],
      ),
    );
  }

  // 🔥 ĐÃ THÊM: Hộp thoại chọn Lớp giống hệt trang Đăng ký
  void _showEditClassDialog(BuildContext context) {
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
            title: const Text("Chọn Lớp"),
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
              items: classes
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (val) {
                if (val != null) {
                  setDialogState(() => tempClass = val);
                }
              },
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
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
                child: const Text("Lưu"),
              ),
            ],
          );
        },
      ),
    );
  }

  // --- CÁC HỘP THOẠI KHÁC ---
  void _showLanguageDialog(BuildContext context) {
    final List<String> options = [
      "Tiếng Việt",
      "Tiếng Kinh",
      "Tiếng mẹ đẻ",
      "Vietnamese",
    ];
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
              const Text("Chọn ngôn ngữ"),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: options.map((lang) {
              return RadioListTile<String>(
                title: Text(lang),
                value: lang,
                groupValue: _selectedLanguage,
                activeColor: primaryColor,
                contentPadding: EdgeInsets.zero,
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedLanguage = value);
                    Navigator.pop(dialogContext);
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
              const Text("Chính sách bảo mật"),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  "1. Thu thập dữ liệu",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  "Ứng dụng chỉ lưu trữ các thông tin cơ bản như Họ tên, Email, Lớp và Lịch sử học tập của bạn để phục vụ việc đồng bộ tiến trình.\n",
                ),
                Text(
                  "2. Sử dụng thông tin",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  "Dữ liệu của bạn được sử dụng để xếp hạng trên Leaderboard, cập nhật Thống kê và cá nhân hóa trải nghiệm Trợ lý ảo AI.\n",
                ),
                Text(
                  "3. Chia sẻ dữ liệu",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  "Chúng tôi cam kết KHÔNG bán, cho thuê hay chia sẻ thông tin cá nhân của bạn cho bất kỳ bên thứ ba nào với mục đích thương mại.\n",
                ),
                Text(
                  "4. Quyền của người dùng",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  "Bạn hoàn toàn có quyền xóa tài khoản và mọi dữ liệu liên quan bất cứ lúc nào.",
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
              child: const Text("Đã hiểu"),
            ),
          ],
        );
      },
    );
  }

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
                "Phiên bản: Beta 0.8.0",
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
            child: const Text("Huỷ", style: TextStyle(color: Colors.grey)),
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
                          onPressed: () =>
                              setState(() => obscureOld = !obscureOld),
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
                          onPressed: () =>
                              setState(() => obscureNew = !obscureNew),
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
                  child: const Text(
                    "Hủy",
                    style: TextStyle(color: Colors.grey),
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
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
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
