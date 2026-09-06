import 'dart:io';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class DroneVideoCard extends StatefulWidget {
  final String videoPath;
  final String title;
  final bool isPlaying;
  final VoidCallback onPlayTapped;

  const DroneVideoCard({
    super.key,
    required this.videoPath,
    required this.title,
    required this.isPlaying,
    required this.onPlayTapped,
  });

  @override
  State<DroneVideoCard> createState() => _DroneVideoCardState();
}

class _DroneVideoCardState extends State<DroneVideoCard> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializePreview(); // Initialize controller on widget load to extract 1st frame
  }

  Future<void> _initializePreview() async {
    final File videoFile = File(widget.videoPath);
    if (!await videoFile.exists()) return;

    _controller = VideoPlayerController.networkUrl(Uri.file(videoFile.path));

    try {
      await _controller!.initialize();
      // Seek explicitly to position 0 to guarantee first frame display
      await _controller!.seekTo(Duration.zero);
      
      if (mounted) {
        setState(() => _isInitialized = true);
      }
    } catch (e) {
      debugPrint("Preview initialization error: $e");
    }
  }

  void _handlePlayTapped() {
    if (_controller == null || !_isInitialized) return;

    widget.onPlayTapped(); // Trigger parent active index state update
    _controller!.play();
  }

  @override
  void didUpdateWidget(DroneVideoCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isPlaying && oldWidget.isPlaying) {
      _controller?.pause();
    }
  }

  Future<void> _initAndPlay() async {
    widget.onPlayTapped();

    if (_controller == null) {
      final File videoFile = File(widget.videoPath);
      if (!await videoFile.exists()) return;

      _controller = VideoPlayerController.networkUrl(Uri.file(videoFile.path));

      try {
        await _controller!.initialize();
        if (mounted) setState(() => _isInitialized = true);
      } catch (e) {
        debugPrint("Video init error: $e");
        return;
      }
    }

    _controller!.play();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  void _openFullscreen(BuildContext context) {
    if (_controller == null || !_isInitialized) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(widget.title, style: const TextStyle(color: Colors.white, fontSize: 14)),
          ),
          body: SafeArea(
            child: Center(
              child: AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    VideoPlayer(_controller!),
                    _buildControlBar(isFullscreen: true),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlBar({bool isFullscreen = false}) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: _controller!,
      builder: (context, value, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: Colors.black54,
          child: Row(
            children: [
              // Play / Pause Button
              IconButton(
                icon: Icon(
                  value.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 20,
                ),
                onPressed: () {
                  value.isPlaying ? _controller!.pause() : _controller!.play();
                },
              ),

              // Position / Duration Text
              Text(
                "${_formatDuration(value.position)} / ${_formatDuration(value.duration)}",
                style: const TextStyle(color: Colors.white, fontSize: 11),
              ),
              const SizedBox(width: 8),

              // Interactive Progress Bar
              Expanded(
                child: VideoProgressIndicator(
                  _controller!,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  colors: const VideoProgressColors(
                    playedColor: Color(0xFF0A58CA),
                    bufferedColor: Colors.white24,
                    backgroundColor: Colors.white10,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Fullscreen Toggle
              if (!isFullscreen)
                IconButton(
                  icon: const Icon(Icons.fullscreen, color: Colors.white, size: 20),
                  onPressed: () => _openFullscreen(context),
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
          Container(
            height: 220,
            color: Colors.black,
            child: _isInitialized
                ? Stack(
                    alignment: Alignment.bottomCenter,
                    children: [
                      // 1. Shows First Frame (when paused) or Video Frames (when playing)
                      Center(
                        child: AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: VideoPlayer(_controller!),
                        ),
                      ),

                      // 2. Overlay Play Button when NOT playing
                      if (!widget.isPlaying)
                        GestureDetector(
                          onTap: _handlePlayTapped,
                          child: Container(
                            color: Colors.black38, // Semi-transparent dark overlay
                            child: const Center(
                              child: Icon(
                                Icons.play_circle_fill,
                                color: Colors.white,
                                size: 56,
                              ),
                            ),
                          ),
                        ),

                      // 3. Playback Controls when active
                      if (widget.isPlaying) _buildControlBar(),
                    ],
                  )
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }

  //@override
  //Widget build(BuildContext context) {
  //  return Card(
  //    margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
  //    clipBehavior: Clip.antiAlias,
  //    child: Column(
  //      crossAxisAlignment: CrossAxisAlignment.start,
  //      children: [
  //        Padding(
  //          padding: const EdgeInsets.all(12),
  //          child: Text(
  //            widget.title,
  //            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
  //          ),
  //        ),
  //        Container(
  //          height: 220,
  //          color: Colors.black,
  //          child: _isInitialized && widget.isPlaying
  //              ? Stack(
  //                  alignment: Alignment.bottomCenter,
  //                  children: [
  //                    Center(
  //                      child: AspectRatio(
  //                        aspectRatio: _controller!.value.aspectRatio,
  //                        child: VideoPlayer(_controller!),
  //                      ),
  //                    ),
  //                    _buildControlBar(),
  //                  ],
  //                )
  //              : Center(
  //                  child: IconButton(
  //                    iconSize: 52,
  //                    icon: const Icon(Icons.play_circle_fill, color: Colors.white),
  //                    onPressed: _initAndPlay,
  //                  ),
  //                ),
  //        ),
  //      ],
  //    ),
  //  );
  //}
}