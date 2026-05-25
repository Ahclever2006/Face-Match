import 'dart:math' as math;

import 'package:injectable/injectable.dart';

@lazySingleton
class EmbeddingMathService {
  /// Returns the unit-length version of the vector (L2 normalization).
  List<double> l2Normalize(List<double> vector) {
    double sumOfSquares = 0.0;
    for (final v in vector) {
      sumOfSquares += v * v;
    }
    final norm = math.sqrt(sumOfSquares);
    if (norm == 0) return vector;

    return vector.map((v) => v / norm).toList(growable: false);
  }

  /// Cosine similarity between two vectors of equal length.
  /// Returns a value in [-1, 1]. For L2-normalized vectors it's a dot product.
  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) {
      throw ArgumentError(
        'Vector lengths differ: ${a.length} vs ${b.length}',
      );
    }

    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }

    final denom = math.sqrt(normA) * math.sqrt(normB);
    if (denom == 0) return 0.0;

    return dot / denom;
  }

  /// Maps a cosine similarity score (-1..1) to a UI confidence (0..100).
  /// Uses a simple linear mapping anchored around the threshold.
  /// This is a PoC mapping; production calibration will refine it.
  double similarityToConfidence(double similarity) {
    // Treat 0.4 → 0% and 0.9 → 100% as a starting envelope.
    const min = 0.4;
    const max = 0.9;
    final clamped = similarity.clamp(min, max);
    return ((clamped - min) / (max - min)) * 100.0;
  }
}
