import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

class GroupCallPage extends StatefulWidget {
  const GroupCallPage({super.key});

  @override
  State<GroupCallPage> createState() => _GroupCallPageState();
}

class _GroupCallPageState extends State<GroupCallPage> {
  final TextEditingController _roomController = TextEditingController();
  final Map<String, RTCPeerConnection> _peerIdToPc = {};
  final Map<String, RTCVideoRenderer> _peerIdToRenderer = {};
  final Map<String, StreamSubscription> _peerListeners = {};
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  MediaStream? _localStream;
  bool _rendererInitialized = false;

  bool _joined = false;
  bool _micEnabled = true;
  bool _camEnabled = true;
  String _roomId = '';
  String _selectedRoomId = '';
  bool _voiceConnected = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _cleanup().ignore();
    if (_rendererInitialized) {
      _localRenderer.dispose();
    }
    _roomController.dispose();
    super.dispose();
  }

  Future<void> _initRenderer() async {
    try {
      await _localRenderer.initialize();
      _rendererInitialized = true;
    } catch (_) {}
  }

  Future<bool> _promptForPermissions() async {
    // Microphone (required)
    var mic = await Permission.microphone.status;
    if (!mic.isGranted) {
      mic = await Permission.microphone.request();
      if (!mic.isGranted) {
        final open = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Microphone access needed'),
            content: const Text(
              'To speak in the room, enable microphone access for Prayer Buddy.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Not now'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Open Settings'),
              ),
            ],
          ),
        );
        if (open == true) await openAppSettings();
        return false;
      }
    }

    // Camera (optional): request once; if denied, continue voice-only
    var cam = await Permission.camera.status;
    if (!cam.isGranted && !cam.isPermanentlyDenied) {
      await Permission.camera.request();
    }
    return true;
  }

  Future<void> _initLocalMedia() async {
    await _initRenderer();
    final mediaConstraints = {
      'audio': true,
      // Always attempt to get video initially so iOS can present the
      // system camera permission prompt. We will fall back to audio-only
      // if this fails (e.g., user denies or simulator has no camera).
      'video': {
        'facingMode': 'user',
        'width': {'ideal': 640},
        'height': {'ideal': 360},
        'frameRate': {'ideal': 24},
      },
    };
    MediaStream? stream;
    try {
      stream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    } catch (e) {
      // Fallback to audio-only if camera init fails (e.g., simulator issues)
      try {
        stream = await navigator.mediaDevices.getUserMedia({
          'audio': true,
          'video': false,
        });
      } catch (_) {
        rethrow;
      }
    }
    _localStream = stream;
    _localRenderer.srcObject = stream;
    setState(() {});
  }

  Future<RTCPeerConnection> _createPeerConnection(
    String remoteUid, {
    required bool isOfferer,
  }) async {
    const iceServers = [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ];
    final config = {'iceServers': iceServers, 'sdpSemantics': 'unified-plan'};
    final pc = await createPeerConnection(config);

    // Local tracks
    final local = _localStream;
    if (local != null) {
      for (final track in local.getTracks()) {
        await pc.addTrack(track, local);
      }
    }

    // Remote tracks
    pc.onTrack = (RTCTrackEvent event) async {
      if (event.streams.isEmpty) return;
      final remoteStream = event.streams.first;
      if (!_peerIdToRenderer.containsKey(remoteUid)) {
        final renderer = RTCVideoRenderer();
        await renderer.initialize();
        renderer.srcObject = remoteStream;
        _peerIdToRenderer[remoteUid] = renderer;
        if (mounted) setState(() {});
      } else {
        _peerIdToRenderer[remoteUid]!.srcObject = remoteStream;
        if (mounted) setState(() {});
      }
    };

    // ICE candidates → Firestore
    final me = FirebaseAuth.instance.currentUser;
    final calls = FirebaseFirestore.instance.collection('calls');
    final roomDoc = calls.doc(_roomId);
    final connId = '${me!.uid}_$remoteUid';
    final reverseConnId = '${remoteUid}_${me.uid}';
    final connDoc = roomDoc
        .collection('connections')
        .doc(isOfferer ? connId : reverseConnId);

    pc.onIceCandidate = (RTCIceCandidate c) async {
      if (c.candidate == null) return;
      final col = connDoc.collection(
        isOfferer ? 'offerCandidates' : 'answerCandidates',
      );
      await col.add({
        'candidate': c.candidate,
        'sdpMid': c.sdpMid,
        'sdpMLineIndex': c.sdpMLineIndex,
        'createdAt': FieldValue.serverTimestamp(),
      });
    };

    _peerIdToPc[remoteUid] = pc;
    return pc;
  }

  Future<void> _startMeshWith(String remoteUid) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null || remoteUid.isEmpty || remoteUid == me.uid) return;
    final amOfferer = me.uid.compareTo(remoteUid) > 0;

    final pc = await _createPeerConnection(remoteUid, isOfferer: amOfferer);
    final calls = FirebaseFirestore.instance.collection('calls');
    final roomDoc = calls.doc(_roomId);
    final connId = amOfferer
        ? '${me.uid}_$remoteUid'
        : '${remoteUid}_${me.uid}';
    final connDoc = roomDoc.collection('connections').doc(connId);

    // Listen for SDP and candidates
    _peerListeners['$remoteUid-conn']?.cancel();
    _peerListeners['$remoteUid-conn'] = connDoc.snapshots().listen((
      snap,
    ) async {
      final data = snap.data();
      if (data == null) return;
      final currentRemote = await pc.getRemoteDescription();
      if (!amOfferer && data['offer'] != null && currentRemote == null) {
        final offer = data['offer'] as Map<String, dynamic>;
        await pc.setRemoteDescription(
          RTCSessionDescription(
            offer['sdp'] as String,
            offer['type'] as String,
          ),
        );
        final answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        await connDoc.set({
          'from': remoteUid,
          'to': me.uid,
          'answer': {'type': answer.type, 'sdp': answer.sdp},
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      final currentRemote2 = await pc.getRemoteDescription();
      if (amOfferer && data['answer'] != null && currentRemote2 == null) {
        final answer = data['answer'] as Map<String, dynamic>;
        await pc.setRemoteDescription(
          RTCSessionDescription(
            answer['sdp'] as String,
            answer['type'] as String,
          ),
        );
      }
    });

    // Listen for ICE candidates from the other side
    _peerListeners['$remoteUid-cand']?.cancel();
    final remoteCandCol = connDoc.collection(
      amOfferer ? 'answerCandidates' : 'offerCandidates',
    );
    _peerListeners['$remoteUid-cand'] = remoteCandCol.snapshots().listen((
      qs,
    ) async {
      for (final d in qs.docChanges) {
        if (d.type == DocumentChangeType.added) {
          final c = d.doc.data() as Map<String, dynamic>;
          final ice = RTCIceCandidate(
            c['candidate'] as String?,
            c['sdpMid'] as String?,
            (c['sdpMLineIndex'] as num?)?.toInt(),
          );
          await pc.addCandidate(ice);
        }
      }
    });

    // If offerer, create and write offer
    if (amOfferer) {
      final offer = await pc.createOffer();
      await pc.setLocalDescription(offer);
      await connDoc.set({
        'from': me.uid,
        'to': remoteUid,
        'offer': {'type': offer.type, 'sdp': offer.sdp},
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> _join() async {
    if (_joined) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final id = _roomId.isNotEmpty
        ? _roomId
        : (_selectedRoomId.isNotEmpty ? _selectedRoomId : 'prayer-1');
    setState(() => _roomId = id);

    final calls = FirebaseFirestore.instance.collection('calls');
    final roomDoc = calls.doc(_roomId);
    await roomDoc.set({
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await roomDoc.collection('participants').doc(user.uid).set({
      'uid': user.uid,
      'joinedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (mounted) setState(() => _joined = true);
  }

  Future<void> _connectVoice() async {
    if (_voiceConnected || !_joined) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      // Attempt to open mic/camera directly; iOS will show the system prompt
      // on first getUserMedia call if Info.plist keys exist.
      await _initLocalMedia();
    } catch (e) {
      // If the system blocked the prompt or access is denied, fall back to
      // an explicit permission dialog that can open Settings.
      final granted = await _promptForPermissions();
      if (!granted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Enable mic/camera in Settings to speak.'),
            ),
          );
        }
        return;
      }
      // Try again after user action
      await _initLocalMedia();
    }

    final roomDoc = FirebaseFirestore.instance.collection('calls').doc(_roomId);

    // Connect to existing participants now
    final current = await roomDoc.collection('participants').get();
    for (final doc in current.docs) {
      final otherUid = doc.id;
      if (otherUid != user.uid) {
        await _startMeshWith(otherUid);
      }
    }

    // And subscribe for future joiners
    _peerListeners['participants']?.cancel();
    _peerListeners['participants'] = roomDoc
        .collection('participants')
        .snapshots()
        .listen((qs) {
          for (final change in qs.docChanges) {
            final otherUid = change.doc.id;
            if (otherUid == user.uid) continue;
            if (change.type == DocumentChangeType.added) {
              _startMeshWith(otherUid);
            }
            if (change.type == DocumentChangeType.removed) {
              _teardownPeer(otherUid);
            }
          }
        });

    if (mounted) setState(() => _voiceConnected = true);
  }

  Future<void> _disconnectVoice() async {
    if (!_voiceConnected) return;
    // Tear down peers and local stream, keep room membership
    for (final k in _peerListeners.keys.toList()) {
      if (k == 'participants')
        continue; // keep lobby listener off; will re-add on connect
      await _peerListeners.remove(k)?.cancel();
    }
    for (final uid in _peerIdToPc.keys.toList()) {
      await _peerIdToPc.remove(uid)?.close();
    }
    for (final uid in _peerIdToRenderer.keys.toList()) {
      await _peerIdToRenderer.remove(uid)?.dispose();
    }
    await _localStream?.dispose();
    _localStream = null;
    _localRenderer.srcObject = null;
    if (mounted) setState(() => _voiceConnected = false);
  }

  Future<void> _leave() async {
    await _cleanup();
    if (mounted) {
      setState(() {
        _joined = false;
        _roomId = '';
      });
    }
  }

  Future<void> _teardownPeer(String remoteUid) async {
    _peerListeners.remove('$remoteUid-conn')?.cancel();
    _peerListeners.remove('$remoteUid-cand')?.cancel();
    final pc = _peerIdToPc.remove(remoteUid);
    await pc?.close();
    final r = _peerIdToRenderer.remove(remoteUid);
    await r?.dispose();
    if (mounted) setState(() {});
  }

  Future<void> _cleanup() async {
    for (final sub in _peerListeners.values) {
      await sub.cancel();
    }
    _peerListeners.clear();
    for (final pc in _peerIdToPc.values) {
      await pc.close();
    }
    _peerIdToPc.clear();
    for (final r in _peerIdToRenderer.values) {
      await r.dispose();
    }
    _peerIdToRenderer.clear();

    final me = FirebaseAuth.instance.currentUser;
    if (me != null && _roomId.isNotEmpty) {
      final roomDoc = FirebaseFirestore.instance
          .collection('calls')
          .doc(_roomId);
      await roomDoc
          .collection('participants')
          .doc(me.uid)
          .delete()
          .catchError((_) {});
    }
    await _localStream?.dispose();
    _localStream = null;
    if (_rendererInitialized) {
      try {
        _localRenderer.srcObject = null;
      } catch (_) {}
    }
  }

  Future<void> _toggleMic() async {
    _micEnabled = !_micEnabled;
    for (final t in _localStream?.getAudioTracks() ?? const []) {
      t.enabled = _micEnabled;
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleCam() async {
    _camEnabled = !_camEnabled;
    for (final t in _localStream?.getVideoTracks() ?? const []) {
      t.enabled = _camEnabled;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];
    if (_localStream != null) {
      tiles.add(_buildRendererTile(_localRenderer, label: 'You'));
    }
    _peerIdToRenderer.forEach((uid, renderer) {
      tiles.add(_buildRendererTile(renderer));
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5DC),
      appBar: AppBar(
        title: Text(_joined ? 'Group Call' : 'Group Rooms'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _joined
            ? Column(
                children: [
                  Expanded(
                    child: tiles.isEmpty
                        ? const Center(
                            child: Text('Connected (no video streams yet)'),
                          )
                        : GridView.count(
                            crossAxisCount:
                                MediaQuery.of(context).size.width > 600 ? 3 : 2,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            children: tiles,
                          ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (_voiceConnected) ...[
                        IconButton(
                          tooltip: _micEnabled ? 'Mute' : 'Unmute',
                          onPressed: _toggleMic,
                          icon: Icon(_micEnabled ? Icons.mic : Icons.mic_off),
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          tooltip: _camEnabled ? 'Stop video' : 'Start video',
                          onPressed: _toggleCam,
                          icon: Icon(
                            _camEnabled ? Icons.videocam : Icons.videocam_off,
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _disconnectVoice,
                          child: const Text('Disconnect'),
                        ),
                      ] else ...[
                        ElevatedButton.icon(
                          onPressed: _connectVoice,
                          icon: const Icon(Icons.headset_mic),
                          label: const Text('Connect voice'),
                        ),
                      ],
                      const SizedBox(width: 12),
                      OutlinedButton(
                        onPressed: _leave,
                        child: const Text('Leave room'),
                      ),
                    ],
                  ),
                ],
              )
            : _buildLobby(context),
      ),
    );
  }

  Widget _buildLobby(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Voice Channels',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        _roomOption(
          id: 'prayer-1',
          title: 'Prayer Room 1',
          subtitle: 'Join a group prayer call',
        ),
        const SizedBox(height: 8),
        _roomOption(
          id: 'prayer-2',
          title: 'Prayer Room 2',
          subtitle: 'Another group prayer call',
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              if (_selectedRoomId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Select a room to join.')),
                );
                return;
              }
              setState(() => _roomId = _selectedRoomId);
              await _join();
            },
            child: const Text('Join'),
          ),
        ),
      ],
    );
  }

  Widget _roomOption({
    required String id,
    required String title,
    required String subtitle,
  }) {
    final selected = _selectedRoomId == id;
    return InkWell(
      onTap: () => setState(() => _selectedRoomId = id),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFF795548).withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? const Color(0xFF795548)
                : Colors.black.withOpacity(0.08),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.volume_up,
              color: selected
                  ? const Color(0xFF795548)
                  : const Color(0xFF6C5E55),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Color(0xFF8B8B7A)),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle, color: Color(0xFF795548)),
          ],
        ),
      ),
    );
  }

  Widget _buildRendererTile(RTCVideoRenderer renderer, {String label = ''}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        color: Colors.black,
        child: Stack(
          children: [
            RTCVideoView(
              renderer,
              objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
              mirror: renderer == _localRenderer,
            ),
            if (label.isNotEmpty)
              Positioned(
                left: 8,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
