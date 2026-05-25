import 'dart:developer' as developer;
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
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
  final ImagePicker _picker = ImagePicker();
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

  Future<String?> _takePictureFile() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return null;
    try {
      final XFile file = await controller.takePicture();
      return file.path;
    } catch (e, st) {
      developer.log('takePicture failed', name: 'Camera', error: e, stackTrace: st);
      return null;
    }
  }

  Future<void> _onCaptureReference() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);

    final path = await _takePictureFile();
    if (path == null || !mounted) {
      if (mounted) setState(() => _isCapturing = false);
      return;
    }

    await context.read<FaceMatchCubit>().captureReferenceFromGallery(path);
    if (mounted) setState(() => _isCapturing = false);
  }

  Future<void> _onVerify() async {
    if (_isCapturing) return;
    setState(() => _isCapturing = true);

    final path = await _takePictureFile();
    if (path == null || !mounted) {
      if (mounted) setState(() => _isCapturing = false);
      return;
    }

    await context.read<FaceMatchCubit>().verifyCandidateFromGallery(path);
    if (mounted) setState(() => _isCapturing = false);
  }

  Future<void> _onPickFromGallery() async {
    if (_isCapturing) return;

    final XFile? picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
    );
    if (picked == null || !mounted) return;

    setState(() => _isCapturing = true);

    final cubit = context.read<FaceMatchCubit>();
    if (cubit.state.reference == null) {
      await cubit.captureReferenceFromGallery(picked.path);
    } else {
      await cubit.verifyCandidateFromGallery(picked.path);
    }

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
            tooltip: 'Reset',
            onPressed: () => context.read<FaceMatchCubit>().reset(),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: !_isCameraReady
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 1 / _controller!.value.aspectRatio,
                        child: CameraPreview(_controller!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  BlocBuilder<FaceMatchCubit, FaceMatchState>(
                    builder: (context, state) => ResultPanel(state: state),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: BlocBuilder<FaceMatchCubit, FaceMatchState>(
                      builder: (context, state) => _buildActions(state),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildActions(FaceMatchState state) {
    final hasReference = state.reference != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isCapturing ? null : _onCaptureReference,
                icon: const Icon(Icons.person_add),
                label: Text(
                  hasReference ? 'Replace Reference' : 'Capture Reference',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: (_isCapturing || !hasReference) ? null : _onVerify,
                icon: const Icon(Icons.verified_user),
                label: const Text('Verify'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isCapturing ? null : _onPickFromGallery,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(
              hasReference
                  ? 'Verify with Gallery Image'
                  : 'Use Gallery Image as Reference',
            ),
          ),
        ),
      ],
    );
  }
}
