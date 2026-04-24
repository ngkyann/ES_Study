import 'package:flutter/material.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:esstudy/screens/profile_page.dart';
import 'package:esstudy/screens/room_search_page.dart';

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

class _MenuData {
  final IconData icon;
  final String title;
  final Color color;
  final bool isSearch;
  _MenuData(this.icon, this.title, this.color, {this.isSearch = false});
}
