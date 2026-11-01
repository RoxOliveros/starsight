import 'package:flutter/material.dart';
import '../business_layer/CategorySummaryService.dart';
import '../business_layer/overall_summary_service.dart';
import 'parents_area_screen.dart';

enum OverallSummaryStatus { generating, ready, empty, failed }

class OverallSummaryCard extends StatefulWidget {
  final String childId;

  final String? fallbackName;

  final ValueChanged<OverallSummaryStatus>? onStatusChanged;

  const OverallSummaryCard({
    super.key,
    required this.childId,
    this.fallbackName,
    this.onStatusChanged,
  });

  @override
  State<OverallSummaryCard> createState() => _OverallSummaryCardState();
}

class _OverallSummaryCardState extends State<OverallSummaryCard> {
  late Future<OverallSummary?> _future;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  Future<OverallSummary?> _fetch() {
    final future = OverallSummaryService.load(
      childId: widget.childId,
      fallbackName: widget.fallbackName,
    );
    future.then(
      (summary) => _report(
        summary == null
            ? OverallSummaryStatus.empty
            : OverallSummaryStatus.ready,
      ),
      onError: (_) => _report(OverallSummaryStatus.failed),
    );
    return future;
  }

  void _report(OverallSummaryStatus status) {
    if (!mounted) return;
    widget.onStatusChanged?.call(status);
  }

  void _retry() {
    widget.onStatusChanged?.call(OverallSummaryStatus.generating);
    setState(() => _future = _fetch());
  }

  static const _bodyStyle = TextStyle(
    fontFamily: 'Nunito',
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.45,
    color: ColorTheme.brown,
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF5),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF7D070).withValues(alpha: 0.5),
          width: 3,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 20,
                color: Color(0xFFF7C325),
              ),
              SizedBox(width: 8),
              Text(
                'OVERALL SUMMARY',
                style: TextStyle(
                  fontFamily: AppTextStyles.fredoka,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFF7C325),
                  letterSpacing: 0.6,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<OverallSummary?>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Row(
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Putting the summary together…',
                        style: _bodyStyle,
                      ),
                    ),
                  ],
                );
              }

              if (snapshot.hasError) {
                final error = snapshot.error;
                final message = error is ReportGenerationException
                    ? error.message
                    : "We couldn't load the summary right now.";
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(message, style: _bodyStyle),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: _retry,
                      child: const Text('Try again'),
                    ),
                  ],
                );
              }

              final summary = snapshot.data;
              if (summary == null) {
                return const Text(
                  'Once your child plays a game, the overall summary '
                  'will appear here.',
                  style: _bodyStyle,
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: Text(
                      summary.text,
                      textAlign: TextAlign.justify,
                      style: _bodyStyle,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    summary.categoriesIncluded < summary.categoriesTotal
                        ? '*Based on ${summary.categoriesIncluded} of '
                              '${summary.categoriesTotal} categories played '
                              'so far. This summary will keep changing as '
                              'your child plays or completes more levels in '
                              'each category.*'
                        : '*This summary will keep changing as your child '
                              'plays or completes more levels in each '
                              'category.*',
                    style: TextStyle(
                      fontFamily: 'Nunito',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      color: ColorTheme.brown.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
