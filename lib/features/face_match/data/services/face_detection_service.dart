import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:injectable/injectable.dart';

@lazySingleton
class FaceDetectionService {
  late final FaceDetector _detector;

  FaceDetectionService() {
    _detector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: false,
        enableLandmarks: true,
        enableClassification: true,
        performanceMode: FaceDetectorMode.accurate,
        minFaceSize: 0.15,
      ),
    );
  }

  Future<List<Face>> detect(InputImage image) async {
    return _detector.processImage(image);
  }

  void dispose() {
    _detector.close();
  }
}
