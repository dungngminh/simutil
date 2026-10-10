import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:simutil_adb/simutil_adb.dart';

/// Plays a [ScrcpySession]'s MPEG-TS feed with libmpv tuned for latency.
class ScrcpyVideoView extends StatefulWidget {
  const ScrcpyVideoView({super.key, required this.session});

  final ScrcpySession session;

  @override
  State<ScrcpyVideoView> createState() => _ScrcpyVideoViewState();
}

class _ScrcpyVideoViewState extends State<ScrcpyVideoView> {
  final _player = Player();
  late final _controller = VideoController(_player);

  static const _mpvOptions = [
    ('load-unsafe-playlists', 'yes'),
    ('demuxer', 'lavf'),
    ('demuxer-lavf-format', 'mpegts'),
    ('demuxer-lavf-analyzeduration', '0.1'),
    ('demuxer-lavf-probesize', '4096'),
    ('untimed', 'yes'),
    ('cache', 'no'),
    ('demuxer-readahead-secs', '0'),
    ('video-latency-hacks', 'yes'),
    ('network-timeout', '0'),
    ('interpolation', 'no'),
  ];

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final native = _player.platform as NativePlayer;
    for (final (key, value) in _mpvOptions) {
      await native.setProperty(key, value);
    }
    await _player.setVolume(0);
    final uri = widget.session.videoUri;
    if (uri != null && mounted) await _player.open(Media(uri.toString()));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Video(
    controller: _controller,
    controls: NoVideoControls,
    fill: const Color(0xFF000000),
  );
}
