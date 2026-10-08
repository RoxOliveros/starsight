import 'package:audioplayers/audioplayers.dart';


// USAGE
// SfxHelper.instance.play(Sfx.keyTap);

abstract class Sfx {static const String keyTap = 'audio/sound_effects/bubble_click.wav';}

class SfxHelper {
  SfxHelper._();
  static final SfxHelper instance = SfxHelper._();

  static const int _poolSize = 4;
  final List<AudioPlayer> _pool = [];
  int _next = 0;
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    _ready = true;

    final ctx = AudioContext(
      android: const AudioContextAndroid(
        audioFocus: AndroidAudioFocus.none,
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.ambient,
      ),
    );

    for (var i = 0; i < _poolSize; i++) {
      final p = AudioPlayer();
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setAudioContext(ctx);
      _pool.add(p);
    }
  }

  Future<void> preload(List<String> assets) =>
      AudioCache.instance.loadAll(assets);

  void play(String asset, {double volume = 1.0}) {
    if (!_ready) {
      init().then((_) => play(asset, volume: volume)).catchError((_) {});
      return;
    }
    final p = _pool[_next];
    _next = (_next + 1) % _pool.length;
    p
        .stop()
        .then((_) => p.play(AssetSource(asset), volume: volume))
        .catchError((_) {});
  }
}