import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../cubit/face_match_cubit.dart';
import '../cubit/face_match_state.dart';
import '../widgets/result_panel.dart';

class FaceMatchScreen extends StatefulWidget {
  const FaceMatchScreen({super.key});

  @override
  State<FaceMatchScreen> createState() => _FaceMatchScreenState();
}

class _FaceMatchScreenState extends State<FaceMatchScreen> {
  CameraController? _controller;
  bool _isCameraReady = false;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    final status = await Permission.camera.request();
    if (!status.isGranted) return;

    final cameras = await availableCameras();
    if (cameras.isEmpty) return;

    // Prefer front camera for face match
    final front = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      front,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isIOS
          ? ImageFormatGroup.bgra8888
          : ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();
    if (!mounted) return;

    setState(() => _isCameraReady = true);
  }

  Future<CameraImage?> _captureSingleFrame() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return null;

    CameraImage? captured;
    await controller.startImageStream((image) {
      captured ??= image;
    });

    // Give the stream a moment to deliver a frame
    await Future.delayed(const Duration(milliseconds: 300));
    await controller.stopImageStream();

    return captured;
  }

  Future<void> _onCaptureReference() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);

    final frame = await _captureSingleFrame();
    if (frame == null || !mounted) {
      setState(() => _isCapturing = false);
      return;
    }

    final orientation = _controller!.description.sensorOrientation;
    await context.read<FaceMatchCubit>().captureReference(frame, orientation);

    if (mounted) setState(() => _isCapturing = false);
  }

  Future<void> _onVerify() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);

    final frame = await _captureSingleFrame();
    if (frame == null || !mounted) {
      setState(() => _isCapturing = false);
      return;
    }

    final orientation = _controller!.description.sensorOrientation;
    await context.read<FaceMatchCubit>().verifyCandidate(frame, orientation);

    if (mounted) setState(() => _isCapturing = false);
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Face Match PoC'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<FaceMatchCubit>().reset(),
          ),
        ],
      ),
      body: !_isCameraReady
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                AspectRatio(
                  aspectRatio: _controller!.value.aspectRatio,
                  child: CameraPreview(_controller!),
                ),
                const SizedBox(height: 16),
                BlocBuilder<FaceMatchCubit, FaceMatchState>(
                  builder: (context, state) => ResultPanel(state: state),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: BlocBuilder<FaceMatchCubit, FaceMatchState>(
                    builder: (context, state) {
                      final hasReference = state.reference != null;
                      return Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isCapturing
                                  ? null
                                  : _onCaptureReference,
                              icon: const Icon(Icons.person_add),
                              label: Text(
                                hasReference
                                    ? 'Replace Reference'
                                    : 'Capture Reference',
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: (_isCapturing || !hasReference)
                                  ? null
                                  : _onVerify,
                              icon: const Icon(Icons.verified_user),
                              label: const Text('Verify'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
