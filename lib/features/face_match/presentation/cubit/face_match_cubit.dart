import 'package:camera/camera.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/face_embedding.dart';
import '../../domain/entities/face_match_failure.dart';
import '../../domain/usecases/compute_face_embedding.dart';
import '../../domain/usecases/verify_face_against_reference.dart';
import 'face_match_state.dart';

@injectable
class FaceMatchCubit extends Cubit<FaceMatchState> {
  final ComputeFaceEmbedding _computeEmbedding;
  final VerifyFaceAgainstReference _verify;

  FaceMatchCubit(
    this._computeEmbedding,
    this._verify,
  ) : super(const FaceMatchInitial());

  Future<void> captureReference(
    CameraImage frame,
    int sensorOrientation,
  ) async {
    await _captureReferenceFrom(
      () => _computeEmbedding(frame, sensorOrientation),
    );
  }

  Future<void> captureReferenceFromGallery(String filePath) async {
    await _captureReferenceFrom(() => _computeEmbedding.fromFile(filePath));
  }

  Future<void> verifyCandidate(
    CameraImage frame,
    int sensorOrientation,
  ) async {
    await _verifyCandidateFrom(
      () => _computeEmbedding(frame, sensorOrientation),
    );
  }

  Future<void> verifyCandidateFromGallery(String filePath) async {
    await _verifyCandidateFrom(() => _computeEmbedding.fromFile(filePath));
  }

  void reset() {
    emit(const FaceMatchInitial());
  }

  // ─── Internal helpers ──────────────────────────────────────────────────────
  Future<void> _captureReferenceFrom(
    Future<Either<FaceMatchFailure, FaceEmbedding>> Function() compute,
  ) async {
    emit(
      FaceMatchLoading(
        reference: state.reference,
        message: 'Computing reference embedding...',
      ),
    );

    final result = await compute();

    result.fold(
      (failure) => emit(
        FaceMatchFailureState(
          failure: failure,
          reference: state.reference,
        ),
      ),
      (embedding) => emit(FaceMatchReferenceCaptured(embedding)),
    );
  }

  Future<void> _verifyCandidateFrom(
    Future<Either<FaceMatchFailure, FaceEmbedding>> Function() compute,
  ) async {
    final reference = state.reference;
    if (reference == null) return;

    emit(
      FaceMatchLoading(
        reference: reference,
        message: 'Computing candidate embedding...',
      ),
    );

    final result = await compute();

    result.fold(
      (failure) => emit(
        FaceMatchFailureState(
          failure: failure,
          reference: reference,
        ),
      ),
      (candidate) {
        final verification = _verify(
          reference: reference,
          candidate: candidate,
        );
        emit(
          FaceMatchVerified(
            reference: reference,
            candidate: candidate,
            result: verification,
          ),
        );
      },
    );
  }
}
