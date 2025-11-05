# 🏏 Batsman Pro — AI-Driven Shot Analysis

**Batsman Pro** is an AI-powered cricket analytics system that helps players and coaches analyze batting performance using computer vision and deep learning.  
It detects batting shots, tracks footwork, identifies bat-ball contact, and provides performance analytics — all through a powerful **Flutter frontend** and **Flask backend**.

---

## 🚀 Overview

| Technology | Purpose |
|-------------|----------|
| **Flutter** | Cross-platform mobile & web frontend |
| **Flask** | Backend API for video processing & storage |
| **Firebase** | Authentication & user management |
| **OpenCV / NumPy** | AI & computer vision processing |

---

## 🧠 Key Features

### 🧩 AI & Computer Vision
- 🎥 Shot classification & segmentation  
- 🦶 Footwork detection  
- ⚾ Bat-ball contact detection  
- ✂️ Automatic highlight generation  
- 📊 Performance analytics dashboard  

### 📱 Flutter Frontend
- 🔐 Firebase Authentication  
- ☁️ Upload videos to backend  
- 🎬 Inline video player with playback controls  
- 🧩 Edit, rename, and delete videos  
- 🌙 Dark mode with gold-accent UI  

### 🔙 Flask Backend
- `/upload` → Uploads video  
- `/videos` → Lists all uploaded videos  
- `/uploads/<filename>` → Streams a specific video  
- `/delete/<filename>` → Deletes selected video  
- `/rename` → Renames video file  

---

## 🏗️ Project Structure

```
batsman_pro/
│
├── backend_flask/
│   ├── app.py                # Flask backend server
│   ├── batball.py            # AI / CV processing logic
│   ├── uploads/              # Uploaded videos folder
│   ├── requirements.txt      # Python dependencies
│   └── venv/                 # Virtual environment (ignored)
│
└── flutter_application_1/
    ├── lib/
    │   ├── main.dart
    │   ├── pages/
    │   │   ├── login.dart
    │   │   ├── register.dart
    │   │   ├── dashboard.dart
    │   │   └── videos_page.dart
    ├── android/
    ├── ios/
    ├── web/
    └── pubspec.yaml
```

---

## ⚙️ Installation & Setup

### 🐍 Flask Backend Setup
```bash
cd backend_flask
python -m venv venv
venv\Scripts\activate         # Windows
# source venv/bin/activate    # macOS / Linux
pip install -r requirements.txt
python app.py
```
✅ Runs the backend server at: **http://0.0.0.0:5000**

---

### 💙 Flutter Frontend Setup
```bash
cd flutter_application_1
flutter pub get
flutter run
```
For **Web**:
```bash
flutter run -d chrome
```

Update your backend IP inside:
```dart
const localIp = '192.168.1.100'; // Replace with your PC's IP
```

---

## 🔌 API Reference

| Endpoint | Method | Description |
|-----------|---------|-------------|
| `/upload` | POST | Upload video file |
| `/videos` | GET | Get all uploaded videos |
| `/uploads/<filename>` | GET | Stream video |
| `/delete/<filename>` | DELETE | Delete video |
| `/rename` | POST | Rename uploaded file |

---

## 🧾 Requirements

**Backend**
- Python 3.10+
- Flask, Flask-CORS
- OpenCV, NumPy

**Frontend**
- Flutter 3.0+
- Firebase Auth
- video_player, http, provider

---

## 🧠 Learnings

- Integrated **Flutter** frontend with a **Flask** backend  
- Built custom APIs for upload, playback, and analytics  
- Used **AI models** for video-based classification  
- Designed cross-platform responsive UI  

---

## 🧩 Future Enhancements

- ☁️ Cloud storage integration  
- 🧠 Real-time shot prediction  
- 📈 Player & team statistics dashboard  
- 🎯 Trajectory and impact speed estimation  

---


## 🧾 License

This project was created as part of the **Final Year Project at Usman Institute of Technology (UIT)**.  
All rights reserved © 2025 **Afnan Inayat**.

---

## 🌐 Connect with Me

- 💼 [LinkedIn](https://linkedin.com/in/afnaninayat)
- 💻 [GitHub](https://github.com/Afnaninayat)
- ✉️ **afnan.inayat@example.com**

---

### ⭐ If you found this project helpful, please give it a star on GitHub!
