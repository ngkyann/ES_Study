import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:esstudy/models/study_room.dart';
import 'package:esstudy/widgets/room_card.dart';
import 'package:esstudy/screens/online_room_page.dart';

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

  // String _getRank(int points) {
  //   if (points < 500) return "Tân binh";
  //   if (points < 1500) return "Đồng";
  //   if (points < 3000) return "Bạc";
  //   if (points < 5000) return "Vàng";
  //   return "Kim cương";
  // }

  void _showJoinByCodeDialog(BuildContext context) {
    final TextEditingController codeController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Vào phòng riêng tư"),
        content: TextField(
          controller: codeController,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: InputDecoration(
            hintText: "Nhập mã 6 chữ số",
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            filled: true,
            fillColor: Colors.grey.shade100,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Hủy", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            onPressed: () async {
              final code = codeController.text.trim();
              if (code.length != 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Mã phòng phải có 6 chữ số!")),
                );
                return;
              }

              final snap = await FirebaseFirestore.instance
                  .collection('study_rooms')
                  .where('roomCode', isEqualTo: code)
                  .get();
              if (snap.docs.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Không tìm thấy phòng hoặc mã sai!"),
                  ),
                );
                return;
              }

              final roomDoc = snap.docs.first;
              final data = roomDoc.data();
              Navigator.pop(ctx);
              _showJoinRoomDialog(context, data, roomDoc.id);
            },
            child: const Text(
              "Tìm kiếm",
              style: TextStyle(color: Colors.white),
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
    int maxMembers = roomData['maxMembers'] ?? 4;
    int currentMembers = List.from(roomData['participants'] ?? []).length;
    String roomName = roomData['roomName'] ?? "Phòng học online";

    if (currentMembers >= maxMembers) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Phòng đã đạt giới hạn thành viên!")),
      );
      return;
    }

    String? selectedPlanId;
    String selectedPlanTitle = "Học tự do";
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
                  const Text(
                    "Chuẩn bị vào phòng",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "Hãy chọn kế hoạch cá nhân bạn muốn thực hiện trong phòng này:",
                  ),
                  const SizedBox(height: 15),
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('plans')
                        .where('userId', isEqualTo: widget.currentUserId)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const CircularProgressIndicator();
                      }

                      final now = DateTime.now();
                      final validDocs = snapshot.data!.docs.where((doc) {
                        DateTime time = (doc['time'] as Timestamp).toDate();
                        return time.isBefore(now) || time.isAtSameMomentAs(now);
                      }).toList();

                      return DropdownButtonFormField<String?>(
                        value: selectedPlanId,
                        isExpanded: true,
                        hint: const Text("Học tự do"),
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
                              selectedPlanTitle = "Học tự do";
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
                    child: const Text(
                      "Vào học ngay",
                      style: TextStyle(color: Colors.white, fontSize: 16),
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
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Tìm phòng học",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Colors.orangeAccent,
        icon: const Icon(Icons.vpn_key, color: Colors.white),
        label: const Text(
          "Nhập mã",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
                    hintText: "Tìm kiếm theo @ID...(@tên_phòng)",
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
                    labelText: 'Lọc theo lớp',
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
                  items: _grades
                      .map(
                        (grade) =>
                            DropdownMenuItem(value: grade, child: Text(grade)),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedFilterGrade = val);
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('study_rooms')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  );
                }

                // 🔥 ĐÃ THÊM: Bọc state trống bằng RefreshIndicator
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return RefreshIndicator(
                    color: primaryColor,
                    backgroundColor: Colors.white,
                    onRefresh: () async {
                      await Future.delayed(const Duration(seconds: 1));
                      setState(() {});
                    },
                    child: _buildEmptyState("Chưa có phòng học nào đang mở."),
                  );
                }

                final docs = snapshot.data!.docs;
                final List<DocumentSnapshot> filteredDocs = docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;

                  if (data['isPrivate'] == true) return false;

                  final roomGrade = data['hostClass'] ?? "";
                  final hostId = data['hostId'] ?? "";

                  bool matchesGrade =
                      _selectedFilterGrade == "Tất cả" ||
                      roomGrade == _selectedFilterGrade;

                  final cleanSearchId = _searchId
                      .replaceAll('@', '')
                      .toLowerCase();
                  bool matchesId =
                      cleanSearchId.isEmpty ||
                      hostId.toLowerCase().contains(cleanSearchId);

                  return matchesGrade && matchesId;
                }).toList();

                // 🔥 ĐÃ THÊM: Bọc state trống (sau khi lọc) bằng RefreshIndicator
                if (filteredDocs.isEmpty) {
                  return RefreshIndicator(
                    color: primaryColor,
                    backgroundColor: Colors.white,
                    onRefresh: () async {
                      await Future.delayed(const Duration(seconds: 1));
                      setState(() {});
                    },
                    child: _buildEmptyState(
                      "Không tìm thấy phòng công khai phù hợp.",
                    ),
                  );
                }

                // 🔥 ĐÃ THÊM: Bọc ListView bằng RefreshIndicator
                return RefreshIndicator(
                  color: primaryColor,
                  backgroundColor: Colors.white,
                  onRefresh: () async {
                    // Cố tình delay 1 giây để hiệu ứng load xoay xoay nhìn rõ ràng, mượt mà
                    await Future.delayed(const Duration(seconds: 1));
                    setState(() {});
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredDocs.length,
                    itemBuilder: (context, index) {
                      final data =
                          filteredDocs[index].data() as Map<String, dynamic>;

                      int hostPoints = data['hostPoints'] ?? 0;

                      StudyRoom room = StudyRoom(
                        hostName: data['roomName'] ?? data['hostName'] ?? "Ẩn danh",
                        hostId: "@${data['hostId']}",
                        points: hostPoints,
                        // rank: _getRank(hostPoints),
                        currentMembers: List.from(
                          data['participants'] ?? [],
                        ).length,
                        maxMembers: data['maxMembers'] ?? 4,
                        startTime: "Đang diễn ra",
                        endTime: "${data['duration'] ?? 30} phút",
                        grade: data['hostClass'] ?? "Lớp ?",
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
  }

  Widget _buildEmptyState(String message) {
    return ListView(
      // Bắt buộc phải có physics này thì ListView dù trống vẫn có thể vuốt pull-to-refresh
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
