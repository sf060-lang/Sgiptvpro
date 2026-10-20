import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';

import '../models.dart';
import '../store.dart';
import '../xtream_api.dart';

/// Tam ekran oynatıcı (libmpv). Canlı kanallarda önceki/sonraki kanala geçiş,
/// film/dizilerde kaldığı yerden devam eder.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.entries, this.index = 0});
  final List<PlayEntry> entries;
  final int index;
  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final AppState st;
  late final Player player;
  late final VideoController video;
  late int idx;

  final cur = ValueNotifier<PlayEntry?>(null);
  final fit = ValueNotifier<BoxFit>(BoxFit.contain);
  final error = ValueNotifier<String?>(null);

  int retries = 0;
  bool _disposed = false;
  Timer? _timer;
  final _subs = <StreamSubscription<dynamic>>[];

  bool get isMobile => Platform.isAndroid || Platform.isIOS;
  bool get _isLive => cur.value?.type == MediaType.live;

  @override
  void initState() {
    super.initState();
    st = context.read<AppState>();
    idx = widget.index;

    final bufferMb = isMobile ? 96 : 256;
    player = Player(
      configuration: PlayerConfiguration(bufferSize: bufferMb * 1024 * 1024),
    );
    video = VideoController(
      player,
      configuration: VideoControllerConfiguration(enableHardwareAcceleration: st.hwAccel),
    );

    if (isMobile) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    }

    _subs.add(player.stream.error.listen(_onError));
    _subs.add(player.stream.completed.listen((c) {
      if (c) _onCompleted();
    }));
    // Görüntü çözülmeye başladıysa deneme sayacını sıfırla.
    _subs.add(player.stream.width.listen((w) {
      if ((w ?? 0) > 0) {
        retries = 0;
        if (error.value != null) error.value = null;
      }
    }));
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _savePos());

    _start();
  }

  Future<void> _start() async {
    await _initMpv();
    if (!_disposed) await _open();
  }

  Future<void> _initMpv() async {
    final p = player.platform as dynamic;
    Future<void> set(String k, String v) async {
      try {
        await p.setProperty(k, v);
      } catch (_) {}
    }

    await set('user-agent', XtreamApi.ua);
    await set('tls-verify', 'no');
    await set('network-timeout', '20');
    await set('cache', 'yes');
    await set('cache-secs', '60');
    await set('demuxer-max-bytes', isMobile ? '96MiB' : '256MiB');
    await set('demuxer-max-back-bytes', isMobile ? '32MiB' : '64MiB');
    await set('demuxer-lavf-o',
        'reconnect=1,reconnect_streamed=1,reconnect_on_network_error=1,reconnect_delay_max=5');
    if (!isMobile) {
      await set('hwdec', st.hwAccel ? 'auto-safe' : 'no');
    }
  }

  Future<void> _open() async {
    if (_disposed) return;
    final e = widget.entries[idx];
    cur.value = e;
    if (retries == 0) error.value = null;

    final url = st.api!.urlFor(e, st.liveFormat);
    final pos = e.type == MediaType.live ? 0 : (st.positions[e.key] ?? 0);
    try {
      await player.open(
        Media(
          url,
          httpHeaders: {'User-Agent': XtreamApi.ua},
          start: pos > 10 ? Duration(seconds: pos - 3) : null,
        ),
        play: true,
      );
      st.addHistory(e);
    } catch (err) {
      _onError('$err');
    }
  }

  void _onError(String e) {
    if (_disposed) return;
    if (_isLive && retries < 5) {
      retries++;
      error.value = 'Bağlantı yeniden deneniyor ($retries/5)…';
      Future.delayed(const Duration(seconds: 2), () {
        if (!_disposed) _open();
      });
    } else {
      error.value = 'Oynatılamadı: $e';
    }
  }

  void _onCompleted() {
    if (_disposed) return;
    final e = cur.value;
    if (e == null) return;
    if (e.type == MediaType.live) {
      // Canlı akış beklenmedik şekilde bittiyse yeniden bağlan.
      Future.delayed(const Duration(seconds: 1), () {
        if (!_disposed) _open();
      });
      return;
    }
    st.savePosition(e.key, 0);
    if (e.type == MediaType.series && idx < widget.entries.length - 1) {
      go(1);
    }
  }

  void go(int d) {
    final n = widget.entries.length;
    if (n < 2) return;
    _savePos();
    idx = (idx + d + n) % n;
    retries = 0;
    _open();
  }

  void retry() {
    retries = 0;
    error.value = null;
    _open();
  }

  void _savePos() {
    final e = cur.value;
    if (e == null || e.type == MediaType.live) return;
    final p = player.state.position.inSeconds;
    final d = player.state.duration.inSeconds;
    if (p < 5) return;
    st.savePosition(e.key, (d > 0 && p > d - 30) ? 0 : p);
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    _savePos();
    player.dispose();
    if (isMobile) {
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: ValueListenableBuilder<BoxFit>(
        valueListenable: fit,
        builder: (_, f, __) => Video(
          controller: video,
          fit: f,
          controls: (state) => _Controls(host: this, state: state),
        ),
      ),
    );
  }
}

class _Controls extends StatefulWidget {
  const _Controls({required this.host, required this.state});
  final _PlayerScreenState host;
  final VideoState state;
  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  bool _visible = true;
  Timer? _hide;
  final _focus = FocusNode();
  double? _drag;

  _PlayerScreenState get host => widget.host;
  Player get p => host.player;
  bool get _live => host.cur.value?.type == MediaType.live;

  @override
  void initState() {
    super.initState();
    _arm();
  }

  @override
  void dispose() {
    _hide?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _arm() {
    _hide?.cancel();
    _hide = Timer(const Duration(seconds: 4), () {
      if (mounted && p.state.playing) setState(() => _visible = false);
    });
  }

  void _show() {
    if (!_visible) setState(() => _visible = true);
    _arm();
  }

  void _back() {
    if (widget.state.isFullscreen()) {
      widget.state.exitFullscreen();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  void _seekBy(int sec) {
    final target = p.state.position + Duration(seconds: sec);
    p.seek(target < Duration.zero ? Duration.zero : target);
  }

  KeyEventResult _onKey(FocusNode n, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    _show();
    if (k == LogicalKeyboardKey.space || k == LogicalKeyboardKey.mediaPlayPause) {
      p.playOrPause();
    } else if (k == LogicalKeyboardKey.arrowUp || k == LogicalKeyboardKey.pageUp) {
      host.go(-1);
    } else if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.pageDown) {
      host.go(1);
    } else if (k == LogicalKeyboardKey.arrowLeft) {
      if (!_live) _seekBy(-10);
    } else if (k == LogicalKeyboardKey.arrowRight) {
      if (!_live) _seekBy(10);
    } else if (k == LogicalKeyboardKey.keyF || k == LogicalKeyboardKey.f11) {
      if (!host.isMobile) widget.state.toggleFullscreen();
    } else if (k == LogicalKeyboardKey.keyM) {
      p.setVolume(p.state.volume > 0 ? 0 : 100);
    } else if (k == LogicalKeyboardKey.escape) {
      _back();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: MouseRegion(
        onHover: (_) => _show(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            setState(() => _visible = !_visible);
            if (_visible) _arm();
          },
          onDoubleTap: () {
            if (host.isMobile) {
              p.playOrPause();
            } else {
              widget.state.toggleFullscreen();
            }
          },
          child: Stack(
            children: [
              Center(
                child: StreamBuilder<bool>(
                  stream: p.stream.buffering,
                  initialData: p.state.buffering,
                  builder: (_, s) =>
                      s.data == true ? const CircularProgressIndicator() : const SizedBox.shrink(),
                ),
              ),
              ValueListenableBuilder<String?>(
                valueListenable: host.error,
                builder: (_, e, __) => e == null ? const SizedBox.shrink() : _errorCard(e),
              ),
              IgnorePointer(
                ignoring: !_visible,
                child: AnimatedOpacity(
                  opacity: _visible ? 1 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Column(
                    children: [
                      _top(),
                      Expanded(child: _center()),
                      _bottom(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorCard(String e) => Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(16),
          decoration:
              BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 36, color: Colors.white),
              const SizedBox(height: 8),
              Text(e, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FilledButton(onPressed: host.retry, child: const Text('Tekrar dene')),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: _back, child: const Text('Geri')),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _top() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back),
            Expanded(
              child: ValueListenableBuilder<PlayEntry?>(
                valueListenable: host.cur,
                builder: (_, e, __) => Text(
                  e?.title ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            _resolutionBadge(),
            ValueListenableBuilder<PlayEntry?>(
              valueListenable: host.cur,
              builder: (_, e, __) {
                if (e == null || e.type == MediaType.series) return const SizedBox.shrink();
                return ListenableBuilder(
                  listenable: host.st,
                  builder: (_, __) {
                    final fav = host.st.isFavEntry(e);
                    return IconButton(
                      tooltip: 'Favori',
                      icon: Icon(fav ? Icons.star : Icons.star_border,
                          color: fav ? Colors.amber : null),
                      onPressed: () => host.st.toggleFavEntry(e),
                    );
                  },
                );
              },
            ),
            _trackMenu(audio: true),
            _trackMenu(audio: false),
            ValueListenableBuilder<BoxFit>(
              valueListenable: host.fit,
              builder: (_, f, __) => IconButton(
                tooltip: 'En-boy oranı',
                icon: const Icon(Icons.aspect_ratio),
                onPressed: () {
                  host.fit.value = switch (f) {
                    BoxFit.contain => BoxFit.cover,
                    BoxFit.cover => BoxFit.fill,
                    _ => BoxFit.contain,
                  };
                  _arm();
                },
              ),
            ),
            if (!host.isMobile)
              IconButton(
                tooltip: 'Tam ekran (F)',
                icon: const Icon(Icons.fullscreen),
                onPressed: () => widget.state.toggleFullscreen(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _resolutionBadge() {
    return StreamBuilder<int?>(
      stream: p.stream.width,
      initialData: p.state.width,
      builder: (_, ws) => StreamBuilder<int?>(
        stream: p.stream.height,
        initialData: p.state.height,
        builder: (_, hs) {
          final w = ws.data ?? 0, h = hs.data ?? 0;
          if (w == 0 || h == 0) return const SizedBox.shrink();
          final label = w >= 7000
              ? '8K'
              : w >= 3600
                  ? '4K'
                  : w >= 2400
                      ? '2K'
                      : w >= 1800
                          ? 'FHD'
                          : w >= 1200
                              ? 'HD'
                              : 'SD';
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 6),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(6)),
            child: Text('$label  $w×$h',
                style: const TextStyle(fontSize: 12, color: Colors.white)),
          );
        },
      ),
    );
  }

  String _trackLabel(Object x) {
    String id = '';
    String? title, lang;
    if (x is AudioTrack) {
      id = x.id;
      title = x.title;
      lang = x.language;
    } else if (x is SubtitleTrack) {
      id = x.id;
      title = x.title;
      lang = x.language;
    }
    if (id == 'auto') return 'Otomatik';
    if (id == 'no') return 'Kapalı';
    final parts = [title, lang].where((e) => e != null && e.isNotEmpty).join(' · ');
    return parts.isEmpty ? 'Parça $id' : parts;
  }

  Widget _trackMenu({required bool audio}) {
    return StreamBuilder<Tracks>(
      stream: p.stream.tracks,
      initialData: p.state.tracks,
      builder: (_, s) {
        final t = s.data ?? p.state.tracks;
        final List<Object> list = audio ? t.audio : t.subtitle;
        if (list.length <= 2) return const SizedBox.shrink();
        return PopupMenuButton<Object>(
          tooltip: audio ? 'Ses' : 'Altyazı',
          icon: Icon(audio ? Icons.audiotrack : Icons.subtitles),
          onSelected: (v) {
            if (v is AudioTrack) p.setAudioTrack(v);
            if (v is SubtitleTrack) p.setSubtitleTrack(v);
          },
          itemBuilder: (_) => [
            for (final x in list) PopupMenuItem<Object>(value: x, child: Text(_trackLabel(x))),
          ],
        );
      },
    );
  }

  Widget _center() {
    final multi = host.widget.entries.length > 1;
    return ValueListenableBuilder<PlayEntry?>(
      valueListenable: host.cur,
      builder: (_, e, __) {
        final live = e?.type == MediaType.live;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (multi)
              IconButton(
                iconSize: 40,
                tooltip: 'Önceki (↑)',
                icon: const Icon(Icons.skip_previous),
                onPressed: () => host.go(-1),
              ),
            if (!live)
              IconButton(
                iconSize: 40,
                tooltip: '-10 sn (←)',
                icon: const Icon(Icons.replay_10),
                onPressed: () => _seekBy(-10),
              ),
            StreamBuilder<bool>(
              stream: p.stream.playing,
              initialData: p.state.playing,
              builder: (_, s) => IconButton(
                iconSize: 64,
                icon: Icon(s.data == true ? Icons.pause_circle : Icons.play_circle),
                onPressed: p.playOrPause,
              ),
            ),
            if (!live)
              IconButton(
                iconSize: 40,
                tooltip: '+10 sn (→)',
                icon: const Icon(Icons.forward_10),
                onPressed: () => _seekBy(10),
              ),
            if (multi)
              IconButton(
                iconSize: 40,
                tooltip: 'Sonraki (↓)',
                icon: const Icon(Icons.skip_next),
                onPressed: () => host.go(1),
              ),
          ],
        );
      },
    );
  }

  Widget _bottom() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
          child: ValueListenableBuilder<PlayEntry?>(
            valueListenable: host.cur,
            builder: (_, e, __) {
              final live = e?.type == MediaType.live;
              return Row(
                children: [
                  if (live)
                    const Expanded(
                      child: Row(
                        children: [
                          Icon(Icons.circle, size: 10, color: Colors.redAccent),
                          SizedBox(width: 6),
                          Text('CANLI'),
                        ],
                      ),
                    )
                  else
                    Expanded(child: _seekBar()),
                  if (!host.isMobile) _volume(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _seekBar() {
    return StreamBuilder<Duration>(
      stream: p.stream.position,
      initialData: p.state.position,
      builder: (_, s) {
        final dur = p.state.duration;
        final maxMs = dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1.0;
        final pos = (s.data ?? Duration.zero).inMilliseconds.toDouble().clamp(0.0, maxMs);
        final shown = _drag ?? pos;
        return Row(
          children: [
            Text(_fmt(Duration(milliseconds: shown.toInt()))),
            Expanded(
              child: Slider(
                value: shown.clamp(0.0, maxMs),
                max: maxMs,
                onChanged: (v) {
                  setState(() => _drag = v);
                  _arm();
                },
                onChangeEnd: (v) {
                  p.seek(Duration(milliseconds: v.toInt()));
                  setState(() => _drag = null);
                },
              ),
            ),
            Text(_fmt(dur)),
          ],
        );
      },
    );
  }

  Widget _volume() {
    return SizedBox(
      width: 170,
      child: StreamBuilder<double>(
        stream: p.stream.volume,
        initialData: p.state.volume,
        builder: (_, s) {
          final v = (s.data ?? 100).clamp(0.0, 100.0);
          return Row(
            children: [
              IconButton(
                icon: Icon(v == 0 ? Icons.volume_off : Icons.volume_up),
                onPressed: () => p.setVolume(v > 0 ? 0 : 100),
              ),
              Expanded(
                child: Slider(value: v, max: 100, onChanged: (x) => p.setVolume(x)),
              ),
            ],
          );
        },
      ),
    );
  }
}
