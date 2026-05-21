import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:esstudy/screens/chat_page.dart';
import 'package:esstudy/constants/var.dart';

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
      ).showSnackBar(SnackBar(
          content: Text(languageNotifier.value == "Tiếng Việt"
              ? "Đã gửi lời mời kết bạn!"
              : "Friend request sent!")));
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

    // TÌM ID CỦA CHUỖI BẠN BÈ ĐỂ XÓA
    String streakId = _getChatId(widget.currentUserId, targetUserId);
    final streakRef =
        FirebaseFirestore.instance.collection('friend_streaks').doc(streakId);

    // Xóa khỏi danh sách bạn bè của mình
    batch.update(myRef, {
      'friends': FieldValue.arrayRemove([targetUserId]),
    });
    // Xóa khỏi danh sách bạn bè của người kia
    batch.update(targetRef, {
      'friends': FieldValue.arrayRemove([widget.currentUserId]),
    });
    // XÓA DOCUMENT CHUỖI KHỎI DATABASE
    batch.delete(streakRef);

    await batch.commit();
  }

  // HỘP THOẠI XÁC NHẬN KHI XÓA BẠN BÈ
  void _showUnfriendConfirmDialog(String targetId, String targetName) {
    bool isVN = languageNotifier.value == "Tiếng Việt";

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            const Icon(Icons.person_remove, color: Colors.red),
            const SizedBox(width: 8),
            Text(isVN ? "Hủy kết bạn" : "Unfriend"),
          ],
        ),
        content: Text(
          isVN
              ? "Bạn có chắc chắn muốn hủy kết bạn với $targetName không?"
              : "Are you sure you want to unfriend $targetName?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isVN ? "Hủy" : "Cancel",
                style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.pop(ctx); // Đóng Dialog
              _unfriend(targetId); // Tiến hành xóa
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    isVN
                        ? "Đã hủy kết bạn với $targetName"
                        : "Unfriended $targetName",
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            child: Text(isVN ? "Xóa" : "Unfriend",
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
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
    return ValueListenableBuilder<String>(
        valueListenable: languageNotifier,
        builder: (context, lang, child) {
          bool isVN = lang == "Tiếng Việt";
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('users').snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Scaffold(
                  appBar: AppBar(
                    title: Text(isVN ? "Bạn bè" : "Friends"),
                    backgroundColor: primaryColor,
                    centerTitle: true,
                  ),
                  body: const Center(child: CircularProgressIndicator()),
                );
              }

              final users = snapshot.data!.docs;
              DocumentSnapshot? myDoc;
              try {
                myDoc =
                    users.firstWhere((doc) => doc.id == widget.currentUserId);
              } catch (e) {
                myDoc = null;
              }

              if (myDoc == null) {
                return const Scaffold(
                  body: Center(child: Text("Lỗi dữ liệu của người dùng")),
                );
              }

              Map<String, dynamic> myData =
                  myDoc.data() as Map<String, dynamic>;
              List<String> myFriends =
                  List<String>.from(myData['friends'] ?? []);
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
                    title: Text(
                      isVN ? "Bạn bè" : "Friends",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    centerTitle: true,
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    bottom: TabBar(
                      indicatorColor: Colors.white,
                      indicatorWeight: 3,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      tabs: [
                        Tab(text: isVN ? "Bạn bè" : "Friends"),
                        Tab(
                          child: Badge(
                            offset: const Offset(15, -6),
                            isLabelVisible: requestsList.isNotEmpty,
                            label: Text(
                              '${requestsList.length}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            backgroundColor: Colors.red,
                            child: Text(isVN ? "Lời mời" : "Requests"),
                          ),
                        ),
                        Tab(text: isVN ? "Tìm kiếm" : "Search"),
                      ],
                    ),
                  ),
                  body: TabBarView(
                    children: [
                      // TAB 1: BẠN BÈ
                      friendsList.isEmpty
                          ? Center(
                              child: Text(
                                  isVN
                                      ? "Bạn chưa có người bạn nào."
                                      : "You have no friends yet.",
                                  style: const TextStyle(color: Colors.grey)))
                          : ListView.builder(
                              itemCount: friendsList.length,
                              itemBuilder: (context, index) {
                                var friendData = friendsList[index].data()
                                    as Map<String, dynamic>;
                                String targetId = friendsList[index].id;
                                String targetName =
                                    friendData['name'] ?? 'Ẩn danh';

                                return FutureBuilder<DocumentSnapshot>(
                                    future: FirebaseFirestore.instance
                                        .collection('friend_streaks')
                                        .doc(_getChatId(
                                            widget.currentUserId, targetId))
                                        .get(),
                                    builder: (context, streakSnap) {
                                      int streak = 0;
                                      if (streakSnap.hasData &&
                                          streakSnap.data!.exists) {
                                        streak = (streakSnap.data!.data()
                                                    as Map<String, dynamic>)[
                                                'streak'] ??
                                            0;
                                      }
                                      bool hasStreak = streak >= 3;

                                      return ListTile(
                                        onTap: () => _openUserProfile(
                                            targetId, targetName),
                                        leading: CircleAvatar(
                                          backgroundColor:
                                              primaryColor.withOpacity(0.2),
                                          backgroundImage:
                                              (friendData['avatarUrl'] !=
                                                          null &&
                                                      friendData['avatarUrl']
                                                          .toString()
                                                          .isNotEmpty)
                                                  ? NetworkImage(
                                                      friendData['avatarUrl'])
                                                  : null,
                                          child: (friendData['avatarUrl'] !=
                                                      null &&
                                                  friendData['avatarUrl']
                                                      .toString()
                                                      .isNotEmpty)
                                              ? null
                                              : const Icon(Icons.person,
                                                  color: Colors.blue),
                                        ),
                                        title: Row(
                                          children: [
                                            Text(targetName,
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.bold)),
                                            if (hasStreak) ...[
                                              const SizedBox(width: 5),
                                              const Icon(
                                                  Icons.local_fire_department,
                                                  color: Colors.orange,
                                                  size: 18),
                                              Text("$streak",
                                                  style: const TextStyle(
                                                      color: Colors.orange,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14)),
                                            ]
                                          ],
                                        ),
                                        subtitle: Text("ID: @$targetId"),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.message,
                                                  color: Colors.blueAccent),
                                              onPressed: () {
                                                Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (_) => ChatPage(
                                                        chatId: _getChatId(
                                                            widget
                                                                .currentUserId,
                                                            targetId),
                                                        currentUserId: widget
                                                            .currentUserId,
                                                        targetUserName:
                                                            targetName,
                                                      ),
                                                    ));
                                              },
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                  Icons.person_remove,
                                                  color: Colors.red),
                                              onPressed: () =>
                                                  _showUnfriendConfirmDialog(
                                                      targetId, targetName),
                                            ),
                                          ],
                                        ),
                                      );
                                    });
                              },
                            ),

                      // TAB 2: LỜI MỜI
                      requestsList.isEmpty
                          ? Center(
                              child: Text(
                                isVN ? "Không có lời mời nào." : "No requests.",
                                style: const TextStyle(color: Colors.grey),
                              ),
                            )
                          : ListView.builder(
                              itemCount: requestsList.length,
                              itemBuilder: (context, index) {
                                var reqData = requestsList[index].data()
                                    as Map<String, dynamic>;
                                String targetId = requestsList[index].id;
                                String targetName =
                                    reqData['name'] ?? 'Ẩn danh';

                                return ListTile(
                                  onTap: () => _openUserProfile(
                                    targetId,
                                    targetName,
                                  ),
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        Colors.orange.withOpacity(0.2),
                                    backgroundImage:
                                        (reqData['avatarUrl'] != null &&
                                                reqData['avatarUrl']
                                                    .toString()
                                                    .isNotEmpty)
                                            ? NetworkImage(reqData['avatarUrl'])
                                            : null,
                                    child: (reqData['avatarUrl'] != null &&
                                            reqData['avatarUrl']
                                                .toString()
                                                .isNotEmpty)
                                        ? null
                                        : const Icon(
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
                                  subtitle: Text(isVN
                                      ? "Đã gửi cho bạn lời mời"
                                      : "Sent you a request"),
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
                                        child: Text(
                                          isVN ? "Chấp nhận" : "Accept",
                                          style: const TextStyle(
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
                                        child: Text(
                                          isVN ? "Từ chối" : "Decline",
                                          style: const TextStyle(
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
                              isVN
                                  ? "Mã ID của bạn là: @${widget.currentUserId}\n(Gửi mã này cho bạn bè để họ tìm kiếm bạn)"
                                  : "Your ID is: @${widget.currentUserId}\n(Share this with friends so they can find you)",
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
                                hintText: isVN
                                    ? "Nhập ID người dùng để tìm kiếm..."
                                    : "Enter user ID to search...",
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
                                      );
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: _searchQuery.isEmpty
                                ? Center(
                                    child: Text(
                                      isVN
                                          ? "Nhập ID để tìm kiếm..."
                                          : "Enter ID to search...",
                                      style:
                                          const TextStyle(color: Colors.grey),
                                    ),
                                  )
                                : searchList.isEmpty
                                    ? Center(
                                        child: Text(
                                          isVN
                                              ? "Không tìm thấy người dùng với ID này"
                                              : "No user with this ID was found",
                                          style: const TextStyle(
                                              color: Colors.grey),
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
                                          bool requestSent =
                                              theirRequests.contains(
                                            widget.currentUserId,
                                          );

                                          return ListTile(
                                            onTap: () => _openUserProfile(
                                              targetId,
                                              targetName,
                                            ),
                                            leading: CircleAvatar(
                                              backgroundColor:
                                                  Colors.grey.shade200,
                                              backgroundImage: (searchData[
                                                              'avatarUrl'] !=
                                                          null &&
                                                      searchData['avatarUrl']
                                                          .toString()
                                                          .isNotEmpty)
                                                  ? NetworkImage(
                                                      searchData['avatarUrl'])
                                                  : null,
                                              child: (searchData['avatarUrl'] !=
                                                          null &&
                                                      searchData['avatarUrl']
                                                          .toString()
                                                          .isNotEmpty)
                                                  ? null
                                                  : const Icon(Icons.person,
                                                      color: Colors.grey),
                                            ),
                                            title: Text(
                                              targetName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            subtitle: Text("ID: @$targetId"),
                                            trailing: isFriend
                                                ? Text(
                                                    isVN ? "Bạn bè" : "Friends",
                                                    style: const TextStyle(
                                                      color: Colors.green,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  )
                                                : requestSent
                                                    ? Text(
                                                        isVN
                                                            ? "Đã gửi lời mời"
                                                            : "Request sent",
                                                        style: const TextStyle(
                                                          color: Colors.orange,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      )
                                                    : ElevatedButton(
                                                        style: ElevatedButton
                                                            .styleFrom(
                                                          backgroundColor:
                                                              primaryColor,
                                                        ),
                                                        onPressed: () =>
                                                            _sendFriendRequest(
                                                                targetId),
                                                        child: Text(
                                                          isVN
                                                              ? "Kết bạn"
                                                              : "Add Friend",
                                                          style:
                                                              const TextStyle(
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
        });
  }
}

// =====================================================================
// TRANG XEM HỒ SƠ NGƯỜI KHÁC (ĐÃ ĐƯỢC ĐỒNG BỘ VỚI PROFILE PAGE)
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
    try {
      final userRef = FirebaseFirestore.instance.collection('users');
      final userDoc = await userRef.doc(userId).get();

      if (!userDoc.exists || userDoc.data() == null) {
        return {};
      }

      final data = Map<String, dynamic>.from(userDoc.data()!);
      final userPoints = data['points'] ?? 0;

      final higherScoreQuery = await userRef
          .where('points', isGreaterThan: userPoints)
          .count()
          .get();

      int rank = (higherScoreQuery.count ?? 0) + 1;
      data['rank'] = rank;

      // Xử lý lấy thông tin Bạn thân học tập của họ
      if (data['featuredFriendId'] != null) {
        String fId = data['featuredFriendId'];
        var fDoc = await userRef.doc(fId).get();
        if (fDoc.exists) {
          data['featuredFriendName'] = fDoc.data()?['name'] ?? 'Ẩn danh';
          String streakId =
              userId.compareTo(fId) < 0 ? '${userId}_$fId' : '${fId}_$userId';
          var streakDoc = await FirebaseFirestore.instance
              .collection('friend_streaks')
              .doc(streakId)
              .get();
          if (streakDoc.exists) {
            data['featuredFriendStreak'] = streakDoc.data()?['streak'] ?? 0;
          }
        }
      }
      return data;
    } catch (e) {
      debugPrint("Lỗi khi tải thông tin user: $e");
      return {};
    }
  }

  // Khối Card Tiểu sử (Chỉ xem)
  Widget _buildReadOnlyBioSection(bool isVN, String bio) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        padding: const EdgeInsets.all(16),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: primaryColor),
                const SizedBox(width: 8),
                Text(
                  isVN ? "Tiểu sử" : "Bio",
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              bio.isNotEmpty
                  ? bio
                  : (isVN
                      ? "Chưa có dòng giới thiệu nào."
                      : "No bio added yet."),
              style: TextStyle(
                color: bio.isNotEmpty ? Colors.black87 : Colors.grey,
                fontSize: 14,
                fontStyle: bio.isNotEmpty ? FontStyle.normal : FontStyle.italic,
              ),
            ),
          ],
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
                isVN ? "Hồ sơ của $userName" : "$userName's Profile",
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
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                      child: Text(
                          isVN ? "Không thể tải dữ liệu" : "Cannot load data"));
                }

                final data = snapshot.data!;
                final points = data['points'] ?? 0;
                final streak = data['streakCount'] ?? data['streak'] ?? 0;
                final rank = data['rank'] ?? 0;
                final className =
                    data['class'] ?? (isVN ? "Chưa có lớp" : "No class yet");
                final List<dynamic> medals = data['medals'] ?? [];

                final String? avatarUrl = data['avatarUrl']?.toString();
                final String? bannerUrl =
                    data['bannerUrl']?.toString(); // 🔥 Đã lấy Banner
                final String bio = data['bio']?.toString() ?? "";

                String joinDateText = isVN ? "Chưa rõ" : "Unknown";
                if (data['createdAt'] != null) {
                  DateTime date = (data['createdAt'] as Timestamp).toDate();
                  joinDateText =
                      "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
                }

                String rankText;
                if (rank == 1) {
                  rankText =
                      isVN ? "🥇 Hạng 1 (Quán quân)" : "🥇 Rank 1 (Champion)";
                } else if (rank >= 2 && rank <= 10) {
                  rankText = isVN
                      ? "🥈 Hạng $rank (Top 10)"
                      : "🥈 Rank $rank (Top 10)";
                } else if (rank >= 11 && rank <= 50) {
                  rankText = isVN
                      ? "🥉 Hạng $rank (Top 50)"
                      : "🥉 Rank $rank (Top 50)";
                } else if (rank > 50) {
                  rankText = isVN ? "Hạng $rank" : "Rank $rank";
                } else {
                  rankText = isVN ? "Chưa xếp hạng" : "Unranked";
                }

                return SingleChildScrollView(
                  child: Column(
                    children: [
                      // KHUNG AVATAR + BANNER (Thiết kế đồng bộ với ProfilePage)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          image: (bannerUrl != null && bannerUrl.isNotEmpty)
                              ? DecorationImage(
                                  image: NetworkImage(bannerUrl),
                                  fit: BoxFit.cover,
                                  colorFilter: ColorFilter.mode(
                                    Colors.black.withOpacity(0.35),
                                    BlendMode.darken,
                                  ),
                                )
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 25,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Khung Avatar
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child:
                                    (avatarUrl != null && avatarUrl.isNotEmpty)
                                        ? Image.network(
                                            avatarUrl,
                                            width: 100,
                                            height: 100,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                              return Icon(Icons.person,
                                                  color: primaryColor,
                                                  size: 50);
                                            },
                                          )
                                        : Icon(Icons.person,
                                            color: primaryColor, size: 50),
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
                                fontSize: 16,
                                color: Colors.white70,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 15),
                            // Thẻ Chuỗi học tập
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color:
                                    (bannerUrl != null && bannerUrl.isNotEmpty)
                                        ? Colors.black.withOpacity(0.3)
                                        : Colors.white.withOpacity(0.2),
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
                                    isVN
                                        ? "Chuỗi $streak ngày học"
                                        : "$streak-day streak",
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

                      // NỘI DUNG THÔNG TIN BÊN DƯỚI
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // 1. Khối Tiểu sử
                            _buildReadOnlyBioSection(isVN, bio),

                            // 2. Khối Bạn thân nổi bật
                            if (data['featuredFriendId'] != null &&
                                data['featuredFriendStreak'] != null &&
                                data['featuredFriendStreak'] >= 3)
                              Card(
                                elevation: 0,
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                    side: BorderSide(
                                        color: Colors.orange.shade200)),
                                color: Colors.orange.shade50,
                                child: ListTile(
                                  leading: const Icon(Icons.favorite,
                                      color: Colors.redAccent),
                                  title: Text(
                                      isVN
                                          ? "Bạn thân học tập"
                                          : "Study Bestie",
                                      style: const TextStyle(
                                          fontSize: 13, color: Colors.grey)),
                                  subtitle: Row(
                                    children: [
                                      Text(data['featuredFriendName'],
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.black87)),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.local_fire_department,
                                          color: Colors.orange, size: 20),
                                      Text("${data['featuredFriendStreak']}",
                                          style: const TextStyle(
                                              color: Colors.orange,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16)),
                                    ],
                                  ),
                                ),
                              ),

                            // 3. Các Info Card thông tin
                            _infoCard(Icons.alternate_email,
                                isVN ? "ID người dùng" : "User ID", "@$userId"),
                            _infoCard(Icons.military_tech,
                                isVN ? "Xếp hạng" : "Rank", rankText),
                            _infoCard(Icons.workspace_premium,
                                isVN ? "Tổng điểm" : "Total Points", "$points"),
                            _infoCard(
                                Icons.calendar_month,
                                isVN ? "Ngày gia nhập" : "Joined Date",
                                joinDateText),
                            _infoCard(Icons.school, isVN ? "Lớp" : "Class",
                                className),

                            const SizedBox(height: 25),

                            // 4. Khối Huy chương (Giữ nguyên từ bản trước vì tính năng này hữu ích)
                            Text(
                              isVN ? "Huy chương mùa giải" : "Season Medals",
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _buildMedalsSection(medals, isVN),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        });
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

  Widget _buildMedalsSection(List<dynamic> medals, bool isVN) {
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
            Text(
              isVN ? "Chưa có thành tích nào" : "No achievements yet",
              style: const TextStyle(color: Colors.grey, fontSize: 14),
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
                  medal['season'] ?? (isVN ? "Mùa giải" : "Season"),
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
