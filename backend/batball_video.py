import os
import cv2
import json
import math
import numpy as np
from collections import deque
from ultralytics import YOLO
from shapely.geometry import Point, Polygon
import torch

# -----------------------------------------------------
# MAIN FUNCTION - called from Flask
# -----------------------------------------------------
def process_video_for_highlight(video_path, out_highlight_path, contact_frames_root, ball_model_path, bat_model_path, device='cpu'):
    """
    Processes a cricket video, detects bat-ball contact, saves highlight video and JSON metadata.
    Returns: dict containing output paths
    """
    # ensure output directories
    os.makedirs(contact_frames_root, exist_ok=True)
    os.makedirs(os.path.dirname(out_highlight_path), exist_ok=True)

    # load models lazily
    print(f"🟢 Loading models on {device} ...")
    ball_model = YOLO(ball_model_path)
    bat_model = YOLO(bat_model_path)

    if device == 'cpu':
        print("Running on CPU — slower but works for local testing.")
    else:
        if torch.cuda.is_available():
            ball_model.to('cuda')
            bat_model.to('cuda')
            print("Using GPU acceleration.")

    # --- constants ---
    CROP_SIZE = 640
    CONF_THRESH = 0.24
    IOU = 0.5
    CONTACT_RADIUS = 5
    CONTACT_MIN_GAP = 16
    PRE_FRAMES = 20
    POST_FRAMES = 20
    BALL_SEEN_FRAMES = 2
    BALL_MISS_FRAMES = 5
    LINGER_FRAMES = 7

    # open video
    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        raise RuntimeError(f"Could not open video: {video_path}")

    orig_w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    orig_h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)

    print(f"🎞️ Loaded video {video_path} ({orig_w}x{orig_h}, {fps:.1f} FPS, {total_frames} frames)")

    # setup VideoWriter
    highlight_writer = None
    for codec in ['mp4v', 'XVID', 'avc1']:
        fourcc = cv2.VideoWriter_fourcc(*codec)
        writer_try = cv2.VideoWriter(out_highlight_path, fourcc, fps, (orig_w, orig_h))
        if writer_try.isOpened():
            highlight_writer = writer_try
            print(f"[INFO] Highlight writer opened using codec {codec}")
            break

    if highlight_writer is None:
        print("[WARN] Could not initialize VideoWriter; highlights won't be saved.")

    # main vars
    frame_buffer = deque(maxlen=PRE_FRAMES)
    last_contact_frame = -9999
    skip_until = -1
    post_frames_left = 0
    last_written_idx = -1
    written_frames = 0
    contacts = []

    last_ball = deque(maxlen=2)
    last_bat = deque(maxlen=2)
    ball_visible_frames = 0
    ball_missing_frames = 0
    linger_counter = 0
    ball_active = False

    frame_idx = 0
    while True:
        ret, frame = cap.read()
        if not ret:
            break

        frame_buffer.append((frame_idx, frame.copy()))

        # skip cooldown window
        if frame_idx > last_contact_frame and frame_idx <= skip_until:
            if post_frames_left > 0 and highlight_writer:
                highlight_writer.write(frame)
                post_frames_left -= 1
            frame_idx += 1
            continue

        # --- crop square center ---
        h, w = frame.shape[:2]
        size = min(h, w)
        x1 = (w - size) // 2
        y1 = (h - size) // 2
        cropped = cv2.resize(frame[y1:y1+size, x1:x1+size], (CROP_SIZE, CROP_SIZE))

        balls_current = []
        bats_current = []

        # ---------- BALL DETECTION ----------
        try:
            ball_results = ball_model(cropped, conf=CONF_THRESH, iou=IOU, classes=[0])
            if ball_results and len(ball_results) > 0:
                r0 = ball_results[0]
                if hasattr(r0, 'boxes') and r0.boxes is not None and len(r0.boxes) > 0:
                    boxes_xyxy = r0.boxes.xyxy.cpu().numpy()
                    confs = r0.boxes.conf.cpu().numpy()
                    for (x1, y1, x2, y2), conf in zip(boxes_xyxy, confs):
                        cx = int(round((x1 + x2) / 2.0))
                        cy = int(round((y1 + y2) / 2.0))
                        balls_current.append((cx, cy, float(conf)))
        except Exception as e:
            print(f"[WARN] Ball detection failed at frame {frame_idx}: {e}")

        # --- update ball state ---
        if balls_current:
            ball_visible_frames += 1
            ball_missing_frames = 0
        else:
            ball_missing_frames += 1
            ball_visible_frames = max(0, ball_visible_frames - 1)

        if ball_visible_frames >= BALL_SEEN_FRAMES:
            ball_active = True
            linger_counter = LINGER_FRAMES
        elif ball_missing_frames >= BALL_MISS_FRAMES:
            if linger_counter > 0:
                linger_counter -= 1
                ball_active = True
            else:
                ball_active = False

        # ---------- BAT DETECTION ----------
        if ball_active:
            try:
                bat_results = bat_model.predict(source=cropped, imgsz=CROP_SIZE, conf=CONF_THRESH, verbose=False)
                if bat_results and len(bat_results) > 0:
                    for r in bat_results:
                        obb_attr = getattr(r, 'obb', None)
                        if obb_attr is not None and getattr(obb_attr, 'xyxyxyxy', None) is not None:
                            obb_boxes = obb_attr.xyxyxyxy.cpu().numpy()
                            obb_confs = obb_attr.conf.cpu().numpy()
                            for box_flat, conf in zip(obb_boxes, obb_confs):
                                pts = box_flat.reshape(4, 2).astype(int).tolist()
                                bats_current.append((pts, float(conf)))
            except Exception as e:
                print(f"[WARN] Bat detection failed at frame {frame_idx}: {e}")

        # ---------- CONTACT DETECTION ----------
        contact_found = False
        contact_ball = None
        contact_bat = None
        if balls_current and bats_current:
            for (cx, cy, bconf) in balls_current:
                ball_area = Point(cx, cy).buffer(5)
                for (pts, bat_conf) in bats_current:
                    poly = Polygon(pts)
                    if poly.is_valid and ball_area.intersects(poly):
                        contact_found = True
                        contact_ball = (cx, cy, float(bconf))
                        contact_bat = (pts, float(bat_conf))
                        break
                if contact_found:
                    break

        # ---------- IF CONTACT ----------
        if contact_found and frame_idx > last_contact_frame + CONTACT_MIN_GAP:
            print(f"[CONTACT] Detected at frame {frame_idx}")
            last_contact_frame = frame_idx
            skip_until = frame_idx + CONTACT_MIN_GAP

            ann = cropped.copy()
            if contact_bat:
                pts, conf = contact_bat
                cv2.polylines(ann, [np.array(pts, np.int32)], True, (0,255,0), 2)
            if contact_ball:
                cx, cy, _ = contact_ball
                cv2.circle(ann, (cx, cy), 5, (0,0,255), -1)

            img_path = os.path.join(contact_frames_root, f"contact_{frame_idx:06d}.jpg")
            cv2.imwrite(img_path, ann)

            contacts.append({
                "frame_idx": frame_idx,
                "img": img_path
            })

            # write highlight clip
            if highlight_writer:
                for idx, buf_frame in list(frame_buffer):
                    if idx <= last_written_idx:
                        continue
                    highlight_writer.write(buf_frame[1])  # ✅ use the frame element
                    last_written_idx = idx
                    written_frames += 1

                highlight_writer.write(frame)
                last_written_idx = frame_idx
                written_frames += 1
                post_frames_left = POST_FRAMES

        if post_frames_left > 0 and highlight_writer:
            highlight_writer.write(frame)
            last_written_idx = frame_idx
            written_frames += 1
            post_frames_left -= 1

        frame_idx += 1

    cap.release()
    if highlight_writer:
        highlight_writer.release()

    json_path = os.path.join(contact_frames_root, "contact_info.json")
    with open(json_path, "w") as jf:
        json.dump(contacts, jf, indent=2)

    print(f"✅ Done! Saved highlight: {out_highlight_path}")
    print(f"✅ Contacts JSON: {json_path}")

    return {
        "highlight_path": out_highlight_path,
        "contacts_json": json_path
    }
