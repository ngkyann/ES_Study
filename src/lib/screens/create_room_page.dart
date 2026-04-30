import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:esstudy/screens/online_room_page.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';

class CreateRoomPage extends StatefulWidget {
  final String userId;
  final String userName;
  final String userClass;

  const CreateRoomPage({
    super.key,
    required this.userId,
    required this.userName,
    required this.userClass,
  });

  @override
  State<CreateRoomPage> createState() => _CreateRoomPageState();
}

class _CreateRoomPageState extends State<CreateRoomPage> {
  int _selectedMinutes = 30;
  int _maxMembers = 4;
  final List<int> _timeOptions = [15, 30, 45, 60, 90, 120];
  final List<int> _memberOptions = [2, 4, 6, 8, 10];

  String? _selectedPlanId;
  String _selectedPlanTitle = "Học tự do";
  List<String> _goalsForRoom = [];

  // 🔥 ĐÃ THÊM: Biến lưu trạng thái Riêng tư và Mã phòng
  bool _isPrivate = false;
  String _roomCode = "";

  bool _isLoading = false;

  void _createAndJoinRoom() async {
    setState(() => _isLoading = true);

    final String newRoomId = const Uuid().v4();

    // Tạo mã phòng 6 chữ số nếu là phòng riêng tư
    if (_isPrivate) {
      _roomCode = (100000 + Random().nextInt(900000)).toString();
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OnlineRoomPage(
          isHost: true,
          roomId: newRoomId,
          userId: widget.userId,
          userName: widget.userName,
          duration: _selectedMinutes,
          maxMembers: _maxMembers,
          planId: _selectedPlanId,
          planTitle: _selectedPlanTitle,
          goals: _goalsForRoom,
          // 🔥 Truyền thêm thông tin phòng
          isPrivate: _isPrivate,
          roomCode: _isPrivate ? _roomCode : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Tạo phòng Online",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: _buildConfigCard(
                    title: "Thời gian học",
                    icon: Icons.timer,
                    child: DropdownButtonFormField<int>(
                      value: _selectedMinutes,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: _timeOptions
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text("$e phút"),
                            ),
                          )
                          .toList(),
                      onChanged: (val) =>
                          setState(() => _selectedMinutes = val!),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildConfigCard(
                    title: "Giới hạn",
                    icon: Icons.people_alt,
                    child: DropdownButtonFormField<int>(
                      value: _maxMembers,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      items: _memberOptions
                          .map(
                            (e) => DropdownMenuItem(
                              value: e,
                              child: Text("$e người"),
                            ),
                          )
                          .toList(),
                      onChanged: (val) => setState(() => _maxMembers = val!),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // 🔥 ĐÃ THÊM: Tuỳ chọn Phòng Riêng tư
            _buildConfigCard(
              title: "Quyền riêng tư",
              icon: Icons.security,
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  "Phòng học Riêng tư",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: const Text(
                  "Yêu cầu mã 6 số để tham gia. Phòng sẽ bị ẩn trên danh sách tìm kiếm chung.",
                  style: TextStyle(fontSize: 12),
                ),
                value: _isPrivate,
                activeColor: primaryColor,
                onChanged: (val) => setState(() => _isPrivate = val),
              ),
            ),
            const SizedBox(height: 16),

            _buildConfigCard(
              title: "Kế hoạch cá nhân của bạn",
              icon: Icons.assignment,
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('plans')
                    .where('userId', isEqualTo: widget.userId)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const LinearProgressIndicator();

                  final now = DateTime.now();
                  final validDocs = snapshot.data!.docs.where((doc) {
                    DateTime time = (doc['time'] as Timestamp).toDate();
                    return time.isBefore(now) || time.isAtSameMomentAs(now);
                  }).toList();

                  return DropdownButtonFormField<String?>(
                    value: _selectedPlanId,
                    isExpanded: true,
                    hint: const Text("Học tự do (Không nhiệm vụ)"),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text("Học tự do"),
                      ),
                      ...validDocs.map(
                        (doc) => DropdownMenuItem(
                          value: doc.id,
                          child: Text(doc['title']),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedPlanId = val;
                        _goalsForRoom = [];
                        if (val != null) {
                          final doc = validDocs.firstWhere((d) => d.id == val);
                          final data = doc.data() as Map<String, dynamic>;
                          _selectedPlanTitle = data['title'];

                          List<String> allTasks = List<String>.from(
                            data['tasks'] ?? [],
                          );
                          List<bool> allStatus = List<bool>.from(
                            data['completedTasks'] ??
                                List.generate(allTasks.length, (_) => false),
                          );

                          for (int i = 0; i < allTasks.length; i++) {
                            if (!allStatus[i]) _goalsForRoom.add(allTasks[i]);
                          }
                        } else {
                          _selectedPlanTitle = "Học tự do";
                        }
                      });
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 5,
              ),
              onPressed: _isLoading ? null : _createAndJoinRoom,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      "Khởi tạo Phòng học",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConfigCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: primaryColor),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }
}
