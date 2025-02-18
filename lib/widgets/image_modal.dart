import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class ImageModal extends StatefulWidget {
  final String mediaPath;

  const ImageModal({super.key, required this.mediaPath});

  @override
  State<ImageModal> createState() => _ImageModalState();
}

class _ImageModalState extends State<ImageModal> {
  late VideoPlayerController? _videoController;
  bool _isVideo = false;

  @override
  void initState() {
    super.initState();

    // Determine if the file is a video
    _isVideo = widget.mediaPath.split("?").first.endsWith('.mp4');

    if (_isVideo) {
      _videoController =
          VideoPlayerController.networkUrl(Uri.parse(widget.mediaPath))
            ..initialize().then((_) {
              setState(() {}); // Refresh UI once the video is initialized
            })
            ..setLooping(true);
    } else {
      _videoController = null;
    }
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
          child: _isVideo
              ? _buildVideoPlayer(context)
              : _buildImageDisplay(context),
        ),
      ),
    );
  }

  // Widget for video playback
  Widget _buildVideoPlayer(BuildContext context) {
    if (_videoController == null || !_videoController!.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return FittedBox(
      fit: BoxFit.fitHeight,
      child: Stack(
        alignment: Alignment.center,
        children: [
          FittedBox(
            fit: BoxFit.cover, // Ensures the video covers the full area
            child: SizedBox(
              width: _videoController!.value.size.width,
              height: _videoController!.value.size.height,
              child: VideoPlayer(_videoController!),
            ),
          ),
          IconButton(
            icon: Icon(
              _videoController!.value.isPlaying
                  ? Icons.pause
                  : Icons.play_arrow,
              color: Colors.white,
              size: 50,
            ),
            onPressed: () {
              setState(() {
                if (_videoController!.value.isPlaying) {
                  _videoController!.pause();
                } else {
                  _videoController!.play();
                }
              });
            },
          ),
        ],
      ),
    );
  }

  // Widget for image display
  Widget _buildImageDisplay(BuildContext context) {
    if (widget.mediaPath.contains("/data/user/")) {
      return Image.file(
        File(widget.mediaPath),
        fit: BoxFit.cover,
      );
    }

    return Image.network(
      widget.mediaPath,
      fit: BoxFit.cover,
      loadingBuilder: (BuildContext context, Widget child,
          ImageChunkEvent? loadingProgress) {
        if (loadingProgress == null) {
          return child; // Image fully loaded
        } else {
          return const Center(
            child: CircularProgressIndicator(), // Loading indicator
          );
        }
      },
    );
  }
}
