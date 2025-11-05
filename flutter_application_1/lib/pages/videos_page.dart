// lib/pages/videos_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../widgets/bottom_nav_bar.dart';
import 'dashboard_page.dart';

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

  // 🔗 Replace localhost with your backend IP when deployed
  final String serverUrl = "http://localhost:5000";

  @override
  void initState() {
    super.initState();
    fetchVideos();
  }

  // ✅ Fetch uploaded video list from Flask
  Future<void> fetchVideos() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse("$serverUrl/videos"));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        final fetchedVideos = data
            .map((url) => {
                  'title': url.toString().split('/').last,
                  'url': url,
                  'id': url.toString().split('/').last,
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

  // ✅ Update title locally
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
      final response =
          await http.delete(Uri.parse("$serverUrl/delete/$fileName"));
      if (response.statusCode == 200) {
        setState(() {
          videos.removeWhere((v) => v['title'] == fileName);
        });
        _showMessageDialog("Deleted", "Video deleted successfully.");
      } else if (response.statusCode == 404) {
        _showMessageDialog("Not Found", "Video file not found on the server.");
      } else {
        _showMessageDialog("Error",
            "Failed to delete video (Status: ${response.statusCode}).");
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
          style:
              const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child:
                const Text("OK", style: TextStyle(color: Color(0xFFEABC5C))),
          ),
        ],
      ),
    );
  }

  // ✅ Processing dialog that shows backend logs in real time
  void _showProcessingDialog(Stream<String> logStream) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white24),
          ),
          title: const Text(
            "Processing Video...",
            style: TextStyle(color: Color(0xFFEABC5C)),
          ),
          content: StreamBuilder<String>(
            stream: logStream,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const SizedBox(
                  height: 80,
                  child: Center(
                    child:
                        CircularProgressIndicator(color: Color(0xFFEABC5C)),
                  ),
                );
              }
              return SizedBox(
                width: double.maxFinite,
                height: 150,
                child: SingleChildScrollView(
                  child: Text(
                    snapshot.data!,
                    style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                        fontFamily: 'monospace'),
                  ),
                ),
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel",
                  style: TextStyle(color: Color(0xFFEABC5C))),
            ),
          ],
        );
      },
    );
  }

  // ✅ Navigate + process video before showing Dashboard
  Future<void> _navigateToAnalytics(String videoId) async {
    final String apiUrl = "$serverUrl/generatehighlight/$videoId";

    // Simulate log stream (backend live logs)
    final logStreamController = StreamController<String>();
    _showProcessingDialog(logStreamController.stream);

    try {
      final request = http.Request('POST', Uri.parse(apiUrl));
      final response = await http.Client().send(request);

      // ✅ Stream backend logs as they arrive
      response.stream
          .transform(utf8.decoder)
          .listen((chunk) => logStreamController.add(chunk));

      final fullResponse = await http.Response.fromStream(response);
      logStreamController.close();
      Navigator.pop(context); // close dialog

      if (fullResponse.statusCode == 200) {
        final data = json.decode(fullResponse.body);
        final String highlightUrl = data["highlight_url"] ??
            "$serverUrl/videos/${videoId.split('.').first}_highlight.mp4";

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardPage(
              videoId: videoId,
              highlightUrl: highlightUrl,
            ),
          ),
        );
      } else {
        _showMessageDialog(
          "Processing Failed",
          "Server returned status: ${fullResponse.statusCode}",
        );
      }
    } catch (e) {
      Navigator.pop(context);
      _showMessageDialog("Error", "Unable to process video: $e");
    } finally {
      logStreamController.close();
    }
  }

  // Logout handler
  void _handleLogout() {
    Navigator.pushReplacementNamed(context, '/login');
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
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
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

      drawer: Drawer(
        child: Container(
          color: Colors.black,
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/profile');
                },
                child: const DrawerHeader(
                  decoration: BoxDecoration(color: Colors.white10),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.white12,
                        child: Icon(Icons.person, size: 30, color: Colors.white),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Afnan Inayat\nafnan@example.com',
                          style: TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _DrawerTile(
                icon: Icons.dashboard_outlined,
                label: 'Dashboard',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/dashboard');
                },
              ),
              _DrawerTile(
                icon: Icons.video_library,
                label: 'Your Videos',
                onTap: () {
                  Navigator.pop(context);
                },
              ),
              _DrawerTile(
                icon: Icons.person_outline,
                label: 'Profile',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/profile');
                },
              ),
              const Divider(color: Colors.white12),
              _DrawerTile(
                icon: Icons.logout,
                label: 'Logout',
                onTap: () {
                  Navigator.pop(context);
                  _handleLogout();
                },
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14.0),
                child: Text(
                  'v1.0.0',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar: const BottomNavBar(currentIndex: 0),

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: goldLight),
            )
          : videos.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: fetchVideos,
                  color: goldLight,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: videos.length,
                    itemBuilder: (_, i) {
                      return VideoTile(
                        videoData: videos[i],
                        onTitleUpdate: _updateTitle,
                        onDelete: (name) => _deleteVideo(videos[i]['title']),
                        onShowAnalytics: (title) => _navigateToAnalytics(title),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

// 🔹 Drawer item
class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _DrawerTile({
    Key? key,
    required this.icon,
    required this.label,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const goldLight = Color(0xFFEABC5C);
    return ListTile(
      leading: Icon(icon, color: goldLight),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18.0),
      horizontalTitleGap: 6,
    );
  }
}

// 🔹 Video Tile Widget
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
            leading:
                const Icon(Icons.play_circle_fill, color: goldLight, size: 36),
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
                        icon: const Icon(Icons.delete, color: Colors.redAccent),
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
