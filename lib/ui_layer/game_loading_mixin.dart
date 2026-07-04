import 'dart:async';
import 'package:flutter/material.dart';

mixin GameLoadingMixin<T extends StatefulWidget> on State<T> {
  bool isGameLoading = true;
  final DateTime _loadStart = DateTime.now();

  Duration get minLoadTime => const Duration(milliseconds: 1500);

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

  Widget buildWithLoading({
    required Widget loadingScreen,
    required Widget Function() gameBuilder,
  }) {
    return isGameLoading ? loadingScreen : gameBuilder();
  }
}