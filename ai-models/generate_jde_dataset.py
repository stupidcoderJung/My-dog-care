import os
import sys
import subprocess
import shutil
import numpy as np
import torch
import cv2
from PIL import Image
from tqdm import tqdm
import yaml
from pathlib import Path

# --- Setup & Installation Check ---
def install_dependencies():
    packages = ["ultralytics", "transformers", "datasets", "scikit-learn", "pillow", "torch", "torchvision"]
    print(f"Checking/Installing dependencies: {', '.join(packages)}...")
    subprocess.check_call([sys.executable, "-m", "pip", "install"] + packages)

try:
    import ultralytics
    import transformers
    import datasets
    import sklearn
except ImportError:
    install_dependencies()
    import ultralytics
    import transformers
    import datasets
    import sklearn

from ultralytics import YOLO
from transformers import AutoImageProcessor, AutoModel
from sklearn.cluster import DBSCAN
from datasets import load_dataset

# --- Configuration ---
DATASET_NAME = "drzraf/petfinder-dogs"
OUTPUT_DIR = "datasets"
IMAGES_DIR = os.path.join(OUTPUT_DIR, "images", "train")
LABELS_DIR = os.path.join(OUTPUT_DIR, "labels", "train")
CONFIG_FILE = "dog_jde.yaml"
NUM_SAMPLES = 2000  # Set to None for full dataset, or integer for testing
CONF_THRESHOLD = 0.5
DOG_CLASS_ID = 16 # COCO class for dog
DINO_MODEL_NAME = "facebook/dinov2-small"
DBSCAN_EPS = 0.15 # Strict threshold for clustering
DBSCAN_MIN_SAMPLES = 2

# --- Device Setup ---
device = "cuda" if torch.cuda.is_available() else "cpu"
print(f"Using device: {device}")

# --- 1. Prepare Directories ---
if os.path.exists(OUTPUT_DIR):
    print(f"Cleaning existing directory: {OUTPUT_DIR}")
    shutil.rmtree(OUTPUT_DIR)
os.makedirs(IMAGES_DIR, exist_ok=True)
os.makedirs(LABELS_DIR, exist_ok=True)

# --- 2. Load Dataset ---
print(f"Loading dataset: {DATASET_NAME}...")
# Use streaming=True to avoid downloading the whole thing if we only want samples
ds = load_dataset(DATASET_NAME, split="train", streaming=True)

if NUM_SAMPLES:
    print(f"Taking top {NUM_SAMPLES} samples for processing...")
    data_stream = ds.take(NUM_SAMPLES)
else:
    data_stream = ds

# --- 3. Initialize Models ---
print("Loading YOLOv8n for detection...")
yolo_model = YOLO("yolov8n.pt")

print(f"Loading DINOv2 ({DINO_MODEL_NAME}) for feature extraction...")
processor = AutoImageProcessor.from_pretrained(DINO_MODEL_NAME)
dino_model = AutoModel.from_pretrained(DINO_MODEL_NAME).to(device)
dino_model.eval()

# --- 4. Processing Loop ---
print("Starting processing pipeline...")

# Store data for clustering if metadata ID is missing
crop_embeddings = []
crop_metadata = [] # Stores (image_filename, box_normalized, original_w, original_h)
metadata_id_map = {} # Map original PetID to integer ID
next_id = 0

# Helper to extract embedding
def get_embedding(image_crop):
    inputs = processor(images=image_crop, return_tensors="pt").to(device)
    with torch.no_grad():
        outputs = dino_model(**inputs)
    # Use CLS token (first token) as embedding
    embedding = outputs.last_hidden_state[:, 0, :].cpu().numpy().flatten()
    return embedding

# We need to iterate once to process images and collect embeddings/IDs
processed_count = 0
valid_images = 0

for i, sample in tqdm(enumerate(data_stream), total=NUM_SAMPLES if NUM_SAMPLES else None, desc="Processing Images"):
    try:
        image = sample['image']
        
        # Ensure RGB
        if image.mode != "RGB":
            image = image.convert("RGB")
            
        w, h = image.size
        
        # Run YOLO Detection
        results = yolo_model(image, verbose=False, classes=[DOG_CLASS_ID], conf=CONF_THRESHOLD)
        
        if not results or len(results[0].boxes) == 0:
            continue
            
        # Check for Metadata ID
        # 'PetID' is common in PetFinder datasets. Adjust key if needed after inspection.
        # If 'photo_id' or similar exists, we need to be careful. We want 'subject' ID.
        subject_id = sample.get('PetID') or sample.get('id') or sample.get('label') 
        
        # If subject_id is not useful (e.g. just a row index), treat as None
        # For drzraf/petfinder-dogs, let's assume if we can't find a clear ID string, we use visual clustering.
        
        has_metadata_id = False
        current_int_id = -1
        
        if subject_id and isinstance(subject_id, (str, int)):
            has_metadata_id = True
            if subject_id not in metadata_id_map:
                metadata_id_map[subject_id] = next_id
                next_id += 1
            current_int_id = metadata_id_map[subject_id]
        
        # Process detections
        boxes = results[0].boxes
        
        # Save image
        filename = f"{i:06d}.jpg"
        image_path = os.path.join(IMAGES_DIR, filename)
        image.save(image_path)
        
        label_lines = []
        
        for box in boxes:
            xywhn = box.xywhn[0].cpu().numpy() # x_center, y_center, width, height (normalized)
            xyxy = box.xyxy[0].cpu().numpy() # x1, y1, x2, y2
            
            # Crop for embedding (if needed)
            if not has_metadata_id:
                # Crop image
                crop = image.crop((xyxy[0], xyxy[1], xyxy[2], xyxy[3]))
                emb = get_embedding(crop)
                
                crop_embeddings.append(emb)
                crop_metadata.append({
                    "filename": filename,
                    "bbox": xywhn, # x_c, y_c, w, h
                    "temp_id": -1 # To be filled by clustering
                })
            else:
                # Write label directly
                # Format: class_idx identity_id x_c y_c w h
                # JDE usually expects class 0 for the object of interest if single class
                label_lines.append(f"0 {current_int_id} {xywhn[0]:.6f} {xywhn[1]:.6f} {xywhn[2]:.6f} {xywhn[3]:.6f}")
        
        # If we had metadata IDs, write the label file now
        if has_metadata_id and label_lines:
            label_path = os.path.join(LABELS_DIR, f"{i:06d}.txt")
            with open(label_path, "w") as f:
                f.write("\n".join(label_lines))
            valid_images += 1
            
        elif not has_metadata_id:
            # We delay writing labels for this image until clustering is done
            # But we still count it as processed
            valid_images += 1

        processed_count += 1
        
    except Exception as e:
        print(f"Error processing image {i}: {e}")
        continue

print(f"Processed {processed_count} images.")

# --- 5. Clustering (If needed) ---
if crop_embeddings:
    print(f"Running DBSCAN clustering on {len(crop_embeddings)} crops...")
    X = np.array(crop_embeddings)
    
    # Normalize embeddings for cosine similarity (DBSCAN with euclidean on normalized vectors ~= cosine)
    X = X / np.linalg.norm(X, axis=1, keepdims=True)
    
    # DBSCAN
    # eps is distance threshold. Lower = stricter.
    # min_samples = min neighbors to form a core point.
    db = DBSCAN(eps=DBSCAN_EPS, min_samples=DBSCAN_MIN_SAMPLES, metric='euclidean').fit(X)
    labels = db.labels_
    
    # Assign IDs
    # labels: -1 is noise (unique), others are cluster IDs
    
    # We need to map cluster IDs to our global ID space
    # And handle noise points
    
    cluster_id_map = {} # cluster_label -> global_id
    
    # Start IDs after the metadata-based IDs (if any)
    current_global_id = next_id 
    
    print("Assigning IDs from clusters...")
    
    # Group crops by filename to write label files efficiently
    file_labels = {}
    
    for idx, cluster_label in enumerate(labels):
        meta = crop_metadata[idx]
        fname = meta['filename']
        bbox = meta['bbox']
        
        final_id = -1
        
        if cluster_label == -1:
            # Noise point -> Unique ID
            final_id = current_global_id
            current_global_id += 1
        else:
            # Cluster -> Shared ID
            if cluster_label not in cluster_id_map:
                cluster_id_map[cluster_label] = current_global_id
                current_global_id += 1
            final_id = cluster_id_map[cluster_label]
            
        if fname not in file_labels:
            file_labels[fname] = []
            
        # Format: 0 {identity_id} {x_center} {y_center} {width} {height}
        file_labels[fname].append(f"0 {final_id} {bbox[0]:.6f} {bbox[1]:.6f} {bbox[2]:.6f} {bbox[3]:.6f}")
        
    # Write label files for clustered data
    print("Writing labels for clustered images...")
    for fname, lines in file_labels.items():
        label_path = os.path.join(LABELS_DIR, fname.replace(".jpg", ".txt"))
        with open(label_path, "w") as f:
            f.write("\n".join(lines))

    print(f"Clustering complete. Total unique identities: {current_global_id}")

# --- 6. Create Config File ---
print(f"Generating {CONFIG_FILE}...")

config_content = f"""
path: {os.path.abspath(OUTPUT_DIR)} # dataset root dir
train: images/train  # train images (relative to 'path')
val: images/train  # val images (relative to 'path') - using train for demo
test:  # test images (optional)

# Classes
nc: 1  # number of classes
names: ['dog']  # class names
"""

with open(CONFIG_FILE, "w") as f:
    f.write(config_content)

print("="*50)
print("Pipeline Complete!")
print(f"Images: {IMAGES_DIR}")
print(f"Labels: {LABELS_DIR}")
print(f"Config: {CONFIG_FILE}")
print("="*50)
