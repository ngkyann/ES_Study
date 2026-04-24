import 'package:flutter/material.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:esstudy/models/study_room.dart';

class RoomCard extends StatelessWidget {
  final StudyRoom room;
  final VoidCallback? onJoin;

  const RoomCard({super.key, required this.room, this.onJoin});

  @override
  Widget build(BuildContext context) {
    bool isFull = room.currentMembers >= room.maxMembers;
    return Card(
      elevation: 0,
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: primaryColor,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          room.hostName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          room.hostId,
                          style: const TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    "${room.currentMembers}/${room.maxMembers}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isFull ? Colors.red : Colors.green,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${room.grade} • ${room.points} điểm",
                        style: const TextStyle(fontSize: 13),
                      ),
                      Text(
                        "Hạng: ${room.rank}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.blueGrey,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        "Thời gian học:",
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      Text(
                        "${room.startTime}/${room.endTime}",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isFull ? null : onJoin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text("Vào phòng"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
