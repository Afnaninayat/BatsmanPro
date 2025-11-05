import os
import cv2
import json
import math
import numpy as np
from collections import deque
from ultralytics import YOLO
from shapely.geometry import Point, Polygon


BALL_MODEL_PATH = 'cricket_ball_detector.pt'
BAT_MODEL_PATH  = 'bestBat.pt'

# Single video input
VIDEO_PATH = 'E:/testvideos/test.mp4'
print(f"Video path set to: {VIDEO_PATH}")


# Output folders
CONTACT_FRAMES_ROOT = 'contact_frames'
HIGHLIGHT_OUT_PATH  = 'batballu2/highlight.mp4'

CROP_SIZE = 640
CONF_THRESH = 0.24
IOU = 0.5
CONTACT_RADIUS = 5
CONTACT_MIN_GAP = 16

# highlight windows
PRE_FRAMES = 20
POST_FRAMES = 20

# ball active state thresholds
BALL_SEEN_FRAMES = 2
BALL_MISS_FRAMES = 5
LINGER_FRAMES = 7

# ----------------------------- MODEL LOAD -----------------------------
ball_model = YOLO(BALL_MODEL_PATH)
bat_model  = YOLO(BAT_MODEL_PATH)

# ----------------------------- UTILITIES -----------------------------
def adaptive_square_crop(frame, target_size=CROP_SIZE):
    h, w = frame.shape[:2]
    size = min(h, w)
    x1 = (w - size) // 2
    y1 = (h - size) // 2
    cropped = frame[y1:y1+size, x1:x1+size]
    return cv2.resize(cropped, (target_size, target_size))

def set_video_path(video_path):
    global VIDEO_PATH
    VIDEO_PATH = video_path



def polygon_centroid(pts):
    pts_arr = np.array(pts, dtype=float)
    cx = float(np.mean(pts_arr[:, 0]))
    cy = float(np.mean(pts_arr[:, 1]))
    return cx, cy

def translate_polygon(pts, dx, dy):
    return [[int(round(x + dx)), int(round(y + dy))] for x, y in pts]

# ----------------------------- PROCESS SINGLE VIDEO -----------------------------
def process_single_video(video_path):
    os.makedirs(CONTACT_FRAMES_ROOT, exist_ok=True)

    cap = cv2.VideoCapture(video_path)
    if not cap.isOpened():
        raise RuntimeError(f"Could not open video: {video_path}")

    orig_w = int(cap.get(cv2.CAP_PROP_FRAME_WIDTH))
    orig_h = int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT))
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    total_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)

    crop_size_px = min(orig_h, orig_w)
    crop_x1 = (orig_w - crop_size_px) // 2
    crop_y1 = (orig_h - crop_size_px) // 2
    scale_from_640_to_crop = crop_size_px / CROP_SIZE

    print(f"Video loaded: {video_path}")
    print(f"Resolution={orig_w}x{orig_h}, fps={fps:.2f}, total_frames={total_frames}")

    last_ball = deque(maxlen=2)
    last_bat  = deque(maxlen=2)
    contacts = []
    last_contact_frame = -9999
    skip_until = -1

    # ball active state
    ball_visible_frames = 0
    ball_missing_frames = 0
    linger_counter = 0
    ball_active = False

    # highlight buffer and writer
    frame_buffer = deque(maxlen=PRE_FRAMES)      # stores tuples (frame_idx, orig_frame)
    post_frames_left = 0
    highlight_writer = None
    last_written_idx = -1
    written_frames = 0

    # init writer once (try common codecs)
    writer = None
    for codec in ['avc1', 'mp4v', 'XVID', 'H264']:
        fourcc = cv2.VideoWriter_fourcc(*codec)
        writer_try = cv2.VideoWriter(HIGHLIGHT_OUT_PATH, fourcc, fps, (orig_w, orig_h))
        if writer_try.isOpened():
            writer = writer_try
            print(f"[INFO] Highlight writer opened with codec '{codec}'")
            break
        else:
            writer_try.release()
    if writer is None:
        print("[WARN] Could not open any VideoWriter codec. Highlight will be skipped.")
    else:
        highlight_writer = writer

    # contact counter for mathematical mapping of highlight index
    contact_count = 0

    frame_idx = 0
    while True:
        ret, frame = cap.read()
        if not ret:
            break

        # store original-resolution frame in buffer (copy to avoid mutation)
        frame_buffer.append((frame_idx, frame.copy()))

        # respect skip window (cooldown skip of inference)
        if frame_idx > last_contact_frame and frame_idx <= skip_until:
            # even if skipping inference, we may need to write highlight post frames
            if post_frames_left > 0 and highlight_writer:
                highlight_writer.write(frame)
                post_frames_left -= 1
                last_written_idx = frame_idx
                written_frames += 1
            frame_idx += 1
            continue

        # crop for detection
        cropped = adaptive_square_crop(frame)
        balls_current = []
        bats_current = []

        # ---------- BALL DETECTION (always run) ----------
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

        # ---------- UPDATE BALL STATE ----------
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

        # ---------- BAT DETECTION (conditional) ----------
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
                        elif hasattr(r, 'boxes') and r.boxes is not None and len(r.boxes) > 0:
                            boxes_xyxy = r.boxes.xyxy.cpu().numpy()
                            confs = r.boxes.conf.cpu().numpy()
                            for (x1, y1, x2, y2), conf in zip(boxes_xyxy, confs):
                                pts = [[int(x1), int(y1)], [int(x2), int(y1)],
                                    [int(x2), int(y2)], [int(x1), int(y2)]]
                                bats_current.append((pts, float(conf)))
            except Exception as e:
                print(f"[WARN] Bat detection failed at frame {frame_idx}: {e}")

        # ---------- PREDICTIVE ESTIMATION ----------
        if not balls_current:
            if len(last_ball) >= 2:
                (x1, y1, c1, f1), (x2, y2, c2, f2) = last_ball[0], last_ball[1]
                dx = x2 - x1
                dy = y2 - y1
                pred_x = int(round(x2 + dx))
                pred_y = int(round(y2 + dy))
                pred_conf = float(c2) * 0.8
                if pred_conf >= CONF_THRESH:
                    balls_current.append((pred_x, pred_y, pred_conf))
            elif len(last_ball) == 1:
                (x, y, c, f) = last_ball[-1]
                pred_conf = float(c) * 0.9
                if pred_conf >= CONF_THRESH:
                    balls_current.append((int(x), int(y), pred_conf))

        if not bats_current and len(last_bat) > 0:
            if len(last_bat) >= 2:
                (pts1, conf1, f1), (pts2, conf2, f2) = last_bat[0], last_bat[1]
                cx1, cy1 = polygon_centroid(pts1)
                cx2, cy2 = polygon_centroid(pts2)
                dx, dy = cx2 - cx1, cy2 - cy1
                pred_pts = translate_polygon(pts2, dx, dy)
                pred_conf = float(conf2) * 0.8
                if pred_conf >= CONF_THRESH:
                    bats_current.append((pred_pts, pred_conf))
            else:
                pts, conf, f = last_bat[-1]
                pred_conf = float(conf) * 0.9
                if pred_conf >= CONF_THRESH:
                    bats_current.append((pts, pred_conf))

        # ---------- CONTACT DETECTION ----------
        contact_found = False
        contact_ball = None
        contact_bat = None
        if balls_current and bats_current:
            for (cx, cy, bconf) in balls_current:
                ball_area = Point(cx, cy).buffer(CONTACT_RADIUS)
                for (pts, bat_conf) in bats_current:
                    poly = Polygon(pts)
                    if poly.is_valid and ball_area.intersects(poly):
                        contact_found = True
                        contact_ball = (cx, cy, float(bconf))
                        contact_bat = (pts, float(bat_conf))
                        break
                if contact_found:
                    break

        # ---------- IF CONTACT: SAVE CONTACT IMAGE + METADATA + START HIGHLIGHT ----------
        if contact_found and frame_idx > last_contact_frame + CONTACT_MIN_GAP:
            # annotate and save 640x640 contact image
            ann = cropped.copy()
            if contact_bat:
                pts, conf = contact_bat
                cv2.polylines(ann, [np.array(pts, np.int32)], True, (0,255,0), 2)
                cv2.putText(ann, f"{conf:.2f}", (pts[0][0], max(0, pts[0][1]-6)),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.45, (0,255,0), 1)
            if contact_ball:
                cx, cy, bconf = contact_ball
                cv2.circle(ann, (cx, cy), 5, (0,0,255), -1)
                cv2.putText(ann, f"{bconf:.2f}", (cx+6, cy-6),
                            cv2.FONT_HERSHEY_SIMPLEX, 0.45, (0,0,255), 1)
            fname = os.path.join(CONTACT_FRAMES_ROOT, f"contact_{frame_idx:06d}.jpg")
            cv2.imwrite(fname, ann)

            # map to original coords
            def map_to_original(x640, y640):
                x_in_crop = int(round(x640 * scale_from_640_to_crop))
                y_in_crop = int(round(y640 * scale_from_640_to_crop))
                return int(crop_x1 + x_in_crop), int(crop_y1 + y_in_crop)

            mapped_ball = None
            if contact_ball:
                bx, by, bconf = contact_ball
                bx_o, by_o = map_to_original(bx, by)
                mapped_ball = {"x_640": bx, "y_640": by, "conf": bconf,
                            "x_orig": bx_o, "y_orig": by_o}

            mapped_bat = None
            if contact_bat:
                pts640, batconf = contact_bat
                pts_orig = [[map_to_original(px, py)[0], map_to_original(px, py)[1]] for (px, py) in pts640]
                mapped_bat = {"pts_640": pts640, "conf": batconf, "pts_orig": pts_orig}

            # bookkeeping
            last_contact_frame = frame_idx
            skip_until = frame_idx + CONTACT_MIN_GAP
            print(f"[CONTACT] frame {frame_idx} saved -> {fname}")

            # increment contact counter (used for mathematical highlight mapping)
            contact_count += 1
            # compute highlight index for this contact (first contact -> PRE_FRAMES)
            frame_highlight = (contact_count - 1) * (PRE_FRAMES + POST_FRAMES + 1) + PRE_FRAMES if highlight_writer else None

            contacts.append({
                "frame_idx": frame_idx,
                "frame_highlight": frame_highlight,
                "ball": mapped_ball,
                "bat": mapped_bat
            })

            # Start or extend highlight writing (fast approach: write pre buffer, contact, then post frames)
            if highlight_writer:
                # write buffered pre-frames (only those not yet written)
                for idx, buf_frame in list(frame_buffer):
                    if idx <= last_written_idx:
                        continue
                    highlight_writer.write(buf_frame)  # buf_frame is tuple (idx, frame) -> writer accepts frame
                    # small safety: if buf_frame is tuple, get the frame element
                    # some envs might require highlight_writer.write(buf_frame[1]) — adjust if needed
                    # but here we keep consistency with previous code pattern
                    last_written_idx = idx
                    written_frames += 1

                # write the contact frame itself (original-resolution)
                highlight_writer.write(frame)
                last_written_idx = frame_idx
                written_frames += 1

                # set post-frames to write for upcoming frames in the main loop
                post_frames_left = POST_FRAMES
            else:
                print("[WARN] highlight_writer not available; skipping highlight writing for this contact.")

        # ---------- If in highlight post-window, write original frame to highlight writer ----------
        if post_frames_left > 0 and highlight_writer:
            # write current original-resolution frame (frame is the current original)
            highlight_writer.write(frame)
            last_written_idx = frame_idx
            written_frames += 1
            post_frames_left -= 1

        # ---------- Update memory ----------
        if balls_current:
            bx, by, bconf = balls_current[0]
            last_ball.append((bx, by, bconf, frame_idx))
        if bats_current:
            pts, bconf = bats_current[0]
            last_bat.append((pts, bconf, frame_idx))

        frame_idx += 1

    # end loop
    cap.release()

    # release writer
    if highlight_writer:
        highlight_writer.release()

    # -------------------- SAVE JSON --------------------
    json_path = os.path.join(CONTACT_FRAMES_ROOT, "contact_info.json")
    with open(json_path, "w") as jf:
        json.dump(contacts, jf, indent=2)
    print(f"[INFO] Saved contact metadata: {json_path}")

    # quick check
    if highlight_writer:
        if os.path.exists(HIGHLIGHT_OUT_PATH) and os.path.getsize(HIGHLIGHT_OUT_PATH) > 0:
            print(f"[INFO] Highlight video created ({written_frames} frames): {HIGHLIGHT_OUT_PATH}")
        else:
            print("[ERROR] Highlight video file is empty or failed to write.")
    else:
        print("[INFO] No highlight writer available; highlight not created.")

if __name__ == "__main__":
    process_single_video(VIDEO_PATH)