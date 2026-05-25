import 'package:injectable/injectable.dart';

import '../entities/face_embedding.dart';
import '../entities/verification_result.dart';
import '../repositories/face_match_repository.dart';

@injectable
class VerifyFaceAgainstReference {
  final FaceMatchRepository _repository;

  VerifyFaceAgainstReference(this._repository);

  VerificationResult call({
    required FaceEmbedding reference,
    required FaceEmbedding candidate,
    double threshold = 0.65,
  }) {
    return _repository.verify(
      reference: reference,
      candidate: candidate,
      threshold: threshold,
    );
  }
}
