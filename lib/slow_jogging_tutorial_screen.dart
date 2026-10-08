import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import 'services/user_session.dart';

class SlowJoggingTutorial {
  static const String _preferenceKeyPrefix = 'slow_jogging_tutorial_seen_v1';

  static Future<void> playIfNeeded(BuildContext context) async {
    await _ExerciseTutorial.playIfNeeded(
      context,
      preferenceKeyPrefix: _preferenceKeyPrefix,
      title: '超慢跑教學',
      assetPath: 'assets/videos/slow_jogging_tutorial.mp4',
    );
  }
}

class SquatTutorial {
  static const String _preferenceKeyPrefix = 'squat_tutorial_seen_v1';

  static Future<void> playIfNeeded(BuildContext context) async {
    await _ExerciseTutorial.playIfNeeded(
      context,
      preferenceKeyPrefix: _preferenceKeyPrefix,
      title: '深蹲教學',
      assetPath: 'assets/videos/squat_tutorial.mp4',
    );
  }
}

class _ExerciseTutorial {
  static Future<void> playIfNeeded(
    BuildContext context, {
    required String preferenceKeyPrefix,
    required String title,
    required String assetPath,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final preferenceKey = '${preferenceKeyPrefix}_${UserSession.memberId}';

    if (preferences.getBool(preferenceKey) == true || !context.mounted) {
      return;
    }

    final didFinish = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ExerciseTutorialScreen(
          title: title,
          assetPath: assetPath,
        ),
      ),
    );

    if (didFinish == true) {
      await preferences.setBool(preferenceKey, true);
    }
  }
}

class ExerciseTutorialScreen extends StatefulWidget {
  final String title;
  final String assetPath;

  const ExerciseTutorialScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  @override
  State<ExerciseTutorialScreen> createState() => _ExerciseTutorialScreenState();
}

class _ExerciseTutorialScreenState extends State<ExerciseTutorialScreen> {
  late final VideoPlayerController _controller;
  late final Future<void> _initialization;
  int _completedPlayCount = 0;
  bool _isHandlingCompletion = false;
  bool _isLeaving = false;
  bool _showOrientationHint = true;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.assetPath)
      ..addListener(_handlePlaybackUpdate);
    _initialization = _initializeAndPlay();
  }

  Future<void> _initializeAndPlay() async {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    try {
      await _controller.initialize();
      await Future<void>.delayed(const Duration(seconds: 2));

      if (!mounted || _isLeaving) return;

      setState(() {
        _showOrientationHint = false;
      });

      await _controller.play();
    } catch (_) {
      if (mounted) {
        setState(() {
          _showOrientationHint = false;
        });
      }
      rethrow;
    }
  }

  void _handlePlaybackUpdate() {
    if (_isLeaving ||
        _isHandlingCompletion ||
        !_controller.value.isInitialized) {
      return;
    }

    final duration = _controller.value.duration;
    final position = _controller.value.position;

    if (duration > Duration.zero &&
        position >= duration - const Duration(milliseconds: 100)) {
      _handleVideoCompleted();
    }
  }

  Future<void> _handleVideoCompleted() async {
    if (_isLeaving || _isHandlingCompletion) {
      return;
    }

    _isHandlingCompletion = true;
    _completedPlayCount++;

    if (_completedPlayCount < 2) {
      await _controller.seekTo(Duration.zero);

      if (!mounted || _isLeaving) return;

      await _controller.play();
      _isHandlingCompletion = false;
      return;
    }

    await _controller.pause();

    if (!mounted || _isLeaving) return;

    final replay = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('是否重新觀看？'),
        content: Text(
          '教學影片已播放 $_completedPlayCount 次。你可以再看一次，或直接開始運動。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('開始運動'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('重新觀看'),
          ),
        ],
      ),
    );

    if (!mounted || _isLeaving) return;

    if (replay == true) {
      await _controller.seekTo(Duration.zero);

      if (!mounted || _isLeaving) return;

      await _controller.play();
      _isHandlingCompletion = false;
      return;
    }

    _finishTutorial();
  }

  void _finishTutorial() {
    if (_isLeaving || !mounted) {
      return;
    }

    _isLeaving = true;
    _restorePortraitMode();
    Navigator.of(context).pop(true);
  }

  void _restorePortraitMode() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  void _togglePlayback() {
    if (!_controller.value.isInitialized) {
      return;
    }

    if (_controller.value.isPlaying) {
      _controller.pause();
    } else {
      _controller.play();
    }

    setState(() {});
  }

  @override
  void dispose() {
    _restorePortraitMode();
    _controller
      ..removeListener(_handlePlaybackUpdate)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<void>(
              future: _initialization,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _VideoError(onContinue: _finishTutorial);
                }

                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _togglePlayback,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: _controller.value.aspectRatio,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                );
              },
            ),
            Positioned(
              top: 12,
              left: 20,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 12,
              child: TextButton(
                onPressed: _finishTutorial,
                style: TextButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.55),
                  foregroundColor: Colors.white,
                ),
                child: const Text('跳過'),
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 20,
              child: FutureBuilder<void>(
                future: _initialization,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done ||
                      snapshot.hasError) {
                    return const SizedBox.shrink();
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      VideoProgressIndicator(
                        _controller,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: Colors.white,
                          bufferedColor: Colors.white38,
                          backgroundColor: Colors.white24,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        '點擊畫面可暫停或繼續播放',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  );
                },
              ),
            ),
            if (_showOrientationHint)
              const Positioned.fill(
                child: ColoredBox(
                  color: Colors.black,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.screen_rotation_rounded,
                          color: Colors.white,
                          size: 72,
                        ),
                        SizedBox(height: 20),
                        Text(
                          '請將手機橫放',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          '即將以全螢幕播放教學影片',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _VideoError extends StatelessWidget {
  final VoidCallback onContinue;

  const _VideoError({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 48),
            const SizedBox(height: 16),
            const Text(
              '教學影片暫時無法播放',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: onContinue,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: const Text('繼續開始運動'),
            ),
          ],
        ),
      ),
    );
  }
}
