import 'dart:typed_data';

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
        mainAxisSize: MainAxisSize.min,
        children: [
          _thumbnailRow(state),
          ..._content(context, state),
        ],
      ),
    );
  }

  Widget _thumbnailRow(FaceMatchState s) {
    final reference = s.reference;
    final candidate = s is FaceMatchVerified ? s.candidate : null;
    if (reference == null && candidate == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          if (reference != null)
            _Thumbnail(label: 'Reference', bytes: reference.imageBytes),
          if (reference != null && candidate != null)
            const SizedBox(width: 12),
          if (candidate != null)
            _Thumbnail(label: 'Candidate', bytes: candidate.imageBytes),
        ],
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
      FaceMatchInitial() => const [
          Text(
            'Ready',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 4),
          Text('Tap "Capture Reference" to start.'),
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
          const SizedBox(height: 4),
          const Text('Now tap "Verify" with the same or a different person.'),
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
          const SizedBox(height: 4),
          Text('Cosine similarity: ${r.similarity.toStringAsFixed(4)}'),
          Text('UI confidence:     ${r.confidence.toStringAsFixed(2)}%'),
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

class _Thumbnail extends StatelessWidget {
  final String label;
  final Uint8List bytes;

  const _Thumbnail({required this.label, required this.bytes});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.memory(
            bytes,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
            gaplessPlayback: true,
          ),
        ),
      ],
    );
  }
}
