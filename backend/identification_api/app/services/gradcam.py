from typing import Optional, Tuple
import cv2
import numpy as np
from PIL import Image
from app.schemas.scan import HighlightBox


def resize_keep_aspect(img_np: np.ndarray, max_side: int = 1024) -> np.ndarray:
    """Resize image so its longest dimension is max_side, maintaining exact aspect ratio."""
    h, w = img_np.shape[:2]
    if max(h, w) <= max_side:
        return img_np
    if h > w:
        new_h = max_side
        new_w = int(round(w * (max_side / h)))
    else:
        new_w = max_side
        new_h = int(round(h * (max_side / w)))
    return cv2.resize(img_np, (new_w, new_h), interpolation=cv2.INTER_AREA)


def generate_demo_saliency_heatmap(img_rgb: np.ndarray) -> np.ndarray:
    """Deterministic, image-driven defect saliency map for DEMO mode."""
    hsv = cv2.cvtColor(img_rgb, cv2.COLOR_RGB2HSV)
    lower_brown = np.array([5, 40, 20])
    upper_brown = np.array([35, 255, 170])
    mask1 = cv2.inRange(hsv, lower_brown, upper_brown)

    lower_dark = np.array([0, 0, 0])
    upper_dark = np.array([180, 255, 60])
    mask2 = cv2.inRange(hsv, lower_dark, upper_dark)

    combined_mask = cv2.bitwise_or(mask1, mask2).astype(np.float32)

    if np.sum(combined_mask) < 100:
        h, w = img_rgb.shape[:2]
        y, x = np.ogrid[:h, :w]
        cy, cx = h / 2, w / 2
        dist = np.sqrt((x - cx) ** 2 + (y - cy) ** 2)
        combined_mask = np.exp(-(dist ** 2) / (2 * (min(h, w) / 4) ** 2))

    ksize = int(max(img_rgb.shape[:2]) * 0.05) | 1
    smoothed = cv2.GaussianBlur(combined_mask, (ksize, ksize), 0)

    min_val, max_val = np.min(smoothed), np.max(smoothed)
    if max_val > min_val:
        normalized = (smoothed - min_val) / (max_val - min_val)
    else:
        normalized = np.zeros_like(smoothed)

    return normalized


def generate_keras_gradcam(
    model,
    preprocessed_input: np.ndarray,
    predicted_class_idx: int,
    layer_name: str = "top_conv"
) -> np.ndarray:
    """
    Generate Grad-CAM heatmap matching the upgraded model's explainability pipeline.
    Directly extracts feature maps from target conv layer and pools gradients from the condition head.
    """
    import tensorflow as tf

    img_array = tf.cast(preprocessed_input, tf.float32)

    # 1. Try direct root layer
    last_conv_layer = None
    try:
        last_conv_layer = model.get_layer(layer_name)
    except (ValueError, KeyError, AttributeError):
        last_conv_layer = None

    if last_conv_layer is not None:
        condition_output_index = next(
            (idx for idx, name in enumerate(model.output_names) if "condition" in name.lower()),
            0
        )
        grad_model = tf.keras.models.Model(
            [model.inputs], [last_conv_layer.output, model.outputs[condition_output_index]]
        )
        with tf.GradientTape() as tape:
            conv_outputs, preds = grad_model(img_array)
            tape.watch(conv_outputs)
            if isinstance(preds, (list, tuple)):
                condition_preds = preds[0]
            else:
                condition_preds = preds
            class_channel = condition_preds[:, predicted_class_idx]
        grads = tape.gradient(class_channel, conv_outputs)

    else:
        # 2. Nested backbone model (Standard EfficientNetB0 multi-head architecture)
        backbone = next(
            (
                layer for layer in model.layers
                if isinstance(layer, tf.keras.Model)
                and layer_name in [child.name for child in layer.layers]
            ),
            None,
        )

        if backbone is None:
            # Fallback to the first Model layer in model.layers
            backbone = next(
                (layer for layer in model.layers if isinstance(layer, tf.keras.Model)),
                None,
            )
            if backbone is None:
                raise ValueError(
                    f"Grad-CAM layer '{layer_name}' was not found in the model."
                )
            for child in reversed(backbone.layers):
                if any(k in child.name.lower() for k in ['conv', 'relu', 'concat', 'top']):
                    layer_name = child.name
                    break

        last_conv_layer = backbone.get_layer(layer_name)

        backbone_model = tf.keras.models.Model(
            backbone.inputs, [last_conv_layer.output, backbone.output]
        )

        backbone_idx = model.layers.index(backbone)
        classifier_input = tf.keras.Input(shape=backbone.output.shape[1:])
        x = classifier_input
        condition_out = None
        for layer in model.layers[backbone_idx + 1:]:
            if "condition" in layer.name.lower():
                condition_out = layer(x)
                break
            elif "severity" in layer.name.lower():
                continue
            else:
                try:
                    x = layer(x)
                except Exception:
                    pass

        if condition_out is None:
            condition_out = x

        classifier_model = tf.keras.models.Model(classifier_input, condition_out)

        with tf.GradientTape() as tape:
            conv_outputs, backbone_out = backbone_model(img_array)
            tape.watch(conv_outputs)
            preds = classifier_model(backbone_out)
            if isinstance(preds, (list, tuple)):
                condition_preds = preds[0]
            else:
                condition_preds = preds
            class_channel = condition_preds[:, predicted_class_idx]

        grads = tape.gradient(class_channel, conv_outputs)

    if grads is None:
        with tf.GradientTape() as input_tape:
            input_tape.watch(img_array)
            predictions = model(img_array, training=False)
            cond_p = predictions[0] if isinstance(predictions, (list, tuple)) else predictions
            input_class_channel = cond_p[:, predicted_class_idx]
        input_grads = input_tape.gradient(input_class_channel, img_array)
        heatmap = tf.reduce_mean(tf.abs(input_grads), axis=-1)[0]
        return (heatmap / (tf.reduce_max(heatmap) + 1e-10)).numpy()

    pooled_grads = tf.reduce_mean(grads, axis=(0, 1, 2))
    conv_outputs = conv_outputs[0]
    heatmap = conv_outputs @ pooled_grads[..., tf.newaxis]
    heatmap = tf.squeeze(heatmap)
    heatmap = tf.maximum(heatmap, 0) / (tf.math.reduce_max(heatmap) + 1e-10)
    return heatmap.numpy()


def draw_styled_viewfinder(img: np.ndarray, pt1: Tuple[int, int], pt2: Tuple[int, int], color=(255, 230, 0), thickness: int = 3):
    """Draws a camera-style viewfinder box with rounded corners and white side markers."""
    x1, y1 = pt1
    x2, y2 = pt2
    w = max(10, x2 - x1)
    h = max(10, y2 - y1)
    r = min(18, int(min(w, h) * 0.12))

    # Top and bottom horizontal lines
    if x2 - r > x1 + r:
        cv2.line(img, (x1 + r, y1), (x2 - r, y1), color, thickness)
        cv2.line(img, (x1 + r, y2), (x2 - r, y2), color, thickness)

    # Vertical side lines with white center segment
    mid_y = (y1 + y2) // 2
    seg_h = max(6, int(h * 0.25))
    y_seg_top = max(y1 + r, mid_y - seg_h // 2)
    y_seg_bot = min(y2 - r, mid_y + seg_h // 2)

    # Left side
    cv2.line(img, (x1, y1 + r), (x1, y_seg_top), color, thickness)
    cv2.line(img, (x1, y_seg_top), (x1, y_seg_bot), (255, 255, 255), thickness + 1)
    cv2.line(img, (x1, y_seg_bot), (x1, y2 - r), color, thickness)

    # Right side
    cv2.line(img, (x2, y1 + r), (x2, y_seg_top), color, thickness)
    cv2.line(img, (x2, y_seg_top), (x2, y_seg_bot), (255, 255, 255), thickness + 1)
    cv2.line(img, (x2, y_seg_bot), (x2, y2 - r), color, thickness)

    # Corner rounded arcs
    if r > 0:
        cv2.ellipse(img, (x1 + r, y1 + r), (r, r), 180, 0, 90, color, thickness)
        cv2.ellipse(img, (x2 - r, y1 + r), (r, r), 270, 0, 90, color, thickness)
        cv2.ellipse(img, (x1 + r, y2 - r), (r, r), 90, 0, 90, color, thickness)
        cv2.ellipse(img, (x2 - r, y2 - r), (r, r), 0, 0, 90, color, thickness)


def _get_banana_mask(orig_resized: np.ndarray) -> np.ndarray:
    """
    Detect banana fruit region via HSV color segmentation.
    Returns uint8 binary mask (255=banana, 0=background).
    Falls back to full-image mask if no banana region detected.
    """
    h, w = orig_resized.shape[:2]
    orig_bgr = cv2.cvtColor(orig_resized, cv2.COLOR_RGB2BGR)
    hsv = cv2.cvtColor(orig_bgr, cv2.COLOR_BGR2HSV)

    lower_yellow = np.array([15, 40, 60])
    upper_yellow = np.array([40, 255, 255])
    lower_green = np.array([35, 30, 40])
    upper_green = np.array([85, 255, 230])
    lower_brown = np.array([5, 40, 20])
    upper_brown = np.array([22, 255, 200])

    mask = cv2.bitwise_or(
        cv2.inRange(hsv, lower_yellow, upper_yellow),
        cv2.inRange(hsv, lower_green, upper_green),
    )
    mask = cv2.bitwise_or(mask, cv2.inRange(hsv, lower_brown, upper_brown))

    kernel = cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (25, 25))
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)
    mask = cv2.morphologyEx(mask, cv2.MORPH_DILATE, kernel)

    contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    clean = np.zeros_like(mask)
    if contours:
        largest = max(contours, key=cv2.contourArea)
        if cv2.contourArea(largest) > (w * h * 0.008):
            cv2.drawContours(clean, [largest], -1, 255, cv2.FILLED)

    if cv2.countNonZero(clean) == 0:
        clean = np.full((h, w), 255, dtype=np.uint8)

    return clean


def create_gradcam_overlay(
    original_rgb: Image.Image,
    heatmap_2d: np.ndarray,
    alpha: float = 0.45,
    draw_box: bool = True,
    is_healthy: bool = False
) -> Tuple[Image.Image, Image.Image, Optional[HighlightBox]]:
    """
    Overlays Grad-CAM heatmap onto the original image.

    - Healthy banana : soft green (SUMMER colormap) glow ONLY over fruit region.
      Background stays natural. Box drawn around the whole fruit.
    - Diseased banana: JET heatmap masked to the banana region only so defect
      hotspots appear ON the banana skin, not on the background.
    """
    orig_np = np.array(original_rgb)
    orig_resized = resize_keep_aspect(orig_np, max_side=1024)
    h, w = orig_resized.shape[:2]

    heatmap_resized = cv2.resize(heatmap_2d.astype(np.float32), (w, h), interpolation=cv2.INTER_CUBIC)
    heatmap_resized = np.clip(heatmap_resized, 0.0, 1.0)

    # Isolate banana fruit region via HSV color segmentation
    banana_mask = _get_banana_mask(orig_resized)
    fruit_mask_f = banana_mask.astype(np.float32) / 255.0
    fruit_mask_3d = np.stack([fruit_mask_f] * 3, axis=-1)

    if is_healthy:
        # -----------------------------------------------------------------
        # HEALTHY: soft green glow ONLY on fruit area.
        # EfficientNetB0 has no defect focus for healthy images, so raw
        # Grad-CAM paints everything red — replace with a smooth fruit-shape
        # green highlight driven by the color mask instead.
        # -----------------------------------------------------------------
        fruit_f_smooth = cv2.GaussianBlur(fruit_mask_f, (0, 0), sigmaX=max(w, h) * 0.03)
        mn, mx = fruit_f_smooth.min(), fruit_f_smooth.max()
        if mx > mn:
            fruit_f_smooth = (fruit_f_smooth - mn) / (mx - mn)

        heatmap_u8 = (fruit_f_smooth * 255).astype(np.uint8)
        # SUMMER colormap: green->yellow (healthy indicator)
        heatmap_bgr = cv2.applyColorMap(heatmap_u8, cv2.COLORMAP_SUMMER)
        heatmap_rgb = cv2.cvtColor(heatmap_bgr, cv2.COLOR_BGR2RGB)

        blend_alpha = 0.28  # subtle glow
        blended_fruit = np.clip(
            heatmap_rgb.astype(np.float32) * blend_alpha
            + orig_resized.astype(np.float32) * (1.0 - blend_alpha),
            0, 255,
        ).astype(np.uint8)

        # Blend only within fruit mask; background stays original
        blended = (
            blended_fruit.astype(np.float32) * fruit_mask_3d
            + orig_resized.astype(np.float32) * (1.0 - fruit_mask_3d)
        ).clip(0, 255).astype(np.uint8)

        # Box = entire fruit boundary
        box_mask = banana_mask

    else:
        # -----------------------------------------------------------------
        # DISEASED: JET heatmap masked to banana region only.
        # Prevents background from being colored red/blue.
        # -----------------------------------------------------------------
        heatmap_masked = heatmap_resized * fruit_mask_f
        hm_max = heatmap_masked.max()
        if hm_max > 1e-6:
            heatmap_masked = heatmap_masked / hm_max

        heatmap_u8 = (heatmap_masked * 255).astype(np.uint8)
        heatmap_bgr = cv2.applyColorMap(heatmap_u8, cv2.COLORMAP_JET)
        heatmap_rgb = cv2.cvtColor(heatmap_bgr, cv2.COLOR_BGR2RGB)

        blended_fruit = np.clip(
            heatmap_rgb.astype(np.float32) * alpha
            + orig_resized.astype(np.float32) * (1.0 - alpha),
            0, 255,
        ).astype(np.uint8)

        # Background stays natural
        blended = (
            blended_fruit.astype(np.float32) * fruit_mask_3d
            + orig_resized.astype(np.float32) * (1.0 - fruit_mask_3d)
        ).clip(0, 255).astype(np.uint8)

        # Box = largest hotspot within banana
        thresh_val = int(255 * 0.38)
        _, box_mask = cv2.threshold(heatmap_u8, thresh_val, 255, cv2.THRESH_BINARY)

    highlight_box: Optional[HighlightBox] = None

    if draw_box:
        contours, _ = cv2.findContours(box_mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        if contours:
            c = max(contours, key=cv2.contourArea)
            if cv2.contourArea(c) > (w * h * 0.005):
                bx, by, bw, bh = cv2.boundingRect(c)
                pad_pct = 0.04 if is_healthy else 0.10
                pad_x = int(bw * pad_pct)
                pad_y = int(bh * pad_pct)
                x1 = max(4, bx - pad_x)
                y1 = max(4, by - pad_y)
                x2 = min(w - 4, bx + bw + pad_x)
                y2 = min(h - 4, by + bh + pad_y)
                thickness = max(2, int(min(w, h) / 120))

                # Draw the styled camera viewfinder
                draw_styled_viewfinder(blended, (x1, y1), (x2, y2), color=(255, 230, 0), thickness=thickness)

                highlight_box = HighlightBox(
                    x=round(float(x1 / w), 4),
                    y=round(float(y1 / h), 4),
                    w=round(float((x2 - x1) / w), 4),
                    h=round(float((y2 - y1) / h), 4),
                )

    return Image.fromarray(orig_resized), Image.fromarray(blended), highlight_box

