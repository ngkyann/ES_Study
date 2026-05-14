import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:esstudy/screens/chat_page.dart';

class FriendsPage extends StatefulWidget {
  final String currentUserId;
  final String currentUserName;

  const FriendsPage({
    super.key,
    required this.currentUserId,
    required this.currentUserName,
  });

  @override
  State<FriendsPage> createState() => _FriendsPageState();
}

class _FriendsPageState extends State<FriendsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  String _getChatId(String uid1, String uid2) {
    return uid1.compareTo(uid2) < 0 ? '${uid1}_$uid2' : '${uid2}_$uid1';
  }

  Future<void> _sendFriendRequest(String targetUserId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(targetUserId)
        .update({
      'friendRequests': FieldValue.arrayUnion([widget.currentUserId]),
    });
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Đã gửi lời mời kết bạn!")));
    }
  }

  Future<void> _acceptFriendRequest(String targetUserId) async {
    final batch = FirebaseFirestore.instance.batch();
    final myRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId);
    final targetRef =
        FirebaseFirestore.instance.collection('users').doc(targetUserId);

    batch.update(myRef, {
      'friendRequests': FieldValue.arrayRemove([targetUserId]),
      'friends': FieldValue.arrayUnion([targetUserId]),
    });
    batch.update(targetRef, {
      'friends': FieldValue.arrayUnion([widget.currentUserId]),
    });
    await batch.commit();
  }

  Future<void> _declineFriendRequest(String targetUserId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId)
        .update({
      'friendRequests': FieldValue.arrayRemove([targetUserId]),
    });
  }

  Future<void> _unfriend(String targetUserId) async {
    final batch = FirebaseFirestore.instance.batch();
    final myRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId);
    final targetRef =
        FirebaseFirestore.instance.collection('users').doc(targetUserId);

    batch.update(myRef, {
      'friends': FieldValue.arrayRemove([targetUserId]),
    });
    batch.update(targetRef, {
      'friends': FieldValue.arrayRemove([widget.currentUserId]),
    });
    await batch.commit();
  }

  // Mở trang Hồ sơ người khác
  void _openUserProfile(String targetId, String targetName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            OtherUserProfilePage(userId: targetId, userName: targetName),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('users').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(
              title: const Text("Bạn bè"),
              backgroundColor: primaryColor,
              centerTitle: true,
            ),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final users = snapshot.data!.docs;
        DocumentSnapshot? myDoc;
        try {
          myDoc = users.firstWhere((doc) => doc.id == widget.currentUserId);
        } catch (e) {
          myDoc = null;
        }

        if (myDoc == null) {
          return const Scaffold(
            body: Center(child: Text("Lỗi dữ liệu của người dùng")),
          );
        }

        Map<String, dynamic> myData = myDoc.data() as Map<String, dynamic>;
        List<String> myFriends = List<String>.from(myData['friends'] ?? []);
        List<String> myRequests = List<String>.from(
          myData['friendRequests'] ?? [],
        );

        List<DocumentSnapshot> friendsList = [];
        List<DocumentSnapshot> requestsList = [];
        List<DocumentSnapshot> searchList = [];

        for (var doc in users) {
          if (doc.id == widget.currentUserId) continue;

          if (myFriends.contains(doc.id)) {
            friendsList.add(doc);
          } else if (myRequests.contains(doc.id)) {
            requestsList.add(doc);
          }

          if (_searchQuery.isNotEmpty &&
              doc.id.toLowerCase().contains(_searchQuery.toLowerCase())) {
            searchList.add(doc);
          }
        }

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text(
                "Bạn bè",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              centerTitle: true,
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              bottom: const TabBar(
                indicatorColor: Colors.white,
                indicatorWeight: 3,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(text: "Bạn bè"),
                  Tab(text: "Lời mời"),
                  Tab(text: "Tìm kiếm"),
                ],
              ),
            ),
            body: TabBarView(
              children: [
                // TAB 1: BẠN BÈ
                friendsList.isEmpty
                    ? const Center(
                        child: Text(
                          "Bạn chưa có người bạn nào.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: friendsList.length,
                        itemBuilder: (context, index) {
                          var friendData =
                              friendsList[index].data() as Map<String, dynamic>;
                          String targetId = friendsList[index].id;
                          String targetName = friendData['name'] ?? 'Ẩn danh';

                          return ListTile(
                            onTap: () => _openUserProfile(
                              targetId,
                              targetName,
                            ), // 🔥 Bấm để xem thông tin
                            leading: CircleAvatar(
                              backgroundColor: primaryColor.withOpacity(0.2),
                              child: const Icon(
                                Icons.person,
                                color: Colors.blue,
                              ),
                            ),
                            title: Text(
                              targetName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text("ID: @$targetId"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.message,
                                    color: Colors.blueAccent,
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatPage(
                                          chatId: _getChatId(
                                            widget.currentUserId,
                                            targetId,
                                          ),
                                          currentUserId: widget.currentUserId,
                                          targetUserName: targetName,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.person_remove,
                                    color: Colors.red,
                                  ),
                                  onPressed: () => _unfriend(targetId),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                // TAB 2: LỜI MỜI
                requestsList.isEmpty
                    ? const Center(
                        child: Text(
                          "Không có lời mời nào.",
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        itemCount: requestsList.length,
                        itemBuilder: (context, index) {
                          var reqData = requestsList[index].data()
                              as Map<String, dynamic>;
                          String targetId = requestsList[index].id;
                          String targetName = reqData['name'] ?? 'Ẩn danh';

                          return ListTile(
                            onTap: () => _openUserProfile(
                              targetId,
                              targetName,
                            ), // 🔥 Bấm để xem thông tin
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange.withOpacity(0.2),
                              child: const Icon(
                                Icons.person_add,
                                color: Colors.orange,
                              ),
                            ),
                            title: Text(
                              targetName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: const Text("Đã gửi cho bạn lời mời"),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                  ),
                                  onPressed: () =>
                                      _acceptFriendRequest(targetId),
                                  child: const Text(
                                    "Chấp nhận",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.grey.shade300,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                  ),
                                  onPressed: () =>
                                      _declineFriendRequest(targetId),
                                  child: const Text(
                                    "Từ chối",
                                    style: TextStyle(
                                      color: Colors.black87,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                // TAB 3: TÌM KIẾM
                Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 16,
                      ),
                      color: primaryColor.withOpacity(0.1),
                      child: SelectableText(
                        "Mã ID của bạn là: @${widget.currentUserId}\n(Gửi mã này cho bạn bè để họ tìm kiếm bạn)",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: "Nhập ID người dùng để tìm kiếm...",
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 0,
                          ),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _searchQuery = val.trim().replaceAll(
                                  '@',
                                  '',
                                ); // Tự động xóa @ nếu user nhập thừa
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: _searchQuery.isEmpty
                          ? const Center(
                              child: Text(
                                "Nhập ID để tìm kiếm",
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : searchList.isEmpty
                              ? const Center(
                                  child: Text(
                                    "Không tìm thấy người dùng với ID này",
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: searchList.length,
                                  itemBuilder: (context, index) {
                                    var targetDoc = searchList[index];
                                    var searchData = targetDoc.data()
                                        as Map<String, dynamic>;
                                    String targetId = targetDoc.id;
                                    String targetName =
                                        searchData['name'] ?? 'Ẩn danh';

                                    bool isFriend =
                                        myFriends.contains(targetId);
                                    List<String> theirRequests =
                                        List<String>.from(
                                      searchData['friendRequests'] ?? [],
                                    );
                                    bool requestSent = theirRequests.contains(
                                      widget.currentUserId,
                                    );

                                    return ListTile(
                                      onTap: () => _openUserProfile(
                                        targetId,
                                        targetName,
                                      ), // 🔥 Bấm để xem thông tin
                                      leading: const CircleAvatar(
                                        child: Icon(Icons.person),
                                      ),
                                      title: Text(
                                        targetName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text("ID: @$targetId"),
                                      trailing: isFriend
                                          ? const Text(
                                              "Bạn bè",
                                              style: TextStyle(
                                                color: Colors.green,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            )
                                          : requestSent
                                              ? const Text(
                                                  "Đã gửi lời mời",
                                                  style: TextStyle(
                                                    color: Colors.orange,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                )
                                              : ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                    backgroundColor:
                                                        primaryColor,
                                                  ),
                                                  onPressed: () =>
                                                      _sendFriendRequest(
                                                          targetId),
                                                  child: const Text(
                                                    "Kết bạn",
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// =====================================================================
// TRANG XEM HỒ SƠ NGƯỜI KHÁC (TÍCH HỢP SẴN TRONG FILE NÀY)
// =====================================================================
class OtherUserProfilePage extends StatelessWidget {
  final String userId;
  final String userName;

  const OtherUserProfilePage({
    super.key,
    required this.userId,
    required this.userName,
  });

  Future<Map<String, dynamic>> _fetchUserInfo() async {
    // Tải dữ liệu người dùng
    final userDoc =
        await FirebaseFirestore.instance.collection('users').doc(userId).get();

    // Tải toàn bộ user để tính hạng
    final usersSnap = await FirebaseFirestore.instance
        .collection('users')
        .orderBy('points', descending: true)
        .get();
    int rank = 0;
    for (int i = 0; i < usersSnap.docs.length; i++) {
      if (usersSnap.docs[i].id == userId) {
        rank = i + 1;
        break;
      }
    }

    final data = userDoc.data() as Map<String, dynamic>;
    data['rank'] = rank;
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          "Hồ sơ của $userName",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _fetchUserInfo(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: Text("Không thể tải dữ liệu"));
          }

          final data = snapshot.data!;
          final points = data['points'] ?? 0;
          final streak = data['streakCount'] ?? 0;
          final rank = data['rank'] ?? 0;
          final className = data['class'] ?? "Chưa có lớp";
          final List<dynamic> medals = data['medals'] ?? [];

          // Xử lý Ngày tham gia
          String joinDateText = "Chưa rõ";
          if (data['createdAt'] != null) {
            DateTime date = (data['createdAt'] as Timestamp).toDate();
            joinDateText =
                "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
          }

          // Xử lý Hiển thị Hạng
          String rankText;
          if (rank == 1) {
            rankText = "🥇 Hạng 1 (Quán quân)";
          } else if (rank >= 2 && rank <= 10) {
            rankText = "🥈 Hạng $rank (Top 10)";
          } else if (rank >= 11 && rank <= 50) {
            rankText = "🥉 Hạng $rank (Top 50)";
          } else if (rank > 50) {
            rankText = "Hạng $rank";
          } else {
            rankText = "Chưa xếp hạng";
          }

          return SingleChildScrollView(
            child: Column(
              children: [
                // Phần đầu: Avatar & Thông tin cơ bản
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  decoration: BoxDecoration(
                    color: primaryColor,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.15),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.person,
                          color: Colors.blueAccent,
                          size: 50,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        "@$userId",
                        style: const TextStyle(
                          fontSize: 14,
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_fire_department,
                              color: Colors.orangeAccent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "Chuỗi $streak ngày học",
                              style: const TextStyle(
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

                // Phần dưới: Chỉ số và Huy chương
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Thông tin học tập",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _infoCard(
                        Icons.workspace_premium,
                        "Tổng điểm",
                        "$points",
                      ),
                      _infoCard(Icons.military_tech, "Xếp hạng", rankText),
                      _infoCard(Icons.school, "Lớp", className),
                      _infoCard(
                        Icons.calendar_month,
                        "Ngày gia nhập",
                        joinDateText,
                      ),
                      const SizedBox(height: 25),
                      const Text(
                        "Huy chương mùa giải",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildMedalsSection(medals),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoCard(IconData icon, String label, String value) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ListTile(
          leading: Icon(icon, color: primaryColor),
          title: Text(
            label,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          trailing: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
        ),
      ),
    );
  }

  Widget _buildMedalsSection(List<dynamic> medals) {
    if (medals.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(30),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300, width: 1),
        ),
        child: Column(
          children: [
            Icon(
              Icons.military_tech_outlined,
              size: 50,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 10),
            const Text(
              "Chưa có thành tích nào",
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.75,
      ),
      itemCount: medals.length,
      itemBuilder: (context, index) {
        final medal = medals[index];
        int rank = medal['rank'] ?? 100;

        IconData medalIcon;
        Color medalColor;

        if (rank == 1) {
          medalIcon = Icons.emoji_events;
          medalColor = Colors.amber;
        } else if (rank >= 2 && rank <= 10) {
          medalIcon = Icons.emoji_events;
          medalColor = const Color(0xFFC0C0C0);
        } else if (rank >= 11 && rank <= 50) {
          medalIcon = Icons.emoji_events;
          medalColor = const Color(0xFFCD7F32);
        } else {
          medalIcon = Icons.military_tech;
          medalColor = Colors.blueAccent;
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: medalColor.withOpacity(0.15),
                ),
                child: Icon(medalIcon, size: 38, color: medalColor),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  medal['name'] ?? "Top $rank",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  medal['season'] ?? "Mùa giải",
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
