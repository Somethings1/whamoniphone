# WHAM-iOS: Real-Time 3D Human Pose Estimation on Mobile

An iOS implementation of **WHAM** (World-grounded Humans with Accurate Motion),
highly optimized for Apple Silicon and deployed via CoreML and SceneKit.

Currently, this project runs the **17-Joint (COCO)** pipeline. It turns a
complex PyTorch 3D human pose network into a lightweight, real-time iOS
application by overcoming severe memory limitations (OOM crashes) and stripping
out bloated feature extractors.

## 🚀 Features

* **17-Joint 3D Keypoint Rendering:** Fast, lightweight, and mathematically
bulletproof. Extracts and renders spatial coordinates without the overhead of
Forward Kinematics.
* **Stateful RNN Inference:** Bypasses CoreML's static graph unrolling. By
splitting the Motion Encoder into `Init` and `Step` models, the app maintains
temporal memory across frames without causing the iPhone's RAM to explode.
* **ViT Distillation:** Replaces the massive ViT-H/16 feature extractor with a
mobile-friendly `FastViT` architecture.
* **Sensor Fusion (Gyro):** Uses CoreMotion to dynamically override the neural
network's gravity predictions, pinning the 3D world to real-world physics and
preventing the "leaning" artifacts common in vision-only models.

---

## 🧠 Architecture & Pipeline

Running a temporal 3D pose network on a 4GB RAM mobile device requires breaking
the original pipeline into manageable, stateless chunks for the Apple Neural
Engine (ANE).

### 1. 2D Keypoint Detection
Uses a quantized **YOLOv8n-pose** (`.mlpackage`) to extract 17 COCO keypoints
frame-by-frame.

### 2. Feature Extraction (The FastViT Hack)
The original WHAM relies on HMR2.0's ViT-H/16, which is far too heavy for iOS.
This project uses a custom Knowledge Distillation pipeline to project a
`fastvit_sa24` student model into the 1024-dimensional latent space of the
teacher model, retaining accuracy at a fraction of the compute cost.

### 3. The RNN Split (OOM Fix)
If you export the original WHAM RNN directly to CoreML, the compiler unrolls the
temporal loop, consuming all available RAM and crashing the app instantly. We
solved this by splitting the PyTorch model *before* export:
* **`WHAM_Init.mlpackage`**: Runs once on Frame 0 to generate the initial hidden
state ($h_0$).
* **`WHAM_Step.mlpackage`**: Runs with a fixed sequence length of 1. It takes
the current frame and $h_{t-1}$ as inputs, and outputs the pose alongside the
new $h_t$. Swift manually manages this memory state between frames.


---

## 🛠 Installation & Setup

### Prerequisites
* Xcode 15.0+
* iOS 16.0+ (Tested on iPhone 11 Pro Max)
* Python 3.10 (for model conversion/distillation scripts)

### Running the App
1. Clone this repository.
2. Ensure you have the required `.mlpackage` files in your Xcode project navigator:
   * `yolov8n-pose.mlpackage`
   * `WHAM_I.mlpackage`
   * `WHAM_S.mlpackage`
   * `FastViT.mlpackage`
   * Those can be found on [This link](https://drive.google.com/drive/folders/1v0LbdCmUaXcJzMl1qvLy8gSK1XFbMSH_?usp=sharing)
3. Build and run on a **physical device**. (The Xcode Simulator does not have a
Neural Engine or Gyroscope and will perform terribly).

---

## 📁 Repository Structure

* `/WhamApp` - The iOS Swift source code.
    * `Skeleton3DEngine.swift` - The custom SceneKit renderer.
    * `WhamAnalyzer.swift` - The CoreML inference pipeline.
* `/utils` - Python scripts for PyTorch-to-CoreML conversion.
    * `distillvit-2.ipynb` - The FastViT distillation workflow.
    * `split_rnn.py` - Scripts for exposing hidden states to CoreML.

---

## 🙏 Acknowledgements

* [WHAM](https://github.com/yuedongchen/WHAM) for the core neural network architecture.
* Apple's `coremltools` documentation, for making us figure out stateful inference the hard way.
