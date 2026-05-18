import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:esstudy/constants/var.dart'; // 🔥 IMPORT BIẾN NGÔN NGỮ

class StatisticsPage extends StatefulWidget {
  final String userId;

  const StatisticsPage({super.key, required this.userId});

  @override
  State<StatisticsPage> createState() => _StatisticsPageState();
}

class _StatisticsPageState extends State<StatisticsPage> {
  bool _isLoading = true;

  int _totalMinutes = 0;
  int _totalSessions = 0;
  int _totalCompletedGoals = 0;

  double _avgMinutesPerSession = 0.0;
  double _avgGoalsPerSession = 0.0;

  int _currentPoints = 0;
  int _currentRank = 0;
  int _currentStreak = 0;

  int _highestPoints = 0;
  int _highestRank = 0;
  int _highestStreak = 0;

  // 🔥 BIẾN LƯU HUY CHƯƠNG
  List<dynamic> _medals = [];

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      // 1. Tải lịch sử học tập
      final historySnap = await FirebaseFirestore.instance
          .collection('study_history')
          .where('userId', isEqualTo: widget.userId)
          .get();

      int tempMinutes = 0;
      int tempGoals = 0;
      List<DateTime> allStudyDates = [];

      for (var doc in historySnap.docs) {
        final data = doc.data();
        tempMinutes += (data['minutes'] as num?)?.toInt() ?? 0;
        tempGoals += (data['completed'] as num?)?.toInt() ?? 0;
        if (data['time'] != null) {
          allStudyDates.add((data['time'] as Timestamp).toDate());
        }
      }

      int tempSessions = historySnap.docs.length;

      // Tính toán chuỗi ngày dài nhất
      Set<String> uniqueDateStrings = {};
      List<DateTime> sortedUniqueDates = [];
      for (var d in allStudyDates) {
        DateTime dateOnly = DateTime.utc(d.year, d.month, d.day);
        String dStr = "${d.year}-${d.month}-${d.day}";
        if (!uniqueDateStrings.contains(dStr)) {
          uniqueDateStrings.add(dStr);
          sortedUniqueDates.add(dateOnly);
        }
      }
      sortedUniqueDates.sort((a, b) => a.compareTo(b));
      int calcHighestStreak = 0;
      int currentLoopStreak = 0;
      DateTime? previousDate;
      for (var d in sortedUniqueDates) {
        if (previousDate == null) {
          currentLoopStreak = 1;
        } else {
          final difference = d.difference(previousDate).inDays;
          if (difference == 1) {
            currentLoopStreak++;
          } else if (difference > 1) {
            currentLoopStreak = 1;
          }
        }
        if (currentLoopStreak > calcHighestStreak) {
          calcHighestStreak = currentLoopStreak;
        }
        previousDate = d;
      }

      // 2. Tải thông tin User và Rank
      final usersSnap = await FirebaseFirestore.instance
          .collection('users')
          .orderBy('points', descending: true)
          .get();

      int tempRank = 0;
      int tempPoints = 0;
      int tempCurrentStreak = 0;
      Map<String, dynamic>? myData;

      for (int i = 0; i < usersSnap.docs.length; i++) {
        if (usersSnap.docs[i].id == widget.userId) {
          tempRank = i + 1;
          myData = usersSnap.docs[i].data();
          tempPoints = myData['points'] ?? 0;
          tempCurrentStreak = myData['streakCount'] ?? 0;
          _medals = myData['medals'] ?? [];
          break;
        }
      }

      int savedHighestRank = myData?['highestRank'] ?? tempRank;
      int savedHighestPoints = myData?['highestPoints'] ?? tempPoints;
      int savedHighestStreak = myData?['highestStreak'] ?? 0;
      bool needsUpdateRecord = false;

      if (tempPoints > savedHighestPoints) {
        savedHighestPoints = tempPoints;
        needsUpdateRecord = true;
      }
      if (savedHighestRank == 0 || tempRank < savedHighestRank) {
        savedHighestRank = tempRank;
        needsUpdateRecord = true;
      }
      if (calcHighestStreak > savedHighestStreak) {
        savedHighestStreak = calcHighestStreak;
        needsUpdateRecord = true;
      }

      if (needsUpdateRecord) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .set({
          'highestRank': savedHighestRank,
          'highestPoints': savedHighestPoints,
          'highestStreak': savedHighestStreak,
        }, SetOptions(merge: true));
      }

      if (mounted) {
        setState(() {
          _totalSessions = tempSessions;
          _totalMinutes = tempMinutes;
          _totalCompletedGoals = tempGoals;
          _avgMinutesPerSession =
              tempSessions > 0 ? tempMinutes / tempSessions : 0.0;
          _avgGoalsPerSession =
              tempSessions > 0 ? tempGoals / tempSessions : 0.0;
          _currentPoints = tempPoints;
          _currentRank = tempRank;
          _currentStreak = tempCurrentStreak;
          _highestPoints = savedHighestPoints;
          _highestRank = savedHighestRank;
          _highestStreak = savedHighestStreak;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Lỗi tải thành tích: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // 🔥 NHẬN THÊM BIẾN isVN ĐỂ DỊCH ĐƠN VỊ THỜI GIAN
  String _formatTotalTime(int totalMins, bool isVN) {
    if (totalMins < 60) return "$totalMins ${isVN ? 'phút' : 'mins'}";
    int hours = totalMins ~/ 60;
    int mins = totalMins % 60;
    if (mins == 0) return "$hours ${isVN ? 'giờ' : 'hrs'}";
    return "$hours ${isVN ? 'giờ' : 'hrs'} $mins ${isVN ? 'phút' : 'mins'}";
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 BỌC ValueListenableBuilder CHO TOÀN BỘ GIAO DIỆN
    return ValueListenableBuilder<String>(
      valueListenable: languageNotifier,
      builder: (context, lang, child) {
        bool isVN = lang == "Tiếng Việt";

        return Scaffold(
          backgroundColor: Colors.grey.shade50,
          appBar: AppBar(
            title: Text(
              isVN ? "Thành tích học tập" : "Achievements", // 🔥 DỊCH
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            centerTitle: true,
            elevation: 0,
          ),
          body: _isLoading
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : RefreshIndicator(
                  color: primaryColor,
                  backgroundColor: Colors.white,
                  onRefresh: _loadStatistics,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- Banner Thành tích hiện tại ---
                        _buildTopBanner(isVN), // 🔥 Truyền isVN

                        const SizedBox(height: 25),
                        Text(
                          isVN
                              ? "Kỷ lục & Tổng quát"
                              : "Records & Overview", // 🔥 DỊCH
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 15),

                        // Grid chỉ số
                        _buildStatGrid(isVN), // 🔥 Truyền isVN

                        const SizedBox(height: 25),
                        Text(
                          isVN ? "Chỉ số học tập" : "Study Metrics", // 🔥 DỊCH
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 15),

                        // Chỉ số trung bình
                        _buildAverageSection(isVN), // 🔥 Truyền isVN

                        const SizedBox(height: 25),
                        // HUY CHƯƠNG DANH GIÁ
                        Text(
                          isVN
                              ? "Huy chương mùa giải"
                              : "Season Medals", // 🔥 DỊCH
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 15),
                        _buildMedalsSection(isVN), // 🔥 Truyền isVN

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  // --- Widget: Banner trên cùng ---
  Widget _buildTopBanner(bool isVN) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 25, horizontal: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryColor, primaryColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            isVN ? "THỨ HẠNG HIỆN TẠI" : "CURRENT RANKING", // 🔥 DỊCH
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildBannerItem(
                Icons.emoji_events,
                Colors.amber,
                "#$_currentRank",
                isVN ? "Hạng" : "Rank", // 🔥 DỊCH
              ),
              Container(width: 1, height: 50, color: Colors.white30),
              _buildBannerItem(
                Icons.stars,
                Colors.white,
                "$_currentPoints",
                isVN ? "Điểm" : "Points", // 🔥 DỊCH
              ),
              Container(width: 1, height: 50, color: Colors.white30),
              _buildBannerItem(
                Icons.local_fire_department,
                Colors.orangeAccent,
                "$_currentStreak",
                isVN ? "Ngày chuỗi" : "Streak", // 🔥 DỊCH
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- Widget: Grid chỉ số kỷ lục ---
  Widget _buildStatGrid(bool isVN) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.15,
      children: [
        _buildStatCard(
          icon: Icons.military_tech,
          color: Colors.blueAccent,
          title: isVN ? "Hạng cao nhất" : "Highest Rank", // 🔥 DỊCH
          value: "Top $_highestRank",
        ),
        _buildStatCard(
          icon: Icons.stars,
          color: Colors.amber.shade600,
          title: isVN ? "Điểm cao nhất" : "Highest Points", // 🔥 DỊCH
          value: "$_highestPoints pt",
        ),
        _buildStatCard(
          icon: Icons.whatshot,
          color: Colors.deepOrange,
          title: isVN ? "Chuỗi dài nhất" : "Longest Streak", // 🔥 DỊCH
          value: "$_highestStreak ${isVN ? 'ngày' : 'days'}", // 🔥 DỊCH
        ),
        _buildStatCard(
          icon: Icons.timer,
          color: Colors.orange,
          title: isVN ? "Tổng thời gian" : "Total Time", // 🔥 DỊCH
          value: _formatTotalTime(_totalMinutes, isVN), // 🔥 DỊCH TRONG HÀM
        ),
        _buildStatCard(
          icon: Icons.event_available,
          color: Colors.green,
          title: isVN ? "Số buổi đã học" : "Total Sessions", // 🔥 DỊCH
          value: "$_totalSessions ${isVN ? 'buổi' : 'sessions'}", // 🔥 DỊCH
        ),
        _buildStatCard(
          icon: Icons.task_alt,
          color: Colors.blue,
          title: isVN ? "Mục tiêu đã xong" : "Goals Completed", // 🔥 DỊCH
          value: "$_totalCompletedGoals",
        ),
      ],
    );
  }

  // --- Widget: Các chỉ số trung bình ---
  Widget _buildAverageSection(bool isVN) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildAverageTile(
            Icons.hourglass_bottom,
            Colors.purple,
            isVN ? "Thời gian trung bình" : "Average Time", // 🔥 DỊCH
            "${_avgMinutesPerSession.toStringAsFixed(1)} ${isVN ? 'phút / buổi' : 'mins / session'}", // 🔥 DỊCH
          ),
          const Divider(
            height: 1,
            indent: 80,
            endIndent: 20,
            color: Colors.black12,
          ),
          _buildAverageTile(
            Icons.pie_chart,
            Colors.teal,
            isVN ? "Tốc độ hoàn thành" : "Completion Rate", // 🔥 DỊCH
            "${_avgGoalsPerSession.toStringAsFixed(1)} ${isVN ? 'mục tiêu / buổi' : 'goals / session'}", // 🔥 DỊCH
          ),
        ],
      ),
    );
  }

  // 🔥 WIDGET HIỂN THỊ CÚP ĐỒNG BỘ VỚI LOGIC CỦA LEADERBOARD
  Widget _buildMedalsSection(bool isVN) {
    if (_medals.isEmpty) {
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
              size: 60,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 10),
            Text(
              // 🔥 Đã xóa const
              isVN ? "Chưa có thành tích" : "No achievements yet", // 🔥 DỊCH
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              // 🔥 Đã xóa const
              isVN
                  ? "Hãy cố gắng lọt top mùa giải này nhé!"
                  : "Try to reach the top this season!", // 🔥 DỊCH
              style: const TextStyle(color: Colors.grey, fontSize: 13),
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
        childAspectRatio: 0.75, // Kéo dài card ra một chút để vừa chữ
      ),
      itemCount: _medals.length,
      itemBuilder: (context, index) {
        final medal = _medals[index];
        int rank = medal['rank'] ?? 100; // Mặc định nếu lỗi là rank thấp

        IconData medalIcon;
        Color medalColor;

        // 🔥 LOGIC ĐỒNG BỘ VỚI BẢNG XẾP HẠNG
        if (rank == 1) {
          medalIcon = Icons.emoji_events;
          medalColor = Colors.amber; // Top 1: Cúp Vàng
        } else if (rank >= 2 && rank <= 10) {
          medalIcon = Icons.emoji_events;
          medalColor = const Color(0xFFC0C0C0); // Top 2-10: Cúp Bạc
        } else if (rank >= 11 && rank <= 50) {
          medalIcon = Icons.emoji_events;
          medalColor = const Color(0xFFCD7F32); // Top 11-50: Cúp Đồng
        } else {
          medalIcon = Icons.military_tech;
          medalColor = Colors.blueAccent; // Huy chương an ủi cho top 51+
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
              // Hiệu ứng "Tỏa sáng" nhẹ đằng sau cúp
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: medalColor.withOpacity(0.15),
                ),
                child: Icon(medalIcon, size: 38, color: medalColor),
              ),
              const SizedBox(height: 10),

              // Tên thành tích
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: Text(
                  medal['name'] ?? "Top $rank",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 4),

              // Nhãn Mùa giải
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  medal['season'] ?? (isVN ? "Mùa giải" : "Season"), // 🔥 DỊCH
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

  // --- Các hàm build nhỏ trợ giúp ---
  Widget _buildBannerItem(
    IconData icon,
    Color iconColor,
    String value,
    String label,
  ) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 42),
        const SizedBox(height: 6),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: primaryColor.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 36),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAverageTile(
    IconData icon,
    Color color,
    String title,
    String value,
  ) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 28),
      ),
      title: Text(
        title,
        style: const TextStyle(color: Colors.grey, fontSize: 13),
      ),
      subtitle: Text(
        value,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.black87,
        ),
      ),
    );
  }
}
