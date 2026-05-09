import 'package:lottie/lottie.dart';

class LottieCache {
  static final LottieCache _instance = LottieCache._();
  static LottieCache get instance => _instance;
  LottieCache._();

  final Map<String, LottieComposition> _cache = {};

  Future<void> preload(List<String> paths) async {
    await Future.wait(
      paths.map((path) async {
        if (!_cache.containsKey(path)) {
          _cache[path] = await AssetLottie(path).load();
        }
      }),
    );
  }

  LottieComposition? get(String path) => _cache[path];
}