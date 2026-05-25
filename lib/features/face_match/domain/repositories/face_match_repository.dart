import 'package:camera/camera.dart';
import 'package:fpdart/fpdart.dart';

import '../entities/face_embedding.dart';
import '../entities/face_match_failure.dart';
import '../entities/verification_result.dart';

abstract class FaceMatchRepository {
  /// Captures the current frame, detects a face, computes its embedding.
  Future<Either<FaceMatchFailure, FaceEmbedding>> computeEmbedding(
    CameraImage frame,
    int sensorOrientation,
  );

  /// Detects a face from an image file (e.g. from gallery) and computes
  /// its embedding.
  Future<Either<FaceMatchFailure, FaceEmbedding>> computeEmbeddingFromFile(
    String filePath,
  );

  /// Compares two embeddings using cosine similarity and maps to a result.
  VerificationResult verify({
    required FaceEmbedding reference,
    required FaceEmbedding candidate,
    required double threshold,
  });
}
