import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:esstudy/models/study_room.dart';
import 'package:esstudy/widgets/room_card.dart';
import 'package:esstudy/screens/online_room_page.dart';
import 'package:esstudy/constants/var.dart';

class RoomSearchPage extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;

  const RoomSearchPage({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<RoomSearchPage> createState() => _RoomSearchPageState();
}

class _RoomSearchPageState extends State<RoomSearchPage> {
  String _selectedFilterGrade = "Tất cả";
  String _searchId = "";

  final List<String> _grades = [
    "Tất cả",
    ...List.generate(12, (index) => 'Lớp ${index + 1}'),
  ];

  void _showJoinByCodeDialog(BuildContext context) {
    bool isVN = languageNotifier.value == "Tiếng Việt"; // 🔥 THÊM NGÔN NGỮ
    final TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(isVN ? "Vào phòng riêng tư" : "Join private room"),
        content: TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(
            hintText: isVN ? "Nhập mã 6 chữ số" : "Enter 6-digit code",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Colors.grey.shade100,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isVN ? "Hủy" : "Cancel",
                style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.length != 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(isVN
                          ? "Mã phòng phải có 6 chữ số!"
                          : "Room code must be 6 digits!")),
                );
                return;
              }

              final snap = await FirebaseFirestore.instance
                  .collection('study_rooms')
                  .where('roomCode', isEqualTo: code)
                  .get();
              if (snap.docs.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isVN
                        ? "Không tìm thấy phòng hoặc mã sai!"
                        : "Room not found or incorrect code!"),
                  ),
                );
                return;
              }

              final roomDoc = snap.docs.first;
              final data = roomDoc.data();
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              _showJoinRoomDialog(context, data, roomDoc.id);
            },
            child: Text(
              isVN ? "Tìm kiếm" : "Search",
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _showJoinRoomDialog(
    BuildContext context,
    Map<String, dynamic> roomData,
    String roomId,
  ) {
    bool isVN = languageNotifier.value == "Tiếng Việt"; // 🔥 THÊM NGÔN NGỮ
    int maxMembers = roomData['maxMembers'] ?? 4;
    int currentMembers = List.from(roomData['participants'] ?? []).length;
    String roomName = roomData['roomName'] ??
        (isVN ? "Phòng học online" : "Online study room");

    if (currentMembers >= maxMembers) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(isVN
                ? "Phòng đã đạt giới hạn thành viên!"
                : "Room has reached its member limit!")),
      );
      return;
    }

    String? selectedPlanId;
    String selectedPlanTitle = isVN ? "Học tự do" : "Free Study";
    List<String> goalsForRoom = [];

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (bottomSheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isVN ? "Chuẩn bị vào phòng" : "Get ready to join",
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    isVN
                        ? "Hãy chọn kế hoạch cá nhân bạn muốn thực hiện trong phòng này:"
                        : "Select your personal plan to accomplish in this room:",
                  ),
                  const SizedBox(height: 15),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('plans')
                        .where('userId', isEqualTo: widget.currentUserId)
                        .where('time', isLessThanOrEqualTo: Timestamp.now())
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator();
                      }

                      final validDocs = snapshot.data!.docs;

                      return DropdownButtonFormField<String?>(
                        value: selectedPlanId,
                        isExpanded: true,
                        hint: Text(isVN ? "Học tự do" : "Free Study"),
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
                          setModalState(() {
                            selectedPlanId = val;
                            goalsForRoom = [];
                            if (val != null) {
                              final doc = validDocs.firstWhere(
                                (d) => d.id == val,
                              );
                              final data = doc.data() as Map<String, dynamic>;
                              selectedPlanTitle = data['title'];

                              List<String> allTasks = List<String>.from(
                                data['tasks'] ?? [],
                              );
                              List<bool> allStatus = List<bool>.from(
                                data['completedTasks'] ??
                                    List.generate(
                                      allTasks.length,
                                      (_) => false,
                                    ),
                              );
                              for (int i = 0; i < allTasks.length; i++) {
                                if (!allStatus[i]) {
                                  goalsForRoom.add(allTasks[i]);
                                }
                              }
                            } else {
                              selectedPlanTitle =
                                  isVN ? "Học tự do" : "Free Study";
                            }
                          });
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(bottomSheetContext);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => OnlineRoomPage(
                            isHost: false,
                            roomId: roomId,
                            roomName: roomName,
                            userId: widget.currentUserId,
                            userName: widget.currentUserName,
                            duration: roomData['duration'] ?? 30,
                            maxMembers: maxMembers,
                            planId: selectedPlanId,
                            planTitle: selectedPlanTitle,
                            goals: goalsForRoom,
                          ),
                        ),
                      );
                    },
                    child: Text(
                      isVN ? "Vào học ngay" : "Join now",
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 BỌC TÒAN BỘ ValueListenableBuilder
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, child) {
        bool isVN = lang == "Tiếng Việt";

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: Text(
              isVN ? "Tìm phòng học" : "Search Room",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            centerTitle: true,
          ),
          floatingActionButton: FloatingActionButton.extended(
            backgroundColor: Colors.orangeAccent,
            icon: const Icon(Icons.vpn_key, color: Colors.white),
            label: Text(
              isVN ? "Nhập mã" : "Enter code",
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
            ),
            onPressed: () => _showJoinByCodeDialog(context),
          ),
          body: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    TextField(
                      onChanged: (value) =>
                          setState(() => _searchId = value.trim()),
                      decoration: InputDecoration(
                        hintText: isVN
                            ? "Tìm kiếm theo @ID...(@id_chủ_phòng)"
                            : "Search by @ID...(@host_id)",
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      decoration: InputDecoration(
                        labelText: isVN ? 'Lọc theo lớp' : 'Filter by class',
                        prefixIcon: const Icon(Icons.filter_list),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(15),
                          borderSide: BorderSide.none,
                        ),
                      ),
                      value: _selectedFilterGrade,
                      items: _grades.map((grade) {
                        String displayTxt = isVN
                            ? grade
                            : grade
                                .replaceFirst('Lớp', 'Class')
                                .replaceFirst('Tất cả', 'All');
                        return DropdownMenuItem(
                            value: grade, child: Text(displayTxt));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null)
                          setState(() => _selectedFilterGrade = val);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: (() {
                    // Xây dựng Query động: Lọc tối đa trên Server
                    Query query =
                        FirebaseFirestore.instance.collection('study_rooms');

                    // 1. Chỉ lấy phòng công khai
                    query = query.where('isPrivate', isEqualTo: false);

                    // 2. Lọc theo lớp (nếu không phải "Tất cả")
                    if (_selectedFilterGrade != "Tất cả") {
                      query = query.where('hostClass',
                          isEqualTo: _selectedFilterGrade);
                    }

                    // 3. Sắp xếp theo thời gian tạo mới nhất
                    return query
                        .orderBy('createdAt', descending: true)
                        .snapshots();
                  })(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(color: primaryColor),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return RefreshIndicator(
                        color: primaryColor,
                        backgroundColor: Colors.white,
                        onRefresh: () async {
                          await Future.delayed(const Duration(seconds: 1));
                          setState(() {});
                        },
                        child: _buildEmptyState(isVN
                            ? "Chưa có phòng học nào đang mở."
                            : "No active study rooms currently."),
                      );
                    }

                    final docs = snapshot.data!.docs;

                    // Lọc Client-side: CHỈ lọc tìm kiếm ID (do Firestore không hỗ trợ contains)
                    final List<DocumentSnapshot> filteredDocs =
                        docs.where((doc) {
                      final data = doc.data() as Map<String, dynamic>;
                      final cleanSearchId =
                          _searchId.replaceAll('@', '').toLowerCase();

                      if (cleanSearchId.isEmpty)
                        return true; // Bỏ qua lọc nếu không gõ từ khóa

                      final hostId =
                          data['hostId']?.toString().toLowerCase() ?? "";
                      return hostId.contains(cleanSearchId);
                    }).toList();

                    if (filteredDocs.isEmpty) {
                      return RefreshIndicator(
                        color: primaryColor,
                        backgroundColor: Colors.white,
                        onRefresh: () async {
                          await Future.delayed(const Duration(seconds: 1));
                          setState(() {});
                        },
                        child: _buildEmptyState(
                          isVN
                              ? "Không tìm thấy phòng công khai phù hợp."
                              : "No matching public rooms found.",
                        ),
                      );
                    }

                    return RefreshIndicator(
                      color: primaryColor,
                      backgroundColor: Colors.white,
                      onRefresh: () async {
                        await Future.delayed(const Duration(seconds: 1));
                        setState(() {});
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(16),
                        itemCount: filteredDocs.length,
                        itemBuilder: (context, index) {
                          final data = filteredDocs[index].data()
                              as Map<String, dynamic>;

                          int hostPoints = data['hostPoints'] ?? 0;
                          String originalClass = data['hostClass'] ?? "Lớp ?";

                          StudyRoom room = StudyRoom(
                            hostName: data['roomName'] ??
                                data['hostName'] ??
                                (isVN ? "Ẩn danh" : "Anonymous"),
                            hostId: "@${data['hostId']}",
                            points: hostPoints,
                            currentMembers: List.from(
                              data['participants'] ?? [],
                            ).length,
                            maxMembers: data['maxMembers'] ?? 4,
                            startTime: isVN ? "Đang diễn ra" : "Ongoing",
                            endTime:
                                "${data['duration'] ?? 30} ${isVN ? 'phút' : 'mins'}",
                            grade: isVN
                                ? originalClass
                                : originalClass.replaceFirst('Lớp', 'Class'),
                          );

                          return RoomCard(
                            room: room,
                            onJoin: () => _showJoinRoomDialog(
                              context,
                              data,
                              filteredDocs[index].id,
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String message) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 80),
      children: [
        const Icon(Icons.search_off, size: 80, color: Colors.grey),
        const SizedBox(height: 10),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.grey, fontSize: 16),
        ),
      ],
    );
  }
}
