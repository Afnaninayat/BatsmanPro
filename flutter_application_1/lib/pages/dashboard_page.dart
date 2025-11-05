// lib/pages/dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../widgets/bottom_nav_bar.dart';

class DashboardPage extends StatefulWidget {
  final String? videoId; // from videos page
  final String? highlightUrl; // highlight video URL from Flask

  const DashboardPage({
    super.key,
    this.videoId,
    this.highlightUrl,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  static const Color goldLight = Color(0xFFEABC5C);
  static const Color background = Color(0xFF000000);

  VideoPlayerController? _controller;
  bool _isMuted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    if (widget.highlightUrl != null) {
      _initializeVideo(widget.highlightUrl!);
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initializeVideo(String url) async {
    try {
      _controller = VideoPlayerController.network(url)
        ..initialize().then((_) {
          setState(() => _isLoading = false);
          _controller!.play();
        });
    } catch (e) {
      debugPrint("⚠️ Video load error: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  // ✅ Mute / unmute toggle
  void _toggleMute() {
    if (_controller != null) {
      setState(() {
        _isMuted = !_isMuted;
        _controller!.setVolume(_isMuted ? 0 : 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 1,
        centerTitle: true,
        leading: Builder(
          builder: (ctx) => IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.analytics_outlined, color: goldLight, size: 26),
            SizedBox(width: 8),
            Text(
              "Detailed Analytics",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),

      bottomNavigationBar: const BottomNavBar(currentIndex: 1),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: goldLight),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (widget.highlightUrl == null)
                    const Expanded(
                      child: Center(
                        child: Text(
                          "No highlight video available.",
                          style: TextStyle(color: Colors.white54, fontSize: 16),
                        ),
                      ),
                    )
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // 🎥 Video Player
                        AspectRatio(
                          aspectRatio:
                              _controller?.value.aspectRatio ?? (16 / 9),
                          child: _controller != null &&
                                  _controller!.value.isInitialized
                              ? Stack(
                                  alignment: Alignment.bottomCenter,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: VideoPlayer(_controller!),
                                    ),
                                    _buildVideoControls(),
                                  ],
                                )
                              : const Center(
                                  child: CircularProgressIndicator(
                                      color: goldLight),
                                ),
                        ),
                        const SizedBox(height: 20),

                        // 📊 Static Shot Tiles
                        _buildShotTypeGrid(),
                      ],
                    ),
                ],
              ),
      ),
    );
  }

  // 🎮 Video control overlay
  Widget _buildVideoControls() {
    return Container(
      color: Colors.black38,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(
              _controller!.value.isPlaying
                  ? Icons.pause_circle_filled
                  : Icons.play_circle_fill,
              color: goldLight,
              size: 40,
            ),
            onPressed: () {
              setState(() {
                _controller!.value.isPlaying
                    ? _controller!.pause()
                    : _controller!.play();
              });
            },
          ),
          const SizedBox(width: 20),
          IconButton(
            icon: Icon(
              _isMuted ? Icons.volume_off : Icons.volume_up,
              color: Colors.white,
              size: 28,
            ),
            onPressed: _toggleMute,
          ),
          const SizedBox(width: 20),
          Expanded(
            child: VideoProgressIndicator(
              _controller!,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: goldLight,
                backgroundColor: Colors.white24,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🏏 Static shot type tiles
  Widget _buildShotTypeGrid() {
    final List<Map<String, dynamic>> shotTypes = [
      {"label": "Cover Drive", "icon": Icons.sports_cricket},
      {"label": "Pull Shot", "icon": Icons.sports_baseball},
      {"label": "Flick Shot", "icon": Icons.sports_tennis},
      {"label": "Cut Shot", "icon": Icons.sports_handball},
      {"label": "Straight Drive", "icon": Icons.sports},
      {"label": "Defense", "icon": Icons.shield_outlined},
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: shotTypes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 2.5,
      ),
      itemBuilder: (context, index) {
        final shot = shotTypes[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(shot['icon'], color: goldLight, size: 22),
              const SizedBox(width: 8),
              Text(
                shot['label'],
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        );
      },
    );
  }
}
