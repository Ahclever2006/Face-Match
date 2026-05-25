import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:camera/camera.dart';
import 'package:fpdart/fpdart.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
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

      final inputImage = _cameraImageToInputImage(frame, sensorOrientation);
      if (inputImage == null) {
        return const Left(
          ImageProcessingFailure('Could not build InputImage from frame'),
        );
      }

      // ML Kit returns face boxes in the rotated coordinate space (after
      // applying the rotation specified in InputImageMetadata), so we rotate
      // the RGB image the same way before cropping.
      final rgbImage = _preprocessor.cameraImageToImage(
        frame,
        sensorOrientation,
      );

      return _runPipeline(inputImage, rgbImage);
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
  Future<Either<FaceMatchFailure, FaceEmbedding>> computeEmbeddingFromFile(
    String filePath,
  ) async {
    try {
      if (!_modelService.isReady) {
        return const Left(ModelNotLoadedFailure());
      }

      final inputImage = InputImage.fromFilePath(filePath);
      final img.Image rgbImage;
      try {
        rgbImage = _preprocessor.fileToImage(filePath);
      } catch (e) {
        return Left(ImageProcessingFailure(e.toString()));
      }

      return _runPipeline(inputImage, rgbImage);
    } catch (e, st) {
      developer.log(
        'Embedding computation from file failed',
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

  // ─── Shared pipeline ───────────────────────────────────────────────────────
  Future<Either<FaceMatchFailure, FaceEmbedding>> _runPipeline(
    InputImage inputImage,
    img.Image rgbImage,
  ) async {
    final faces = await _detectionService.detect(inputImage);
    if (faces.isEmpty) {
      return const Left(NoFaceDetectedFailure());
    }
    if (faces.length > 1) {
      return const Left(MultipleFacesFailure());
    }

    final face = faces.first;

    final leftEyeOpen = face.leftEyeOpenProbability ?? 1.0;
    final rightEyeOpen = face.rightEyeOpenProbability ?? 1.0;
    if (leftEyeOpen < 0.5 || rightEyeOpen < 0.5) {
      return const Left(PoorQualityFailure('Eyes appear closed'));
    }

    final faceCrop = _preprocessor.cropFace(rgbImage, face);
    final modelInput = _preprocessor.normalizeForModel(faceCrop);
    final rawEmbedding = _modelService.computeEmbedding(modelInput);
    final normalized = _math.l2Normalize(rawEmbedding);
    final jpegBytes = _preprocessor.encodeJpeg(faceCrop);

    return Right(
      FaceEmbedding(
        vector: normalized,
        computedAt: DateTime.now(),
        imageBytes: jpegBytes,
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────
  InputImage? _cameraImageToInputImage(
    CameraImage image,
    int sensorOrientation,
  ) {
    final rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    if (rotation == null) return null;

    if (Platform.isAndroid) {
      // ML Kit on Android needs NV21 (or YV12) via fromBytes. The previous
      // approach passed only the Y plane and silently failed face detection
      // on multi-plane YUV_420_888 devices.
      final Uint8List bytes;
      if (image.format.group == ImageFormatGroup.yuv420) {
        bytes = _preprocessor.yuv420ToNv21(image);
      } else if (image.planes.length == 1) {
        bytes = image.planes.first.bytes;
      } else {
        return null;
      }

      return InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: Size(image.width.toDouble(), image.height.toDouble()),
          rotation: rotation,
          format: InputImageFormat.nv21,
          bytesPerRow: image.width,
        ),
      );
    }

    // iOS: BGRA8888, single plane.
    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null) return null;
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
