from flask import Flask, request, jsonify, send_from_directory, abort
from flask_cors import CORS
from werkzeug.utils import safe_join
import os
import subprocess  # Import subprocess module
from updated_script.send_video import process_video
from batball_video import process_batball

app = Flask(__name__)
CORS(app)

UPLOAD_FOLDER = os.path.join(os.getcwd(), 'uploads')
os.makedirs(UPLOAD_FOLDER, exist_ok=True)

# ----------------------------------------------------------
# Upload endpoint
# ----------------------------------------------------------
@app.route('/upload', methods=['POST'])
def upload_video():
    video = request.files.get('video')
    if not video:
        return jsonify({'error': 'No video uploaded'}), 400

    filename = video.filename
    file_path = os.path.join(UPLOAD_FOLDER, filename)

    # ✅ Save uploaded video
    video.save(file_path)

    # # ✅ Call your highlight generator (optional)
    # try:
    #     batball.set_video_path(file_path)
    #     batball.process_single_video(file_path)
    # except Exception as e:
    #     print(f"⚠️ batball processing failed: {e}")

    # ✅ Return the full URL for Flutter to play
    video_url = f"http://localhost:5000/uploads/{filename}"
    return jsonify({
        'message': 'Video uploaded successfully',
        'path': video_url
    }), 200


# ----------------------------------------------------------
# Serve uploaded video files
# ----------------------------------------------------------
@app.route('/videos/<path:filename>', methods=['GET'])
def serve_uploaded_file(filename):
    file_path = safe_join(UPLOAD_FOLDER, filename)
    if not os.path.exists(file_path):
        abort(404)
    return send_from_directory(UPLOAD_FOLDER, filename)

@app.route('/delete/<path:filename>',methods=['DELETE'])
def delete_file(filename):
    try:
        file_path = os.path.join(UPLOAD_FOLDER, filename)
        print(f"Attempting to delete file: {file_path}")
        if os.path.exists(file_path):
            os.remove(file_path)
            return jsonify({"message": f"{filename} deleted successfully"}), 200
        else:
            return jsonify({"error": "File not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    
@app.route('/generatehighlight/<filename>', methods=['POST'])
def generate_highlight(filename):
    try:
        video_path = os.path.join(UPLOAD_FOLDER, filename)

        if not os.path.exists(video_path):
            return jsonify({'error': 'File not found'}), 404

        try:
            # result = process_video(video_path)
            print("START")
            process_batball(video_path)
            print("END")
            return jsonify({"message": "Highlight generated"}), 200
        except:
            return jsonify({'message': 'Processing failed inside process_video function'}), 400

    except Exception as e:
        print(f"Error generating highlight: {e}")
        return jsonify({'message': str(e)}), 500

@app.route('/videos', methods=['GET'])
def list_videos():
    try:
        files = [
            f"http://localhost:5000/videos/{name}"
            for name in os.listdir(UPLOAD_FOLDER)
            if name.lower().endswith(('.mp4', '.mov', '.avi', '.mkv'))
        ]
        return jsonify(files)
    except Exception as e:
        print(f"Error listing videos: {e}")
        return jsonify([]), 500
# ----------------------------------------------------------
# Run the app
# ----------------------------------------------------------
if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
