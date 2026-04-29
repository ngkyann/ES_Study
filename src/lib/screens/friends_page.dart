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

  // Hàm tạo Chat ID duy nhất cho 2 người (ghép theo thứ tự alphabet)
  String _getChatId(String uid1, String uid2) {
    return uid1.compareTo(uid2) < 0 ? '${uid1}_$uid2' : '${uid2}_$uid1';
  }

  // --- CÁC HÀM XỬ LÝ LỜI MỜI VÀ BẠN BÈ ---
  Future<void> _sendFriendRequest(String targetUserId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(targetUserId)
        .update({
          'friendRequests': FieldValue.arrayUnion([widget.currentUserId]),
        });
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Đã gửi lời mời kết bạn!")));
  }

  Future<void> _acceptFriendRequest(String targetUserId) async {
    final batch = FirebaseFirestore.instance.batch();
    final myRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.currentUserId);
    final targetRef = FirebaseFirestore.instance
        .collection('users')
        .doc(targetUserId);

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
    final targetRef = FirebaseFirestore.instance
        .collection('users')
        .doc(targetUserId);

    batch.update(myRef, {
      'friends': FieldValue.arrayRemove([targetUserId]),
    });
    batch.update(targetRef, {
      'friends': FieldValue.arrayRemove([widget.currentUserId]),
    });
    await batch.commit();
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

        if (myDoc == null)
          return const Scaffold(
            body: Center(child: Text("Lỗi dữ liệu người dùng")),
          );

        Map<String, dynamic> myData = myDoc.data() as Map<String, dynamic>;
        List<String> myFriends = List<String>.from(myData['friends'] ?? []);
        List<String> myRequests = List<String>.from(
          myData['friendRequests'] ?? [],
        );

        List<DocumentSnapshot> friendsList = [];
        List<DocumentSnapshot> requestsList = [];
        List<DocumentSnapshot> searchList = [];

        for (var doc in users) {
          if (doc.id == widget.currentUserId) continue; // Bỏ qua bản thân

          if (myFriends.contains(doc.id)) {
            friendsList.add(doc);
          } else if (myRequests.contains(doc.id)) {
            requestsList.add(doc);
          }

          // 🔥 ĐÃ SỬA: Lọc tìm kiếm theo ID thay vì Tên (name)
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
                // TAB 1: DANH SÁCH BẠN BÈ
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
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: primaryColor.withOpacity(0.2),
                              child: const Icon(
                                Icons.person,
                                color: Colors.blue,
                              ),
                            ),
                            title: Text(
                              friendData['name'] ?? 'Ẩn danh',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              "ID: @$targetId",
                            ), // 🔥 Hiển thị ID của bạn bè
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
                                          targetUserName:
                                              friendData['name'] ?? 'Ẩn danh',
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

                // TAB 2: LỜI MỜI KẾT BẠN
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
                          var reqData =
                              requestsList[index].data()
                                  as Map<String, dynamic>;
                          String targetId = requestsList[index].id;
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.orange.withOpacity(0.2),
                              child: const Icon(
                                Icons.person_add,
                                color: Colors.orange,
                              ),
                            ),
                            title: Text(
                              reqData['name'] ?? 'Ẩn danh',
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

                // TAB 3: TÌM KIẾM THEO ID
                Column(
                  children: [
                    // 🔥 ĐÃ THÊM: Banner hiển thị ID của người dùng để họ dễ copy
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
                          hintText:
                              "Nhập ID người dùng để tìm kiếm...", // 🔥 Đổi câu gợi ý
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
                            _searchQuery = val.trim();
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
                                var searchData =
                                    targetDoc.data() as Map<String, dynamic>;
                                String targetId = targetDoc.id;

                                bool isFriend = myFriends.contains(targetId);

                                List<String> theirRequests = List<String>.from(
                                  searchData['friendRequests'] ?? [],
                                );
                                bool requestSent = theirRequests.contains(
                                  widget.currentUserId,
                                );

                                return ListTile(
                                  leading: const CircleAvatar(
                                    child: Icon(Icons.person),
                                  ),
                                  title: Text(
                                    searchData['name'] ?? 'Ẩn danh',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  subtitle: Text(
                                    "ID: $targetId",
                                  ), // 🔥 Hiện ID trong lúc tìm kiếm
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
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: primaryColor,
                                          ),
                                          onPressed: () =>
                                              _sendFriendRequest(targetId),
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
