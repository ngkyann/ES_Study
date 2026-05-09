import 'dart:async';
import 'dart:math';
import 'dart:io'; // Bây giờ có thể dùng thoải mái vì bỏ Web rồi
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AntiAFKManager {
  static final AntiAFKManager _instance = AntiAFKManager._internal();
  factory AntiAFKManager() => _instance;
  AntiAFKManager._internal();

  OverlayEntry? _overlayEntry;
  Timer? _spawnTimer;
  Timer? _afkTimeoutTimer;
  bool _isShowing = false;

  // Cấu hình thời gian (Điều chỉnh theo nhu cầu)
  final int _minInterval = 5; 
  final int _maxInterval = 30; 
  final int _secondsToClick = 30; 

  void start(BuildContext context) {
    _stopTimers();
    _scheduleNextSpawn(context);
  }

  void _scheduleNextSpawn(BuildContext context) {
    _spawnTimer?.cancel(); // Đảm bảo không có timer cũ chạy đè
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
                // Hiệu ứng nhảy nhẹ cho Capybara
                Image.asset(
                  'assets/capybara.gif',
                  width: 100,
                  height: 100,
                  fit: BoxFit.contain,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    "Chill check! Tap me!",
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

    _afkTimeoutTimer = Timer(Duration(seconds: _secondsToClick), () {
      if (_isShowing) _punishUser();
    });
  }

  void _dismissCapybara(BuildContext context) {
    _stopTimers();
    _scheduleNextSpawn(context);
  }

  void _punishUser() {
    if (Platform.isAndroid) {
      SystemNavigator.pop(); 
    } else {
      exit(0);
    }
  }

  void _stopTimers() {
    _spawnTimer?.cancel();
    _afkTimeoutTimer?.cancel();
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    _isShowing = false;
  }
}