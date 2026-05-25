PLACE THE MODEL FILE HERE
=========================

Paste your downloaded `mobilefacenet.tflite` file into THIS folder.

Expected:
- File name: mobilefacenet.tflite
- File size: ~5 MB
- Source: github.com/MCarlomagno/FaceRecognitionAuth (assets/mobilefacenet.tflite)

After placing the file, you can delete this README.txt.

The pubspec.yaml is already configured to bundle the `assets/models/` folder
as a Flutter asset, so the model will be loaded at runtime via:

    Interpreter.fromAsset('assets/models/mobilefacenet.tflite');
