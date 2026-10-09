import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import '../business_layer/audio_settings.dart';

final AudioContext _voiceContext = AudioContext(
  android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
  iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
);
final Expando<bool> _configured = Expando<bool>();
Directory? _dir;

Future<void> playAssetAudio(AudioPlayer player, String assetPath) async {
  if (_configured[player] != true) {
    await player.setAudioContext(_voiceContext);
    _configured[player] = true;
  }
  _dir ??= await getTemporaryDirectory();
  final bytes = (await rootBundle.load(assetPath)).buffer.asUint8List();
  final file = File('${_dir!.path}/${assetPath.replaceAll('/', '_')}');
  if (!await file.exists() || await file.length() != bytes.length) {
    await file.writeAsBytes(bytes, flush: true);
  }
  await player.play(
    DeviceFileSource(file.path),
    volume: AudioSettings.instance.gamesVolume,
  );
}

Future<void> waitForAudio(AudioPlayer player) async {
  if (player.state != PlayerState.playing &&
      player.state != PlayerState.paused) {
    return;
  }
  try {
    await player.onPlayerStateChanged.firstWhere((s) =>
    s == PlayerState.completed ||
        s == PlayerState.stopped ||
        s == PlayerState.disposed);
  } catch (_) {
  }
}