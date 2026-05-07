// --- MODEL DỮ LIỆU PHÒNG HỌC ---
class StudyRoom {
  final String hostName;
  final String hostId;
  final int points;
  // final String rank;
  final int currentMembers;
  final int maxMembers;
  final String startTime;
  final String endTime;
  final String grade;

  StudyRoom({
    required this.hostName,
    required this.hostId,
    required this.points,
    // required this.rank,
    required this.currentMembers,
    required this.maxMembers,
    required this.startTime,
    required this.endTime,
    required this.grade,
  });
}
