import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:livekit_client/livekit_client.dart';

import '../services/api_service.dart';
import 'models/community_group.dart';
import 'models/community_group_activity.dart';
import 'pose/group_pose_analyzer.dart';
import 'pose/group_pose_frame.dart';
import 'pose/group_pose_painter.dart';

class GroupRunScreen extends StatefulWidget {
  final CommunityGroupActivity? activity;
  final CommunityGroup? group;
  final String title;
  final String exerciseType;

  const GroupRunScreen({
    super.key,
    this.activity,
    this.group,
    this.title = '揪團運動視訊房',
    this.exerciseType = 'slow_jogging',
  });

  @override
  State<GroupRunScreen> createState() => _GroupRunScreenState();
}

class _GroupRunScreenState extends State<GroupRunScreen>
    with WidgetsBindingObserver {
  Room? _room;
  EventsListener<RoomEvent>? _events;
  String? _featuredIdentity;
  String? _error;
  String? _cameraNotice;
  bool _joining = false;
  bool _changingMedia = false;
  bool _closing = false;
  bool _isForeground = true;
  bool _showSkeleton = true;
  Timer? _poseTimer;
  GroupPoseAnalyzer? _poseAnalyzer;
  GroupPoseFrame? _localPose;
  final Map<String, GroupPoseFrame> _remotePoses = {};
  final Map<String, int> _remotePoseSequences = {};
  final Map<String, String> _remotePoseSessions = {};
  bool _poseTickBusy = false;
  bool _publishingPose = false;
  int _poseEpoch = 0;
  int _poseSequence = 0;
  DateTime? _lastPosePublish;

  void _startPoseAnalysis(Room room) {
    if (GroupPoseAnalyzer.isSupported) {
      _poseAnalyzer = GroupPoseAnalyzer(
        exerciseTitle: widget.exerciseType == 'squat' ? '深蹲' : '超慢跑',
      );
    }
    _localPose = GroupPoseFrame(status: GroupPoseStatus.waiting);
    _poseTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      unawaited(_samplePose(room));
    });
  }

  Future<void> _samplePose(Room room) async {
    if (_closing || !identical(room, _room)) {
      return;
    }
    _refresh(); // Also expires remote results when their data stream stops.
    if (_poseTickBusy) {
      return;
    }
    _poseTickBusy = true;
    final epoch = _poseEpoch;
    try {
      final local = room.localParticipant;
      if (!_isForeground || local == null || !local.isCameraEnabled()) {
        if (_localPose?.status != GroupPoseStatus.paused) {
          _localPose = GroupPoseFrame(status: GroupPoseStatus.paused);
        }
      } else if (_poseAnalyzer == null) {
        _localPose = GroupPoseFrame(status: GroupPoseStatus.unsupported);
      } else {
        LocalVideoTrack? track;
        for (final publication in local.videoTrackPublications) {
          if (!publication.muted && publication.track is LocalVideoTrack) {
            track = publication.track;
            break;
          }
        }
        if (track == null) {
          return;
        }
        final result =
            await _poseAnalyzer!.sample(track.mediaStreamTrack.captureFrame);
        if (_closing ||
            !identical(room, _room) ||
            epoch != _poseEpoch ||
            !_isForeground ||
            !local.isCameraEnabled()) {
          return;
        }
        _localPose = result;
      }
      final sample = _localPose;
      if (sample != null && identical(room, _room) && !_closing) {
        await _publishPose(room, sample);
        _refresh();
      }
    } finally {
      _poseTickBusy = false;
    }
  }

  Future<void> _publishPose(Room room, GroupPoseFrame frame,
      {bool force = false}) async {
    final now = DateTime.now();
    if (_publishingPose ||
        !identical(room, _room) ||
        _closing ||
        room.connectionState != ConnectionState.connected ||
        (!force &&
            _lastPosePublish != null &&
            now.difference(_lastPosePublish!).inMilliseconds < 450)) {
      return;
    }
    final payload = frame.encode(++_poseSequence, now);
    if (payload.length > 1200) {
      return;
    }
    _publishingPose = true;
    _lastPosePublish = now;
    try {
      await room.localParticipant
          ?.publishData(payload, topic: groupPoseTopic, reliable: false)
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // A lost metrics packet must not disconnect the video call.
    } finally {
      _publishingPose = false;
    }
  }

  void _receivePose(Room room, DataReceivedEvent event) {
    final sender = event.participant;
    if (!identical(room, _room) ||
        _closing ||
        sender == null ||
        event.topic != groupPoseTopic ||
        !room.remoteParticipants.containsKey(sender.identity)) {
      return;
    }
    if (_remotePoseSessions[sender.identity] != sender.sid) {
      _remotePoseSessions[sender.identity] = sender.sid;
      _remotePoseSequences.remove(sender.identity);
    }
    final packet = GroupPoseFrame.decode(event.data, DateTime.now());
    if (packet == null ||
        packet.sequence <= (_remotePoseSequences[sender.identity] ?? -1)) {
      return;
    }
    _remotePoseSequences[sender.identity] = packet.sequence;
    _remotePoses[sender.identity] = packet.frame;
    _refresh();
  }

  void _pausePose() {
    _poseEpoch++;
    _localPose = GroupPoseFrame(status: GroupPoseStatus.paused);
    final room = _room;
    if (room != null) unawaited(_publishPose(room, _localPose!, force: true));
  }

  GroupPoseFrame? _poseFor(Participant participant) =>
      participant.identity == _room?.localParticipant?.identity
          ? _localPose
          : _remotePoses[participant.identity];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _refresh() {
    if (mounted && !_closing) setState(() {});
  }

  String _joinError(Object error) {
    if (error is DioException) {
      final data = error.response?.data;
      if (data is Map && data['detail'] is String) {
        return data['detail'] as String;
      }
      return ApiService().getErrorMessage(error);
    }
    return '視訊連線失敗，請確認網路後重試。';
  }

  Future<void> _join() async {
    if (_joining || _closing) {
      return;
    }
    setState(() {
      _joining = true;
      _error = null;
      _cameraNotice = null;
    });
    try {
      await _releaseRoom();
      final activityId = widget.activity?.id;
      final groupId = widget.group?.id;
      if (activityId == null && groupId == null) {
        throw StateError('Missing group');
      }
      final response = await ApiService().dio.post<Map<String, dynamic>>(
            'group-runs/token/',
            data: activityId != null
                ? {'activity_id': activityId}
                : {'group_id': groupId},
          );
      if (!mounted || _closing) {
        return;
      }
      final data = response.data!;
      final room = Room(
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
      );
      _room = room;
      room.addListener(_refresh);
      _events = room.createListener()
        ..on<DataReceivedEvent>((event) => _receivePose(room, event))
        ..on<ParticipantDisconnectedEvent>((event) {
          _remotePoses.remove(event.participant.identity);
          _remotePoseSequences.remove(event.participant.identity);
          _remotePoseSessions.remove(event.participant.identity);
          _refresh();
        })
        ..on<RoomDisconnectedEvent>((event) {
          if (mounted && !_closing && identical(_room, room)) {
            setState(() => _error = '視訊已中斷，請重新加入。');
          }
        });
      await room.connect(data['url'] as String, data['token'] as String);
      if (!mounted || _closing) {
        return;
      }
      _featuredIdentity = room.localParticipant?.identity;
      // Joining explicitly consents to camera sharing; microphone stays muted.
      try {
        if (_isForeground) {
          await room.localParticipant?.setCameraEnabled(true);
          if (!_isForeground) await _pauseMedia();
        } else {
          _cameraNotice = '已暫停相機與麥克風，可用下方按鈕重新開啟。';
        }
      } catch (_) {
        _cameraNotice = '相機未開啟，請確認相機權限，再按下方相機按鈕重試。';
      }
      if (mounted && !_closing && identical(_room, room)) {
        _startPoseAnalysis(room);
      }
    } catch (error) {
      await _releaseRoom();
      if (mounted && !_closing) _error = _joinError(error);
    } finally {
      if (mounted && !_closing) setState(() => _joining = false);
    }
  }

  Future<void> _releaseRoom() async {
    final room = _room;
    _room = null;
    _poseTimer?.cancel();
    _poseTimer = null;
    _poseEpoch++;
    final analyzer = _poseAnalyzer;
    _poseAnalyzer = null;
    _localPose = null;
    _remotePoses.clear();
    _remotePoseSequences.clear();
    _remotePoseSessions.clear();
    _lastPosePublish = null;
    try {
      await analyzer?.close();
    } catch (_) {
      debugPrint('[GroupPose] 姿勢分析資源清理異常，仍繼續離開視訊。');
    }
    final events = _events;
    _events = null;
    await events?.dispose();
    if (room != null) {
      room.removeListener(_refresh);
      try {
        await room.disconnect();
      } finally {
        await room.dispose();
      }
    }
  }

  Future<void> _toggleMedia({required bool camera}) async {
    final local = _room?.localParticipant;
    if (local == null || _changingMedia || _joining || !_isForeground) {
      return;
    }
    setState(() => _changingMedia = true);
    try {
      if (camera) {
        _pausePose();
        await local.setCameraEnabled(!local.isCameraEnabled());
      } else {
        await local.setMicrophoneEnabled(!local.isMicrophoneEnabled());
      }
      if (!_isForeground) await _pauseMedia();
      if (mounted && _isForeground) setState(() => _cameraNotice = null);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(camera ? '無法切換相機，請確認相機權限。' : '無法切換麥克風，請確認麥克風權限。'),
        ));
      }
    } finally {
      if (mounted) setState(() => _changingMedia = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _isForeground = true;
    if (state == AppLifecycleState.paused) {
      _isForeground = false;
      // Do not transmit video/audio while the app is in the background.
      unawaited(_pauseMedia());
    }
  }

  Future<void> _pauseMedia() async {
    final local = _room?.localParticipant;
    if (local == null) {
      return;
    }
    try {
      _pausePose();
      await local.setCameraEnabled(false);
      await local.setMicrophoneEnabled(false);
      if (mounted && !_closing) {
        setState(() => _cameraNotice = '已暫停相機與麥克風，可用下方按鈕重新開啟。');
      }
    } catch (_) {
      // If media cannot be stopped, leave the room rather than keep publishing.
      await _releaseRoom();
      if (mounted && !_closing) {
        setState(() => _error = '連線已結束，請重新加入。');
      }
    }
  }

  @override
  void dispose() {
    _closing = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_releaseRoom().catchError((Object _) {
      debugPrint('視訊房間已離開，原生資源清理回報異常。');
    }));
    super.dispose();
  }

  Widget _entry() => Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.video_call, size: 64, color: Colors.greenAccent),
            const SizedBox(height: 20),
            Text(_error ?? '和跑友一起運動',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 20)),
            const SizedBox(height: 16),
            const Text(
              '加入後會分享相機畫面、骨架與姿勢分數。\n姿勢由自己的手機分析，麥克風預設關閉。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, height: 1.6),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _joining ? null : _join,
              icon: _joining
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.videocam),
              label: Text(_joining ? '連線中…' : '開啟相機並加入'),
            ),
          ]),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final room = _room;
    final participants = <Participant>[
      if (room?.localParticipant != null) room!.localParticipant!,
      ...?room?.remoteParticipants.values,
    ];
    Participant? featured;
    for (final p in participants) {
      if (p.identity == _featuredIdentity) featured = p;
    }
    featured ??= participants.isNotEmpty ? participants.first : null;
    final local = room?.localParticipant;
    final inRoom = !_joining && _error == null && featured != null;

    return Scaffold(
      backgroundColor: const Color(0xFF111318),
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: _showSkeleton ? '隱藏骨架' : '顯示骨架',
            onPressed: () => setState(() => _showSkeleton = !_showSkeleton),
            icon: Icon(
                _showSkeleton ? Icons.accessibility_new : Icons.person_outline),
          ),
        ],
        backgroundColor: const Color(0xFF16181F),
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.activity?.title ?? widget.title,
              style: const TextStyle(fontSize: 16),
              overflow: TextOverflow.ellipsis),
          if (inRoom)
            Text(
              room?.connectionState == ConnectionState.reconnecting
                  ? '網路中斷，重新連線中…'
                  : '${participants.length} 人在房內',
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
        ]),
      ),
      body: SafeArea(
        child: !inRoom
            ? _entry()
            : Column(children: [
                if (_cameraNotice != null)
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(_cameraNotice!,
                        style: const TextStyle(color: Colors.amberAccent)),
                  ),
                Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: _ParticipantVideo(
                        key: ValueKey('featured-${featured.identity}'),
                        participant: featured,
                        isMe: identical(featured, local),
                        pose: _poseFor(featured),
                        showSkeleton: _showSkeleton,
                      ),
                    )),
                if (participants.length == 1)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('等待其他跑友加入同一個房間…',
                        style: TextStyle(color: Colors.white70)),
                  ),
                Expanded(
                    flex: 2,
                    child: GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 180,
                        childAspectRatio: 0.85,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                      ),
                      itemCount: participants.length,
                      itemBuilder: (_, index) {
                        final p = participants[index];
                        return InkWell(
                          onTap: () =>
                              setState(() => _featuredIdentity = p.identity),
                          child: _ParticipantVideo(
                            key: ValueKey(p.identity),
                            participant: p,
                            isMe: identical(p, local),
                            pose: _poseFor(p),
                            showSkeleton: _showSkeleton,
                          ),
                        );
                      },
                    )),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Wrap(
                    spacing: 20,
                    alignment: WrapAlignment.center,
                    children: [
                      IconButton.filledTonal(
                        tooltip:
                            local?.isCameraEnabled() == true ? '關閉相機' : '開啟相機',
                        onPressed: _changingMedia
                            ? null
                            : () => _toggleMedia(camera: true),
                        icon: Icon(local?.isCameraEnabled() == true
                            ? Icons.videocam
                            : Icons.videocam_off),
                      ),
                      IconButton.filledTonal(
                        tooltip: local?.isMicrophoneEnabled() == true
                            ? '關閉麥克風'
                            : '開啟麥克風',
                        onPressed: _changingMedia
                            ? null
                            : () => _toggleMedia(camera: false),
                        icon: Icon(local?.isMicrophoneEnabled() == true
                            ? Icons.mic
                            : Icons.mic_off),
                      ),
                      IconButton.filled(
                        tooltip: '離開房間',
                        style:
                            IconButton.styleFrom(backgroundColor: Colors.red),
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.call_end, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ]),
      ),
    );
  }
}

class _ParticipantVideo extends StatelessWidget {
  final Participant participant;
  final bool isMe;
  final GroupPoseFrame? pose;
  final bool showSkeleton;

  const _ParticipantVideo(
      {super.key,
      required this.participant,
      required this.isMe,
      this.pose,
      this.showSkeleton = true});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: participant,
        builder: (_, __) {
          VideoTrack? video;
          for (final publication in participant.videoTrackPublications) {
            final track = publication.track;
            if (!publication.muted && track is VideoTrack) {
              video = track;
              break;
            }
          }
          final name = participant.name.isEmpty ? '跑友' : participant.name;
          return Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF252A35),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: participant.isSpeaking
                      ? Colors.greenAccent
                      : Colors.white24,
                  width: 2),
            ),
            child: Stack(fit: StackFit.expand, children: [
              if (video != null)
                VideoTrackRenderer(video,
                    key: ValueKey(video.sid),
                    mirrorMode: VideoViewMirrorMode.off)
              else
                Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.videocam_off,
                      color: Colors.white54, size: 32),
                  const SizedBox(height: 8),
                  Text(participant.isCameraEnabled() ? '影像連線中…' : '相機已關閉',
                      style: const TextStyle(color: Colors.white70)),
                ])),
              if (video != null &&
                  showSkeleton &&
                  pose?.canDisplayScore(DateTime.now()) == true)
                Positioned.fill(
                    child: IgnorePointer(
                        child: CustomPaint(
                  painter: GroupPosePainter(pose!),
                ))),
              if (video != null)
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: _PoseBadge(frame: pose, isMe: isMe),
                ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  color: Colors.black54,
                  child: Text(
                      '${isMe ? '我 · ' : ''}$name${participant.isMicrophoneEnabled() ? '' : ' · 已靜音'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white, fontSize: 12)),
                ),
              ),
            ]),
          );
        },
      );
}

class _PoseBadge extends StatelessWidget {
  final GroupPoseFrame? frame;
  final bool isMe;
  const _PoseBadge({required this.frame, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final data = frame;
    final fresh = data?.isFresh(DateTime.now()) ?? false;
    final valid = data?.canDisplayScore(DateTime.now()) ?? false;
    String text;
    if (valid) {
      text = '姿勢分數 ${data!.score!.toStringAsFixed(0)}/100';
    } else if (data == null || data.status == GroupPoseStatus.waiting) {
      text = isMe ? '正在辨識姿勢…' : '等待跑友姿勢資料';
    } else if (data.status == GroupPoseStatus.paused) {
      text = '姿勢分析已暫停';
    } else if (!fresh) {
      text = '姿勢資料已過期';
    } else {
      text = switch (data.status) {
        GroupPoseStatus.noPose => '請讓全身入鏡',
        GroupPoseStatus.unsupported => '此裝置不支援姿勢分析',
        _ => '姿勢分析暫時無法使用',
      };
    }
    return Align(
      alignment: Alignment.topLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
            color: Colors.black87, borderRadius: BorderRadius.circular(8)),
        child: Text(
            valid && data!.feedback.isNotEmpty
                ? '$text\n${data.feedback}'
                : text,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11,
                color: valid ? Colors.greenAccent : Colors.amberAccent)),
      ),
    );
  }
}
