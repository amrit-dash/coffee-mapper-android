import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:coffee_mapper/utils/logger.dart';

class ImageCaptureWidget extends StatefulWidget {
  final Function(String) onImageCaptured;
  final Function() onCancel;

  const ImageCaptureWidget({
    super.key,
    required this.onImageCaptured,
    required this.onCancel,
  });

  @override
  State<ImageCaptureWidget> createState() => _ImageCaptureWidgetState();
}

class _ImageCaptureWidgetState extends State<ImageCaptureWidget> {
  final _logger = AppLogger.getLogger('ImageCaptureWidget');
  CameraController? _controller;
  String? _capturedImagePath;
  bool _isPreviewMode = false;
  bool _hasPermissions = false;

  @override
  void initState() {
    super.initState();
    _checkPermissionsAndInitialize();
  }

  Future<void> _checkPermissionsAndInitialize() async {
    try {
      final status = await Permission.camera.request();
      if (status.isGranted) {
        setState(() {
          _hasPermissions = true;
        });
        await _initializeCamera();
      } else {
        _logger.warning('Camera permission denied');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera permission is required to capture images'),
              backgroundColor: Colors.red,
            ),
          );
          widget.onCancel();
        }
      }
    } catch (e) {
      _logger.severe('Error checking permissions: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error checking camera permissions'),
            backgroundColor: Colors.red,
          ),
        );
        widget.onCancel();
      }
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _logger.severe('No cameras available');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No cameras available on this device'),
              backgroundColor: Colors.red,
            ),
          );
          widget.onCancel();
        }
        return;
      }

      final camera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await _controller!.initialize();
      
      if (mounted) setState(() {});
    } catch (e) {
      _logger.severe('Error initializing camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error initializing camera'),
            backgroundColor: Colors.red,
          ),
        );
        widget.onCancel();
      }
    }
  }

  Future<void> _captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      _logger.warning('Camera not initialized');
      return;
    }

    try {
      _logger.info('Starting image capture');
      final image = await _controller!.takePicture();
      _logger.info('Image captured: ${image.path}');

      final imageFile = File(image.path);
      if (!await imageFile.exists()) {
        throw Exception('Image file does not exist after capture');
      }

      final fileSize = await imageFile.length();
      _logger.info('Image file size: ${fileSize ~/ 1024} KB');
      
      if (fileSize == 0) {
        throw Exception('Image file is empty');
      }

      if (fileSize > 10 * 1024 * 1024) { // 10MB limit for images
        throw Exception('Image file too large (max 10MB)');
      }

      setState(() {
        _capturedImagePath = image.path;
        _isPreviewMode = true;
      });
    } catch (e) {
      _logger.severe('Error capturing image: $e');
    }
  }

  void _retakeImage() {
    setState(() {
      _capturedImagePath = null;
      _isPreviewMode = false;
    });
  }

  void _confirmImage() {
    if (_capturedImagePath != null) {
      widget.onImageCaptured(_capturedImagePath!);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasPermissions) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_controller == null || !_controller!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            if (_isPreviewMode && _capturedImagePath != null)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: Image.file(
                    File(_capturedImagePath!),
                  ),
                ),
              )
            else
              Center(
                child: CameraPreview(_controller!),
              ),
            // Bottom bar with controls
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 179),
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(Icons.close),
                      color: Colors.white,
                      iconSize: 32,
                      onPressed: widget.onCancel,
                    ),
                    if (!_isPreviewMode)
                      GestureDetector(
                        onTap: _captureImage,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 4,
                            ),
                            color: Colors.transparent,
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          IconButton(
                            icon: Icon(Icons.refresh),
                            color: Colors.white,
                            iconSize: 32,
                            onPressed: _retakeImage,
                          ),
                          SizedBox(width: 32),
                          IconButton(
                            icon: Icon(Icons.check),
                            color: Colors.white,
                            iconSize: 32,
                            onPressed: _confirmImage,
                          ),
                        ],
                      ),
                    SizedBox(width: 48), // For balance
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 