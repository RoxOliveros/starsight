import 'dart:io';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

/// Loads an asset WAV file into a temp file and plays it.
/// Returns the AudioPlayer so caller can listen to onPlayerComplete.
Future<void> playAssetAudio(AudioPlayer player, String assetPath) async {
  final dir = await getTemporaryDirectory();
  final data = await rootBundle.load(assetPath);
  final bytes = data.buffer.asUint8List();
  final fileName = assetPath.split('/').last;
  final file = File('${dir.path}/$fileName');
  await file.writeAsBytes(bytes, flush: true);
  await player.play(DeviceFileSource(file.path));
}

/// Waits for the player to finish, then resolves.
Future<void> waitForAudio(AudioPlayer player) async {
  await player.onPlayerComplete.first;
}
