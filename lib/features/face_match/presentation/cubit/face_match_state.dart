import 'package:equatable/equatable.dart';

import '../../domain/entities/face_embedding.dart';
import '../../domain/entities/face_match_failure.dart';
import '../../domain/entities/verification_result.dart';

sealed class FaceMatchState extends Equatable {
  const FaceMatchState();

  /// The reference embedding, if one has been captured.
  FaceEmbedding? get reference => switch (this) {
        FaceMatchInitial() => null,
        FaceMatchLoading(reference: final r) => r,
        FaceMatchReferenceCaptured(reference: final r) => r,
        FaceMatchVerified(reference: final r) => r,
        FaceMatchFailureState(reference: final r) => r,
      };

  @override
  List<Object?> get props => [reference];
}

class FaceMatchInitial extends FaceMatchState {
  const FaceMatchInitial();
}

class FaceMatchLoading extends FaceMatchState {
  @override
  final FaceEmbedding? reference;
  final String? message;

  const FaceMatchLoading({this.reference, this.message});

  @override
  List<Object?> get props => [reference, message];
}

class FaceMatchReferenceCaptured extends FaceMatchState {
  @override
  final FaceEmbedding reference;
  const FaceMatchReferenceCaptured(this.reference);

  @override
  List<Object?> get props => [reference];
}

class FaceMatchVerified extends FaceMatchState {
  @override
  final FaceEmbedding reference;
  final VerificationResult result;

  const FaceMatchVerified({
    required this.reference,
    required this.result,
  });

  @override
  List<Object?> get props => [reference, result];
}

class FaceMatchFailureState extends FaceMatchState {
  @override
  final FaceEmbedding? reference;
  final FaceMatchFailure failure;

  const FaceMatchFailureState({
    required this.failure,
    this.reference,
  });

  @override
  List<Object?> get props => [reference, failure];
}
