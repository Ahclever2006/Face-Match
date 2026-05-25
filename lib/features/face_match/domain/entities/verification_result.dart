import 'package:equatable/equatable.dart';

class VerificationResult extends Equatable {
  final double similarity; // raw cosine, -1..1
  final double confidence; // mapped to 0..100 for UI
  final bool passed;
  final DateTime timestamp;

  const VerificationResult({
    required this.similarity,
    required this.confidence,
    required this.passed,
    required this.timestamp,
  });

  @override
  List<Object?> get props => [similarity, confidence, passed, timestamp];
}
