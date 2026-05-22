import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:esstudy/constants/var.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with TickerProviderStateMixin {
  bool _obscureText = true;
  bool _isLogin = true;
  bool _isLoading = false;
  String? _selectedClass;

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
  void deactivate() {
    FocusScope.of(context).unfocus();
    super.deactivate();
  }

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
        duration: const Duration(seconds: 4),
      ),
    );
  }

  // ====================================================================
  // LOGIC 1: QUÊN MẬT KHẨU (HỖ TRỢ ID HOẶC EMAIL)
  // ====================================================================
  Future<void> _showForgotPasswordDialog() async {
    final TextEditingController resetController = TextEditingController();
    bool isSending = false;
    bool isVN = languageNotifier.value == "Tiếng Việt";

    if (_idController.text.isNotEmpty) {
      resetController.text = _idController.text;
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
                        ? "Nhập ID hoặc Email tài khoản của bạn. Chúng tôi sẽ gửi một liên kết an toàn để bạn đặt lại mật khẩu mới."
                        : "Enter your account ID or Email. We will send a secure link to reset your password.",
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.black54, fontSize: 14, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  _buildClassicTextField(
                    isVN ? "ID hoặc Email của bạn" : "Your ID or Email",
                    Icons.badge_outlined,
                    resetController,
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
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                  ),
                  onPressed: isSending
                      ? null
                      : () async {
                          final targetInput = resetController.text.trim();
                          if (targetInput.isEmpty) {
                            _showMessage(isVN
                                ? "Vui lòng nhập thông tin!"
                                : "Please enter information!");
                            return;
                          }

                          setStateDialog(() => isSending = true);
                          String targetEmail = targetInput;

                          try {
                            if (!targetInput.contains('@')) {
                              final doc = await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(targetInput)
                                  .get();
                              if (!mounted) return;
                              if (doc.exists) {
                                targetEmail = doc.get('email');
                              } else {
                                setStateDialog(() => isSending = false);
                                _showMessage(isVN
                                    ? "Không tìm thấy tài khoản với ID này!"
                                    : "Account not found with this ID!");
                                return;
                              }
                            }

                            await FirebaseAuth.instance
                                .sendPasswordResetEmail(email: targetEmail);
                            if (!mounted) return;

                            if (context.mounted) {
                              if (Navigator.canPop(context)) {
                                Navigator.pop(context);
                              }
                              _showMessage(
                                  isVN
                                      ? "Đã gửi link khôi phục. Vui lòng kiểm tra hộp thư Email của bạn!"
                                      : "Password recovery link sent. Please check your Email inbox!",
                                  isError: false);
                            }
                          } catch (e) {
                            setStateDialog(() => isSending = false);
                            _showMessage(isVN
                                ? "Lỗi gửi thư khôi phục hoặc tài khoản không tồn tại."
                                : "Error sending reset email or account doesn't exist.");
                          }
                        },
                  child: isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2))
                      : Text(
                          isVN ? "Gửi thư xác nhận" : "Send Recovery",
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
    if (!mounted) return;
  }

  // ====================================================================
  // LOGIC 2: HỘP THOẠI HỎI GỬI LẠI EMAIL KÍCH HOẠT (KHI ĐĂNG NHẬP)
  // ====================================================================
  void _showResendVerificationDialog(User unverifiedUser, FirebaseApp tempApp) {
    bool isVN = languageNotifier.value == "Tiếng Việt";
    bool isSending = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              const SizedBox(width: 8),
              Text(isVN ? "Chưa kích hoạt" : "Not Activated"),
            ],
          ),
          content: Text(
            isVN
                ? "Tài khoản của bạn chưa được xác nhận Email. Bạn có muốn gửi lại thư xác nhận vào hòm thư không?"
                : "Your account email is not verified. Do you want to resend the verification email?",
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
                await tempApp.delete();
                if (!mounted) return;
                if (mounted) setState(() => _isLoading = false);
              },
              child: Text(isVN ? "Đóng" : "Close",
                  style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
              onPressed: isSending
                  ? null
                  : () async {
                      setStateDialog(() => isSending = true);
                      try {
                        await unverifiedUser.sendEmailVerification();
                        if (!mounted) return;
                        if (context.mounted) {
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }
                          _showMessage(
                            isVN
                                ? "Đã gửi lại thư xác nhận! Hãy kiểm tra hòm thư."
                                : "Verification email resent! Check your inbox.",
                            isError: false,
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          _showMessage(
                              "Lỗi gửi thư: Vui lòng đợi 1 lát rồi thử lại.");
                        }
                      }
                      await tempApp.delete();
                      if (!mounted) return;
                      if (mounted) setState(() => _isLoading = false);
                    },
              child: isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : Text(isVN ? "Gửi lại" : "Resend",
                      style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ====================================================================
  // LOGIC 3: MÀN HÌNH CHỜ XÁC NHẬN EMAIL ĐĂNG KÝ (TỰ ĐỘNG VÀO APP)
  // ====================================================================
  void _showVerificationWaitingDialog(
      FirebaseApp tempApp, String email, String password) {
    bool isVN = languageNotifier.value == "Tiếng Việt";
    Timer? checkTimer;
    bool isChecking = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            // Tự động quét trạng thái kích hoạt mỗi 3 giây
            checkTimer ??=
                Timer.periodic(const Duration(seconds: 3), (timer) async {
              try {
                final auth = FirebaseAuth.instanceFor(app: tempApp);
                try {
                  await auth.currentUser
                      ?.reload()
                      .timeout(const Duration(seconds: 8));
                } catch (_) {}
                if (!mounted) return;

                if (auth.currentUser?.emailVerified == true) {
                  timer.cancel();
                  if (context.mounted) if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                  await tempApp.delete();
                  if (!mounted) return;

                  // Tiến hành đăng nhập vào luồng chính (Main Auth) -> main.dart sẽ bắt tín hiệu và TỰ CHUYỂN TRANG
                  await FirebaseAuth.instance.signInWithEmailAndPassword(
                      email: email, password: password);
                  if (!mounted) return;
                }
              } catch (e) {
                // Ignore errors like network drops
              }
            });

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Column(
                children: [
                  Icon(Icons.mark_email_unread_outlined,
                      size: 50, color: primaryColor),
                  const SizedBox(height: 10),
                  Text(isVN ? "Xác thực Email" : "Email Verification",
                      textAlign: TextAlign.center),
                ],
              ),
              content: Text(
                isVN
                    ? "Chúng tôi đã gửi thư kích hoạt đến:\n$email\n\nVui lòng kiểm tra hộp thư (hoặc mục Spam). Nhấn vào liên kết để xác nhận, hệ thống sẽ tự động đăng nhập ngay lập tức!"
                    : "We have sent an activation email to:\n$email\n\nPlease check your inbox (or Spam folder). Click the link to verify, the system will auto-login immediately!",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, height: 1.5),
              ),
              actionsAlignment: MainAxisAlignment.center,
              actionsOverflowDirection: VerticalDirection.down,
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: isChecking
                        ? null
                        : () async {
                            setStateDialog(() => isChecking = true);
                            try {
                              final auth =
                                  FirebaseAuth.instanceFor(app: tempApp);
                              await auth.currentUser?.reload();
                              if (!mounted) return;

                              if (auth.currentUser?.emailVerified == true) {
                                checkTimer?.cancel();
                                if (ctx.mounted) Navigator.pop(ctx);
                                await tempApp.delete();
                                if (!mounted) return;

                                // Đăng nhập luồng chính -> main.dart sẽ tự động bắt tín hiệu
                                await FirebaseAuth.instance
                                    .signInWithEmailAndPassword(
                                        email: email, password: password);
                                if (!mounted) return;
                              } else {
                                setStateDialog(() => isChecking = false);
                                _showMessage(isVN
                                    ? "Bạn chưa xác nhận Email! Hãy kiểm tra hòm thư."
                                    : "Email not verified yet! Check your inbox.");
                              }
                            } catch (e) {
                              setStateDialog(() => isChecking = false);
                              _showMessage("Lỗi: Vui lòng thử lại.");
                            }
                          },
                    child: isChecking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2))
                        : Text(isVN ? "Tôi đã xác nhận" : "I have verified",
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold)),
                  ),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () async {
                        checkTimer?.cancel();
                        Navigator.pop(ctx);
                        await tempApp.delete();
                        if (!mounted) return;
                        setState(() {
                          _isLogin = true;
                          _passwordController.clear();
                        });
                      },
                      child: Text(isVN ? "Để sau" : "Later",
                          style: const TextStyle(color: Colors.grey)),
                    ),
                    TextButton(
                      onPressed: () async {
                        try {
                          final auth = FirebaseAuth.instanceFor(app: tempApp);
                          await auth.currentUser?.sendEmailVerification();
                          if (!mounted) return;
                          _showMessage(
                            isVN
                                ? "Đã gửi lại thư xác nhận mới!"
                                : "Resent a new verification email!",
                            isError: false,
                          );
                        } catch (e) {
                          _showMessage(isVN
                              ? "Vui lòng đợi 1 lát rồi gửi lại."
                              : "Please wait a moment before resending.");
                        }
                      },
                      child: Text(isVN ? "Gửi lại mã" : "Resend code",
                          style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    ).then((_) {
      checkTimer?.cancel();
    });
  }

  // ====================================================================
  // LOGIC 4: XỬ LÝ ĐĂNG NHẬP / ĐĂNG KÝ CHÍNH
  // ====================================================================
  Future<void> _handleAuth() async {
    if (_isLoading) return;
    final String id = _idController.text.trim();
    final String password = _passwordController.text.trim();
    bool isVN = languageNotifier.value == "Tiếng Việt";

    if (id.isEmpty || password.isEmpty) {
      _showMessage(isVN
          ? "Vui lòng nhập ID và Mật khẩu!"
          : "Please enter ID and Password!");
      return;
    }

    setState(() => _isLoading = true);

    try {
      if (_isLogin) {
        // ================= ĐĂNG NHẬP BẰNG ID =================
        final userDoc =
            await FirebaseFirestore.instance.collection('users').doc(id).get();
        if (!mounted) return;
        if (!userDoc.exists) {
          setState(() => _isLoading = false);
          _showMessage(isVN
              ? "ID người dùng không tồn tại!"
              : "User ID does not exist!");
          return;
        }

        final data = userDoc.data() as Map<String, dynamic>;
        String realEmail = "$id@esstudy.com"; // Support nick cũ
        if (data.containsKey('email') && data['email'].toString().isNotEmpty) {
          realEmail = data['email'];
        }

        // Bổ sung các trường khởi tạo nếu chưa có (khi login tài khoản cũ)
        Map<String, dynamic> updates = {};
        if (!data.containsKey('activeEffect')) updates['activeEffect'] = '';
        if (!data.containsKey('ownedEffects')) updates['ownedEffects'] = [];
        if (updates.isNotEmpty) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(id)
              .update(updates);
          if (!mounted) return;
        }

        // Kiểm tra ngầm để chặn trường hợp chưa kích hoạt
        final String tempAppName =
            'tempLogin_${DateTime.now().millisecondsSinceEpoch}';
        final FirebaseApp tempApp = await Firebase.initializeApp(
            name: tempAppName, options: Firebase.app().options);
        if (!mounted) return;

        try {
          final tempAuth = FirebaseAuth.instanceFor(app: tempApp);
          UserCredential tempCred;

          try {
            tempCred = await tempAuth.signInWithEmailAndPassword(
                email: realEmail, password: password);
            if (!mounted) return;
          } on FirebaseAuthException catch (fallbackErr) {
            if (fallbackErr.code == 'user-not-found' ||
                fallbackErr.code == 'invalid-credential' ||
                fallbackErr.code == 'wrong-password') {
              try {
                tempCred = await tempAuth.signInWithEmailAndPassword(
                    email: "$id@esstudy.com", password: password);
                if (!mounted) return;
                realEmail = "$id@esstudy.com";
              } catch (_) {
                rethrow; // Ném lỗi sai pass
              }
            } else {
              rethrow;
            }
          }

          if (!tempCred.user!.emailVerified &&
              !tempCred.user!.email!.endsWith('@esstudy.com')) {
            _showResendVerificationDialog(tempCred.user!, tempApp);
            return;
          }

          // KHI ĐÃ HỢP LỆ -> XÓA TEMP VÀ LOGIN BẰNG MAIN AUTH
          // Không cần tắt Loading hay pushRoute ở đây, main.dart sẽ tự động điều hướng hoàn hảo.
          await tempApp.delete();
          if (!mounted) return;
          await FirebaseAuth.instance
              .signInWithEmailAndPassword(email: realEmail, password: password);
          if (!mounted) return;
        } catch (e) {
          await tempApp.delete();
          if (!mounted) return;
          rethrow;
        }
      } else {
        // ================= ĐĂNG KÝ VỚI EMAIL THẬT =================
        final String name = _nameController.text.trim();
        final String email = _emailController.text.trim();

        if (name.isEmpty || email.isEmpty || _selectedClass == null) {
          setState(() => _isLoading = false);
          _showMessage(isVN
              ? "Vui lòng điền đầy đủ thông tin!"
              : "Please fill in all information!");
          return;
        }

        if (password.length < 6) {
          setState(() => _isLoading = false);
          _showMessage(isVN
              ? "Mật khẩu phải có ít nhất 6 ký tự!"
              : "Password must be at least 6 characters!");
          return;
        }

        final idCheckDoc =
            await FirebaseFirestore.instance.collection('users').doc(id).get();
        if (!mounted) return;
        if (idCheckDoc.exists) {
          setState(() => _isLoading = false);
          _showMessage(isVN
              ? "ID này đã có người sử dụng. Vui lòng chọn ID khác!"
              : "This ID is already taken. Please choose another one!");
          return;
        }

        final String tempAppName =
            'tempRegister_${DateTime.now().millisecondsSinceEpoch}';
        final FirebaseApp tempApp = await Firebase.initializeApp(
          name: tempAppName,
          options: Firebase.app().options,
        );
        if (!mounted) return;

        try {
          UserCredential cred = await FirebaseAuth.instanceFor(app: tempApp)
              .createUserWithEmailAndPassword(
            email: email,
            password: password,
          );
          if (!mounted) return;

          await cred.user!.sendEmailVerification();
          if (!mounted) return;

          // 🔥 ĐÃ ĐỒNG BỘ: Bổ sung các trường khởi tạo liên quan đến Shop, Streak, và Bạn bè
          await FirebaseFirestore.instance.collection('users').doc(id).set({
            'name': name,
            'id': id,
            'email': email,
            'class': _selectedClass,
            'points': 100,
            'coin': 15000,
            'streakCount': 0,
            'avatarUrl': '',
            'bannerUrl': '',
            'ownedEffects': [],
            'activeEffect': '',
            'friends': [],
            'friendRequests': [],
            'createdAt': FieldValue.serverTimestamp(),
          });
          if (!mounted) return;
          setState(() => _isLoading = false);

          // Bật màn hình chờ kích hoạt
          _showVerificationWaitingDialog(tempApp, email, password);
        } catch (e) {
          await tempApp.delete();
          if (!mounted) return;
          rethrow;
        }
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
              : "Incorrect ID or Password!";
          break;
        case 'email-already-in-use':
          errorMessage = isVN
              ? "Email này đã được đăng ký cho 1 ID khác!"
              : "This Email is already associated with another ID!";
          break;
        case 'invalid-email':
          errorMessage =
              isVN ? "Định dạng Email không hợp lệ!" : "Invalid Email format!";
          break;
        case 'too-many-requests':
          errorMessage = isVN
              ? "Thử lại quá nhiều. Vui lòng quay lại sau!"
              : "Too many attempts. Try again later!";
          break;
        default:
          errorMessage = isVN ? "Lỗi: ${e.message}" : "Error: ${e.message}";
      }
      _showMessage(errorMessage);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showMessage(isVN ? "Lỗi hệ thống: $e" : "System error: $e");
    }
  }

  // ====================================================================
  // GIAO DIỆN CHÍNH
  // ====================================================================
  @override
  Widget build(BuildContext context) {
    final double screenHeight = MediaQuery.of(context).size.height;
    final double screenWidth = MediaQuery.of(context).size.width;

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
                  await Future.delayed(const Duration(milliseconds: 250));
                  if (!mounted) return;
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

                        // [1] Chỉ hiện Hỏi tên khi Đăng Ký
                        if (!_isLogin) ...[
                          _buildClassicTextField(
                            isVN ? "Họ và tên" : "Full Name",
                            Icons.person_outline_rounded,
                            _nameController,
                            focusNode: _nameFocus,
                          ),
                          const SizedBox(height: 18),
                        ],

                        // [2] Ô ID luôn hiện (Đăng nhập thì xài ID, Đăng ký thì tự tạo ID)
                        _buildClassicTextField(
                          isVN ? "ID người dùng" : "User ID",
                          Icons.badge_outlined,
                          _idController,
                          focusNode: _idFocus,
                          keyboardType: TextInputType.text,
                        ),
                        const SizedBox(height: 18),

                        // [3] Chỉ hiện Email thật để kích hoạt khi Đăng ký
                        if (!_isLogin) ...[
                          _buildClassicTextField(
                            isVN
                                ? "Email (để nhận thư kích hoạt)"
                                : "Email (for verification)",
                            Icons.email_outlined,
                            _emailController,
                            focusNode: _emailFocus,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 18),
                        ],

                        // [4] Ô Mật khẩu luôn hiện
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
                              labelText: isVN ? "Mật khẩu" : "Password",
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

                        // Chỉ hiện quên mật khẩu ở trang Đăng Nhập
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
                                        : 'Forgot password?',
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

                        // [5] Chỉ hiện nút Chọn Lớp khi Đăng Ký
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
                                hintText: isVN ? 'Chọn lớp' : 'Select class',
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
                              onPressed: _isLoading
                                  ? null
                                  : () async {
                                      FocusScope.of(context).unfocus();
                                      await _handleAuth();
                                    },
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
