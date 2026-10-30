# Experiments Summary: 224px vs 300px Resolution Comparison

**Diagnostic Report Generated:** 2026-10-11  
**Dataset Splits:** Deterministic Hash-Based Split (Train: 618, Val: 76, Test: 88 images across 6 classes)  
**Target Hardware:** 35% CPU Cap (4 worker threads), Dedicated GPU device 0

---

## 1. Overall Performance Comparison

| Experiment | Architecture | Image Size | Test Accuracy | Macro-F1 | Time/Epoch | Test Images |
|---|---|---|---|---|---|---|
| **combo_224** | MobileNetV2 | 224x224 | **86.36%** | **0.8048** | 11.23s | 88 |
| **res300_combo** | MobileNetV2 | 300x300 | **88.64%** | **0.8315** | 19.39s | 88 |
| **effb3_300** | EfficientNetB3 | 300x300 | **87.50%** | **0.8190** | 71.29s | 88 |

---

## 2. Per-Class F1 Score Breakdown

| Variety Class | combo_224 (224px) | res300_combo (300px) | effb3_300 (300px) |
|---|---|---|---|
| **Ambul_Banana** | 0.8000 | 0.8333 | 0.8182 |
| **Ambun_Banana** | 0.4000 | 0.5000 | 0.4444 |
| **Anamalu_Banana** | 0.9375 | 0.9375 | 0.9375 |
| **Kolikuttu_Banana** | 0.9020 | 0.9200 | 0.9167 |
| **Red_Banana** | 0.9655 | 0.9655 | 0.9655 |
| **Seeni_Banana** | 0.8235 | 0.8333 | 0.8333 |

---

## 3. Winning Configuration Analysis

- **Winner:** **`res300_combo` (MobileNetV2 + Combo Settings at 300x300)**
- **Why it won:**
  1. Achieves superior Macro-F1 (**0.8315** vs **0.8048** baseline), particularly improving difficult classes like `Ambun_Banana` and `Ambul_Banana` where finer skin texture resolution is critical.
  2. Training speed is ~3.7x faster than EfficientNetB3 (19.4s vs 71.3s per epoch), fitting within the project's real-time continuous learning requirements.
  3. Direct upgrade path for the MobileNetV2 production inference pipeline.

### Winning Settings for `training_config.json`:
- **Architecture:** `mobilenetv2`
- **Image Size:** `300`
- **Batch Size:** `16`
- **Stage 1:** `20` epochs, learning rate `1e-3`, base model frozen
- **Stage 2:** `10` epochs, learning rate `1e-5`, unfreeze last `30` layers
- **Augmentation Preset:** `combo` (RandomFlip, RandomRotation 0.15, RandomZoom 0.15, RandomBrightness 0.15, RandomContrast 0.15)
- **Class Weights:** `balanced`
- **Early Stopping:** `patience=5`, `restore_best_weights=True`
- **Seed:** `42`
