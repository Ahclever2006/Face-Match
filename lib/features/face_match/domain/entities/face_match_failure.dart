import 'package:equatable/equatable.dart';

sealed class FaceMatchFailure extends Equatable {
  final String message;
  const FaceMatchFailure(this.message);

  @override
  List<Object?> get props => [message];
}

class ModelNotLoadedFailure extends FaceMatchFailure {
  const ModelNotLoadedFailure() : super('TFLite model is not loaded');
}

class NoFaceDetectedFailure extends FaceMatchFailure {
  const NoFaceDetectedFailure() : super('No face detected in the frame');
}

class MultipleFacesFailure extends FaceMatchFailure {
  const MultipleFacesFailure()
      : super('Multiple faces detected. Only one allowed.');
}

class PoorQualityFailure extends FaceMatchFailure {
  const PoorQualityFailure(super.message);
}

class ImageProcessingFailure extends FaceMatchFailure {
  const ImageProcessingFailure(super.message);
}

class InferenceFailure extends FaceMatchFailure {
  const InferenceFailure(super.message);
}

class CameraFailure extends FaceMatchFailure {
  const CameraFailure(super.message);
}
