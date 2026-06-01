import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

Future<void> playAssetAudio(AudioPlayer player, String assetPath) async {
  try {
    final dir = await getTemporaryDirectory();
    final data = await rootBundle.load(assetPath);
    final bytes = data.buffer.asUint8List();
    final fileName = assetPath.split('/').last;
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    await player.play(DeviceFileSource(file.path));
  } catch (e) {
    debugPrint('[Audio] Error playing $assetPath: $e');
  }
}

Future<void> waitForAudio(AudioPlayer player) async {
  await player.onPlayerComplete.first;
}
