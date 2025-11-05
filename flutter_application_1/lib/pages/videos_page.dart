import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../widgets/bottom_nav_bar.dart';

class VideosPage extends StatefulWidget {
  const VideosPage({super.key});

  @override
  State<VideosPage> createState() => _VideosPageState();
}

class _VideosPageState extends State<VideosPage> {
  static const Color goldLight = Color(0xFFEABC5C);
  static const Color background = Color(0xFF000000);

  List<Map<String, dynamic>> videos = [];
  bool isLoading = true;

  // ⚙️ Replace with your Flask server IP
  final String serverUrl = "http://localhost:5000";

  @override
  void initState() {
    super.initState();
    fetchVideos();
  }

  // ✅ Fetch uploaded video list from Flask
  Future<void> fetchVideos() async {
    try {
      final response = await http.get(Uri.parse("$serverUrl/videos"));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final fetchedVideos = data
            .map((url) => {
                  'title': url.split('/').last,
                  'url': url,
                  'id': url.split('/').last,
                })
            .toList();

        setState(() {
          videos = fetchedVideos;
          isLoading = false;
        });
      } else {
        debugPrint("❌ Error fetching videos: ${response.statusCode}");
        setState(() => isLoading = false);
      }
    } catch (e) {
      debugPrint("⚠️ Exception fetching videos: $e");
      setState(() => isLoading = false);
    }
  }

  // ✅ Update title (local only)
  void _updateTitle(String id, String newTitle) {
    final index = videos.indexWhere((v) => v['id'] == id);
    if (index != -1) {
      setState(() {
        videos[index]['title'] = newTitle;
      });
    }
  }

  // ✅ Delete video from backend
Future<void> _deleteVideo(String fileName) async {
  try {
    final response = await http.delete(Uri.parse("$serverUrl/delete/$fileName"));
    if (response.statusCode == 200) {
      setState(() {
        videos.removeWhere((v) => v['title'] == fileName);
      });
      _showMessageDialog("Deleted", "Video deleted successfully.");
    } else if (response.statusCode == 404) {
      _showMessageDialog("Not Found", "Video file not found on the server.");
    } else {
      _showMessageDialog("Error", "Failed to delete video (Status: ${response.statusCode}).");
    }
  } catch (e) {
    _showMessageDialog("Error", "Unable to connect to server: $e");
  }
}

  // ✅ Dialog helper
  void _showMessageDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white24),
        ),
        title: Text(
          title,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK", style: TextStyle(color: Color(0xFFEABC5C))),
          ),
        ],
      ),
    );
  }

  void _showAnalyticsDialog(String title) {
    _showMessageDialog(
        "Detail Analytics", "Analytics for '$title' will be available soon.");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 1,
        centerTitle: true,
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.video_library_outlined, color: goldLight, size: 26),
            SizedBox(width: 8),
            Text(
              "Your Videos",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),

      // 🎯 Attach BottomNavBar here
      bottomNavigationBar: const BottomNavBar(currentIndex: 0),

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: goldLight),
            )
          : videos.isEmpty
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.video_collection_outlined,
                            color: goldLight, size: 60),
                        SizedBox(height: 15),
                        Text(
                          "No Videos Uploaded Yet",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18),
                        ),
                        SizedBox(height: 6),
                        Text(
                          "Upload your first batting session using the + button below.",
                          textAlign: TextAlign.center,
                          style:
                              TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: videos.length,
                  itemBuilder: (_, i) {
                    return VideoTile(
                      videoData: videos[i],
                      onTitleUpdate: _updateTitle,
                      onDelete: (name) => _deleteVideo(videos[i]['title']),
                      onShowAnalytics: _showAnalyticsDialog,
                    );
                  },
                ),
    );
  }
}

// 🔹 Individual Video Tile
class VideoTile extends StatefulWidget {
  final Map<String, dynamic> videoData;
  final Function(String id, String newTitle) onTitleUpdate;
  final Function(String filename) onDelete;
  final Function(String title) onShowAnalytics;

  const VideoTile({
    super.key,
    required this.videoData,
    required this.onTitleUpdate,
    required this.onDelete,
    required this.onShowAnalytics,
  });

  @override
  State<VideoTile> createState() => _VideoTileState();
}

class _VideoTileState extends State<VideoTile> {
  bool _expanded = false;
  bool _editingTitle = false;
  bool _isVideoVisible = false;
  late TextEditingController _titleController;
  VideoPlayerController? _playerController;

  @override
  void initState() {
    super.initState();
    _titleController =
        TextEditingController(text: widget.videoData['title'] ?? '');
  }

  @override
  void dispose() {
    _playerController?.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _toggleVideo() async {
    if (_isVideoVisible) {
      _playerController?.pause();
      _playerController?.dispose();
      setState(() => _isVideoVisible = false);
    } else {
      setState(() => _isVideoVisible = true);
      _playerController =
          VideoPlayerController.network(widget.videoData['url']);
      await _playerController!.initialize();
      setState(() {});
      _playerController!.play();
    }
  }

  void _saveTitle() {
    setState(() => _editingTitle = false);
    widget.onTitleUpdate(widget.videoData['id'], _titleController.text);
  }

  @override
  Widget build(BuildContext context) {
    const goldLight = Color(0xFFEABC5C);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.play_circle_fill,
                color: goldLight, size: 36),
            title: _editingTitle
                ? TextField(
                    controller: _titleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: "Enter title",
                      hintStyle: TextStyle(color: Colors.white54),
                    ),
                    onSubmitted: (_) => _saveTitle(),
                  )
                : Text(
                    _titleController.text,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w500),
                  ),
            subtitle: const Text("Tap to view video",
                style: TextStyle(color: Colors.white54)),
            onTap: _toggleVideo,
            trailing: PopupMenuButton<String>(
              color: Colors.black,
              surfaceTintColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Colors.white24),
              ),
              onSelected: (value) {
                if (value == 'edit') {
                  setState(() => _editingTitle = true);
                } else if (value == 'delete') {
                  widget.onDelete(widget.videoData['title']);
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: goldLight, size: 20),
                      SizedBox(width: 8),
                      Text("Edit Title",
                          style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.redAccent, size: 20),
                      SizedBox(width: 8),
                      Text("Delete", style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ],
              icon: const Icon(Icons.more_vert, color: goldLight),
            ),
          ),

          // Expandable analytics button
          if (!_isVideoVisible)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Colors.white70),
                onPressed: () => setState(() => _expanded = !_expanded),
              ),
            ),

          if (_expanded)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: ElevatedButton(
                onPressed: () =>
                    widget.onShowAnalytics(_titleController.text),
                style: ElevatedButton.styleFrom(
                  backgroundColor: goldLight,
                  foregroundColor: Colors.black,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text("Show Detail Analytics"),
              ),
            ),

          // Inline video player
          if (_isVideoVisible && _playerController != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: _playerController!.value.aspectRatio,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: VideoPlayer(_playerController!),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(
                          _playerController!.value.isPlaying
                              ? Icons.pause_circle_filled
                              : Icons.play_circle_fill,
                          color: goldLight,
                          size: 45,
                        ),
                        onPressed: () {
                          setState(() {
                            _playerController!.value.isPlaying
                                ? _playerController!.pause()
                                : _playerController!.play();
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete,
                            color: Colors.redAccent),
                        onPressed: () =>
                            widget.onDelete(widget.videoData['title']),
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
