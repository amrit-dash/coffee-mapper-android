import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:video_player/video_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:coffee_mapper/utils/logger.dart';
import 'package:flutter/services.dart';

class VideoCaptureWidget extends StatefulWidget {
  final Function(String) onVideoRecorded;
  final Function() onCancel;

  const VideoCaptureWidget({
    super.key,
    required this.onVideoRecorded,
    required this.onCancel,
  });

  @override
  State<VideoCaptureWidget> createState() => _VideoCaptureWidgetState();
}

class _VideoCaptureWidgetState extends State<VideoCaptureWidget> {
  final _logger = AppLogger.getLogger('VideoCaptureWidget');
  CameraController? _controller;
  VideoPlayerController? _videoPlayerController;
  String? _recordedVideoPath;
  bool _isPreviewMode = false;
  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  bool _isPlaying = false;
  bool _hasPermissions = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    _checkPermissionsAndInitialize();
  }

  Future<void> _checkPermissionsAndInitialize() async {
    try {
      final cameraStatus = await Permission.camera.request();
      final microphoneStatus = await Permission.microphone.request();
      
      if (cameraStatus.isGranted && microphoneStatus.isGranted) {
        setState(() {
          _hasPermissions = true;
        });
        await _initializeCamera();
      } else {
        _logger.warning('Camera or microphone permission denied');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Camera and microphone permissions are required to record videos'),
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
            content: Text('Error checking camera and microphone permissions'),
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
        enableAudio: true,
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

  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      _logger.warning('Camera not initialized');
      return;
    }

    try {
      _logger.info('Starting video recording');
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });

      // Start timer for recording duration
      _recordingTimer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          _recordingDuration += Duration(seconds: 1);
        });
      });
    } catch (e) {
      _logger.severe('Error starting video recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      _logger.warning('Camera not initialized');
      return;
    }

    try {
      _recordingTimer?.cancel();
      _logger.info('Stopping video recording');
      final video = await _controller!.stopVideoRecording();
      _logger.info('Video recorded: ${video.path}');

      final videoFile = File(video.path);
      if (!await videoFile.exists()) {
        throw Exception('Video file does not exist after recording');
      }

      final fileSize = await videoFile.length();
      _logger.info('Video file size: ${fileSize ~/ 1024} KB');
      
      if (fileSize == 0) {
        throw Exception('Video file is empty');
      }

      if (fileSize > 50 * 1024 * 1024) { // 50MB limit for videos
        throw Exception('Video file too large (max 50MB)');
      }

      // Initialize video player for preview
      _videoPlayerController = VideoPlayerController.file(videoFile);
      await _videoPlayerController!.initialize();
      
      setState(() {
        _recordedVideoPath = video.path;
        _isPreviewMode = true;
        _isRecording = false;
      });

      // Start playing the video automatically
      _videoPlayerController!.play();
      _videoPlayerController!.setLooping(true);
      setState(() {
        _isPlaying = true;
      });
    } catch (e) {
      _logger.severe('Error stopping video recording: $e');
    }
  }

  void _retakeVideo() {
    _videoPlayerController?.dispose();
    _videoPlayerController = null;
    setState(() {
      _recordedVideoPath = null;
      _isPreviewMode = false;
      _recordingDuration = Duration.zero;
      _isPlaying = false;
    });
  }

  void _confirmVideo() {
    if (_recordedVideoPath != null) {
      widget.onVideoRecorded(_recordedVideoPath!);
    }
  }

  void _togglePlayPause() {
    if (_videoPlayerController == null) return;

    setState(() {
      if (_isPlaying) {
        _videoPlayerController!.pause();
      } else {
        _videoPlayerController!.play();
      }
      _isPlaying = !_isPlaying;
    });
  }

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _videoPlayerController?.dispose();
    _controller?.dispose();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
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
            if (_isPreviewMode && _videoPlayerController != null)
              Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.expand(
                    child: VideoPlayer(_videoPlayerController!),
                  ),
                  if (!_isPlaying)
                    GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.black.withAlpha(128),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  if (_isPlaying)
                    GestureDetector(
                      onTap: _togglePlayPause,
                      child: Container(
                        color: Colors.transparent,
                        child: const Icon(
                          Icons.pause,
                          size: 48,
                          color: Color(0xB3FFFFFF),
                        ),
                      ),
                    ),
                ],
              )
            else
              Center(
                child: CameraPreview(_controller!),
              ),
            if (_isRecording)
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8),
                      Text(
                        _formatDuration(_recordingDuration),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
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
                        onTap: _isRecording ? _stopRecording : _startRecording,
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _isRecording ? Colors.red : Colors.white,
                              width: 4,
                            ),
                            color: _isRecording ? Colors.red.withAlpha(77) : Colors.transparent,
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
                            onPressed: _retakeVideo,
                          ),
                          SizedBox(width: 32),
                          IconButton(
                            icon: Icon(Icons.check),
                            color: Colors.white,
                            iconSize: 32,
                            onPressed: _confirmVideo,
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