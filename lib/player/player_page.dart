/// 播放页：基于 media_kit 的沉浸式播放器，提供播放、快进、进度拖动与倍速控制。
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../pflx/pflx.dart';
import '../pflx/pflx_stream_server.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({
    super.key,
    required this.sourcePath,
    this.info,
    required this.isPflx,
  });

  final String sourcePath;
  final PflxInfo? info;
  final bool isPflx;

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final Player _player;
  late final VideoController _controller;
  PflxStreamServer? _streamServer;

  bool _ready = false;
  bool _controlsVisible = true;
  bool _playing = false;
  bool _scrubbing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  Duration _scrubPosition = Duration.zero;
  double _speed = 1.0;
  Timer? _hideTimer;
  bool _isLandscape = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
    _initPlayer();
  }

  @override
  void dispose() {
    _cancelAutoHide();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.dark,
    ));
    _streamServer?.stop();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggleOrientation() async {
    setState(() => _isLandscape = !_isLandscape);
    if (_isLandscape) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
    } else {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
    }
    _scheduleAutoHide();
  }

  Future<void> _initPlayer() async {
    _player = Player();
    _controller = VideoController(_player);

    _player.stream.playing.listen((value) {
      if (mounted) {
        setState(() => _playing = value);
        if (value) {
          _scheduleAutoHide();
        } else {
          _cancelAutoHide();
        }
      }
    });
    _player.stream.position.listen((value) {
      if (mounted && !_scrubbing) setState(() => _position = value);
    });
    _player.stream.duration.listen((value) {
      if (mounted) setState(() => _duration = value);
    });

    if (widget.isPflx && widget.info != null) {
      _streamServer = await PflxStreamServer.start(widget.sourcePath, widget.info);
      await _player.open(Media(_streamServer!.url));
    } else {
      await _player.open(Media(widget.sourcePath));
    }

    if (!mounted) return;
    setState(() => _ready = true);
    _scheduleAutoHide();
  }

  void _scheduleAutoHide() {
    _cancelAutoHide();
    if (!_playing || !_controlsVisible || _scrubbing) return;
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && _playing && _controlsVisible && !_scrubbing) {
        setState(() => _controlsVisible = false);
      }
    });
  }

  void _cancelAutoHide() {
    _hideTimer?.cancel();
    _hideTimer = null;
  }

  void _toggleControls() {
    setState(() {
      _controlsVisible = !_controlsVisible;
      if (_controlsVisible) {
        _scheduleAutoHide();
      } else {
        _cancelAutoHide();
      }
    });
  }

  Future<void> _togglePlayback() async {
    if (_playing) {
      await _player.pause();
    } else {
      await _player.play();
    }
  }

  Future<void> _seekRelative(int seconds) async {
    final target = _position + Duration(seconds: seconds);
    final max = _duration == Duration.zero ? target : _duration;
    await _player.seek(_clampDuration(target, Duration.zero, max));
    if (mounted) {
      setState(() => _controlsVisible = true);
      _scheduleAutoHide();
    }
  }

  void _onScrubStart(double value) {
    _cancelAutoHide();
    setState(() {
      _scrubbing = true;
      _scrubPosition = _fromMilliseconds(value);
      _controlsVisible = true;
    });
  }

  void _onScrubUpdate(double value) {
    setState(() => _scrubPosition = _fromMilliseconds(value));
  }

  Future<void> _onScrubEnd(double value) async {
    final target = _fromMilliseconds(value);
    await _player.seek(target);
    if (!mounted) return;
    setState(() {
      _scrubbing = false;
      _position = target;
    });
    _scheduleAutoHide();
  }

  Duration _fromMilliseconds(double value) =>
      Duration(milliseconds: value.round().clamp(0, _duration.inMilliseconds));

  Future<void> _setSpeed(double speed) async {
    await _player.setRate(speed);
    if (mounted) {
      setState(() => _speed = speed);
      _scheduleAutoHide();
    }
  }

  String get _title {
    if (widget.isPflx) return widget.info?['name'] as String? ?? '隐藏视频';
    return widget.sourcePath.replaceAll('\\', '/').split('/').last;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (_, _) {},
      child: Scaffold(
        backgroundColor: Colors.black,
        body: _ready
            ? _buildPlayer()
            : const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
      ),
    );
  }

  Widget _buildPlayer() {
    final currentPosition = _scrubbing ? _scrubPosition : _position;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleControls,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Video(controller: _controller, controls: NoVideoControls),
          ),
          _PlayerScrim(showControls: _controlsVisible),
          _PlayerTopBar(
            visible: _controlsVisible,
            title: _title,
            isPflx: widget.isPflx,
            onClose: () => Navigator.of(context).pop(),
          ),
          Center(
            child: AnimatedOpacity(
              opacity: _controlsVisible ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              child: IgnorePointer(
                ignoring: !_controlsVisible,
                child: _CenterControls(
                  playing: _playing,
                  onReplay: () => _seekRelative(-10),
                  onPlayPause: _togglePlayback,
                  onForward: () => _seekRelative(10),
                ),
              ),
            ),
          ),
          _PlayerBottomControls(
            visible: _controlsVisible,
            playing: _playing,
            isLandscape: _isLandscape,
            position: currentPosition,
            duration: _duration,
            speed: _speed,
            onPlayPause: _togglePlayback,
            onSpeedTap: () => _showSpeedSheet(),
            onToggleOrientation: _toggleOrientation,
            onScrubStart: _onScrubStart,
            onScrubUpdate: _onScrubUpdate,
            onScrubEnd: _onScrubEnd,
          ),
        ],
      ),
    );
  }

  Future<void> _showSpeedSheet() async {
    setState(() => _controlsVisible = true);
    final speed = await showModalBottomSheet<double>(
      context: context,
      backgroundColor: const Color(0xFF202027),
      showDragHandle: true,
      builder: (context) => _SpeedSheet(current: _speed),
    );
    if (speed != null) await _setSpeed(speed);
  }
}

class _PlayerScrim extends StatelessWidget {
  const _PlayerScrim({required this.showControls});

  final bool showControls;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 180),
        opacity: showControls ? 1 : 0,
        child: const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x66000000), Colors.transparent, Color(0x99000000)],
              stops: [0, .46, 1],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlayerTopBar extends StatelessWidget {
  const _PlayerTopBar({
    required this.visible,
    required this.title,
    required this.isPflx,
    required this.onClose,
  });

  final bool visible;
  final String title;
  final bool isPflx;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: SafeArea(
        bottom: false,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, -1.2),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 160),
            child: IgnorePointer(
              ignoring: !visible,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 16, 10),
                child: Row(
                  children: [
                    _RoundControl(
                      tooltip: '退出播放',
                      icon: Icons.keyboard_arrow_down_rounded,
                      onPressed: onClose,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPflx ? Icons.auto_awesome_rounded : Icons.movie_outlined,
                                color: const Color(0xFFD5D1FF),
                                size: 13,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isPflx ? 'PFLX 隐藏视频' : '本地视频',
                                style: const TextStyle(color: Color(0xFFD5D1FF), fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.size = 44,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: .16),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(icon, color: Colors.white, size: size * .54),
          ),
        ),
      ),
    );
  }
}

class _CenterControls extends StatelessWidget {
  const _CenterControls({
    required this.playing,
    required this.onReplay,
    required this.onPlayPause,
    required this.onForward,
  });

  final bool playing;
  final VoidCallback onReplay;
  final VoidCallback onPlayPause;
  final VoidCallback onForward;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _RoundControl(
          tooltip: '后退 10 秒',
          icon: Icons.replay_10_rounded,
          onPressed: onReplay,
          size: 54,
        ),
        const SizedBox(width: 22),
        Tooltip(
          message: playing ? '暂停' : '播放',
          child: Material(
            color: Colors.white,
            elevation: 12,
            shadowColor: Colors.black.withValues(alpha: .55),
            shape: const CircleBorder(),
            child: InkWell(
              onTap: onPlayPause,
              customBorder: const CircleBorder(),
              child: SizedBox(
                width: 74,
                height: 74,
                child: Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  color: const Color(0xFF252432),
                  size: 42,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 22),
        _RoundControl(
          tooltip: '前进 10 秒',
          icon: Icons.forward_10_rounded,
          onPressed: onForward,
          size: 54,
        ),
      ],
    );
  }
}

class _PlayerBottomControls extends StatelessWidget {
  const _PlayerBottomControls({
    required this.visible,
    required this.playing,
    required this.isLandscape,
    required this.position,
    required this.duration,
    required this.speed,
    required this.onPlayPause,
    required this.onSpeedTap,
    required this.onToggleOrientation,
    required this.onScrubStart,
    required this.onScrubUpdate,
    required this.onScrubEnd,
  });

  final bool visible;
  final bool playing;
  final bool isLandscape;
  final Duration position;
  final Duration duration;
  final double speed;
  final VoidCallback onPlayPause;
  final VoidCallback onSpeedTap;
  final VoidCallback onToggleOrientation;
  final ValueChanged<double> onScrubStart;
  final ValueChanged<double> onScrubUpdate;
  final ValueChanged<double> onScrubEnd;

  @override
  Widget build(BuildContext context) {
    final total = duration.inMilliseconds.toDouble();
    final current = position.inMilliseconds.toDouble().clamp(0.0, total <= 0 ? 1.0 : total);
    return Align(
      alignment: Alignment.bottomCenter,
      child: SafeArea(
        top: false,
        child: AnimatedSlide(
          offset: visible ? Offset.zero : const Offset(0, 1.25),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: visible ? 1 : 0,
            duration: const Duration(milliseconds: 160),
            child: IgnorePointer(
              ignoring: !visible,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        activeTrackColor: Colors.white,
                        inactiveTrackColor: Colors.white.withValues(alpha: .28),
                        thumbColor: Colors.white,
                        overlayColor: Colors.white.withValues(alpha: .14),
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 18),
                      ),
                      child: Slider(
                        value: current,
                        min: 0,
                        max: total <= 0 ? 1 : total,
                        onChangeStart: onScrubStart,
                        onChanged: onScrubUpdate,
                        onChangeEnd: onScrubEnd,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        IconButton(
                          onPressed: onPlayPause,
                          tooltip: playing ? '暂停' : '播放',
                          icon: Icon(
                            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Text(
                          _formatDuration(position),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          ' / ${_formatDuration(duration)}',
                          style: const TextStyle(
                            color: Color(0xFFCAC7D0),
                            fontSize: 13,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: onSpeedTap,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.white.withValues(alpha: .16),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            '${speed.toStringAsFixed(speed % 1 == 0 ? 0 : 2)}x',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          onPressed: onToggleOrientation,
                          tooltip: isLandscape ? '切换竖屏' : '切换横屏',
                          icon: Icon(
                            isLandscape
                                ? Icons.screen_lock_portrait_rounded
                                : Icons.screen_rotation_rounded,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SpeedSheet extends StatelessWidget {
  const _SpeedSheet({required this.current});

  final double current;
  static const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '播放速度',
              style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              '选择适合当前视频的播放节奏。',
              style: TextStyle(color: Color(0xFFCBC7D2)),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: _speeds.map((speed) {
                final selected = (speed - current).abs() < .001;
                return ChoiceChip(
                  label: SizedBox(
                    width: 56,
                    child: Text(
                      '${speed.toStringAsFixed(speed % 1 == 0 ? 0 : 2)}x',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  selected: selected,
                  selectedColor: const Color(0xFFC4BEFF),
                  backgroundColor: const Color(0xFF302F39),
                  labelStyle: TextStyle(
                    color: selected ? const Color(0xFF29245A) : Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                  onSelected: (_) => Navigator.of(context).pop(speed),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

Duration _clampDuration(Duration value, Duration minimum, Duration maximum) {
  if (value < minimum) return minimum;
  if (value > maximum) return maximum;
  return value;
}

String _formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  if (hours > 0) {
    return '$hours:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
  return '${duration.inMinutes}:${seconds.toString().padLeft(2, '0')}';
}
