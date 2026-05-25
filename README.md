# Face Match PoC — Rooli Supervisor

A standalone proof-of-concept for testing MobileFaceNet face verification on-device, before integrating into the main Rooli Supervisor project.

This is **not the production app**. It's a sandbox to confirm:
- The model loads correctly
- The input/output shapes match what we expect
- Cosine similarity behaves sensibly between same/different faces
- The on-device pipeline performs well enough

---

## 1. Where to put the model

Drop the `mobilefacenet.tflite` file you downloaded into:

```
assets/models/mobilefacenet.tflite
```

The folder is already created. Just paste the file there.

The `pubspec.yaml` is already set up to include this asset.

---

## 2. Setup

```bash
# 1. Install dependencies
flutter pub get

# 2. Generate DI code
dart run build_runner build --delete-conflicting-outputs

# 3. Run on Android (recommended for first test)
flutter run
```

### Android setup notes

Add to `android/app/src/main/AndroidManifest.xml` inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
```

And in `android/app/build.gradle` make sure:

```gradle
android {
    defaultConfig {
        minSdkVersion 26  // ML Kit needs 21+, TFLite GPU needs 26+
    }
}
```

### iOS setup notes

Add to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to verify identity</string>
```

---

## 3. What this PoC does

1. **Capture Reference** — opens camera, captures a face, computes embedding, stores it in memory as "the reference"
2. **Verify** — opens camera, captures another face, computes embedding, calculates cosine similarity with the reference, shows the result

### What to test

- **Same person, same lighting** → expect similarity > 0.7
- **Same person, different lighting** → expect similarity > 0.55
- **Different people** → expect similarity < 0.45

These ranges are estimates. The actual threshold for the production app will be calibrated in Phase 0 of the main project.

### What gets printed to console

On startup:
```
[ML] Model loaded
[ML] Input shape: [1, 112, 112, 3]
[ML] Input type: float32
[ML] Output shape: [1, 192]
[ML] Output type: float32
```

If these match, the model is the one we expect (matches specs.md §2.1).

---

## 4. Folder structure (Clean Architecture, scaled down)

```
lib/
├── core/
│   ├── di/              # get_it + injectable setup
│   └── services/        # cross-cutting services
└── features/
    └── face_match/
        ├── data/        # services, repository impls
        ├── domain/      # entities, repo interfaces, use cases
        └── presentation/
            ├── cubit/   # state management
            ├── screens/ # screens
            └── widgets/ # reusable widgets
```

This mirrors the production project structure on a smaller scale.

---

## 5. After the PoC works

When you've confirmed:
- Model loads with the expected shapes
- Same-person captures produce high similarity
- Different-person captures produce low similarity

→ You're good to start Phase 1 of the main Rooli Supervisor project per `specs.md`.

Discard this PoC project. It served its purpose.
