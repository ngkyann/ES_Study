import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/constants/colors.dart';

class LeaderboardPage extends StatelessWidget {
  final String currentUserId;

  const LeaderboardPage({super.key, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Bảng xếp hạng",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      // Thanh hiển thị thứ hạng của bạn cố định ở dưới cùng
      bottomNavigationBar: _buildMyRankSection(),
      body: Container(
        color: Colors.white, // Ép nền trắng để không bị lỗi Dark Mode
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('users')
              .orderBy('points', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: primaryColor),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Text(
                  "Chưa có dữ liệu.",
                  style: TextStyle(color: Colors.black54),
                ),
              );
            }

            final users = snapshot.data!.docs;

            // 🔥 ĐÃ THÊM: RefreshIndicator để vuốt tải lại trang
            return RefreshIndicator(
              color: primaryColor,
              backgroundColor: Colors.white,
              onRefresh: () async {
                // Giả lập thời gian load 1 giây để hiện vòng xoay cho mượt
                await Future.delayed(const Duration(seconds: 1));
              },
              child: ListView.builder(
                // 🔥 BẮT BUỘC: Thêm physics để nội dung ngắn vẫn vuốt được
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  100,
                ), // Cách đáy để không bị đè bởi thanh bottom
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final userData = users[index].data() as Map<String, dynamic>;
                  final String userId = users[index].id;
                  final int rank = index + 1;
                  bool isMe = userId == currentUserId;

                  return _buildLeaderboardItem(
                    rank,
                    userData['name'] ?? 'Ẩn danh',
                    userData['class'] ?? 'Lớp ?',
                    userData['points'] ?? 0,
                    isMe,
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  // --- THANH "HẠNG CỦA TÔI" (CỐ ĐỊNH) ---
  Widget _buildMyRankSection() {
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

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          decoration: BoxDecoration(
            color: primaryColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                _buildRankBadge(myRank, isInsideBottomBar: true),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Hạng của bạn",
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                      Text(
                        myData['name'] ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
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
    int rank,
    String name,
    String className,
    int points,
    bool isMe,
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
                    name + (isMe ? " (Bạn)" : ""),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                  Text(
                    className,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              "$points pt",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: primaryColor,
              ),
            ),
          ],
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
        backgroundColor: isInsideBottomBar
            ? Colors.white24
            : Colors.grey.shade100,
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
