import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AudioSettings extends ChangeNotifier {
  AudioSettings._();
  static final AudioSettings instance = AudioSettings._();

  bool _musicOn = true;
  double _musicVolume = 1.0; // multiplier on each track's base volume
  bool _sfxOn = true;
  double _sfxVolume = 1.0;

  bool get musicOn => _musicOn;
  double get musicVolume => _musicVolume;
  bool get sfxOn => _sfxOn;
  double get sfxVolume => _sfxVolume;

  Future<void> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      _musicOn = p.getBool('music_on') ?? true;
      _musicVolume = p.getDouble('music_volume') ?? 1.0;
      _sfxOn = p.getBool('sfx_on') ?? true;
      _sfxVolume = p.getDouble('sfx_volume') ?? 1.0;
    } catch (e) {
      debugPrint('AudioSettings: load failed: $e');
    }
  }

  void setMusicOn(bool v) {
    _musicOn = v;
    notifyListeners();
    _save((p) => p.setBool('music_on', v));
  }

  void setMusicVolume(double v) {
    _musicVolume = v.clamp(0.0, 1.0);
    notifyListeners();
    _save((p) => p.setDouble('music_volume', _musicVolume));
  }

  void setSfxOn(bool v) {
    _sfxOn = v;
    notifyListeners();
    _save((p) => p.setBool('sfx_on', v));
  }

  void setSfxVolume(double v) {
    _sfxVolume = v.clamp(0.0, 1.0);
    notifyListeners();
    _save((p) => p.setDouble('sfx_volume', _sfxVolume));
  }

  Future<void> _save(Future<bool> Function(SharedPreferences) write) async {
    try {
      await write(await SharedPreferences.getInstance());
    } catch (e) {
      debugPrint('AudioSettings: save failed: $e');
    }
  }
}