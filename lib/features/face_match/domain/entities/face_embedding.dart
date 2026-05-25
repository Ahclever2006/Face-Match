import 'package:equatable/equatable.dart';

class FaceEmbedding extends Equatable {
  final List<double> vector;
  final DateTime computedAt;

  const FaceEmbedding({
    required this.vector,
    required this.computedAt,
  });

  @override
  List<Object?> get props => [vector, computedAt];
}
