import 'dart:async';
import 'package:flutter/material.dart';

mixin GameLoadingMixin<T extends StatefulWidget> on State<T> {
  bool isGameLoading = true;
  DateTime _loadStart = DateTime.now();

  Duration get minLoadTime => const Duration(milliseconds: 1500);

  void restartLoading() {
    setState(() {
      isGameLoading = true;
      _loadStart = DateTime.now();
    });
  }

  Future<void> finishLoading(VoidCallback onDone) async {
    final elapsed = DateTime.now().difference(_loadStart);
    final remaining = minLoadTime - elapsed;
    if (remaining > Duration.zero) {
      await Future.delayed(remaining);
    }
    if (!mounted) return;
    setState(() => isGameLoading = false);
    onDone();
  }

  /// [overlay], when provided, is stacked on top of whichever state is
  /// currently showing (loadingScreen OR gameBuilder()). Use this for
  /// anything that needs to be visible *before* loading finishes — e.g. a
  /// face-detection prompt that itself gates when loading finishes. Putting
  /// that kind of widget inside [gameBuilder] instead creates a deadlock:
  /// gameBuilder never renders until loading is done, but loading may be
  /// waiting on something only the hidden widget could surface.
  Widget buildWithLoading({
    required Widget loadingScreen,
    required Widget Function() gameBuilder,
    Widget? overlay,
  }) {
    final base = isGameLoading ? loadingScreen : gameBuilder();
    if (overlay == null) return base;
    return Stack(
      children: [
        Positioned.fill(child: base),
        overlay,
      ],
    );
  }
}
