import 'dart:io';

void main() async {
  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    stderr.writeln('pubspec.yaml not found.');
    exit(1);
  }

  final content = await pubspecFile.readAsString();
  final versionRegex = RegExp(
    r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)',
    multiLine: true,
  );
  final match = versionRegex.firstMatch(content);

  if (match == null) {
    stderr.writeln(
      'Could not parse version in pubspec.yaml (expected format: x.y.z+build)',
    );
    exit(1);
  }

  final major = match.group(1)!;
  final minor = match.group(2)!; // Keeps your sprint version intact (e.g., 3)
  final patch = int.parse(match.group(3)!) + 1; // Increments bugfix digit
  final build = int.parse(match.group(4)!) + 1; // Increments build number

  final newVersionString = 'version: $major.$minor.$patch+$build';
  final updatedContent = content.replaceFirst(versionRegex, newVersionString);

  await pubspecFile.writeAsString(updatedContent);
  stdout.writeln('Bumped version to: $major.$minor.$patch+$build');

  stdout.writeln('Building release APK...');
  final process = await Process.start('flutter', [
    'build',
    'apk',
    '--release',
  ], mode: ProcessStartMode.inheritStdio);

  final exitCode = await process.exitCode;
  exit(exitCode);
}
