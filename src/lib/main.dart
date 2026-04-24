import 'package:flutter/material.dart';

const Color primaryColor = Color(0xFF87CEFA);
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Học Tập App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: primaryColor),
        scaffoldBackgroundColor: const Color(0xFFF5F9FF),
      ),
      home: const LoginPage(),
    );
  }
}

// --- MODEL DỮ LIỆU PHÒNG HỌC ---
class StudyRoom {
  final String hostName;
  final String hostId;
  final int points;
  final String rank;
  final int currentMembers;
  final int maxMembers;
  final String startTime;
  final String endTime;
  final String grade;

  StudyRoom({
    required this.hostName,
    required this.hostId,
    required this.points,
    required this.rank,
    required this.currentMembers,
    required this.maxMembers,
    required this.startTime,
    required this.endTime,
    required this.grade,
  });
}

// --- MÀN HÌNH ĐĂNG NHẬP ---
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _obscureText = true;
  String? _selectedClass;

  // Thêm Controller để lấy dữ liệu nhập vào
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _idController = TextEditingController();

  final List<String> _classes = List.generate(
    12,
    (index) => 'Lớp ${index + 1}',
  );

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: const EdgeInsets.all(24.0),
        alignment: Alignment.center,
        child: SingleChildScrollView(
          child: Column(
            children: [
              const Icon(Icons.auto_stories, size: 80, color: primaryColor),
              const SizedBox(height: 10),
              const Text(
                "E-LEARNING",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 40),
              _buildTextField("Họ và tên", Icons.person, _nameController),
              const SizedBox(height: 16),
              _buildTextField(
                "ID người dùng (Ví dụ: @hocsinh123)",
                Icons.alternate_email,
                _idController,
              ),
              const SizedBox(height: 16),
              _buildTextField("Email/Gmail", Icons.email, null),
              const SizedBox(height: 16),
              TextField(
                obscureText: _obscureText,
                decoration: InputDecoration(
                  labelText: 'Mật khẩu',
                  prefixIcon: const Icon(Icons.lock),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () =>
                        setState(() => _obscureText = !_obscureText),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Chọn lớp',
                    prefixIcon: const Icon(Icons.school),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  initialValue: _selectedClass,
                  items: _classes
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedClass = val),
                ),
              ),
              const SizedBox(height: 30),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.4),
                      blurRadius: 15,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    onPressed: () {
                      // Truyền dữ liệu sang HomePage
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HomePage(
                            userName: _nameController.text.isEmpty
                                ? "Người dùng"
                                : _nameController.text,
                            userId: _idController.text.isEmpty
                                ? "@user"
                                : _idController.text,
                            selectedClass: _selectedClass ?? 'Chưa chọn lớp',
                          ),
                        ),
                      );
                    },
                    child: const Text(
                      "VÀO HỌC NGAY",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    IconData icon,
    TextEditingController? controller,
  ) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

// --- MÀN HÌNH CHÍNH ---
class HomePage extends StatelessWidget {
  final String userName;
  final String userId;
  final String selectedClass;

  const HomePage({
    super.key,
    required this.userName,
    required this.userId,
    required this.selectedClass,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        leadingWidth: 100,
        leading: Container(
          margin: const EdgeInsets.only(left: 16),
          child: const Row(
            children: [
              Icon(Icons.local_fire_department, color: Colors.orangeAccent),
              SizedBox(width: 4),
              Text(
                "15",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
        ),
        title: const Text("Trang chủ"),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfilePage(
                    userName: userName,
                    userId: userId,
                    selectedClass: selectedClass,
                  ),
                ),
              ),
              child: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: primaryColor),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 30,
                    spreadRadius: 4,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Chào buổi sáng,",
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                  Text(
                    userName, // Hiển thị tên người dùng đã nhập
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text(
                "Bắt đầu học",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            _buildGridMenu(context, [
              _MenuData(Icons.add_home, "Tạo phòng", Colors.orange),
              _MenuData(Icons.menu_book, "Học Offline", Colors.green),
              _MenuData(
                Icons.search,
                "Tìm phòng",
                primaryColor,
                isSearch: true,
              ),
            ]),

            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Text(
                "Tiện ích khác",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),

            _buildGridMenu(context, [
              _MenuData(Icons.event_note, "Kế hoạch", Colors.purple),
              _MenuData(Icons.leaderboard, "Xếp hạng", Colors.redAccent),
              _MenuData(Icons.people, "Bạn bè", Colors.teal),
            ]),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildGridMenu(BuildContext context, List<_MenuData> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return InkWell(
          onTap: () {
            if (items[index].isSearch) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const RoomSearchPage()),
              );
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: items[index].color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    items[index].icon,
                    color: items[index].color,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  items[index].title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

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
                    itemBuilder: (context, index) =>
                        _buildRoomCard(filteredRooms[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomCard(StudyRoom room) {
    bool isFull = room.currentMembers >= room.maxMembers;
    return Card(
      elevation: 0,
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: primaryColor,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.hostName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          room.hostId,
                          style: const TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "${room.currentMembers}/${room.maxMembers}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isFull ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${room.grade} • ${room.points} điểm",
                        style: const TextStyle(fontSize: 13),
                      ),
                      Text(
                        "Hạng: ${room.rank}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        "Thời gian học:",
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      Text(
                        "${room.startTime}/${room.endTime}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isFull ? null : () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text("Vào phòng"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- TRANG CÁ NHÂN (Hiển thị dữ liệu động) ---
class ProfilePage extends StatelessWidget {
  final String userName;
  final String userId;
  final String selectedClass;

  const ProfilePage({
    super.key,
    required this.userName,
    required this.userId,
    required this.selectedClass,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hồ sơ cá nhân"),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 30),
              decoration: BoxDecoration(
                color: primaryColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
                // borderRadius: const BorderRadius.only(
                //   bottomLeft: Radius.circular(30),
                //   bottomRight: Radius.circular(30),
                // ),
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, color: primaryColor),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    userName, // Hiển thị tên từ Login
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    "@$userId", // Hiển thị ID từ Login
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department,
                          color: Colors.orangeAccent,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "Chuỗi 15 ngày học",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _infoCard(Icons.alternate_email, "ID người dùng", "@$userId"),
                  _infoCard(Icons.military_tech, "Xếp hạng", "Kim cương"),
                  _infoCard(Icons.workspace_premium, "Tổng điểm", "1,500"),
                  _infoCard(
                    Icons.calendar_month,
                    "Ngày gia nhập",
                    "24/04/2026",
                  ),
                  _infoCard(Icons.school, "Lớp hiện tại", selectedClass),
                  const SizedBox(height: 30),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.edit),
                    label: const Text("Chỉnh sửa thông tin"),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                      side: const BorderSide(color: primaryColor),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoCard(IconData icon, String label, String value) {
    return Card(
      elevation: 0,
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ListTile(
          leading: Icon(icon, color: primaryColor),
          title: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          trailing: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ),
      ),
    );
  }
}

class _MenuData {
  final IconData icon;
  final String title;
  final Color color;
  final bool isSearch;
  _MenuData(this.icon, this.title, this.color, {this.isSearch = false});
}
