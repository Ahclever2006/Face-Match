import 'dart:io';
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

  /// Decodes an image file (JPEG/PNG/etc.) into an RGB image. Throws if the
  /// file can't be decoded.
  img.Image fileToImage(String filePath) {
    final bytes = File(filePath).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw const FormatException('Could not decode image file');
    }
    // Bake EXIF orientation so face boxes line up.
    return img.bakeOrientation(decoded);
  }

  /// Crops the face from the image using the detection bounding box and
  /// resizes the crop to 112x112. The returned image is what's fed to the
  /// model (after normalization) and to the UI preview (after JPEG encoding).
  img.Image cropFace(img.Image image, Face face) {
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
    return img.copyResize(
      cropped,
      width: _modelInputSize,
      height: _modelInputSize,
    );
  }

  /// Normalization: (pixel - 128) / 128 → range [-1, 1]
  /// Matches MobileFaceNet's training preprocessing.
  Float32List normalizeForModel(img.Image faceCrop) {
    final buffer = Float32List(1 * _modelInputSize * _modelInputSize * 3);
    int idx = 0;

    for (int y = 0; y < _modelInputSize; y++) {
      for (int x = 0; x < _modelInputSize; x++) {
        final pixel = faceCrop.getPixel(x, y);
        buffer[idx++] = (pixel.r - 128) / 128.0;
        buffer[idx++] = (pixel.g - 128) / 128.0;
        buffer[idx++] = (pixel.b - 128) / 128.0;
      }
    }

    return buffer;
  }

  /// JPEG-encodes a face crop for UI display.
  Uint8List encodeJpeg(img.Image image, {int quality = 85}) {
    return Uint8List.fromList(img.encodeJpg(image, quality: quality));
  }

  /// Builds NV21 bytes from a YUV_420_888 CameraImage. ML Kit expects NV21
  /// for Android camera frames; passing only the Y plane (the previous
  /// behaviour) caused face detection to silently fail on multi-plane
  /// devices.
  Uint8List yuv420ToNv21(CameraImage image) {
    final width = image.width;
    final height = image.height;
    final ySize = width * height;
    final uvSize = ySize ~/ 2;
    final nv21 = Uint8List(ySize + uvSize);

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    // ── Copy Y plane, respecting row stride ────────────────────────────────
    final yBytes = yPlane.bytes;
    final yRowStride = yPlane.bytesPerRow;
    int outPos = 0;
    if (yRowStride == width) {
      nv21.setRange(0, ySize, yBytes);
      outPos = ySize;
    } else {
      for (int row = 0; row < height; row++) {
        final rowStart = row * yRowStride;
        nv21.setRange(outPos, outPos + width, yBytes, rowStart);
        outPos += width;
      }
    }

    // ── Interleave V then U for NV21 (...VUVU...) ──────────────────────────
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;
    final uvRowStride = uPlane.bytesPerRow;
    final uvPixelStride = uPlane.bytesPerPixel ?? 1;

    final uvHeight = height ~/ 2;
    final uvWidth = width ~/ 2;

    for (int row = 0; row < uvHeight; row++) {
      for (int col = 0; col < uvWidth; col++) {
        final offset = row * uvRowStride + col * uvPixelStride;
        nv21[outPos++] = vBytes[offset];
        nv21[outPos++] = uBytes[offset];
      }
    }

    return nv21;
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
