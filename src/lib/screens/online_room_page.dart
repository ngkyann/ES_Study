import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:esstudy/constants/colors.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:esstudy/constants/var.dart';

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
  bool _isTimerStarted =
      false; // Thay thế _roomEndTime để đánh dấu đã chạy đồng hồ chưa
  Timer? _timer;
  late List<bool> _personalTaskStatus;
  final player = AudioPlayer();
  // DateTime _joinTime = DateTime.now();
  int _currentParticipantsCount = 1;
  bool _hasLeft = false;
  Route? _myRoute;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _myRoute = ModalRoute.of(context); // Lưu lại định danh của trang phòng học
  }

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
  }

  // 🔥 HÀM ĐẾM NGƯỢC ĐỒNG BỘ MỚI
  void _startTimer() {
    _timer?.cancel();
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
        setState(() {
          _remainingSeconds--;
        });

        // Host liên tục đẩy giờ chuẩn lên Firebase mỗi 5s
        if (widget.isHost && _remainingSeconds % 5 == 0) {
          FirebaseFirestore.instance
              .collection('study_rooms')
              .doc(widget.roomId)
              .update({
            'currentRemaining': _remainingSeconds,
          }).catchError((e) {});
        }
      } else {
        // Hết giờ
        timer.cancel();
        _leaveRoomLogic(isFailedAFK: false, isFinishedNatural: true);
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
      debugPrint("Lỗi camera: $e");
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
    _sendSystemMessage(languageNotifier.value == "Tiếng Việt"
        ? "${widget.userName} đã vào phòng."
        : "${widget.userName} joined the room.");

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
        final msg = snap.docChanges.first.doc.data();
        if (msg != null) {
          // 🔥 THÊM MỚI: LẮNG NGHE LỆNH KẾT THÚC PHÒNG TỪ HOST
          if (msg['isSystem'] == true && msg['text'] == '[CMD_ROOM_FINISHED]') {
            if (mounted && !widget.isHost) {
              _remainingSeconds = 0;
              _timer?.cancel();
              // Ép thành viên hoàn thành tự nhiên và nhận đủ điểm!
              _leaveRoomLogic(isFailedAFK: false, isFinishedNatural: true);
            }
            return;
          }

          // Đoạn xử lý thông báo chat cũ giữ nguyên
          if (_isFirstMessageFetch) {
            _isFirstMessageFetch = false;
            return;
          }
          if (msg['senderId'] != widget.userId && msg['senderId'] != 'system') {
            if (!_isChatOpen && mounted) {
              setState(() => _unreadMessages++);
              try {
                player.play(AssetSource('sounds/ting.mp3'));
              } catch (_) {}
            }
          }
        }
      }
    });

    _participantsSub = roomRef.snapshots().listen((snap) {
      if (!snap.exists) {
        if (!widget.isHost && mounted && !_hasLeft) {
          // 🔥 NẾU PHÒNG BỊ XÓA MÀ GIỜ CHỈ CÒN DƯỚI 5 GIÂY -> LÀ DO HOST VỪA KẾT THÚC THÀNH CÔNG!
          if (_remainingSeconds <= 5) {
            _timer?.cancel();
            _leaveRoomLogic(isFailedAFK: false, isFinishedNatural: true);
          } else {
            // Host out sớm thật sự -> Không được cộng điểm
            _leaveRoomLogic(
                isFailedAFK: false,
                isFinishedNatural: false,
                isHostForcedClose: true);
          }
        }
        return;
      }

      final data = snap.data()!;
      _currentParticipantsCount = List.from(data['participants'] ?? []).length;

      // Khởi động đồng hồ lần đầu
      if (!_isTimerStarted) {
        _isTimerStarted = true;
        _remainingSeconds = widget.duration * 60;
        _startTimer();
      }

      // 🔥 ĐỒNG BỘ THỜI GIAN VỚI HOST: Nếu lệch quá 3 giây thì ép thành viên nhảy số theo Host
      if (!widget.isHost && data.containsKey('currentRemaining')) {
        int hostRemaining = data['currentRemaining'];
        if ((_remainingSeconds - hostRemaining).abs() > 3) {
          _remainingSeconds = hostRemaining;
        }
      }
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
    bool isVN = languageNotifier.value == "Tiếng Việt";
    if (_isAfkDialogOpen) Navigator.pop(context);
    _leaveRoomLogic(isFailedAFK: true, isFinishedNatural: false);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red),
            SizedBox(width: 8),
            Text(isVN ? "Phiên học bị hủy" : "Session Cancelled"),
          ],
        ),
        content: Text(
          isVN
              ? "Bạn đã treo máy quá 5 phút mà không phản hồi bong bóng điểm danh. Phiên học đã bị hủy và không được lưu lại để đảm bảo tính công bằng."
              : "You have been AFK for over 5 minutes without responding to the check-in bubble. The session has been cancelled and will not be saved to ensure fairness.",
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
              child: Text(
                isVN ? "Đã hiểu" : "Got it",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onBubbleTap() {
    bool isVN = languageNotifier.value == "Tiếng Việt";
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
            Expanded(
              child: Text(
                isVN ? "Báo cáo tiến độ!" : "Progress Report!",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isVN
                  ? "Chào bạn! Bạn đang học gì thế? Ghi chú lại một chút nhé để chứng minh bạn vẫn đang tập trung!"
                  : "Hi there! What are you studying? Leave a quick note to prove you're still focused!",
            ),
            const SizedBox(height: 15),
            TextField(
              controller: afkController,
              autofocus: true,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: isVN
                    ? "Ví dụ: Đang giải toán..."
                    : "Example: Solving math...",
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
                  SnackBar(
                    content: Text(
                      isVN
                          ? "Ôi chúa ơi! Bạn lười quá, gõ ít nhất 1 chữ đi nào!"
                          : "Oh my! You're so lazy, type at least one word!",
                    ),
                  ),
                );
              }
            },
            child: Text(
              isVN ? "Tiếp tục học" : "Continue Studying",
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
    bool isVN = languageNotifier.value == "Tiếng Việt";
    if (!isFinishedNatural) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text(isVN ? "Thoát giữa chừng?" : "Exit session?"),
            ],
          ),
          content: Text(
            isVN
                ? "Bạn có chắc muốn rời đi? Rời phòng lúc này sẽ KHÔNG được cộng điểm và tiến trình không được lưu."
                : "Are you sure you want to leave? Exiting now will NOT save your progress and points.",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(
                isVN ? "Tiếp tục học" : "Stay",
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: Text(
                isVN ? "Thoát ra" : "Exit",
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

  // 🔥 THAY THẾ TOÀN BỘ HÀM _leaveRoomLogic CŨ BẰNG HÀM NÀY
  Future<void> _leaveRoomLogic({
    required bool isFailedAFK,
    required bool isFinishedNatural,
    bool isHostForcedClose =
        false, // Thêm tham số này để báo hiệu Host đóng phòng
  }) async {
    if (_hasLeft) return; // Tránh việc gọi 2 lần
    _hasLeft = true;
    _timer?.cancel();

    for (var id in _peers.keys) {
      _peers[id]?.close();
    }

    bool isVN = languageNotifier.value == "Tiếng Việt";
    final roomRef =
        FirebaseFirestore.instance.collection('study_rooms').doc(widget.roomId);
    final roomSnap = await roomRef.get();

    // Dùng số lượng thành viên đã lưu, vì nếu phòng bị xóa roomSnap sẽ không đọc được
    int currentParticipants = _currentParticipantsCount;

    if (roomSnap.exists) {
      if (widget.isHost) {
        await roomRef.delete();
      } else {
        await roomRef.update({
          'participants': FieldValue.arrayRemove([widget.userId]),
          'participantNames.${widget.userId}': FieldValue.delete(),
          'participantStates.${widget.userId}': FieldValue.delete(),
        });
        await _sendSystemMessage(isVN
            ? "${widget.userName} đã rời phòng."
            : "${widget.userName} left the room.");
      }
    }

    // 🔥 NẾU TỰ THOÁT SỚM, BỊ AFK HOẶC HOST HỦY PHÒNG (Không cộng điểm cho ai cả)
    // 🔥 ĐÓNG SẠCH MỌI BOTTOM SHEET (CHAT, NHIỆM VỤ, NHÓM) ĐANG MỞ TRƯỚC KHI THOÁT
    if (_myRoute != null && Navigator.of(context).canPop()) {
      Navigator.of(context).popUntil((route) => route == _myRoute);
    }

    // 1. NẾU THẤT BẠI HOẶC HOST OUT SỚM (Không ai có điểm)
    if (isFailedAFK || !isFinishedNatural || isHostForcedClose) {
      // Phạt Host
      if (widget.isHost &&
          !isFinishedNatural &&
          !isFailedAFK &&
          currentParticipants > 1) {
        int penalty = 10 * currentParticipants;
        await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.userId)
            .update({'points': FieldValue.increment(-penalty)});
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(isVN
                    ? "Phạt -$penalty điểm do chủ phòng thoát sớm!"
                    : "Penalty -$penalty points for leaving early!"),
                backgroundColor: Colors.red),
          );
        }
      }

      // Báo cho thành viên Host đã out
      if (!widget.isHost && isHostForcedClose && mounted) {
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (dialogCtx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(isVN ? "Phòng đã đóng!" : "Room Closed!",
                textAlign: TextAlign.center),
            content: Text(
                isVN
                    ? "Chủ phòng đã thoát sớm. Phiên học bị hủy và không có điểm nào được cộng."
                    : "The host left early. Session cancelled and no points awarded.",
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15)),
            actions: [
              Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15))),
                  onPressed: () =>
                      Navigator.pop(dialogCtx), // Chỉ đóng hộp thoại
                  child: Text(isVN ? "Đóng" : "Close",
                      style: const TextStyle(color: Colors.white)),
                ),
              ),
            ],
          ),
        );
      }

      if (mounted && !isFailedAFK) Navigator.pop(context); // Đóng phòng học
      return;
    }

    // 2. NẾU HOÀN THÀNH THÀNH CÔNG (Tất cả nhận điểm)
    // int actualSeconds = DateTime.now().difference(_joinTime).inSeconds;
    int actualMinutes = widget
        .duration; // Đã hoàn thành tự nhiên thì nhận Full thời gian cài đặt
    int earnedPoints = actualMinutes * currentParticipants;

    if (earnedPoints > 0) {
      List<String> finishedTasks = [];
      for (int i = 0; i < widget.goals.length; i++) {
        if (_personalTaskStatus[i]) finishedTasks.add(widget.goals[i]);
      }

      await FirebaseFirestore.instance.collection('study_history').add({
        'userId': widget.userId,
        'time': DateTime.now(),
        'planTitle':
            "${widget.planTitle} (${isVN ? "Học Online" : "Online Study"})",
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
        int currentStreak = userDoc.data()!['streakCount'] ?? 0;
        Timestamp? lastStudyTs = userDoc.data()!['lastStudyDate'];
        if (lastStudyTs != null) {
          DateTime lastStudyDay = DateTime(lastStudyTs.toDate().year,
              lastStudyTs.toDate().month, lastStudyTs.toDate().day);
          int difference = today.difference(lastStudyDay).inDays;
          if (difference == 0)
            newStreak = currentStreak;
          else if (difference == 1) newStreak = currentStreak + 1;
        }
      }

      await userRef.set({
        'points': FieldValue.increment(earnedPoints),
        'streakCount': newStreak,
        'lastStudyDate': Timestamp.fromDate(now),
      }, SetOptions(merge: true));

      // Cập nhật Friend Streak
      if (currentParticipants > 1 && roomSnap.exists) {
        final data = roomSnap.data() as Map<String, dynamic>;
        List<String> participants =
            List<String>.from(data['participants'] ?? []);
        for (String pId in participants) {
          if (pId != widget.userId) {
            String streakId = _getChatId(widget.userId, pId);
            DocumentReference streakRef = FirebaseFirestore.instance
                .collection('friend_streaks')
                .doc(streakId);
            DocumentSnapshot streakSnap = await streakRef.get();
            int newFriendStreak = 1;
            if (streakSnap.exists && streakSnap.data() != null) {
              int currentFriendStreak =
                  (streakSnap.data() as Map<String, dynamic>)['streak'] ?? 0;
              Timestamp? lastTs =
                  (streakSnap.data() as Map<String, dynamic>)['lastStudyDate'];
              if (lastTs != null) {
                DateTime lastDay = DateTime(lastTs.toDate().year,
                    lastTs.toDate().month, lastTs.toDate().day);
                int diff = today.difference(lastDay).inDays;
                if (diff == 0)
                  newFriendStreak = currentFriendStreak;
                else if (diff == 1) newFriendStreak = currentFriendStreak + 1;
              }
            }
            await streakRef.set({
              'streak': newFriendStreak,
              'lastStudyDate': Timestamp.fromDate(now)
            }, SetOptions(merge: true));
          }
        }
      }
    }

    if (mounted) {
      String title = isVN ? "Xuất sắc! 🎉" : "Excellent! 🎉";
      String desc = isVN
          ? "Bạn đã học được $actualMinutes phút!\nSố người cùng học: $currentParticipants\n\n🎁 Thưởng: +$earnedPoints điểm"
          : "You studied for $actualMinutes minutes!\nStudy buddies: $currentParticipants\n\n🎁 Reward: +$earnedPoints points";

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogCtx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(title, textAlign: TextAlign.center),
          content: Text(desc,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16)),
          actions: [
            Center(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15))),
                onPressed: () =>
                    Navigator.pop(dialogCtx), // Chỉ đóng Dialog thưởng
                child: Text(isVN ? "Nhận thưởng" : "Claim reward",
                    style: const TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      );
      if (mounted) Navigator.pop(context); // Thoát khỏi phòng học
    }
  }

// end
// 🔥 THÊM 1: Hàm tạo ID chat 1-1 (Giống bên trang FriendsPage)
  String _getChatId(String uid1, String uid2) {
    return uid1.compareTo(uid2) < 0 ? '${uid1}_$uid2' : '${uid2}_$uid1';
  }

  // 🔥 THÊM 2: Hàm hiển thị danh sách bạn bè và gửi mã
  void _showShareToFriendBottomSheet() {
    bool isVN = languageNotifier.value == "Tiếng Việt";
    showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) {
          return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .doc(widget.userId)
                  .get(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                      child: CircularProgressIndicator(color: primaryColor));
                }
                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Center(
                      child: Text(
                          isVN ? "Lỗi tải danh sách" : "Error loading list"));
                }

                List<String> friendsIds =
                    List<String>.from(snapshot.data!.get('friends') ?? []);

                if (friendsIds.isEmpty) {
                  return Center(
                      child: Text(isVN
                          ? "Bạn chưa có bạn bè nào để gửi"
                          : "You have no friends to send"));
                }

                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        isVN
                            ? "Chọn bạn bè để rủ vào phòng"
                            : "Select friend to invite",
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                          itemCount: friendsIds.length,
                          itemBuilder: (context, index) {
                            String friendId = friendsIds[index];
                            return FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(friendId)
                                  .get(),
                              builder: (context, friendSnap) {
                                if (!friendSnap.hasData)
                                  return const ListTile(title: Text("..."));

                                var friendData = friendSnap.data!.data()
                                    as Map<String, dynamic>;
                                String friendName =
                                    friendData['name'] ?? 'Unknown';
                                String? avatarUrl = friendData['avatarUrl'];

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor:
                                        primaryColor.withOpacity(0.2),
                                    backgroundImage: avatarUrl != null
                                        ? NetworkImage(avatarUrl)
                                        : null,
                                    child: avatarUrl == null
                                        ? Icon(Icons.person,
                                            color: primaryColor)
                                        : null,
                                  ),
                                  title: Text(friendName,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                  trailing: ElevatedButton.icon(
                                    icon: const Icon(Icons.send,
                                        size: 16, color: Colors.white),
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor),
                                    onPressed: () async {
                                      // 1. Tạo ID cuộc trò chuyện
                                      String chatId =
                                          _getChatId(widget.userId, friendId);

                                      // 2. Nội dung tin nhắn rủ rê
                                      String msg = isVN
                                          ? "Vào học cùng mình nhé! Mã phòng riêng tư là: ${widget.roomCode}"
                                          : "Join my study room! The private code is: ${widget.roomCode}";

                                      // 3. Lưu vào Firebase Chats
                                      await FirebaseFirestore.instance
                                          .collection('chats')
                                          .doc(chatId)
                                          .collection('messages')
                                          .add({
                                        'senderId': widget.userId,
                                        'text': msg,
                                        'timestamp':
                                            FieldValue.serverTimestamp(),
                                        'deletedBy': [],
                                      });

                                      await FirebaseFirestore.instance
                                          .collection('chats')
                                          .doc(chatId)
                                          .set({
                                        'lastMessage': msg,
                                        'lastTimestamp':
                                            FieldValue.serverTimestamp(),
                                      }, SetOptions(merge: true));

                                      // 4. Đóng thông báo
                                      if (ctx.mounted) Navigator.pop(ctx);
                                      if (context.mounted)
                                        Navigator.pop(context);

                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(isVN
                                              ? "Đã gửi mã cho $friendName!"
                                              : "Code sent to $friendName!"),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                    },
                                    label: Text(isVN ? "Gửi mã" : "Send",
                                        style: const TextStyle(
                                            color: Colors.white)),
                                  ),
                                );
                              },
                            );
                          }),
                    ),
                  ],
                );
              });
        });
  }

  void _showRoomCodeDialog() {
    if (!mounted) return;
    bool isVN = languageNotifier.value == "Tiếng Việt";
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text(isVN ? "Phòng Riêng Tư" : "Private Room",
            textAlign: TextAlign.center),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(isVN
                ? "Gửi mã này cho bạn bè để tham gia:"
                : "Share this code with friends to join:"),
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
          TextButton.icon(
            icon: Icon(Icons.share, color: primaryColor),
            onPressed: () {
              _showShareToFriendBottomSheet(); // Gọi hàm vừa thêm ở trên
            },
            label: Text(isVN ? "Gửi bạn bè" : "Send to friend",
                style: TextStyle(
                    color: primaryColor, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.copy, color: Colors.white),
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.roomCode!));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        isVN ? "Đã sao chép mã phòng!" : "Room code copied!")),
              );
              Navigator.pop(ctx);
            },
            label: Text(isVN ? "Sao chép" : "Copy",
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _sendSystemMessage(String text) async {
    bool isVN = languageNotifier.value == "Tiếng Việt";
    await FirebaseFirestore.instance
        .collection('study_rooms')
        .doc(widget.roomId)
        .collection('messages')
        .add({
      'senderId': 'system',
      'senderName': isVN ? 'Hệ thống' : 'System',
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
    return ValueListenableBuilder<String>(
        valueListenable: languageNotifier,
        builder: (context, lang, child) {
          bool isVN = lang == "Tiếng Việt";
          List<Widget> videoWidgets = [];
          videoWidgets.add(
            _buildVideoView(
              _localRenderer,
              isVN ? "${widget.userName} (Bạn)" : "${widget.userName} (You)",
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
                _remoteNames[peerId] ?? (isVN ? "Người dùng" : "User"),
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
                          childAspectRatio:
                              videoWidgets.length <= 2 ? 1.5 : 1.0,
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
                                child: Text(
                                  isVN ? "Khung Chat" : "Chat Box",
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
                                        final isMe =
                                            msg['senderId'] == widget.userId;
                                        final isSystem =
                                            msg['isSystem'] ?? false;
                                        if (isSystem) {
                                          return Center(
                                            child: Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
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
                                                  ? primaryColor
                                                      .withOpacity(0.9)
                                                  : Colors.grey.shade200,
                                              borderRadius:
                                                  BorderRadius.circular(12),
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
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                    top:
                                        BorderSide(color: Colors.grey.shade300),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _chatController,
                                        decoration: InputDecoration(
                                          hintText: isVN
                                              ? "Nhập tin nhắn..."
                                              : "Type a message...",
                                          border: InputBorder.none,
                                        ),
                                        onSubmitted: (_) => _sendMessage(),
                                      ),
                                    ),
                                    IconButton(
                                      icon:
                                          Icon(Icons.send, color: primaryColor),
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
                  // 🔥 FIX: Dùng LayoutBuilder để lấy chính xác chiều rộng của khung 500px thay vì toàn bộ màn hình
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minWidth: constraints.maxWidth),
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
                                icon: _isVideoOff
                                    ? Icons.videocam_off
                                    : Icons.videocam,
                                label: "Cam",
                                color: _isVideoOff ? Colors.red : Colors.white,
                                onTap: _toggleVideo,
                              ),
                              _buildControlButton(
                                icon: Icons.checklist,
                                label: isVN ? "Nhiệm vụ" : "Tasks",
                                color: Colors.white,
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    builder: (ctx) => Container(
                                      padding: const EdgeInsets.all(16),
                                      height: 300,
                                      child: Column(
                                        children: [
                                          Text(
                                            isVN
                                                ? "Nhiệm vụ của bạn"
                                                : "Your Tasks",
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Expanded(
                                            child: ListView.builder(
                                              itemCount: widget.goals.length,
                                              itemBuilder: (_, i) =>
                                                  StatefulBuilder(
                                                builder: (ctx, setState) =>
                                                    CheckboxListTile(
                                                  title: Text(widget.goals[i]),
                                                  value: _personalTaskStatus[i],
                                                  onChanged: (val) {
                                                    setState(
                                                      () => _personalTaskStatus[
                                                          i] = val!,
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
                                label: isVN ? "Nhóm" : "Group",
                                color: Colors.white,
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    builder: (ctx) => Container(
                                      padding: const EdgeInsets.all(16),
                                      height: 300,
                                      child: Column(
                                        children: [
                                          Text(
                                            isVN
                                                ? "Người tham gia"
                                                : "Participants",
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Expanded(
                                            child: ListView(
                                              children: [
                                                ListTile(
                                                  title: Text(isVN
                                                      ? "${widget.userName} (Bạn)"
                                                      : "${widget.userName} (You)"),
                                                ),
                                                ..._remoteNames.values.map(
                                                  (name) => ListTile(
                                                      title: Text(name)),
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
                                      style: TextStyle(
                                          color: Colors.white, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              _buildControlButton(
                                icon: Icons.call_end,
                                label: isVN ? "Thoát" : "Exit",
                                color: Colors.red,
                                bgColor: Colors.red.withOpacity(0.2),
                                onTap: () =>
                                    _leaveRoom(isFinishedNatural: false),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
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

                // 🔥 ĐOẠN CODE THÊM MỚI: NÚT XEM VÀ CHIA SẺ MÃ PHÒNG (Góc trên bên phải)
                actions: [
                  if (widget.isPrivate && widget.roomCode != null)
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.white),
                      onPressed:
                          _showRoomCodeDialog, // Gọi lại hộp thoại hiện mã phòng
                    ),
                ],
                // 🔥 KẾT THÚC ĐOẠN THÊM MỚI
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
        });
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
