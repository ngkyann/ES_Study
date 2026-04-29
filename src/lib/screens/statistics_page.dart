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

  // 🔥 ĐÃ THÊM: Biến lưu trữ Chuỗi ngày học
  int _currentStreak = 0;
  int _highestStreak = 0;

  int _highestPoints = 0;
  int _highestRank = 0;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    try {
      // 1. Tải Lịch sử học tập
      final historySnap = await FirebaseFirestore.instance
          .collection('study_history')
          .where('userId', isEqualTo: widget.userId)
          .get();

      int tempMinutes = 0;
      int tempGoals = 0;

      // Phục vụ tính toán chuỗi ngày
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

      // 🔥 THUẬT TOÁN: Tính Chuỗi ngày học dài nhất từ Lịch sử
      Set<String> uniqueDateStrings = {};
      List<DateTime> sortedUniqueDates = [];

      for (var d in allStudyDates) {
        // Cố định giờ về UTC 00:00:00 để tính khoảng cách ngày chính xác
        DateTime dateOnly = DateTime.utc(d.year, d.month, d.day);
        String dStr = "${d.year}-${d.month}-${d.day}";
        if (!uniqueDateStrings.contains(dStr)) {
          uniqueDateStrings.add(dStr);
          sortedUniqueDates.add(dateOnly);
        }
      }

      // Sắp xếp ngày từ cũ đến mới
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
            currentLoopStreak++; // Ngày liên tiếp -> Tăng chuỗi
          } else if (difference > 1) {
            currentLoopStreak = 1; // Bị đứt chuỗi -> Reset về 1
          }
        }
        if (currentLoopStreak > calcHighestStreak) {
          calcHighestStreak = currentLoopStreak;
        }
        previousDate = d;
      }

      // 2. Tải Bảng xếp hạng để lấy Điểm, Hạng hiện tại và Cập nhật Kỷ lục
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
          tempCurrentStreak = myData['streakCount'] ?? 0; // Lấy chuỗi hiện tại
          break;
        }
      }

      // Lấy kỷ lục cũ
      int savedHighestRank = myData?['highestRank'] ?? tempRank;
      int savedHighestPoints = myData?['highestPoints'] ?? tempPoints;
      int savedHighestStreak = myData?['highestStreak'] ?? 0;
      bool needsUpdateRecord = false;

      // So sánh để cập nhật kỷ lục mới
      if (tempPoints > savedHighestPoints) {
        savedHighestPoints = tempPoints;
        needsUpdateRecord = true;
      }
      if (savedHighestRank == 0 || tempRank < savedHighestRank) {
        savedHighestRank = tempRank;
        needsUpdateRecord = true;
      }
      // Ưu tiên lấy giá trị lớn hơn giữa tính toán tự động và lịch sử đã lưu
      if (calcHighestStreak > savedHighestStreak) {
        savedHighestStreak = calcHighestStreak;
        needsUpdateRecord = true;
      }

      // Lưu kỷ lục mới lên Firebase (nếu có phá kỷ lục)
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
                      padding: const EdgeInsets.all(20),
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
                          const Icon(
                            Icons.workspace_premium,
                            color: Colors.yellow,
                            size: 50,
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            "Thành tích hiện tại",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Hạng $_currentRank",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Text(
                                  "•",
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 24,
                                  ),
                                ),
                              ),
                              Text(
                                "$_currentPoints Điểm",
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 25),
                    const Text(
                      "Tổng quan quá trình",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 15),

                    // 🔥 ĐÃ CẬP NHẬT: Lưới 8 ô cực kỳ cân đối
                    GridView.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.1,
                      children: [
                        _buildStatCard(
                          icon: Icons.military_tech,
                          color: Colors.redAccent,
                          title: "Hạng cao nhất",
                          value: "Top $_highestRank",
                        ),
                        _buildStatCard(
                          icon: Icons.stars,
                          color: Colors.amber.shade600,
                          title: "Điểm cao nhất",
                          value: "$_highestPoints pt",
                        ),
                        // 🔥 ĐÃ THÊM: Chuỗi hiện tại và Kỷ lục chuỗi
                        _buildStatCard(
                          icon: Icons.local_fire_department,
                          color: Colors.deepOrange,
                          title: "Chuỗi hiện tại",
                          value: "$_currentStreak ngày",
                        ),
                        _buildStatCard(
                          icon: Icons.whatshot,
                          color: Colors.red,
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
                        _buildStatCard(
                          icon: Icons.hourglass_bottom,
                          color: Colors.purple,
                          title: "Trung bình/buổi",
                          value:
                              "${_avgMinutesPerSession.toStringAsFixed(1)} phút",
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: primaryColor, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.teal.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.pie_chart,
                              color: Colors.teal,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 15),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "Tốc độ hoàn thành",
                                style: TextStyle(
                                  color: Colors.grey,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "${_avgGoalsPerSession.toStringAsFixed(1)} mục tiêu / buổi",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 18,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
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

  Widget _buildStatCard({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const Spacer(),
          Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
