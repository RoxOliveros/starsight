import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Result of [AnalysisPdfService.build].
class AnalysisPdfResult {
  /// null when none of the chosen subjects had a saved report.
  final Uint8List? bytes;

  /// Display names of subjects that were left out (no report generated yet).
  final List<String> missingSubjects;

  const AnalysisPdfResult({required this.bytes, required this.missingSubjects});
}

class _SubjectReport {
  final String name;
  final String? playLabel;
  final String? dateText;
  final Map<String, dynamic>? report;

  const _SubjectReport({
    required this.name,
    this.playLabel,
    this.dateText,
    this.report,
  });
}

/// Fonts + text cleanup. If the Google font can't be downloaded (offline on
/// first use), we fall back to built-in Helvetica, which only supports
/// Latin-1, so [clean] swaps smart punctuation for plain characters.
class _PdfStyle {
  final pw.Font base;
  final pw.Font bold;
  final bool unicode;

  const _PdfStyle({
    required this.base,
    required this.bold,
    required this.unicode,
  });

  String clean(Object? value) {
    var s = (value?.toString() ?? '').trim();
    if (unicode) return s;
    s = s
        .replaceAll(RegExp('[\u2018\u2019]'), "'")
        .replaceAll(RegExp('[\u201C\u201D]'), '"')
        .replaceAll(RegExp('[\u2013\u2014]'), '-')
        .replaceAll('\u2026', '...');
    return String.fromCharCodes(s.runes.map((r) => r > 255 ? 63 : r));
  }
}

class AnalysisPdfService {
  AnalysisPdfService._();

  /// Keep in sync with _maxStoredCycles in CategoryReportScreen.
  static const int _maxStoredCycles = 2;

  static const _orange = PdfColor.fromInt(0xFFEC8A20);
  static const _teal = PdfColor.fromInt(0xFF54BDB8);
  static const _gold = PdfColor.fromInt(0xFFFACC58);
  static const _navy = PdfColor.fromInt(0xFF5F7199);
  static const _brown = PdfColor.fromInt(0xFF6F6764);
  static const _cream = PdfColor.fromInt(0xFFFAF7EB);

  static const String _disclaimer =
      'A helpful guide based on gameplay, not a formal assessment.';

  // ── Public API ───────────────────────────────────────────────────────────

  /// [subjects] maps category id (e.g. 'lumi_town') -> display name, in the
  /// order the sections should appear.
  static Future<AnalysisPdfResult> build({
    required String childId,
    required String childName,
    required Map<String, String> subjects,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Not signed in');

    final loaded = await Future.wait(
      subjects.entries.map(
        (e) => _loadSubject(
          uid: uid,
          childId: childId,
          categoryId: e.key,
          name: e.value,
        ),
      ),
    );

    final withReport = loaded.where((s) => s.report != null).toList();
    final missing = loaded
        .where((s) => s.report == null)
        .map((s) => s.name)
        .toList();

    if (withReport.isEmpty) {
      return AnalysisPdfResult(bytes: null, missingSubjects: missing);
    }

    final style = await _loadStyle();
    final bytes = await _buildDocument(
      style: style,
      childName: childName,
      subjects: withReport,
    );
    return AnalysisPdfResult(bytes: bytes, missingSubjects: missing);
  }

  /// Opens the system share sheet (Save to Files / Drive / email / etc.).
  static Future<void> share(Uint8List bytes, String filename) {
    return Printing.sharePdf(bytes: bytes, filename: filename);
  }

  /// Opens the system "save as" dialog so the parent can pick a folder on
  /// the device (Downloads, Documents, SD card...). Returns false if they
  /// cancelled. Uses the system picker, so no storage permission is needed.
  static Future<bool> saveToDevice(Uint8List bytes, String filename) async {
    final path = await FilePicker.saveFile(
      dialogTitle: 'Save report',
      fileName: filename,
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      bytes: bytes,
    );
    return path != null;
  }

  static String filenameFor(String childName) {
    final safe = childName.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
    return 'StarSight_${safe.isEmpty ? 'Child' : safe}_Report.pdf';
  }

  // ── Firestore ────────────────────────────────────────────────────────────

  /// Picks the most recent play that has a saved report, using the same
  /// cycle slots and `cachedReportData` the report screen writes.
  static Future<_SubjectReport> _loadSubject({
    required String uid,
    required String childId,
    required String categoryId,
    required String name,
  }) async {
    try {
      final categoryRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('children')
          .doc(childId)
          .collection('category_progress')
          .doc(categoryId);

      final slotDocs = await Future.wait(
        List.generate(_maxStoredCycles, (i) => i + 1).map(
          (slot) => categoryRef.collection('cycles').doc('cycle_$slot').get(),
        ),
      );

      Map<String, dynamic>? bestData;
      int bestNumber = -1;
      for (var i = 0; i < slotDocs.length; i++) {
        final data = slotDocs[i].data();
        if (data == null || data['cachedReportData'] == null) continue;
        final number = (data['playthroughNumber'] as num?)?.toInt() ?? (i + 1);
        if (number > bestNumber) {
          bestNumber = number;
          bestData = data;
        }
      }

      if (bestData == null) return _SubjectReport(name: name);

      final ts = bestData['lastUpdated'];
      return _SubjectReport(
        name: name,
        playLabel: _playLabel(bestNumber),
        dateText: ts is Timestamp ? _formatDate(ts.toDate()) : null,
        report: Map<String, dynamic>.from(bestData['cachedReportData'] as Map),
      );
    } catch (e) {
      print('Error loading $categoryId for PDF: $e');
      return _SubjectReport(name: name);
    }
  }

  // ── PDF ──────────────────────────────────────────────────────────────────

  static Future<_PdfStyle> _loadStyle() async {
    try {
      return _PdfStyle(
        base: await PdfGoogleFonts.nunitoRegular(),
        bold: await PdfGoogleFonts.nunitoExtraBold(),
        unicode: true,
      );
    } catch (_) {
      return _PdfStyle(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        unicode: false,
      );
    }
  }

  static Future<Uint8List> _buildDocument({
    required _PdfStyle style,
    required String childName,
    required List<_SubjectReport> subjects,
  }) async {
    final doc = pw.Document(
      title: 'StarSight Progress Report - ${style.clean(childName)}',
      author: 'StarSight',
      theme: pw.ThemeData.withFont(base: style.base, bold: style.bold),
    );

    final widgets = <pw.Widget>[
      _titleBlock(style, childName),
      for (var i = 0; i < subjects.length; i++) ...[
        if (i > 0) pw.NewPage(),
        ..._subjectSection(style, subjects[i]),
      ],
    ];

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
        build: (_) => widgets,
        footer: (ctx) => pw.Column(
          children: [
            pw.Divider(color: _brown, thickness: 0.4),
            pw.SizedBox(height: 4),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  _disclaimer,
                  style: const pw.TextStyle(fontSize: 8, color: _brown),
                ),
                pw.Text(
                  'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8, color: _brown),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    return doc.save();
  }

  static pw.Widget _titleBlock(_PdfStyle s, String childName) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(16),
      decoration: pw.BoxDecoration(
        color: _cream,
        borderRadius: pw.BorderRadius.circular(12),
        border: pw.Border.all(color: _orange, width: 1.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'StarSight Progress Report',
            style: pw.TextStyle(font: s.bold, fontSize: 22, color: _orange),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Prepared for ${s.clean(childName)}',
            style: pw.TextStyle(font: s.bold, fontSize: 13, color: _navy),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            'Generated ${_formatDate(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 9, color: _brown),
          ),
        ],
      ),
    );
  }

  static List<pw.Widget> _subjectSection(_PdfStyle s, _SubjectReport subject) {
    final report = subject.report!;
    final subtitle = [
      if (subject.playLabel != null) subject.playLabel!,
      if (subject.dateText != null) subject.dateText!,
    ].join('  |  ');

    const constructs = [
      ('engagement', 'Engagement', _orange),
      ('attention', 'Attention', _teal),
      ('focus', 'Focus', _gold),
    ];

    return [
      pw.SizedBox(height: 18),
      pw.Text(
        s.clean(subject.name),
        style: pw.TextStyle(font: s.bold, fontSize: 18, color: _navy),
      ),
      if (subtitle.isNotEmpty)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 2),
          child: pw.Text(
            s.clean(subtitle),
            style: const pw.TextStyle(fontSize: 9, color: _brown),
          ),
        ),
      pw.SizedBox(height: 10),
      pw.Text(
        'Overall',
        style: pw.TextStyle(font: s.bold, fontSize: 12, color: _orange),
      ),
      pw.SizedBox(height: 4),
      pw.Text(
        s.clean(report['overallAnalysis']),
        style: const pw.TextStyle(fontSize: 10.5, lineSpacing: 3),
      ),
      for (final (key, title, color) in constructs)
        if (report[key] is Map)
          _constructCard(
            s,
            title,
            Map<String, dynamic>.from(report[key] as Map),
            color,
          ),
    ];
  }

  static pw.Widget _constructCard(
    _PdfStyle s,
    String title,
    Map<String, dynamic> c,
    PdfColor color,
  ) {
    final band = s.clean(c['band']);
    final short = s.clean(c['shortSummary']);
    final detail = s.clean(c['detailedDescription']);

    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(top: 12),
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: color, width: 1.2),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text(
                title,
                style: pw.TextStyle(font: s.bold, fontSize: 13, color: color),
              ),
              pw.SizedBox(width: 8),
              if (band.isNotEmpty)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: pw.BoxDecoration(
                    color: color,
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Text(
                    band.toUpperCase(),
                    style: pw.TextStyle(
                      font: s.bold,
                      fontSize: 8,
                      color: PdfColors.white,
                    ),
                  ),
                ),
            ],
          ),
          if (short.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              short,
              style: pw.TextStyle(font: s.bold, fontSize: 10.5, lineSpacing: 2),
            ),
          ],
          if (detail.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              detail,
              style: const pw.TextStyle(fontSize: 10, lineSpacing: 3),
            ),
          ],
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────

  static String _playLabel(int n) {
    if (n % 100 >= 11 && n % 100 <= 13) return '${n}th Play';
    switch (n % 10) {
      case 1:
        return '${n}st Play';
      case 2:
        return '${n}nd Play';
      case 3:
        return '${n}rd Play';
      default:
        return '${n}th Play';
    }
  }

  static String _formatDate(DateTime d) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }
}
