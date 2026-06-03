import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:esstudy/constants/var.dart'; // 🔥 IMPORT BIẾN NGÔN NGỮ
import 'package:esstudy/screens/friends_page.dart';

class LeaderboardPage extends StatelessWidget {
  final String currentUserId;

  const LeaderboardPage({super.key, required this.currentUserId});

  // 🔥 HÀM ĐIỀU HƯỚNG SANG TRANG CÁ NHÂN (Tái sử dụng logic từ FriendsPage)
  void _openUserProfile(
      BuildContext context, String targetId, String targetName) {
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
    // 🔥 BỌC ValueListenableBuilder
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, child) {
        bool isVN = lang == "Tiếng Việt";

        return Scaffold(
          appBar: AppBar(
            title: Text(
              // 🔥 Bỏ const
              isVN ? "Bảng xếp hạng" : "Leaderboard", // 🔥 Đã dịch
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          // Thanh hiển thị thứ hạng của bạn cố định ở dưới cùng
          bottomNavigationBar:
              _buildMyRankSection(context, isVN), // 🔥 Truyền context vào hàm
          body: Container(
            color: Colors.white,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('points', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    // 🔥 Bỏ const
                    child: Text(
                      isVN
                          ? "Chưa có dữ liệu."
                          : "No data available.", // 🔥 Đã dịch
                      style: const TextStyle(color: Colors.black54),
                    ),
                  );
                }

                final users = snapshot.data!.docs;

                return RefreshIndicator(
                  color: primaryColor,
                  backgroundColor: Colors.white,
                  onRefresh: () async {
                    await Future.delayed(const Duration(seconds: 1));
                  },
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: users.length,
                    itemBuilder: (context, index) {
                      final userData =
                          users[index].data() as Map<String, dynamic>;
                      final String userId = users[index].id;
                      final int rank = index + 1;
                      bool isMe = userId == currentUserId;

                      return _buildLeaderboardItem(
                        context, // 🔥 Truyền context xuống item
                        rank,
                        userData['name'] ??
                            (isVN ? 'Ẩn danh' : 'Anonymous'), // 🔥 Đã dịch
                        userId,
                        userData['class'] ??
                            (isVN ? 'Lớp ?' : 'Class ?'), // 🔥 Đã dịch
                        userData['points'] ?? 0,
                        isMe,
                        isVN, // 🔥 Truyền isVN vào hàm
                      );
                    },
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  // --- THANH "HẠNG CỦA TÔI" (CỐ ĐỊNH) ---
  Widget _buildMyRankSection(BuildContext context, bool isVN) {
    // 🔥 NHẬN THÊM BIẾN context
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .orderBy('points', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();

        final docs = snapshot.data!.docs;
        int myRank = 0;
        Map<String, dynamic>? myData;

        for (int i = 0; i < docs.length; i++) {
          if (docs[i].id == currentUserId) {
            myRank = i + 1;
            myData = docs[i].data() as Map<String, dynamic>;
            break;
          }
        }

        if (myData == null) return const SizedBox();

        final String myName = myData['name'] ?? '';

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                _buildRankBadge(myRank, isInsideBottomBar: true),
                const SizedBox(width: 15),
                Expanded(
                  child: InkWell(
                    onTap: () => _openUserProfile(context, currentUserId,
                        myName), // 🔥 Click vào thanh chân trang xem trang cá nhân chính mình
                    borderRadius: BorderRadius.circular(10),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          // 🔥 Bỏ const
                          isVN ? "Hạng của bạn" : "Your Rank", // 🔥 Đã dịch
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          myName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          "@$currentUserId",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  "${myData['points']} pt",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- THẺ NGƯỜI DÙNG (CÓ HUY CHƯƠNG) ---
  Widget _buildLeaderboardItem(
    BuildContext context, // 🔥 NHẬN BIẾN context
    int rank,
    String name,
    String userId,
    String className,
    int points,
    bool isMe,
    bool isVN, // 🔥 NHẬN BIẾN isVN
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isMe ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isMe ? primaryColor : Colors.grey.shade200,
          width: isMe ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      // 🔥 BỌC CARD BẰNG INKWELL ĐỂ TẠO HIỆU ỨNG GỢN SÓNG KHI CLICK VÀO TÊN/DÒNG NGƯỜI ĐÓ
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => _openUserProfile(
            context, userId, name), // 🔥 KÍCH HOẠT SỰ KIỆN CLICK CHUYỂN TRANG
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(width: 50, child: _buildRankBadge(rank)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name +
                          (isMe
                              ? (isVN ? " (Bạn)" : " (You)")
                              : ""), // 🔥 Dịch chữ (Bạn)
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      "@$userId • $className",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                "$points pt",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- LOGIC HIỂN THỊ HUY CHƯƠNG ---
  Widget _buildRankBadge(int rank, {bool isInsideBottomBar = false}) {
    Color textColor = isInsideBottomBar ? Colors.white : Colors.black87;

    if (rank == 1) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, color: Colors.amber, size: 30),
          Text(
            "#1",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      );
    } else if (rank >= 2 && rank <= 10) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, color: Color(0xFFC0C0C0), size: 28),
          Text(
            "#$rank",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      );
    } else if (rank >= 11 && rank <= 50) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.emoji_events, color: Color(0xFFCD7F32), size: 28),
          Text(
            "#$rank",
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ],
      );
    } else {
      return CircleAvatar(
        radius: 16,
        backgroundColor:
            isInsideBottomBar ? Colors.white24 : Colors.grey.shade100,
        child: Text(
          "$rank",
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      );
    }
  }
}
