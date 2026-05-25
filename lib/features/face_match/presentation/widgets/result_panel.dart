import 'package:flutter/material.dart';

import '../cubit/face_match_state.dart';

class ResultPanel extends StatelessWidget {
  final FaceMatchState state;

  const ResultPanel({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _backgroundFor(state),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _content(context, state),
      ),
    );
  }

  Color _backgroundFor(FaceMatchState s) {
    return switch (s) {
      FaceMatchInitial() => Colors.grey.shade100,
      FaceMatchLoading() => Colors.blue.shade50,
      FaceMatchReferenceCaptured() => Colors.green.shade50,
      FaceMatchVerified(result: final r) =>
        r.passed ? Colors.green.shade100 : Colors.orange.shade100,
      FaceMatchFailureState() => Colors.red.shade50,
    };
  }

  List<Widget> _content(BuildContext ctx, FaceMatchState s) {
    return switch (s) {
      FaceMatchInitial() => [
          const Text(
            'Ready',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          const Text(
            'Tap "Capture Reference" to start.',
          ),
        ],
      FaceMatchLoading(message: final m) => [
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 8),
              Text(m ?? 'Working...'),
            ],
          ),
        ],
      FaceMatchReferenceCaptured(reference: final r) => [
          const Text(
            'Reference captured ✓',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text('Embedding length: ${r.vector.length}'),
          Text('Captured at: ${r.computedAt}'),
          const SizedBox(height: 4),
          const Text(
            'Now tap "Verify" with the same or a different person.',
          ),
        ],
      FaceMatchVerified(result: final r) => [
          Text(
            r.passed ? 'MATCH ✓' : 'NO MATCH ✗',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: r.passed ? Colors.green.shade900 : Colors.orange.shade900,
            ),
          ),
          const SizedBox(height: 8),
          Text('Cosine similarity: ${r.similarity.toStringAsFixed(4)}'),
          Text('UI confidence:     ${r.confidence.toStringAsFixed(2)}%'),
          Text('Timestamp:         ${r.timestamp}'),
          const SizedBox(height: 4),
          const Text(
            'Tap "Verify" again to capture another candidate.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ],
      FaceMatchFailureState(failure: final f) => [
          Text(
            'Error',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.red.shade900,
            ),
          ),
          const SizedBox(height: 4),
          Text(f.message),
        ],
    };
  }
}
