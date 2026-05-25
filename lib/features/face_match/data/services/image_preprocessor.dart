import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img;
import 'package:injectable/injectable.dart';

@lazySingleton
class ImagePreprocessor {
  static const int _modelInputSize = 112;

  /// Converts a CameraImage to an RGB image rotated to portrait.
  img.Image cameraImageToImage(
    CameraImage cameraImage,
    int sensorOrientation,
  ) {
    img.Image rgbImage;

    if (cameraImage.format.group == ImageFormatGroup.yuv420) {
      rgbImage = _yuv420ToImage(cameraImage);
    } else if (cameraImage.format.group == ImageFormatGroup.bgra8888) {
      rgbImage = _bgra8888ToImage(cameraImage);
    } else {
      throw UnsupportedError(
        'Unsupported image format: ${cameraImage.format.group}',
      );
    }

    // Rotate based on sensor orientation so the face is upright.
    // Front camera on Android typically needs -90 (== 270).
    final rotated = img.copyRotate(
      rgbImage,
      angle: -sensorOrientation,
    );

    return rotated;
  }

  /// Crops the face from the image using the detection bounding box,
  /// resizes to 112x112, normalizes to [-1, 1], returns a Float32List.
  Float32List prepareForModel(img.Image image, Face face) {
    final box = face.boundingBox;

    // Add a 10% margin around the face box.
    final marginX = box.width * 0.1;
    final marginY = box.height * 0.1;

    final x = (box.left - marginX).clamp(0.0, image.width.toDouble()).toInt();
    final y = (box.top - marginY).clamp(0.0, image.height.toDouble()).toInt();
    final w = (box.width + 2 * marginX)
        .clamp(0.0, image.width.toDouble() - x)
        .toInt();
    final h = (box.height + 2 * marginY)
        .clamp(0.0, image.height.toDouble() - y)
        .toInt();

    final cropped = img.copyCrop(image, x: x, y: y, width: w, height: h);
    final resized = img.copyResize(
      cropped,
      width: _modelInputSize,
      height: _modelInputSize,
    );

    return _imageToNormalizedFloat32(resized);
  }

  /// Normalization: (pixel - 128) / 128 → range [-1, 1]
  /// Matches MobileFaceNet's training preprocessing.
  Float32List _imageToNormalizedFloat32(img.Image image) {
    final buffer = Float32List(1 * _modelInputSize * _modelInputSize * 3);
    int idx = 0;

    for (int y = 0; y < _modelInputSize; y++) {
      for (int x = 0; x < _modelInputSize; x++) {
        final pixel = image.getPixel(x, y);
        buffer[idx++] = (pixel.r - 128) / 128.0;
        buffer[idx++] = (pixel.g - 128) / 128.0;
        buffer[idx++] = (pixel.b - 128) / 128.0;
      }
    }

    return buffer;
  }

  // ─── YUV420 → RGB ─────────────────────────────────────────────────────────
  img.Image _yuv420ToImage(CameraImage cameraImage) {
    final width = cameraImage.width;
    final height = cameraImage.height;
    final image = img.Image(width: width, height: height);

    final yPlane = cameraImage.planes[0];
    final uPlane = cameraImage.planes[1];
    final vPlane = cameraImage.planes[2];

    final yRowStride = yPlane.bytesPerRow;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final yIndex = y * yRowStride + x;
        final uvIndex = (y >> 1) * uvRowStride + (x >> 1) * uvPixelStride;

        final yp = yPlane.bytes[yIndex];
        final up = uPlane.bytes[uvIndex];
        final vp = vPlane.bytes[uvIndex];

        // YUV → RGB conversion (BT.601)
        int r = (yp + 1.402 * (vp - 128)).round();
        int g =
            (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128)).round();
        int b = (yp + 1.772 * (up - 128)).round();

        r = r.clamp(0, 255);
        g = g.clamp(0, 255);
        b = b.clamp(0, 255);

        image.setPixelRgb(x, y, r, g, b);
      }
    }

    return image;
  }

  // ─── BGRA8888 (iOS) → RGB ─────────────────────────────────────────────────
  img.Image _bgra8888ToImage(CameraImage cameraImage) {
    return img.Image.fromBytes(
      width: cameraImage.width,
      height: cameraImage.height,
      bytes: cameraImage.planes[0].bytes.buffer,
      order: img.ChannelOrder.bgra,
    );
  }
}
