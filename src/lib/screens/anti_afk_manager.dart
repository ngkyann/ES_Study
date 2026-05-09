import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'dart:io' show exit;

class AntiAFKManager {
  static final AntiAFKManager _instance = AntiAFKManager._internal();
  factory AntiAFKManager() => _instance;
  AntiAFKManager._internal();

  OverlayEntry? _overlayEntry;
  Timer? _spawnTimer;
  Timer? _afkTimeoutTimer;
  bool _isShowing = false;

  // Cấu hình thời gian
  final int _minInterval = 1; // Xuất hiện sau ít nhất 10 phút
  final int _maxInterval = 2; // Xuất hiện tối đa sau 25 phút
  final int _secondsToClick = 30; // 15 giây để "vuốt ve" Capybara

  void start(BuildContext context) {
    _stopTimers();
    _scheduleNextSpawn(context);
  }

  void _scheduleNextSpawn(BuildContext context) {
    final nextIn = Random().nextInt(_maxInterval - _minInterval + 1) + _minInterval;
    _spawnTimer = Timer(Duration(minutes: nextIn), () {
      if (context.mounted) _showCapybara(context);
    });
  }

  void _showCapybara(BuildContext context) {
    if (_isShowing) return;
    _isShowing = true;

    final overlay = Overlay.of(context);
    final size = MediaQuery.of(context).size;

    // Tọa độ ngẫu nhiên
    final double posX = Random().nextDouble() * (size.width - 120);
    final double posY = 100 + Random().nextDouble() * (size.height - 250);

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: posY,
        left: posX,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () => _dismissCapybara(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Hiệu ứng bập bênh cho Capybara pixel
                TweenAnimationBuilder(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(seconds: 1),
                  builder: (context, double val, child) {
                    return Transform.translate(
                      offset: Offset(0, sin(val * pi * 2) * 5),
                      child: child,
                    );
                  },
                  child: Image.asset(
                    'assets/capybara.gif',
                    width: 100,
                    height: 100,
                    fit: BoxFit.contain,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    "Click me!",
                    style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    overlay.insert(_overlayEntry!);

    // Hình phạt thoát app
    _afkTimeoutTimer = Timer(Duration(seconds: _secondsToClick), () {
      if (_isShowing) _punishUser();
    });
  }

  void _dismissCapybara(BuildContext context) {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isShowing = false;
    _afkTimeoutTimer?.cancel();
    _scheduleNextSpawn(context);
  }

  void _punishUser() {
    if (kIsWeb) {
      html.window.location.href = "https://www.google.com";
    } else if (Platform.isAndroid || Platform.isIOS) {
      SystemNavigator.pop();
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      exit(0);
    }
  }

  void _stopTimers() {
    _spawnTimer?.cancel();
    _afkTimeoutTimer?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;
    _isShowing = false;
  }
}