from flask import Flask, request, jsonify, send_from_directory, abort
from flask_cors import CORS
from werkzeug.utils import safe_join
import os
import traceback

# Import the processing function you added to batball_video.py
# Make sure batball_video.py contains process_video_for_highlight(...)
from batball_video import process_video_for_highlight

app = Flask(__name__)
CORS(app)

# --- Directories & paths ---
BASE_DIR = os.getcwd()
UPLOAD_FOLDER = os.path.join(BASE_DIR, "uploads")
MODEL_FOLDER = os.path.join(BASE_DIR, "models")

os.makedirs(UPLOAD_FOLDER, exist_ok=True)
os.makedirs(MODEL_FOLDER, exist_ok=True)

BALL_MODEL = os.path.join(MODEL_FOLDER, "cricket_ball_detector.pt")
BAT_MODEL = os.path.join(MODEL_FOLDER, "bestBat.pt")

# --- Routes ---

@app.route("/health", methods=["GET"])
def health():
    return jsonify({"status": "ok"}), 200

@app.route("/upload", methods=["POST"])
def upload_video():
    """
    Accepts multipart form-data with key 'video'.
    Saves the file into uploads/ and returns filename + URL.
    """
    video = request.files.get("video")
    if not video:
        return jsonify({"error": "No video uploaded"}), 400

    filename = video.filename
    if filename == "":
        return jsonify({"error": "Empty filename"}), 400

    # prevent directory traversal
    filename = os.path.basename(filename)
    file_path = os.path.join(UPLOAD_FOLDER, filename)
    try:
        video.save(file_path)
    except Exception as e:
        return jsonify({"error": f"Failed to save file: {e}"}), 500

    video_url = f"http://localhost:5000/videos/{filename}"
    return jsonify({
        "message": "Video uploaded successfully",
        "path": video_url,
        "filename": filename
    }), 200

@app.route("/videos/<path:filename>", methods=["GET"])
def serve_uploaded_file(filename):
    """
    Serves files from uploads/ via /videos/<filename>
    """
    try:
        file_path = safe_join(UPLOAD_FOLDER, filename)
    except Exception:
        abort(404)
    if not file_path or not os.path.exists(file_path):
        abort(404)
    return send_from_directory(UPLOAD_FOLDER, filename, as_attachment=False)

@app.route("/delete/<path:filename>", methods=["DELETE"])
def delete_file(filename):
    """
    Delete a file from uploads/.
    """
    try:
        safe_name = os.path.basename(filename)
        file_path = os.path.join(UPLOAD_FOLDER, safe_name)
        if os.path.exists(file_path):
            os.remove(file_path)
            return jsonify({"message": f"{safe_name} deleted successfully"}), 200
        else:
            return jsonify({"error": "File not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route("/generatehighlight/<path:filename>", methods=["POST"])
def generate_highlight(filename):
    """
    Trigger highlight generation for an uploaded video.
    Calls process_video_for_highlight(...) and returns highlight URL on success.
    """
    try:
        safe_name = os.path.basename(filename)
        video_path = os.path.join(UPLOAD_FOLDER, safe_name)
        if not os.path.exists(video_path):
            return jsonify({"error": "File not found"}), 404

        base_name, _ = os.path.splitext(safe_name)
        highlight_out = os.path.join(UPLOAD_FOLDER, f"{base_name}_highlight.mp4")
        contact_frames_dir = os.path.join(UPLOAD_FOLDER, f"{base_name}_contact_frames")
        os.makedirs(contact_frames_dir, exist_ok=True)

        # Logging to console for debugging (Flask terminal)
        print("▶️ Processing started:", video_path)
        try:
            # force CPU for local testing; change to 'cuda' if you have GPU and torch configured
            result = process_video_for_highlight(
                video_path=video_path,
                out_highlight_path=highlight_out,
                contact_frames_root=contact_frames_dir,
                ball_model_path=BALL_MODEL,
                bat_model_path=BAT_MODEL,
                device="cpu"
            )
        except Exception as e:
            print("Processing internal error:", e)
            traceback.print_exc()
            return jsonify({"message": "Processing failed", "error": str(e)}), 500

        print("✅ Processing finished:", result)

        highlight_url = f"http://localhost:5000/videos/{os.path.basename(highlight_out)}"
        return jsonify({
            "message": "Highlight generated successfully",
            "highlight_url": highlight_url,
            "detail": result
        }), 200

    except Exception as e:
        traceback.print_exc()
        return jsonify({"message": "Server error", "error": str(e)}), 500

@app.route("/videos", methods=["GET"])
def list_videos():
    """
    Returns list of video URLs from uploads/ (only common video file extensions).
    """
    try:
        files = [
            f"http://localhost:5000/videos/{name}"
            for name in os.listdir(UPLOAD_FOLDER)
            if name.lower().endswith(('.mp4', '.mov', '.avi', '.mkv'))
        ]
        return jsonify(files), 200
    except Exception as e:
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500

# --- Run server ---
if __name__ == "__main__":
    # Use debug=True for local development; remove or set False in production
    app.run(host="0.0.0.0", port=5000, debug=True)
