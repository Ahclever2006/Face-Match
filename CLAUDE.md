# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Purpose

PoC for validating on-device face verification using MobileFaceNet before integrating into the Rooli Supervisor app. Two-step flow: capture a reference embedding → verify a candidate embedding against it using cosine similarity.

## Commands

```bash
# Install dependencies
flutter pub get

# Generate DI code (run after adding/modifying @injectable annotations)
dart run build_runner build --delete-conflicting-outputs

# Run the app (requires physical device with camera)
flutter run

# Run tests
flutter test

# Run a single test file
flutter test test/path/to/file_test.dart

# Lint
flutter analyze
```

## Architecture

Clean Architecture with a single `face_match` feature. Layer dependency: `presentation → domain ← data`.

```
lib/
├── core/di/injection.dart          # get_it + injectable DI setup
└── features/face_match/
    ├── domain/
    │   ├── entities/               # FaceEmbedding, VerificationResult, FaceMatchFailure (sealed)
    │   ├── repositories/           # Abstract FaceMatchRepository interface
    │   └── usecases/               # ComputeFaceEmbedding, VerifyFaceAgainstReference
    ├── data/
    │   ├── repositories/           # FaceMatchRepositoryImpl (@LazySingleton)
    │   └── services/               # TFLite, ML Kit, image preprocessing, cosine math
    └── presentation/
        ├── cubit/                  # FaceMatchCubit + sealed FaceMatchState
        ├── screens/                # FaceMatchScreen (camera lifecycle owner)
        └── widgets/                # ResultPanel (state-driven display)
```

### Key Patterns

**Error handling**: `fpdart` `Either<FaceMatchFailure, T>` — this project uses `fpdart` (not `dartz`) because it supports Dart 3 sealed classes.

**Use cases** must extend the generic base:
```dart
abstract class UseCase<Output, Params> {
  Future<Either<FaceMatchFailure, Output>> call(Params params);
}
class NoParams extends Equatable { ... }
```

**DI**: `@injectable` / `@LazySingleton` annotations on services/repos, `@module` for external registrations. Always regenerate after annotation changes.

**State**: Sealed `FaceMatchState` variants — `Initial`, `Loading`, `ReferenceCaptured`, `Verified`, `FailureState`. Cubit calls use cases and maps `Either` results to states.

### Face Embedding Pipeline

1. Capture YUV420 (Android) / BGRA8888 (iOS) frame via `camera` package
2. Detect face + landmarks with `google_mlkit_face_detection` (requires both eyes ≥50% open)
3. Crop with 10% margin, resize to 112×112, normalize to [-1, 1]: `(pixel - 128) / 128`
4. TFLite inference → 192-dim float32 embedding (`mobilefacenet.tflite` in `assets/models/`)
5. L2-normalize the embedding
6. Cosine similarity between reference and candidate; threshold default = 0.65

### Model Asset

`assets/models/mobilefacenet.tflite` must be present (not committed to git if large). Input shape: `[1, 112, 112, 3]`, output: `[1, 192]`. Model shape is validated and logged at startup.

## Platform Setup

**Android** (`android/app/src/main/AndroidManifest.xml`): `CAMERA` permission required.

**iOS** (`ios/Runner/Info.plist`): `NSCameraUsageDescription` key required.

## Deviations from Global Defaults

- Uses `fpdart` instead of `dartz` (Dart 3 compatibility)
- No `Dio` (no network calls — fully on-device inference)
- No `sizeHelper` (minimal UI, PoC scope)
- No dark mode / theming beyond Material 3 defaults (intentional for PoC)
