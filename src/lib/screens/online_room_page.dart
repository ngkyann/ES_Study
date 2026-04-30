import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Để dùng Clipboard copy mã phòng
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:esstudy/constants/colors.dart';

class OnlineRoomPage extends StatefulWidget {
  final bool isHost;
  final String roomId;
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

class _OnlineRoomPageState extends State<OnlineRoomPage> {
  // Bản thân
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  MediaStream? _localStream;

  // Lưới người dùng khác
  final Map<String, RTCPeerConnection> _peers = {};
  final Map<String, RTCVideoRenderer> _remoteRenderers = {};
  final Map<String, String> _remoteNames = {};

  bool _isMuted = false;
  bool _isVideoOff = false;
  bool _isChatOpen = false;

  final TextEditingController _chatController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  int _remainingSeconds = 0;
  Timer? _timer;
  late List<bool> _personalTaskStatus;
  late DateTime _joinTime;

  // Hàng đợi cho tín hiệu mạng đến quá sớm
  final Map<String, List<RTCIceCandidate>> _candidateQueue = {};

  StreamSubscription? _participantsSub;
  StreamSubscription? _signalingSub;

  // Cấu hình máy chủ Google STUN miễn phí
  final Map<String, dynamic> _iceServers = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _personalTaskStatus = List.generate(widget.goals.length, (_) => false);
    _joinTime = DateTime.now();
    _startTimer();
    _initRoom();
  }

  void _startTimer() {
    _remainingSeconds = widget.duration * 60;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        timer.cancel();
        _leaveRoom(isFinishedNatural: true);
      }
    });
  }

  Future<void> _initRoom() async {
    // 1. Xin quyền & Mở Camera/Mic
    await [Permission.camera, Permission.microphone].request();
    await _localRenderer.initialize();
    try {
      _localStream = await navigator.mediaDevices.getUserMedia({
        'video': true,
        'audio': {'echoCancellation': true, 'noiseSuppression': true},
      });
      if (mounted) setState(() => _localRenderer.srcObject = _localStream);
    } catch (e) {
      debugPrint("Lỗi Camera: $e");
    }

    // 2. Tham gia Firebase
    final roomRef = FirebaseFirestore.instance
        .collection('study_rooms')
        .doc(widget.roomId);
    if (widget.isHost) {
      await roomRef.set({
        'hostId': widget.userId,
        'hostName': widget.userName,
        'duration': widget.duration,
        'maxMembers': widget.maxMembers,
        'isPrivate': widget.isPrivate,
        'roomCode': widget.roomCode,
        'createdAt': FieldValue.serverTimestamp(),
        'participants': [widget.userId],
        'participantNames': {widget.userId: widget.userName},
      });
      if (widget.isPrivate && widget.roomCode != null) _showRoomCodeDialog();
    } else {
      await roomRef.update({
        'participants': FieldValue.arrayUnion([widget.userId]),
        'participantNames.${widget.userId}': widget.userName,
      });
    }
    _sendSystemMessage("${widget.userName} đã vào phòng.");

    // 3. Lắng nghe người mới vào (Participants List)
    _participantsSub = roomRef.snapshots().listen((snap) {
      if (!snap.exists) return;
      final data = snap.data()!;
      final names = Map<String, dynamic>.from(data['participantNames'] ?? {});

      names.forEach((pid, pname) {
        if (pid != widget.userId && !_peers.containsKey(pid)) {
          // Người mới! Chuẩn bị Renderer và gọi họ
          _remoteNames[pid] = pname;
          _createPeerConnection(pid, isCaller: true);
        }
      });

      // Dọn dẹp người đã thoát
      final currentIds = names.keys.toSet();
      final myPeers = _peers.keys.toSet();
      for (var id in myPeers) {
        if (!currentIds.contains(id)) _removePeer(id);
      }
    });

    // 4. Lắng nghe hộp thư Tín hiệu Signaling (Của riêng mình)
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
              change.doc.reference.delete(); // Đọc xong xóa luôn
            }
          }
        });
  }

  // ================= WEBRTC SIGNALING CORE =================

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

    // Nhét Camera & Mic của mình vào kết nối
    if (_localStream != null) {
      _localStream!.getTracks().forEach((track) {
        pc.addTrack(track, _localStream!);
      });
    }

    // Bắt luồng dữ liệu (Audio + Video) của người kia
    pc.onAddStream = (MediaStream stream) {
      renderer.srcObject = stream;
      if (mounted) setState(() {});
    };

    // Tìm được đường truyền mạng (ICE) -> Gửi cho bạn kia
    pc.onIceCandidate = (candidate) {
      _sendSignaling(peerId, {
        'type': 'candidate',
        'candidate': candidate.toMap(),
      });
    };

    if (isCaller) {
      // Mình là người gọi -> Tạo Offer
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      _sendSignaling(peerId, {'type': 'offer', 'sdp': offer.sdp});
    }
  }

  Future<void> _handleSignalingMessage(
    String fromPeerId,
    Map<String, dynamic> data,
  ) async {
    final type = data['type'];

    // Nếu chưa có kết nối với người này thì tạo (bị gọi)
    if (!_peers.containsKey(fromPeerId)) {
      await _createPeerConnection(fromPeerId, isCaller: false);
    }

    final pc = _peers[fromPeerId]!;

    if (type == 'offer') {
      await pc.setRemoteDescription(RTCSessionDescription(data['sdp'], type));
      final answer = await pc.createAnswer();
      await pc.setLocalDescription(answer);
      _sendSignaling(fromPeerId, {'type': 'answer', 'sdp': answer.sdp});

      // Thả các Tọa độ (Candidates) bị kẹt trong hàng đợi ra
      if (_candidateQueue.containsKey(fromPeerId)) {
        for (var c in _candidateQueue[fromPeerId]!) {
          await pc.addCandidate(c);
        }
        _candidateQueue.remove(fromPeerId);
      }
    } else if (type == 'answer') {
      await pc.setRemoteDescription(RTCSessionDescription(data['sdp'], type));
    } else if (type == 'answer') {
      await pc.setRemoteDescription(RTCSessionDescription(data['sdp'], type));
    } else if (type == 'candidate') {
      final candMap = data['candidate'];
      final candidate = RTCIceCandidate(
        candMap['candidate'],
        candMap['sdpMid'],
        candMap['sdpMLineIndex'],
      );

      // 🔥 ĐÃ SỬA LỖI: Dùng signalingState thay vì remoteDescription
      // Trạng thái 'have-remote-offer' hoặc 'stable' (sau khi setRemoteDescription)
      // cho biết máy đã sẵn sàng nhận Candidate
      if (pc.signalingState == RTCSignalingState.RTCSignalingStateStable ||
          pc.signalingState ==
              RTCSignalingState.RTCSignalingStateHaveRemoteOffer ||
          pc.signalingState ==
              RTCSignalingState.RTCSignalingStateHaveRemotePrAnswer) {
        await pc.addCandidate(candidate);
      } else {
        // Nếu chưa sẵn sàng, nhốt vào hàng đợi
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
    if (mounted) setState(() {});
  }

  // =========================================================

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
    if (_scrollController.hasClients)
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
  }

  void _toggleMic() {
    if (_localStream != null && _localStream!.getAudioTracks().isNotEmpty) {
      final track = _localStream!.getAudioTracks()[0];
      track.enabled = !track.enabled;
      setState(() => _isMuted = !_isMuted);
    }
  }

  void _toggleVideo() {
    if (_localStream != null && _localStream!.getVideoTracks().isNotEmpty) {
      final track = _localStream!.getVideoTracks()[0];
      track.enabled = !track.enabled;
      setState(() => _isVideoOff = !_isVideoOff);
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
            "Nếu rời đi bây giờ, bạn sẽ KHÔNG nhận được điểm thưởng và tiến độ của bạn sẽ bị hủy bỏ. Chắc chắn thoát?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Tiếp tục học"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "Vẫn thoát",
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    _timer?.cancel();

    for (var id in _peers.keys) {
      _peers[id]?.close();
    }

    final roomRef = FirebaseFirestore.instance
        .collection('study_rooms')
        .doc(widget.roomId);
    final roomSnap = await roomRef.get();
    int currentParticipants = 1;

    if (roomSnap.exists) {
      final data = roomSnap.data() as Map<String, dynamic>;
      currentParticipants = List.from(data['participants'] ?? []).length;
      await roomRef.update({
        'participants': FieldValue.arrayRemove([widget.userId]),
        'participantNames.${widget.userId}': FieldValue.delete(),
      });
      await _sendSystemMessage("${widget.userName} đã rời phòng.");
      if (currentParticipants <= 1) await roomRef.delete();
    }

    if (!isFinishedNatural) {
      if (mounted) Navigator.pop(context);
      return;
    }

    // Tính điểm dựa trên thời gian thực tế
    final int actualSeconds = DateTime.now().difference(_joinTime).inSeconds;
    final int actualMinutes = (actualSeconds / 60).ceil();
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

    final userRef = FirebaseFirestore.instance
        .collection('users')
        .doc(widget.userId);
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
        if (difference == 0)
          newStreak = currentStreak;
        else if (difference == 1)
          newStreak = currentStreak + 1;
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
            "Thời gian học: $actualMinutes phút!\nSố người cùng cố gắng: $currentParticipants người\n\n🎁 Thưởng: +$earnedPoints điểm",
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

  @override
  void dispose() {
    _timer?.cancel();
    _participantsSub?.cancel();
    _signalingSub?.cancel();
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
      videoWidgets.add(
        _buildVideoView(
          renderer,
          _remoteNames[peerId] ?? "Người dùng",
          false,
          false,
        ),
      );
    });

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
                "${(_remainingSeconds ~/ 60).toString().padLeft(2, '0')}:${(_remainingSeconds % 60).toString().padLeft(2, '0')}",
                style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              if (widget.isPrivate)
                Text(
                  "Mã phòng: ${widget.roomCode}",
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
            ],
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(
                _isChatOpen ? Icons.chat_bubble : Icons.chat_bubble_outline,
                color: Colors.white,
              ),
              onPressed: () => setState(() => _isChatOpen = !_isChatOpen),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
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
                      flex: 1,
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
                                      final msg =
                                          docs[index].data()
                                              as Map<String, dynamic>;
                                      final isMe =
                                          msg['senderId'] == widget.userId;
                                      final isSystem = msg['isSystem'] ?? false;
                                      if (isSystem)
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
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
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
                                                () => _personalTaskStatus[i] =
                                                    val!,
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
