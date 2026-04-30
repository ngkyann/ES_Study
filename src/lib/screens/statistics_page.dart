import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:esstudy/constants/colors.dart';

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

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
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

          _avgMinutesPerSession = tempSessions > 0
              ? tempMinutes / tempSessions
              : 0.0;
          _avgGoalsPerSession = tempSessions > 0
              ? tempGoals / tempSessions
              : 0.0;

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
      debugPrint("Lỗi tải thống kê: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTotalTime(int totalMins) {
    if (totalMins < 60) return "$totalMins phút";
    int hours = totalMins ~/ 60;
    int mins = totalMins % 60;
    if (mins == 0) return "$hours giờ";
    return "$hours giờ $mins phút";
  }

  IconData _getRankIcon(int rank) {
    if (rank >= 1 && rank <= 50) return Icons.emoji_events;
    return Icons.military_tech;
  }

  Color _getRankColor(int rank) {
    if (rank == 1) return Colors.amber;
    if (rank >= 2 && rank <= 10) return const Color(0xFFC0C0C0);
    if (rank >= 11 && rank <= 50) return const Color(0xFFCD7F32);
    return Colors.blueAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Thống kê học tập",
          style: TextStyle(fontWeight: FontWeight.bold),
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
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 25,
                        horizontal: 10,
                      ),
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
                          const Text(
                            "THÀNH TÍCH HIỆN TẠI",
                            style: TextStyle(
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
                                _getRankIcon(_currentRank),
                                _getRankColor(_currentRank),
                                "#$_currentRank",
                                "Hạng",
                              ),
                              Container(
                                width: 1,
                                height: 50,
                                color: Colors.white30,
                              ),
                              _buildBannerItem(
                                Icons.stars,
                                Colors.white,
                                "$_currentPoints",
                                "Điểm",
                              ),
                              Container(
                                width: 1,
                                height: 50,
                                color: Colors.white30,
                              ),
                              _buildBannerItem(
                                Icons.local_fire_department,
                                Colors.orangeAccent,
                                "$_currentStreak",
                                "Ngày chuỗi",
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),
                    const Text(
                      "Kỷ lục & Tổng quan",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // 🔥 ĐÃ CHỈNH SỬA: Tỷ lệ 1.15 giúp thẻ "lùn" xuống ôm sát nội dung
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.15,
                      children: [
                        _buildStatCard(
                          icon: _getRankIcon(_highestRank),
                          color: _getRankColor(_highestRank),
                          title: "Hạng cao nhất",
                          value: "Top $_highestRank",
                        ),
                        _buildStatCard(
                          icon: Icons.stars,
                          color: Colors.amber.shade600,
                          title: "Điểm cao nhất",
                          value: "$_highestPoints pt",
                        ),
                        _buildStatCard(
                          icon: Icons.whatshot,
                          color: Colors.deepOrange,
                          title: "Chuỗi dài nhất",
                          value: "$_highestStreak ngày",
                        ),
                        _buildStatCard(
                          icon: Icons.timer,
                          color: Colors.orange,
                          title: "Tổng thời gian",
                          value: _formatTotalTime(_totalMinutes),
                        ),
                        _buildStatCard(
                          icon: Icons.event_available,
                          color: Colors.green,
                          title: "Số buổi đã học",
                          value: "$_totalSessions buổi",
                        ),
                        _buildStatCard(
                          icon: Icons.task_alt,
                          color: Colors.blue,
                          title: "Mục tiêu đã xong",
                          value: "$_totalCompletedGoals mục tiêu",
                        ),
                      ],
                    ),

                    const SizedBox(height: 25),
                    const Text(
                      "Chỉ số trung bình",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 15),

                    Container(
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
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.purple.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.hourglass_bottom,
                                color: Colors.purple,
                                size: 34,
                              ),
                            ),
                            title: const Text(
                              "Thời gian trung bình",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              "${_avgMinutesPerSession.toStringAsFixed(1)} phút / buổi",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const Divider(
                            height: 1,
                            indent: 80,
                            endIndent: 20,
                            color: Colors.black12,
                          ),
                          ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.teal.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.pie_chart,
                                color: Colors.teal,
                                size: 34,
                              ),
                            ),
                            title: const Text(
                              "Tốc độ hoàn thành",
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 13,
                              ),
                            ),
                            subtitle: Text(
                              "${_avgGoalsPerSession.toStringAsFixed(1)} mục tiêu / buổi",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

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
        const SizedBox(height: 2),
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

  // 🔥 ĐÃ CHỈNH SỬA: Căn giữa toàn bộ nội dung trong thẻ
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
        mainAxisAlignment: MainAxisAlignment.center, // Căn giữa theo chiều dọc
        crossAxisAlignment:
            CrossAxisAlignment.center, // Căn giữa theo chiều ngang
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 36),
          ),
          const SizedBox(height: 8), // Khoảng cách thay vì dùng Spacer()
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.center, // Căn giữa chữ khi bị co lại
            child: Text(
              value,
              textAlign: TextAlign.center,
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
}
