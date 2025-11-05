import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../pages/videos_page.dart';
import '../pages/profile_page.dart';

class BottomNavBar extends StatefulWidget {
  final int currentIndex;
  const BottomNavBar({super.key, required this.currentIndex});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  static const Color goldLight = Color(0xFFEABC5C);
  static const Color background = Color(0xFF000000);

  bool _isUploading = false;
  // ignore: unused_field 
  double _uploadProgress = 10;

  // 🔹 Upload video using FilePicker (same logic as dashboard)
  Future<void> _uploadVideo() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.video);
    if (result == null) return;

    final bytes = result.files.first.bytes;
    final name = result.files.first.name;
    if (bytes == null) return;

    final blob = html.Blob([bytes]);
    final file = html.File([blob], name);
    await _uploadVideoWeb(file, name);
  }

  // 🔹 Upload to Flask + Firestore
  Future<void> _uploadVideoWeb(html.File file, String name) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    final doc = FirebaseFirestore.instance.collection('videos').doc();
    await doc.set({
      'userId': user.uid,
      'fileName': name,
      'uploadedAt': FieldValue.serverTimestamp(),
      'status': 'uploading',
    });

    final req = html.HttpRequest();
    req.open('POST', 'http://localhost:5000/upload');
    final form = html.FormData();
    form.appendBlob('video', file, name);
    req.send(form);

    req.upload.onProgress.listen((e) {
      if (e.lengthComputable) {
        setState(() => _uploadProgress = e.loaded! / e.total! * 100);
      }
    });

    req.onLoadEnd.listen((_) async {
      setState(() => _isUploading = false);
      if (req.status == 200) {
        String url = "http://localhost:5000/uploads/$name";
        try {
          final resp = jsonDecode(req.responseText ?? '{}');
          if (resp['path'] != null) url = resp['path'];
        } catch (_) {}
        await doc.update({'path': url, 'status': 'done'});

        _showDialog("✅ Upload Successful",
            "Your video has been uploaded successfully.", true);
      } else {
        _showDialog("Upload Failed", "Something went wrong.", false);
      }
    });
  }

  // 🖤 Black and White Dialog
  void _showDialog(String title, String message, bool success) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.white24),
        ),
        title: Text(
          title,
          style: TextStyle(
            color: success ? Colors.white : Colors.redAccent,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: Text(
          message,
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        ),
        actionsAlignment: MainAxisAlignment.end,
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black,
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.pop(context);
              if (success) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const VideosPage()),
                );
              }
            },
            child: const Text(
              'OK',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 70,
      decoration: const BoxDecoration(
        color: background,
        boxShadow: [
          BoxShadow(color: Colors.black54, blurRadius: 6, offset: Offset(0, -1))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // 🎬 Videos Page Button
          _buildNavItem(
            icon: Icons.play_circle_fill,
            label: "Videos",
            isSelected: widget.currentIndex == 0,
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const VideosPage()),
              );
            },
          ),

          // ➕ Upload Button (center elevated)
          GestureDetector(
            onTap: _isUploading ? null : _uploadVideo,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 65,
              width: 65,
              decoration: BoxDecoration(
                color: goldLight,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.6),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Center(
                child: _isUploading
                    ? const SizedBox(
                        width: 25,
                        height: 25,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.black),
                      )
                    : const Icon(Icons.add, color: Colors.black, size: 32),
              ),
            ),
          ),

          // 👤 Profile Page Button
          _buildNavItem(
            icon: Icons.person_rounded,
            label: "Profile",
            isSelected: widget.currentIndex == 2,
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ProfilePage()),
              );
            },
          ),
        ],
      ),
    );
  }

  // 🔹 Reusable nav item builder with hover/elevation
  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      splashColor: goldLight.withOpacity(0.3),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white10 : Colors.transparent,
          borderRadius: BorderRadius.circular(30),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                color: isSelected ? goldLight : Colors.white70, size: 28),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? goldLight : Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
