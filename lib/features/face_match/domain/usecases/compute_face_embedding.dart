import 'package:camera/camera.dart';
import 'package:fpdart/fpdart.dart';
import 'package:injectable/injectable.dart';

import '../entities/face_embedding.dart';
import '../entities/face_match_failure.dart';
import '../repositories/face_match_repository.dart';

@injectable
class ComputeFaceEmbedding {
  final FaceMatchRepository _repository;

  ComputeFaceEmbedding(this._repository);

  Future<Either<FaceMatchFailure, FaceEmbedding>> call(
    CameraImage frame,
    int sensorOrientation,
  ) {
    return _repository.computeEmbedding(frame, sensorOrientation);
  }

  Future<Either<FaceMatchFailure, FaceEmbedding>> fromFile(String filePath) {
    return _repository.computeEmbeddingFromFile(filePath);
  }
}
