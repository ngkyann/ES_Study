import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:esstudy/screens/online_room_page.dart';
import 'package:uuid/uuid.dart';
import 'dart:math';
import 'package:esstudy/constants/var.dart';

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
  final TextEditingController _roomNameController = TextEditingController(
      text:
          languageNotifier.value == "Tiếng Việt" ? "Phòng học" : "Study room");
  int _selectedMinutes = 30;
  int _maxMembers = 4;
  final List<int> _timeOptions = [1, 30, 45, 60, 90, 120];
  final List<int> _memberOptions = [2, 4, 6, 8, 10, 15];

  String? _selectedPlanId;
  String _selectedPlanTitle =
      languageNotifier.value == "Tiếng Việt" ? "Học tự do" : "Free Study";
  List<String> _goalsForRoom = [];
  bool _isPrivate = false;
  String _roomCode = "";

  bool _isLoading = false;

  @override
  void dispose() {
    _roomNameController.dispose();
    super.dispose();
  }

  void _createAndJoinRoom() async {
    setState(() => _isLoading = true);

    if (_roomNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(languageNotifier.value == "Tiếng Việt"
                ? "Vui lòng đặt tên cho phòng học nhé!"
                : "Please name the study room!")),
      );
      return;
    }

    setState(() => _isLoading = true);
    final String roomName = _roomNameController.text.trim();
    final String newRoomId = const Uuid().v4();

    // Tạo mã phòng 6 chữ số nếu là phòng riêng tư
    if (_isPrivate) {
      _roomCode = (100000 + Random().nextInt(899999)).toString();
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => OnlineRoomPage(
          isHost: true,
          roomId: newRoomId,
          roomName: roomName,
          userId: widget.userId,
          userName: widget.userName,
          duration: _selectedMinutes,
          maxMembers: _maxMembers,
          planId: _selectedPlanId,
          planTitle: _selectedPlanTitle,
          goals: _goalsForRoom,
          isPrivate: _isPrivate,
          roomCode: _isPrivate ? _roomCode : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
        valueListenable: languageNotifier,
        builder: (context, lang, child) {
          bool isVN = lang == "Tiếng Việt";
          return Scaffold(
            backgroundColor: Colors.grey.shade50,
            appBar: AppBar(
              title: Text(
                isVN ? "Tạo phòng học" : "Create Room",
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
                  _buildConfigCard(
                    title: isVN ? "Tên phòng học" : "Room Name",
                    icon: Icons.edit_note,
                    child: TextField(
                      controller: _roomNameController,
                      decoration: InputDecoration(
                        hintText:
                            isVN ? "Nhập tên phòng..." : "Enter room name...",
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: _buildConfigCard(
                          title: isVN ? "Thời gian học" : "Duration",
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
                                    child: Text(isVN ? "$e phút" : "$e mins"),
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
                          title: isVN ? "Số lượng người học" : "Capacity",
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
                                    child:
                                        Text(isVN ? "$e người" : "$e people"),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _maxMembers = val!),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // 🔥 ĐÃ THÊM: Tuỳ chọn Phòng Riêng tư
                  _buildConfigCard(
                    title: isVN ? "Chế độ riêng tư" : "Privacy Mode",
                    icon: Icons.security,
                    child: SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        isVN ? "Phòng học riêng tư" : "Private Study Room",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        isVN
                            ? "Yêu cầu nhập mã 6 số để tham gia. Phòng học sẽ bị ẩn trên danh sách tìm kiếm chung."
                            : "Requires a 6-digit code to join. The room will be hidden from public search.",
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _isPrivate,
                      activeColor: primaryColor,
                      onChanged: (val) => setState(() => _isPrivate = val),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _buildConfigCard(
                    title: isVN
                        ? "Kế hoạch cá nhân của bạn"
                        : "Your Personal Plan",
                    icon: Icons.assignment,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('plans')
                          .where('userId', isEqualTo: widget.userId)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData)
                          return const LinearProgressIndicator();

                        final now = DateTime.now();
                        final validDocs = snapshot.data!.docs.where((doc) {
                          DateTime time = (doc['time'] as Timestamp).toDate();
                          return time.isBefore(now) ||
                              time.isAtSameMomentAs(now);
                        }).toList();

                        return DropdownButtonFormField<String?>(
                          value: _selectedPlanId,
                          isExpanded: true,
                          hint: Text(isVN
                              ? "Học tự do (Không nhiệm vụ)"
                              : "Free Study (No tasks)"),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide.none,
                            ),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text(isVN ? "Học tự do" : "Free Study"),
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
                                final doc =
                                    validDocs.firstWhere((d) => d.id == val);
                                final data = doc.data() as Map<String, dynamic>;
                                _selectedPlanTitle = data['title'];

                                List<String> allTasks = List<String>.from(
                                  data['tasks'] ?? [],
                                );
                                List<bool> allStatus = List<bool>.from(
                                  data['completedTasks'] ??
                                      List.generate(
                                          allTasks.length, (_) => false),
                                );

                                for (int i = 0; i < allTasks.length; i++) {
                                  if (!allStatus[i])
                                    _goalsForRoom.add(allTasks[i]);
                                }
                              } else {
                                _selectedPlanTitle =
                                    isVN ? "Học tự do" : "Free Study";
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
                        : Text(
                            isVN ? "Tạo phòng học" : "Create Room",
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
        });
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
