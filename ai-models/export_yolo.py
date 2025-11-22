from ultralytics import YOLO

# Load the Nano model
model = YOLO("yolo11n.pt")

# Export to CoreML with NMS and FP16
model.export(
    format="coreml",
    nms=True,
    conf=0.5,
    iou=0.45,
    half=True,
    int8=False
)
