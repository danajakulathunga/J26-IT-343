# BananaGuard AI - Machine Learning Scaffold

This directory contains the training and evaluation pipelines for the multi-head EfficientNetB0 neural network.

## Dataset Structure

Prepare a dataset CSV or Excel file containing the following columns:

- `image_id`: Unique string ID for each photo.
- `image_name`: Original image filename.
- `fruit_ID`: Unique ID for each individual banana fruit or bunch (used for group-splitting to prevent data leakage).
- `image_path`: Absolute or relative path to the image file.
- `variety`: Banana cultivar (e.g. Cavendish, Ambul, Kolikuttu, Seeni, Rath Kesel, Anamalu, Suwandel, Puwalu).
- `maturity`: Harvest maturity stage.
- `condition`: Target condition (one of the 17 classes).
- `condition_type`: "Healthy", "Disease", or "Defect".
- `severity`: "mild", "moderate", "severe" (empty or ignored for healthy samples).
- `notes`: Research notes.

## Training

To train the model:

```bash
python ml/train.py --metadata path/to/dataset.csv --image-dir path/to/images --output-model ml/models/bananaguard_model.keras --epochs 40
```

## Evaluation

To evaluate on the test split:

```bash
python ml/evaluate.py --model ml/models/bananaguard_model.keras --test-csv ml/models/test_split.csv --image-dir path/to/images
```

## Deploying Trained Model to Backend

Once training completes, simply copy `bananaguard_model.keras` to `backend/ml/models/bananaguard_model.keras` and set:

```bash
MODEL_MODE=real
```

in `backend/.env`. The FastAPI backend will automatically load the weights and generate true Grad-CAM activations from the EfficientNetB0 convolutional backbone.
