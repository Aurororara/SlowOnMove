import cv2
import numpy as np
import mediapipe as mp
import time
import mediapipe as mp

def calculate_angle(a, b, c):
    a = np.array(a) # 座標1
    b = np.array(b) # 轉換點
    c = np.array(c) # 座標2
    
    radians = np.arctan2(c[1]-b[1], c[0]-b[0]) - np.arctan2(a[1]-b[1], a[0]-b[0])
    angle = np.abs(radians*180.0/np.pi)
    
    if angle > 180.0:
        angle = 360 - angle
        
    return angle

try:
    if not hasattr(mp, 'solutions'):
        from mediapipe.python.solutions import pose as mp_pose
        from mediapipe.python.solutions import drawing_utils as mp_drawing
    else:
        mp_pose = mp.solutions.pose
        mp_drawing = mp.solutions.drawing_utils
except:
    import mediapipe.python.solutions.pose as mp_pose
    import mediapipe.python.solutions.drawing_utils as mp_drawing

# 1. 初始化 Pose 模型
pose = mp_pose.Pose(
    static_image_mode=False,
    model_complexity=2, 
    enable_segmentation=False,
    min_detection_confidence=0.5,
    min_tracking_confidence=0.5
)

# 2. 開啟攝影機
cap = cv2.VideoCapture(0) 

if not cap.isOpened():
    print("❌ 找不到任何可用的攝影機！")
    exit()

print("攝影機啟動中... 按下 'q' 鍵可以退出程式")

# 超慢跑狀態追蹤變數
step_count = 0
is_foot_on_ground = False
last_foot_y = 0
start_time = time.time()

while cap.isOpened():
    success, frame = cap.read()
    if not success:
        print("無法讀取攝影機畫面")
        break

    # 取得當前畫面大小 (直接使用原始 DroidCam 比例，不再裁切)
    h, w, _ = frame.shape
        
    # 如果畫面太小，可以稍微放大 (非必須)
    # frame = cv2.resize(frame, (540, 960))
    # ==========================================

    # 為了 MediaPipe，將 BGR 轉換為 RGB
    image = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
    results = pose.process(image)

    # 轉回 BGR 以便用 OpenCV 顯示
    image = cv2.cvtColor(image, cv2.COLOR_RGB2BGR)

    # 3. 畫出骨架
    if results.pose_landmarks:
        mp_drawing.draw_landmarks(
            image, results.pose_landmarks, mp_pose.POSE_CONNECTIONS,
            mp_drawing.DrawingSpec(color=(0,255,0), thickness=2, circle_radius=2), # 關節點顏色
            mp_drawing.DrawingSpec(color=(0,0,255), thickness=2, circle_radius=2)  # 連線顏色
        )
        
        # --- 將姿勢判斷邏輯移入迴圈內，才能做到即時顯示 ---
        landmarks = results.pose_landmarks.landmark
        
        # 取得左半身關鍵點 (x, y)
        shoulder = [landmarks[11].x, landmarks[11].y]
        hip = [landmarks[23].x, landmarks[23].y]
        knee = [landmarks[25].x, landmarks[25].y]
        ankle = [landmarks[27].x, landmarks[27].y]
        heel = [landmarks[29].x, landmarks[29].y]  # 腳跟 (Left Heel)
        toe = [landmarks[31].x, landmarks[31].y]   # 腳尖 (Left Foot Index)
        
        # 取得關鍵點的能見度(Visibility)，若過低代表鏡頭沒拍到下半身
        heel_vis = landmarks[29].visibility
        toe_vis = landmarks[31].visibility

        # --- 超慢跑邏輯判斷 ---
        
        # 1. 判斷膝蓋是否保持「ㄍ字型」微彎 (超慢跑要訣)
        # 完全打直是 180 度，微彎大約在 140~170 度之間最適當
        knee_angle = calculate_angle(hip, knee, ankle)
        
        # 3. 判斷著地方式 (前腳掌先著地)
        # toe[1] (腳尖) 若大於 heel[1] (腳跟)，代表腳尖在畫面下方 (先觸地)
        # 為了容錯，計算兩者高度差
        foot_diff = toe[1] - heel[1] 

        # 4. 步伐與步頻計算 (簡單透過腳踝 Y 軸的上下變化來判斷顛簸與步伐)
        # 當腳踝 Y 值大於某個門檻(踩到底) 且 之前是抬起狀態
        current_foot_y = ankle[1]
        if current_foot_y > 0.85 and not is_foot_on_ground: # 0.85 是一個相對畫面底部的估計值，需依實際畫面微調
            is_foot_on_ground = True
            step_count += 1
        elif current_foot_y < 0.82:
            is_foot_on_ground = False
            
        elapsed_time = time.time() - start_time
        # 避免除以零
        cadence = int(step_count / (elapsed_time / 60)) if elapsed_time > 0 else 0 

        # --- 狀態更新與顯示提示 ---
        feedback = "Good Form!"
        color = (0, 255, 0) # 預設綠色

        if heel_vis < 0.5 or toe_vis < 0.5:
            feedback = "Feet not visible!"
            color = (0, 0, 255)
        elif knee_angle > 175:
            # 膝蓋完全打直，容易傷膝蓋
            feedback = "Knees Too Straight! Bend Slightly"
            color = (0, 0, 255)
        elif knee_angle < 130:
            # 彎曲太多變成深蹲了
            feedback = "Knees Bending Too Much!"
            color = (0, 165, 255)
        elif foot_diff < 0: 
            # 腳跟比腳尖在畫面中更下方，代表腳跟優先落地
            feedback = "Midfoot Strike Needed!"
            color = (0, 0, 255) # 紅色警告

        # 顯示文字
        cv2.putText(image, f"Status: {feedback}", (30, 60), cv2.FONT_HERSHEY_SIMPLEX, 1, color, 3)
        cv2.putText(image, f"Knee Angle: {int(knee_angle)}", (30, 100), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
        cv2.putText(image, f"Steps: {step_count} (Cadence: {cadence} spm)", (30, 140), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)

    # 顯示畫面
    cv2.imshow('Slow On Move - Pose Tracking', image)

    # 按下 'q' 鍵退出
    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

cap.release()
cv2.destroyAllWindows()