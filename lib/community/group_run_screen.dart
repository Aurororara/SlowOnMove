import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:livekit_client/livekit_client.dart';

import '../services/api_service.dart';
import 'models/community_group.dart';
import 'models/community_group_activity.dart';

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
    if (_joining || _closing) return;
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
      if (!mounted || _closing) return;
      final data = response.data!;
      final room = Room(
        roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
      );
      _room = room;
      room.addListener(_refresh);
      _events = room.createListener()
        ..on<RoomDisconnectedEvent>((event) {
          if (mounted && !_closing && identical(_room, room)) {
            setState(() => _error = '視訊已中斷，請重新加入。');
          }
        });
      await room.connect(data['url'] as String, data['token'] as String);
      if (!mounted || _closing) return;
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
    if (local == null || _changingMedia || _joining || !_isForeground) return;
    setState(() => _changingMedia = true);
    try {
      if (camera) {
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
    if (local == null) return;
    try {
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
              '加入後會分享你的相機畫面給房內成員。\n麥克風預設關閉，可隨時切換或離開。',
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

  const _ParticipantVideo(
      {super.key, required this.participant, required this.isMe});

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
                VideoTrackRenderer(video, key: ValueKey(video.sid))
              else
                Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.videocam_off,
                      color: Colors.white54, size: 32),
                  const SizedBox(height: 8),
                  Text(participant.isCameraEnabled() ? '影像連線中…' : '相機已關閉',
                      style: const TextStyle(color: Colors.white70)),
                ])),
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
