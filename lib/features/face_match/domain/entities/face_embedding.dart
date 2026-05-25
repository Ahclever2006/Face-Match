import 'dart:typed_data';

import 'package:equatable/equatable.dart';

class FaceEmbedding extends Equatable {
  final List<double> vector;
  final DateTime computedAt;

  /// JPEG-encoded bytes of the 112x112 face crop used for inference.
  /// Used by the UI to preview what was captured.
  final Uint8List imageBytes;

  const FaceEmbedding({
    required this.vector,
    required this.computedAt,
    required this.imageBytes,
  });

  @override
  List<Object?> get props => [vector, computedAt, imageBytes];
}
