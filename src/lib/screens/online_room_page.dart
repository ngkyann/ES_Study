import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:audioplayers/audioplayers.dart';

class OnlineRoomPage extends StatefulWidget {
  final bool isHost;
  final String roomId;
  final String roomName;
  final String userId;
  final String userName;
  final int duration;
  final int maxMembers;
  final String? planId;
  final String planTitle;
  final List<String> goals;

  final bool isPrivate;
  final String? roomCode;

  const OnlineRoomPage({
    super.key,
    required this.isHost,
    required this.roomId,
    required this.roomName,
    required this.userId,
    required this.userName,
    required this.duration,
    required this.maxMembers,
    this.planId,
    required this.planTitle,
    required this.goals,
    this.isPrivate = false,
    this.roomCode,
  });

  @override
  State<OnlineRoomPage> createState() => _OnlineRoomPageState();
}

class _OnlineRoomPageState extends State<OnlineRoomPage>
    with WidgetsBindingObserver {
  // WEBRTC
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  final Map<String, RTCPeerConnection> _peers = {};
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  final Map<String, String> _remoteNames = {};
  final Map<String, Map<String, bool>> _remoteStates = {};

  bool _isMuted = true;
  bool _isVideoOff = true;
  bool _isChatOpen = false;

  // CHAT & NOTIFICATIONS
  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  int _unreadMessages = 0;
  bool _isFirstMessageFetch = true;

  // HỆ THỐNG
  int _remainingSeconds = 0;
  Timer? _timer;
  late List<bool> _personalTaskStatus;
  final player = AudioPlayer();

  // ANTI-AFK
  final Random _random = Random();
  int _maxAfkChecks = 0;
  int _afkCheckCount = 0;
  int _secondsSinceLastAfk = 0;
  int _nextAfkTargetSeconds = 0;
  bool _showAfkBubble = false;
  int _afkTimeoutSeconds = 300;
  double _bubbleX = 0.5;
  double _bubbleY = 0.5;
  bool _isAfkDialogOpen = false;

  final Map<String, List<RTCIceCandidate>> _candidateQueue = {};
  StreamSubscription? _participantsSub;
  StreamSubscription? _signalingSub;
  StreamSubscription? _messageSub;

  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
      {'urls': 'stun:stun3.l.google.com:19302'},
      {'urls': 'stun:stun4.l.google.com:19302'},
    ],
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _personalTaskStatus = List.generate(widget.goals.length, (_) => false);

    _maxAfkChecks = widget.duration ~/ 15;
    if (_maxAfkChecks > 0) {
      _nextAfkTargetSeconds = _random.nextInt(121) + 780;
    }
    _initRoom();
    _startTimer();
  }

  void _startTimer() {
    _remainingSeconds = widget.duration * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;

      if (_showAfkBubble) {
        setState(() => _afkTimeoutSeconds--);
        if (_afkTimeoutSeconds <= 0) {
          timer.cancel();
          _failAfkCheck();
          return;
        }
      } else if (_afkCheckCount < _maxAfkChecks) {
        _secondsSinceLastAfk++;
        if (_secondsSinceLastAfk >= _nextAfkTargetSeconds) {
          _triggerAfkBubble();
        }
      }

      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        _leaveRoom(isFinishedNatural: true);
      }
    });
  }

  Future<void> _initRoom() async {
    await [Permission.camera, Permission.microphone].request();
    await _localRenderer.initialize();
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'video': true,
        'audio': {'echoCancellation': true, 'noiseSuppression': true},
      });

      if (_localStream != null) {
        _localStream!.getAudioTracks().forEach(
              (track) => track.enabled = false, // Khởi tạo ban đầu bị Muted
            );
        _localStream!.getVideoTracks().forEach(
              (track) => track.enabled = false, // Khởi tạo ban đầu tắt Cam
            );
        Helper.setSpeakerphoneOn(true);
      }
      if (mounted) setState(() => _localRenderer.srcObject = _localStream);
    } catch (e) {
      debugPrint("Lỗi Camera: $e");
    }

    String myClass = "Lớp ?";
    int myPoints = 0;
    if (widget.isHost) {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get();
      if (userDoc.exists) {
        myClass = userDoc.data()?['class'] ?? "Lớp ?";
        myPoints = userDoc.data()?['points'] ?? 0;
      }
    }

    final roomRef =
        FirebaseFirestore.instance.collection('study_rooms').doc(widget.roomId);
    final myInitialState = {'micOff': true, 'camOff': true};

    if (widget.isHost) {
      await roomRef.set({
        'roomName': widget.roomName,
        'hostId': widget.userId,
        'hostName': widget.userName,
        'hostClass': myClass,
        'hostPoints': myPoints,
        'duration': widget.duration,
        'maxMembers': widget.maxMembers,
        'isPrivate': widget.isPrivate,
        'roomCode': widget.roomCode,
        'createdAt': FieldValue.serverTimestamp(),
        'participants': [widget.userId],
        'participantNames': {widget.userId: widget.userName},
        'participantStates': {widget.userId: myInitialState},
      });
      if (widget.isPrivate && widget.roomCode != null) _showRoomCodeDialog();
    } else {
      await roomRef.update({
        'participants': FieldValue.arrayUnion([widget.userId]),
        'participantNames.${widget.userId}': widget.userName,
        'participantStates.${widget.userId}': myInitialState,
      });
    }
    _sendSystemMessage("${widget.userName} đã vào phòng.");

    // Lắng nghe tín hiệu Signaling NGAY TỪ ĐẦU (Để không lỡ Offer)
    _signalingSub = FirebaseFirestore.instance
        .collection('study_rooms')
        .doc(widget.roomId)
        .collection('signaling')
        .doc(widget.userId)
        .collection('messages')
        .snapshots()
        .listen((snap) {
      for (var change in snap.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;
          _handleSignalingMessage(data['from'], data);
          change.doc.reference.delete();
        }
      }
    });

    _messageSub = FirebaseFirestore.instance
        .collection('study_rooms')
        .doc(widget.roomId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .limit(1)
        .snapshots()
        .listen((snap) {
      if (snap.docChanges.isNotEmpty &&
          snap.docChanges.first.type == DocumentChangeType.added) {
        if (_isFirstMessageFetch) {
          _isFirstMessageFetch = false;
          return;
        }

        final msg = snap.docChanges.first.doc.data();
        if (msg != null &&
            msg['senderId'] != widget.userId &&
            msg['senderId'] != 'system') {
          if (!_isChatOpen && mounted) {
            setState(() => _unreadMessages++);
            try {
              player.play(AssetSource('sounds/ting.mp3'));
            } catch (_) {}
          }
        }
      }
    });

    _participantsSub = roomRef.snapshots().listen((snap) {
      if (!snap.exists) {
        if (!widget.isHost && mounted) {
          _showHostLeftDialogAndExit();
        }
        return;
      }

      final data = snap.data()!;
      final names = Map<String, dynamic>.from(data['participantNames'] ?? {});
      final states = Map<String, dynamic>.from(data['participantStates'] ?? {});

      states.forEach((pid, stateData) {
        if (pid != widget.userId) {
          _remoteStates[pid] = {
            'micOff': stateData['micOff'] == true,
            'camOff': stateData['camOff'] == true,
          };
        }
      });

      names.forEach((pid, pname) {
        if (pid != widget.userId && !_peers.containsKey(pid)) {
          _remoteNames[pid] = pname;
          Future.delayed(const Duration(milliseconds: 500), () {
            if (!mounted || _peers.containsKey(pid)) return; // Tránh gọi 2 lần
            // 🔥 BUG FIX 1: Xác định Caller rạch ròi bằng so sánh ID
            // Điều này tránh trường hợp 2 máy cùng tạo Offer đè lên nhau.
            bool amICaller = widget.userId.compareTo(pid) > 0;
            _createPeerConnection(pid, isCaller: amICaller);
          });
        }
      });

      final currentIds = names.keys.toSet();
      final myPeers = _peers.keys.toSet();
      for (var id in myPeers) {
        if (!currentIds.contains(id)) _removePeer(id);
      }
      if (mounted) setState(() {});
    });
  }

  void _showHostLeftDialogAndExit() {
    _timer?.cancel();
    for (var id in _peers.keys) {
      _peers[id]?.close();
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 8),
            Text("Phòng đã đóng"),
          ],
        ),
        content: const Text(
          "Chủ phòng (Host) đã rời đi. Phòng học đã bị giải tán, hẹn gặp lại bạn lần sau nhé!",
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text(
                "Đã hiểu",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _triggerAfkBubble() {
    setState(() {
      _showAfkBubble = true;
      _afkTimeoutSeconds = 300;
      _bubbleX = _random.nextDouble();
      _bubbleY = _random.nextDouble();
      _afkCheckCount++;
      _secondsSinceLastAfk = 0;
      _nextAfkTargetSeconds = _random.nextInt(121) + 780;
    });
    try {
      player.play(AssetSource('sounds/ting.mp3'));
    } catch (_) {}
  }

  void _failAfkCheck() {
    if (_isAfkDialogOpen) Navigator.pop(context);
    _leaveRoomLogic(isFailedAFK: true, isFinishedNatural: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text("Phiên học bị hủy"),
          ],
        ),
        content: const Text(
          "Bạn đã treo máy quá 5 phút mà không phản hồi bong bóng điểm danh. Phiên học đã bị hủy và không được tính điểm.",
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text(
                "Đã hiểu",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onBubbleTap() {
    final TextEditingController afkController = TextEditingController();
    _isAfkDialogOpen = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.mark_chat_unread, color: primaryColor),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                "Báo cáo tiến độ!",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Chào bạn! Bạn đang học gì thế? Ghi chú lại một chút nhé để chứng minh bạn vẫn đang tập trung!",
            ),
            const SizedBox(height: 15),
            TextField(
              controller: afkController,
              autofocus: true,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: "Ví dụ: Đang giải toán...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              if (afkController.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                setState(() => _showAfkBubble = false);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      "Ôi chúa ơi! Bạn lười quá, gõ ít nhất 1 chữ đi nào!",
                    ),
                  ),
                );
              }
            },
            child: const Text(
              "Tiếp tục học",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    ).then((_) => _isAfkDialogOpen = false);
  }

  Future<void> _createPeerConnection(
    String peerId, {
    required bool isCaller,
  }) async {
    final pc = await createPeerConnection(_iceServers);
    _peers[peerId] = pc;

    final renderer = RTCVideoRenderer();
    await renderer.initialize();
    _remoteRenderers[peerId] = renderer;
    if (mounted) setState(() {});

    // 🔥 BUG FIX 2: Thay `addStream` bằng `addTrack` để WebRTC thế hệ mới chạy mượt
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        pc.addTrack(track, _localStream!);
      });
    }

    // 🔥 Sửa `onAddStream` sang `onTrack`
    pc.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        renderer.srcObject = event.streams[0];
        if (mounted) setState(() {});
      }
    };

    pc.onIceCandidate = (candidate) {
      _sendSignaling(peerId, {
        'type': 'candidate',
        'candidate': candidate.toMap(),
      });
    };

    if (isCaller) {
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      _sendSignaling(peerId, {'type': 'offer', 'sdp': offer.sdp});
    }
  }

  void _drainQueue(String peerId, RTCPeerConnection pc) async {
    if (_candidateQueue.containsKey(peerId)) {
      for (var c in _candidateQueue[peerId]!) {
        await pc.addCandidate(c);
      }
      _candidateQueue.remove(peerId);
    }
  }

  Future<void> _handleSignalingMessage(
    String fromPeerId,
    Map<String, dynamic> data,
  ) async {
    final type = data['type'];

    // Nếu chưa có connection, tạo mới dưới quyền Callee (Người nghe)
    if (!_peers.containsKey(fromPeerId)) {
      await _createPeerConnection(fromPeerId, isCaller: false);
    }

    final pc = _peers[fromPeerId]!;

    if (type == 'offer') {
      await pc.setRemoteDescription(RTCSessionDescription(data['sdp'], type));
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      _sendSignaling(fromPeerId, {'type': 'answer', 'sdp': answer.sdp});
      _drainQueue(fromPeerId, pc); // Xả hàng đợi ICE
    } else if (type == 'answer') {
      await pc.setRemoteDescription(RTCSessionDescription(data['sdp'], type));
      _drainQueue(fromPeerId, pc);
    } else if (type == 'candidate') {
      final candMap = data['candidate'];
      final candidate = RTCIceCandidate(
        candMap['candidate'],
        candMap['sdpMid'],
        candMap['sdpMLineIndex'],
      );

      // 🔥 BUG FIX 3: Chỉ cho add ICE Candidate sau khi đã SetRemoteDescription
      var remoteDesc = await pc.getRemoteDescription();
      if (remoteDesc != null) {
        await pc.addCandidate(candidate);
      } else {
        _candidateQueue.putIfAbsent(fromPeerId, () => []).add(candidate);
      }
    }
  }

  void _sendSignaling(String toPeerId, Map<String, dynamic> data) {
    data['from'] = widget.userId;
    FirebaseFirestore.instance
        .collection('study_rooms')
        .doc(widget.roomId)
        .collection('signaling')
        .doc(toPeerId)
        .collection('messages')
        .add(data);
  }

  void _removePeer(String peerId) {
    _peers[peerId]?.close();
    _peers.remove(peerId);
    _remoteRenderers[peerId]?.dispose();
    _remoteRenderers.remove(peerId);
    _remoteNames.remove(peerId);
    _remoteStates.remove(peerId);
    if (mounted) setState(() {});
  }

  void _toggleMic() {
    if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
      bool newMuteState = !_isMuted;
      _localStream!.getAudioTracks()[0].enabled = !newMuteState;
      setState(() => _isMuted = newMuteState);

      FirebaseFirestore.instance
          .collection('study_rooms')
          .doc(widget.roomId)
          .update({'participantStates.${widget.userId}.micOff': _isMuted});
    }
  }

  void _toggleVideo() {
    if (_localStream != null && _localStream!.getVideoTracks().isNotEmpty) {
      bool newVideoState = !_isVideoOff;
      _localStream!.getVideoTracks()[0].enabled = !newVideoState;
      setState(() => _isVideoOff = newVideoState);

      FirebaseFirestore.instance
          .collection('study_rooms')
          .doc(widget.roomId)
          .update({'participantStates.${widget.userId}.camOff': _isVideoOff});
    }
  }

  Future<void> _leaveRoom({required bool isFinishedNatural}) async {
    if (!isFinishedNatural) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text("Thoát giữa chừng?"),
            ],
          ),
          content: const Text(
            "Bạn có chắc muốn rời đi? Rời phòng lúc này sẽ KHÔNG được cộng điểm và tiến trình không được lưu.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text(
                "Tiếp tục học",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Thoát luôn",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }
    await _leaveRoomLogic(
      isFailedAFK: false,
      isFinishedNatural: isFinishedNatural,
    );
  }

  Future<void> _leaveRoomLogic({
    required bool isFailedAFK,
    required bool isFinishedNatural,
  }) async {
    _timer?.cancel();

    for (var id in _peers.keys) {
      _peers[id]?.close();
    }

    final roomRef =
        FirebaseFirestore.instance.collection('study_rooms').doc(widget.roomId);
    final roomSnap = await roomRef.get();
    int currentParticipants = 1;

    if (roomSnap.exists) {
      final data = roomSnap.data() as Map<String, dynamic>;
      currentParticipants = List.from(data['participants'] ?? []).length;

      if (widget.isHost) {
        await roomRef.delete();
      } else {
        await roomRef.update({
          'participants': FieldValue.arrayRemove([widget.userId]),
          'participantNames.${widget.userId}': FieldValue.delete(),
          'participantStates.${widget.userId}': FieldValue.delete(),
        });
        await _sendSystemMessage("${widget.userName} đã rời phòng.");
      }
    }

    if (isFailedAFK || !isFinishedNatural) {
      if (mounted && !isFailedAFK) {
        Navigator.pop(context);
      }
      return;
    }

    final int actualMinutes = widget.duration;
    int earnedPoints = actualMinutes * currentParticipants;

    List<String> finishedTasks = [];
    for (int i = 0; i < widget.goals.length; i++) {
      if (_personalTaskStatus[i]) finishedTasks.add(widget.goals[i]);
    }

    await FirebaseFirestore.instance.collection('study_history').add({
      'userId': widget.userId,
      'time': DateTime.now(),
      'planTitle': "${widget.planTitle} (Học Online)",
      'goals': widget.goals,
      'completedGoalsList': finishedTasks,
      'completed': finishedTasks.length,
      'total': widget.goals.length,
      'minutes': actualMinutes,
    });

    final userRef =
        FirebaseFirestore.instance.collection('users').doc(widget.userId);
    final userDoc = await userRef.get();
    int newStreak = 1;
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);

    if (userDoc.exists && userDoc.data() != null) {
      final userData = userDoc.data()!;
      int currentStreak = userData['streakCount'] ?? 0;
      Timestamp? lastStudyTs = userData['lastStudyDate'];
      if (lastStudyTs != null) {
        DateTime lastStudy = lastStudyTs.toDate();
        DateTime lastStudyDay = DateTime(
          lastStudy.year,
          lastStudy.month,
          lastStudy.day,
        );
        int difference = today.difference(lastStudyDay).inDays;
        if (difference == 0) {
          newStreak = currentStreak;
        } else if (difference == 1) {
          newStreak = currentStreak + 1;
        }
      }
    }

    await userRef.set({
      'points': FieldValue.increment(earnedPoints),
      'streakCount': newStreak,
      'lastStudyDate': Timestamp.fromDate(now),
    }, SetOptions(merge: true));

    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("Xuất sắc! 🎉", textAlign: TextAlign.center),
          content: Text(
            "Bạn đã kiên trì suốt $actualMinutes phút!\nSố người cùng học: $currentParticipants người\n\n🎁 Thưởng: +$earnedPoints điểm",
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16),
          ),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "Nhận thưởng",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      );
      Navigator.pop(context);
    }
  }

  void _showRoomCodeDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Phòng Riêng Tư", textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Gửi mã này cho bạn bè để tham gia:"),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                widget.roomCode!,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 5,
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            icon: const Icon(Icons.copy, color: Colors.white),
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.roomCode!));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Đã sao chép mã phòng!")),
              );
              Navigator.pop(ctx);
            },
            label: const Text("Copy", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendSystemMessage(String text) async {
    await FirebaseFirestore.instance
        .collection('study_rooms')
        .doc(widget.roomId)
        .collection('messages')
        .add({
      'senderId': 'system',
      'senderName': 'Hệ thống',
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'isSystem': true,
    });
  }

  Future<void> _sendMessage() async {
    if (_chatController.text.trim().isEmpty) return;
    final text = _chatController.text.trim();
    _chatController.clear();
    await FirebaseFirestore.instance
        .collection('study_rooms')
        .doc(widget.roomId)
        .collection('messages')
        .add({
      'senderId': widget.userId,
      'senderName': widget.userName,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'isSystem': false,
    });
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _leaveRoomLogic(isFailedAFK: true, isFinishedNatural: false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _participantsSub?.cancel();
    _signalingSub?.cancel();
    _messageSub?.cancel();
    player.dispose();
    for (var id in _peers.keys) {
      _peers[id]?.close();
      _remoteRenderers[id]?.dispose();
    }
    _localStream?.getTracks().forEach((track) => track.stop());
    _localStream?.dispose();
    _localRenderer.dispose();
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> videoWidgets = [];
    videoWidgets.add(
      _buildVideoView(
        _localRenderer,
        "${widget.userName} (Bạn)",
        _isVideoOff,
        _isMuted,
      ),
    );
    _remoteRenderers.forEach((peerId, renderer) {
      bool isRemoteCamOff = _remoteStates[peerId]?['camOff'] ?? false;
      bool isRemoteMicOff = _remoteStates[peerId]?['micOff'] ?? false;
      videoWidgets.add(
        _buildVideoView(
          renderer,
          _remoteNames[peerId] ?? "Người dùng",
          isRemoteCamOff,
          isRemoteMicOff,
        ),
      );
    });

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final double safeLeft = 20 + _bubbleX * (screenWidth - 100);
    final double safeTop = 100 + _bubbleY * (screenHeight - 250);

    Widget mainBody = Column(
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: GridView.count(
                    crossAxisCount: videoWidgets.length <= 2 ? 1 : 2,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: videoWidgets.length <= 2 ? 1.5 : 1.0,
                    children: videoWidgets,
                  ),
                ),
              ),
              if (_isChatOpen)
                Expanded(
                  flex: 2,
                  child: Container(
                    color: Colors.white,
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          color: primaryColor.withOpacity(0.1),
                          width: double.infinity,
                          child: const Text(
                            "Khung Chat",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('study_rooms')
                                .doc(widget.roomId)
                                .collection('messages')
                                .orderBy('timestamp', descending: true)
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData)
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              final docs = snapshot.data!.docs;
                              return ListView.builder(
                                reverse: true,
                                controller: _scrollController,
                                padding: const EdgeInsets.all(8),
                                itemCount: docs.length,
                                itemBuilder: (context, index) {
                                  final msg = docs[index].data()
                                      as Map<String, dynamic>;
                                  final isMe = msg['senderId'] == widget.userId;
                                  final isSystem = msg['isSystem'] ?? false;
                                  if (isSystem) {
                                    return Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: Text(
                                          msg['text'],
                                          style: const TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  return Align(
                                    alignment: isMe
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 4,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isMe
                                            ? primaryColor.withOpacity(0.9)
                                            : Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: isMe
                                            ? CrossAxisAlignment.end
                                            : CrossAxisAlignment.start,
                                        children: [
                                          if (!isMe)
                                            Text(
                                              msg['senderName'],
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 10,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          Text(
                                            msg['text'],
                                            style: TextStyle(
                                              color: isMe
                                                  ? Colors.white
                                                  : Colors.black87,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade100,
                            border: Border(
                              top: BorderSide(color: Colors.grey.shade300),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _chatController,
                                  decoration: const InputDecoration(
                                    hintText: "Nhập tin nhắn...",
                                    border: InputBorder.none,
                                  ),
                                  onSubmitted: (_) => _sendMessage(),
                                ),
                              ),
                              IconButton(
                                icon: Icon(Icons.send, color: primaryColor),
                                onPressed: _sendMessage,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          color: Colors.black87,
          child: SafeArea(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: MediaQuery.of(context).size.width,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildControlButton(
                      icon: _isMuted ? Icons.mic_off : Icons.mic,
                      label: "Mic",
                      color: _isMuted ? Colors.red : Colors.white,
                      onTap: _toggleMic,
                    ),
                    _buildControlButton(
                      icon: _isVideoOff ? Icons.videocam_off : Icons.videocam,
                      label: "Cam",
                      color: _isVideoOff ? Colors.red : Colors.white,
                      onTap: _toggleVideo,
                    ),
                    _buildControlButton(
                      icon: Icons.checklist,
                      label: "Nhiệm vụ",
                      color: Colors.white,
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (ctx) => Container(
                            padding: const EdgeInsets.all(16),
                            height: 300,
                            child: Column(
                              children: [
                                const Text(
                                  "Nhiệm vụ của bạn",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: widget.goals.length,
                                    itemBuilder: (_, i) => StatefulBuilder(
                                      builder: (ctx, setState) =>
                                          CheckboxListTile(
                                        title: Text(widget.goals[i]),
                                        value: _personalTaskStatus[i],
                                        onChanged: (val) {
                                          setState(
                                            () => _personalTaskStatus[i] = val!,
                                          );
                                          this.setState(() {});
                                        },
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    _buildControlButton(
                      icon: Icons.people,
                      label: "Nhóm",
                      color: Colors.white,
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (ctx) => Container(
                            padding: const EdgeInsets.all(16),
                            height: 300,
                            child: Column(
                              children: [
                                const Text(
                                  "Người tham gia",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Expanded(
                                  child: ListView(
                                    children: [
                                      ListTile(
                                        title: Text("${widget.userName} (Bạn)"),
                                      ),
                                      ..._remoteNames.values.map(
                                        (name) => ListTile(title: Text(name)),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isChatOpen = !_isChatOpen;
                          if (_isChatOpen) _unreadMessages = 0;
                        });
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: _isChatOpen
                                      ? Colors.white24
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _isChatOpen
                                      ? Icons.chat_bubble
                                      : Icons.chat_bubble_outline,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              if (_unreadMessages > 0 && !_isChatOpen)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '$_unreadMessages',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            "Chat",
                            style: TextStyle(color: Colors.white, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    _buildControlButton(
                      icon: Icons.call_end,
                      label: "Thoát",
                      color: Colors.red,
                      bgColor: Colors.red.withOpacity(0.2),
                      onTap: () => _leaveRoom(isFinishedNatural: false),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );

    return WillPopScope(
      onWillPop: () async {
        _leaveRoom(isFinishedNatural: false);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black87,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => _leaveRoom(isFinishedNatural: false),
          ),
          title: Column(
            children: [
              Text(
                widget.roomName,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold),
              ),
              Text(
                "${(_remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}",
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: Stack(
          children: [
            mainBody,
            if (_showAfkBubble)
              Positioned(
                left: safeLeft,
                top: safeTop,
                child: GestureDetector(
                  onTap: _onBubbleTap,
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.red.withOpacity(0.4),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          "${_afkTimeoutSeconds ~/ 60}:${(_afkTimeoutSeconds % 60).toString().padLeft(2, '0')}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.5),
                              blurRadius: 15,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.mark_chat_unread,
                          color: Colors.white,
                          size: 35,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoView(
    RTCVideoRenderer renderer,
    String name,
    bool isCamOff,
    bool isMuted,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(15),
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        children: [
          if (!isCamOff)
            RTCVideoView(
              renderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
              mirror: true,
            )
          else
            Center(
              child: CircleAvatar(
                radius: 30,
                backgroundColor: primaryColor,
                child: const Icon(Icons.person, size: 30, color: Colors.white),
              ),
            ),
          Positioned(
            bottom: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
          if (isMuted)
            const Positioned(
              top: 10,
              right: 10,
              child: Icon(Icons.mic_off, color: Colors.red, size: 20),
            ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    Color? bgColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: bgColor ?? Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}
