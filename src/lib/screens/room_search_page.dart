import 'package:flutter/material.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:esstudy/models/study_room.dart';
import 'package:esstudy/widgets/room_card.dart';

// --- MÀN HÌNH TÌM PHÒNG HỌC (Đã cập nhật Dropdown List) ---
class RoomSearchPage extends StatefulWidget {
  const RoomSearchPage({super.key});

  @override
  State<RoomSearchPage> createState() => _RoomSearchPageState();
}

class _RoomSearchPageState extends State<RoomSearchPage> {
  String _selectedFilterGrade = "Tất cả"; // Mặc định hiển thị Tất cả
  String _searchId = "";

  // Thêm "Tất cả" vào đầu danh sách
  final List<String> _grades = [
    "Tất cả",
    ...List.generate(12, (index) => 'Lớp ${index + 1}'),
  ];

  final List<StudyRoom> _allRooms = [
    StudyRoom(
      hostName: "Lê Minh Tuấn",
      hostId: "@tuan_pro",
      points: 2450,
      rank: "Kim Cương",
      currentMembers: 3,
      maxMembers: 5,
      startTime: "00:45",
      endTime: "02:00",
      grade: "Lớp 10",
    ),
    StudyRoom(
      hostName: "Hoàng Yến",
      hostId: "@yen_study",
      points: 1800,
      rank: "Vàng",
      currentMembers: 2,
      maxMembers: 4,
      startTime: "01:20",
      endTime: "03:00",
      grade: "Lớp 10",
    ),
    StudyRoom(
      hostName: "Trần Bảo",
      hostId: "@bao_99",
      points: 900,
      rank: "Bạc",
      currentMembers: 5,
      maxMembers: 5,
      startTime: "00:10",
      endTime: "02:00",
      grade: "Lớp 9",
    ),
    StudyRoom(
      hostName: "Nguyễn Thảo",
      hostId: "@thao_cham_chi",
      points: 3000,
      rank: "Thách Đấu",
      currentMembers: 1,
      maxMembers: 10,
      startTime: "00:05",
      endTime: "05:00",
      grade: "Lớp 10",
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // Logic lọc: Nếu là "Tất cả" thì bỏ qua lọc lớp
    List<StudyRoom> filteredRooms = _allRooms.where((room) {
      bool matchesGrade =
          _selectedFilterGrade == "Tất cả" ||
          room.grade == _selectedFilterGrade;
      bool matchesId =
          _searchId.isEmpty ||
          room.hostId.toLowerCase().contains(_searchId.toLowerCase());
      return matchesGrade && matchesId;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text("Tìm phòng học"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                TextField(
                  onChanged: (value) => setState(() => _searchId = value),
                  decoration: InputDecoration(
                    hintText: "Tìm kiếm theo ID (ví dụ: @tuan)",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Nút List (Dropdown) để lọc lớp
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Lọc theo lớp',
                    prefixIcon: const Icon(Icons.filter_list),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  initialValue: _selectedFilterGrade,
                  items: _grades
                      .map(
                        (grade) =>
                            DropdownMenuItem(value: grade, child: Text(grade)),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedFilterGrade = val);
                    }
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredRooms.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off, size: 80, color: Colors.grey),
                        SizedBox(height: 10),
                        Text(
                          "Không tìm thấy phòng học nào",
                          style: TextStyle(color: Colors.grey, fontSize: 16),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: filteredRooms.length,
                    itemBuilder: (context, index) {
                      return RoomCard(
                        room: filteredRooms[index],
                        onJoin: () {
                          debugPrint("Join room");
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
