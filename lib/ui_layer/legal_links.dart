import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

abstract class LegalUrls {
  static const String terms =
      'https://roxoliveros.github.io/starsight-legal/terms.html';
  static const String privacy =
      'https://roxoliveros.github.io/starsight-legal/privacy.html';
}

Future<void> openLegal(BuildContext context, String url) async {
  bool opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.inAppBrowserView,
    );
  } catch (_) {}

  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Could not open the page. Check your internet connection.'),
      ),
    );
  }
}