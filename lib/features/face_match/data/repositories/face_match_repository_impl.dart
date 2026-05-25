import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:fpdart/fpdart.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:injectable/injectable.dart';

import '../../domain/entities/face_embedding.dart';
import '../../domain/entities/face_match_failure.dart';
import '../../domain/entities/verification_result.dart';
import '../../domain/repositories/face_match_repository.dart';
import '../services/embedding_math_service.dart';
import '../services/face_detection_service.dart';
import '../services/image_preprocessor.dart';
import '../services/tflite_model_service.dart';

@LazySingleton(as: FaceMatchRepository)
class FaceMatchRepositoryImpl implements FaceMatchRepository {
  final TfliteModelService _modelService;
  final FaceDetectionService _detectionService;
  final ImagePreprocessor _preprocessor;
  final EmbeddingMathService _math;

  FaceMatchRepositoryImpl(
    this._modelService,
    this._detectionService,
    this._preprocessor,
    this._math,
  );

  @override
  Future<Either<FaceMatchFailure, FaceEmbedding>> computeEmbedding(
    CameraImage frame,
    int sensorOrientation,
  ) async {
    try {
      if (!_modelService.isReady) {
        return const Left(ModelNotLoadedFailure());
      }

      // Convert CameraImage → ML Kit InputImage
      final inputImage = _toInputImage(frame, sensorOrientation);
      if (inputImage == null) {
        return const Left(
          ImageProcessingFailure('Could not build InputImage from frame'),
        );
      }

      // Detect faces
      final faces = await _detectionService.detect(inputImage);
      if (faces.isEmpty) {
        return const Left(NoFaceDetectedFailure());
      }
      if (faces.length > 1) {
        return const Left(MultipleFacesFailure());
      }

      final face = faces.first;

      // Apply minimal quality gates for PoC
      final leftEyeOpen = face.leftEyeOpenProbability ?? 1.0;
      final rightEyeOpen = face.rightEyeOpenProbability ?? 1.0;
      if (leftEyeOpen < 0.5 || rightEyeOpen < 0.5) {
        return const Left(PoorQualityFailure('Eyes appear closed'));
      }

      // Preprocess to model input
      final rgbImage =
          _preprocessor.cameraImageToImage(frame, sensorOrientation);
      final modelInput = _preprocessor.prepareForModel(rgbImage, face);

      // Run inference
      final rawEmbedding = _modelService.computeEmbedding(modelInput);

      // L2 normalize
      final normalized = _math.l2Normalize(rawEmbedding);

      return Right(
        FaceEmbedding(
          vector: normalized,
          computedAt: DateTime.now(),
        ),
      );
    } catch (e, st) {
      developer.log(
        'Embedding computation failed',
        name: 'ML',
        error: e,
        stackTrace: st,
      );
      return Left(InferenceFailure(e.toString()));
    }
  }

  @override
  VerificationResult verify({
    required FaceEmbedding reference,
    required FaceEmbedding candidate,
    required double threshold,
  }) {
    final similarity = _math.cosineSimilarity(
      reference.vector,
      candidate.vector,
    );

    return VerificationResult(
      similarity: similarity,
      confidence: _math.similarityToConfidence(similarity),
      passed: similarity >= threshold,
      timestamp: DateTime.now(),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  InputImage? _toInputImage(CameraImage image, int sensorOrientation) {
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;

    // For YUV420 on Android, ML Kit expects NV21 typically, but for the PoC
    // we let it consume the first plane (the Y plane works for face detection).
    if (Platform.isAndroid && image.planes.length != 1) {
      final plane = image.planes.first;
      return InputImage.fromBytes(
        bytes: plane.bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: format,
          bytesPerRow: plane.bytesPerRow,
        ),
      );
    }

    final plane = image.planes.first;
    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }
}
