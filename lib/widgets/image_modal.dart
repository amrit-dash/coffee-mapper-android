import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:coffee_mapper/utils/logger.dart';

class ImageModal extends StatefulWidget {
  final String mediaPath;

  const ImageModal({super.key, required this.mediaPath});

  @override
  State<ImageModal> createState() => _ImageModalState();
}

class _ImageModalState extends State<ImageModal> {
  VideoPlayerController? _videoController;
  bool _isVideo = false;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isPlaying = false;
  final _logger = AppLogger.getLogger('ImageModal');
  static const int _maxRetries = 3;
  static const Duration _initialDelay = Duration(seconds: 1);

  @override
  void initState() {
    super.initState();
    _initializeMedia();
  }

  Future<void> _initializeMedia() async {
    _isVideo = widget.mediaPath.split("?").first.endsWith('.mp4');

    if (_isVideo) {
      await _initializeVideo();
    } else {
      await _initializeImage();
    }
  }

  Future<void> _initializeVideo() async {
    int retryCount = 0;
    Duration delay = _initialDelay;

    while (retryCount < _maxRetries) {
      try {
        _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.mediaPath));
        await _videoController!.initialize();
        _videoController!.setLooping(false);
        _videoController!.addListener(() {
          if (_videoController!.value.position >= _videoController!.value.duration && _videoController!.value.isInitialized) {
            setState(() {
              _isPlaying = false;
            });
            _videoController!.pause();
          }
        });
        setState(() {
          _isLoading = false;
        });
        return;
      } catch (e) {
        retryCount++;
        _logger.warning('Video initialization attempt $retryCount failed: $e');
        
        if (retryCount == _maxRetries) {
          setState(() {
            _isLoading = false;
            _hasError = true;
          });
          return;
        }
        
        await Future.delayed(delay);
        delay *= 2;
      }
    }
  }

  Future<void> _initializeImage() async {
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15.0),
      ),
      child: SizedBox(
        width: MediaQuery.of(context).size.width,
        height: MediaQuery.of(context).size.height * 0.65,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15.0),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _hasError
                  ? _buildErrorWidget(context)
                  : _isVideo
                      ? _buildVideoPlayer(context)
                      : _buildImageDisplay(context),
        ),
      ),
    );
  }

  Widget _buildErrorWidget(BuildContext context) {
    return Container(
      color: Colors.grey[300],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, color: Colors.grey[600], size: 48),
          const SizedBox(height: 16),
          Text(
            'Failed to load media',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _isLoading = true;
                _hasError = false;
              });
              _initializeMedia();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer(BuildContext context) {
    if (_videoController != null && _videoController!.value.isInitialized) {
      return Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: VideoPlayer(_videoController!),
          ),
          if (!_isPlaying)
            GestureDetector(
              onTap: () async {
                if (_videoController!.value.position >= _videoController!.value.duration) {
                  await _videoController!.seekTo(const Duration(milliseconds: 1));
                  await Future.delayed(const Duration(milliseconds: 100));
                }
                setState(() {
                  _isPlaying = true;
                });
                _videoController!.play();
              },
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
              onTap: () {
                setState(() {
                  _isPlaying = false;
                });
                _videoController!.pause();
              },
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
      );
    } else {
      return const Center(child: CircularProgressIndicator());
    }
  }

  Widget _buildImageDisplay(BuildContext context) {
    if (widget.mediaPath.contains("/data/user/")) {
      return Image.file(
        File(widget.mediaPath),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          _logger.severe('Error loading image file: $error');
          return _buildErrorWidget(context);
        },
      );
    }

    return Image.network(
      widget.mediaPath,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        _logger.severe('Error loading image: $error');
        return _buildErrorWidget(context);
      },
      loadingBuilder: (BuildContext context, Widget child,
          ImageChunkEvent? loadingProgress) {
        if (loadingProgress == null) {
          return child;
        }
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null,
          ),
        );
      },
    );
  }
}

