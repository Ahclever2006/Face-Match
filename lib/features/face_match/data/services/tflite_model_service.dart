import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

@lazySingleton
class TfliteModelService {
  static const String _modelPath = 'assets/models/mobilefacenet.tflite';
  static const int _inputSize = 112;
  static const int _outputSize = 192;

  Interpreter? _interpreter;

  Future<void> initialize() async {
    try {
      _interpreter = await Interpreter.fromAsset(_modelPath);

      developer.log('Model loaded', name: 'ML');
      developer.log(
        'Input shape: ${_interpreter!.getInputTensor(0).shape}',
        name: 'ML',
      );
      developer.log(
        'Input type: ${_interpreter!.getInputTensor(0).type}',
        name: 'ML',
      );
      developer.log(
        'Output shape: ${_interpreter!.getOutputTensor(0).shape}',
        name: 'ML',
      );
      developer.log(
        'Output type: ${_interpreter!.getOutputTensor(0).type}',
        name: 'ML',
      );
    } catch (e, st) {
      developer.log(
        'Failed to load model',
        name: 'ML',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  bool get isReady => _interpreter != null;

  /// Runs inference on a preprocessed 112x112x3 float32 tensor.
  /// Returns a 192-dim embedding vector.
  List<double> computeEmbedding(Float32List input) {
    final interpreter = _interpreter;
    if (interpreter == null) {
      throw StateError('Interpreter not initialized. Call initialize() first.');
    }

    final reshapedInput = input.reshape([1, _inputSize, _inputSize, 3]);
    final output = List.generate(
      1,
      (_) => List.filled(_outputSize, 0.0),
    );

    interpreter.run(reshapedInput, output);

    return List<double>.from(output[0]);
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
