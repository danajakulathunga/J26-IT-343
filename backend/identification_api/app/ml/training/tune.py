"""
Hyperparameter Tuning Runner (Phase H4 / Prompt 3).
Executes sequential model ablation and tuning experiments for EfficientNetB3.

Configs:
  T1 baseline: lr-stage2 1e-5, label-smoothing 0.0, bg-swap-prob 0.6
  T2:          lr-stage2 5e-5, label-smoothing 0.0, bg-swap-prob 0.6
  T3:          lr-stage2 1e-5, label-smoothing 0.1, bg-swap-prob 0.6
  T4:          lr-stage2 1e-5, label-smoothing 0.0, bg-swap-prob 0.0 (augmentation ablation)

Constraints:
  - Resumable: Skips runs where history.json already exists.
  - Continues after failures.
  - Logs to data/diagnostics/tune_log.txt.
  - Evaluation ranking on VALIDATION loss/accuracy only (never uses test split).
  - Generates data/diagnostics/tuning_table.md & .csv and runs app.ml.report.
"""

import argparse
import csv
import json
import logging
import os
import subprocess
import sys
import time
from typing import Any, Dict, List, Optional

BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))
if BASE_DIR not in sys.path:
    sys.path.insert(0, BASE_DIR)

DEFAULT_LOG_PATH = os.path.join(BASE_DIR, "data", "diagnostics", "tune_log.txt")
EXPERIMENTS_DIR = os.path.join(BASE_DIR, "app", "ml", "model_versions", "experiments")

CONFIGS = [
    {
        "id": "T1",
        "name": "baseline",
        "description": "Baseline: lr-stage2 1e-5, label-smoothing 0.0, bg-swap-prob 0.6",
        "lr_stage1": 1e-3,
        "lr_stage2": 1e-5,
        "label_smoothing": 0.0,
        "bg_swap_prob": 0.6,
        "epochs_s1": 5,
        "epochs_s2": 3,
    },
    {
        "id": "T2",
        "name": "lr_stage2_5e-5",
        "description": "Higher fine-tune LR: lr-stage2 5e-5",
        "lr_stage1": 1e-3,
        "lr_stage2": 5e-5,
        "label_smoothing": 0.0,
        "bg_swap_prob": 0.6,
        "epochs_s1": 5,
        "epochs_s2": 3,
    },
    {
        "id": "T3",
        "name": "label_smoothing_0.1",
        "description": "Label smoothing regularization: label-smoothing 0.1",
        "lr_stage1": 1e-3,
        "lr_stage2": 1e-5,
        "label_smoothing": 0.1,
        "bg_swap_prob": 0.6,
        "epochs_s1": 5,
        "epochs_s2": 3,
    },
    {
        "id": "T4",
        "name": "no_bg_swap",
        "description": "Augmentation ablation: bg-swap-prob 0.0",
        "lr_stage1": 1e-3,
        "lr_stage2": 1e-5,
        "label_smoothing": 0.0,
        "bg_swap_prob": 0.0,
        "epochs_s1": 5,
        "epochs_s2": 3,
    },
]


def setup_logger(log_file: str) -> logging.Logger:
    os.makedirs(os.path.dirname(os.path.abspath(log_file)), exist_ok=True)
    logger = logging.getLogger("tune_runner")
    logger.setLevel(logging.INFO)
    logger.handlers.clear()

    formatter = logging.Formatter("[%(asctime)s] %(message)s", datefmt="%Y-%m-%d %H:%M:%S")

    # File handler
    fh = logging.FileHandler(log_file, mode="a", encoding="utf-8")
    fh.setFormatter(formatter)
    logger.addHandler(fh)

    # Console handler
    ch = logging.StreamHandler(sys.stdout)
    ch.setFormatter(formatter)
    logger.addHandler(ch)

    return logger


def run_smoke_test(logger: logging.Logger) -> Dict[str, Any]:
    """Runs a 1-epoch smoke test of T1 to measure exact execution time per epoch."""
    smoke_dir = os.path.join(EXPERIMENTS_DIR, "smoke_test")
    os.makedirs(smoke_dir, exist_ok=True)

    logger.info("=======================================================")
    logger.info(" Starting 1-Epoch Smoke Test (Config T1)")
    logger.info(f" Smoke Dir: {smoke_dir}")
    logger.info("=======================================================")

    cmd = [
        sys.executable,
        "-m",
        "app.ml.training.train_pipeline",
        "--out-dir",
        smoke_dir,
        "--arch",
        "efficientnetb3",
        "--split",
        "group",
        "--batch-size",
        "32",
        "--seed",
        "42",
        "--epochs-stage1",
        "1",
        "--epochs-stage2",
        "0",
        "--lr-stage1",
        "0.001",
        "--lr-stage2",
        "1e-05",
        "--label-smoothing",
        "0.0",
        "--bg-swap-prob",
        "0.6",
        "--run-name",
        "smoke_test_T1",
    ]

    t0 = time.time()
    res = subprocess.run(cmd, cwd=BASE_DIR, capture_output=True, text=True)
    duration = time.time() - t0

    if res.returncode != 0:
        logger.error(f"Smoke test failed with return code {res.returncode}:\n{res.stderr}")
        raise RuntimeError(f"Smoke test failed: {res.stderr}")

    logger.info(f"Smoke test completed successfully in {duration:.2f}s ({duration/60.0:.2f} min).")

    # Total batch estimate: 4 configs x (5 stage 1 + 3 stage 2 = 8 epochs) = 32 epochs
    # Stage 2 takes ~same or slightly longer per epoch.
    sec_per_epoch = duration
    total_epochs = len(CONFIGS) * (5 + 3)  # 32 epochs
    baseline_estimate = total_epochs * sec_per_epoch
    estimate_low = baseline_estimate * 1.50   # +50%
    estimate_high = baseline_estimate * 1.80  # +80%

    logger.info(f"Measured seconds per epoch: {sec_per_epoch:.2f}s")
    logger.info(f"Total Batch (32 epochs) baseline estimate: {baseline_estimate / 60.0:.1f} min")
    logger.info(f"Batch estimate with +50% to +80% safety margin: {estimate_low / 60.0:.1f} min - {estimate_high / 60.0:.1f} min ({estimate_low / 3600.0:.2f}h - {estimate_high / 3600.0:.2f}h)")

    return {
        "seconds_per_epoch": round(sec_per_epoch, 2),
        "baseline_estimate_min": round(baseline_estimate / 60.0, 1),
        "estimate_50_pct_min": round(estimate_low / 60.0, 1),
        "estimate_80_pct_min": round(estimate_high / 60.0, 1),
        "estimate_50_pct_hr": round(estimate_low / 3600.0, 2),
        "estimate_80_pct_hr": round(estimate_high / 3600.0, 2),
    }


def execute_config(cfg: Dict[str, Any], logger: logging.Logger) -> bool:
    run_dir = os.path.join(EXPERIMENTS_DIR, f"tune_{cfg['id']}")
    history_path = os.path.join(run_dir, "history.json")

    if os.path.isfile(history_path):
        logger.info(f"[RESUME] Skipping {cfg['id']} ({cfg['name']}): history.json already exists in {run_dir}")
        return True

    os.makedirs(run_dir, exist_ok=True)
    logger.info(f"\n=======================================================")
    logger.info(f" Starting Experiment {cfg['id']}: {cfg['name']}")
    logger.info(f" Details: {cfg['description']}")
    logger.info(f" Output Dir: {run_dir}")
    logger.info(f"=======================================================")

    cmd = [
        sys.executable,
        "-m",
        "app.ml.training.train_pipeline",
        "--out-dir",
        run_dir,
        "--arch",
        "efficientnetb3",
        "--split",
        "group",
        "--batch-size",
        "32",
        "--seed",
        "42",
        "--epochs-stage1",
        str(cfg["epochs_s1"]),
        "--epochs-stage2",
        str(cfg["epochs_s2"]),
        "--lr-stage1",
        str(cfg["lr_stage1"]),
        "--lr-stage2",
        str(cfg["lr_stage2"]),
        "--label-smoothing",
        str(cfg["label_smoothing"]),
        "--bg-swap-prob",
        str(cfg["bg_swap_prob"]),
        "--run-name",
        f"tune_{cfg['id']}_{cfg['name']}",
    ]

    t0 = time.time()
    try:
        proc = subprocess.Popen(
            cmd,
            cwd=BASE_DIR,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
        )
        if proc.stdout:
            for line in proc.stdout:
                clean_line = line.rstrip()
                if clean_line:
                    logger.info(clean_line)
        proc.wait()
        duration = time.time() - t0

        if proc.returncode != 0:
            logger.error(f"[ERROR] Experiment {cfg['id']} failed with code {proc.returncode}")
            return False

        logger.info(f"[SUCCESS] Experiment {cfg['id']} completed in {duration:.1f}s ({duration/60.0:.2f} min).")

        # Run report generator
        try:
            from app.ml.report import generate_report
            logger.info(f"Generating visual and markdown report for {cfg['id']}...")
            generate_report(run_dir)
        except Exception as e:
            logger.warning(f"Report generation for {cfg['id']} encountered an issue: {e}")

        return True
    except Exception as e:
        logger.error(f"[EXCEPTION] Failed running experiment {cfg['id']}: {e}")
        return False


def collect_tuning_results(logger: logging.Logger) -> List[Dict[str, Any]]:
    """Gathers validation-only performance metrics for each completed tuning experiment."""
    results = []

    for cfg in CONFIGS:
        run_dir = os.path.join(EXPERIMENTS_DIR, f"tune_{cfg['id']}")
        history_path = os.path.join(run_dir, "history.json")
        metrics_path = os.path.join(run_dir, "metrics.json")

        if not os.path.isfile(history_path):
            continue

        with open(history_path, "r", encoding="utf-8") as f:
            history = json.load(f)

        if not history:
            continue

        # Extract strictly VALIDATION metrics and final train metrics
        val_losses = [r["val_loss"] for r in history]
        val_accs = [r["val_accuracy"] for r in history]

        best_val_loss = min(val_losses)
        best_val_acc = max(val_accs)
        final_train_acc = history[-1]["accuracy"]
        final_val_acc = history[-1]["val_accuracy"]
        train_val_gap = round(final_train_acc - final_val_acc, 4)

        duration_sec = 0.0
        if os.path.isfile(metrics_path):
            with open(metrics_path, "r", encoding="utf-8") as f:
                m = json.load(f)
                duration_sec = m.get("timing", {}).get("total_duration_seconds", 0.0)

        results.append({
            "run_id": cfg["id"],
            "name": cfg["name"],
            "what_changed": cfg["description"],
            "best_val_acc": round(best_val_acc, 4),
            "best_val_loss": round(best_val_loss, 4),
            "final_train_acc": round(final_train_acc, 4),
            "final_val_acc": round(final_val_acc, 4),
            "train_val_gap": train_val_gap,
            "time": f"{duration_sec / 60.0:.1f}m",
            "duration_sec": round(duration_sec, 1),
        })

    # Rank exclusively by validation loss (ascending: lower is better)
    results.sort(key=lambda x: x["best_val_loss"])
    return results


def write_tuning_table(results: List[Dict[str, Any]], logger: logging.Logger):
    """Writes data/diagnostics/tuning_table.md and .csv."""
    diagnostics_dir = os.path.join(BASE_DIR, "data", "diagnostics")
    os.makedirs(diagnostics_dir, exist_ok=True)

    csv_path = os.path.join(diagnostics_dir, "tuning_table.csv")
    md_path = os.path.join(diagnostics_dir, "tuning_table.md")

    if not results:
        logger.warning("No tuning results available to write table.")
        return

    winner = results[0]
    logger.info(f"\n=======================================================")
    logger.info(f" TUNING RESULTS (Ranked strictly by Validation Loss)")
    logger.info(f" WINNER: {winner['run_id']} ({winner['name']}) with Best Val Loss: {winner['best_val_loss']}")
    logger.info(f"=======================================================")

    # Write CSV
    fieldnames = [
        "run_id", "what_changed", "best_val_acc", "best_val_loss",
        "final_train_acc", "train_val_gap", "time"
    ]
    with open(csv_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(results)
    logger.info(f"Saved CSV table to: {csv_path}")

    # Write Markdown
    rows = []
    for rank, r in enumerate(results, 1):
        is_winner = "🏆 **WINNER**" if rank == 1 else f"#{rank}"
        rows.append(
            f"| {is_winner} | **{r['run_id']}** | {r['what_changed']} | **{r['best_val_loss']:.4f}** | {r['best_val_acc'] * 100:.2f}% | {r['final_train_acc'] * 100:.2f}% | {r['train_val_gap']:.4f} | {r['time']} |"
        )
    table_rows_str = "\n".join(rows)

    md_content = f"""# Hyperparameter Tuning Summary: EfficientNetB3

> [!NOTE]
> **Evaluation Constraint**: Runs are ranked strictly on **Validation Loss** and **Validation Accuracy** on the validation partition. Test split data and external evaluation sets are never used for model selection.

---

## Ranked Tuning Table

| Rank | Run ID | What Changed | Best Val Loss | Best Val Acc | Final Train Acc | Train-Val Gap | Time |
| :---: | :---: | :--- | :---: | :---: | :---: | :---: | :---: |
{table_rows_str}

---

## Winner Selection

- **Winning Run**: **{winner['run_id']} ({winner['name']})**
- **Selected Criterion**: Lowest Validation Loss = **{winner['best_val_loss']:.4f}** (Best Val Accuracy = **{winner['best_val_acc'] * 100:.2f}%**)
- **Configuration**: {winner['what_changed']}
"""
    with open(md_path, "w", encoding="utf-8") as f:
        f.write(md_content)
    logger.info(f"Saved Markdown table to: {md_path}")


def main():
    parser = argparse.ArgumentParser(description="Hyperparameter tuning batch runner")
    parser.add_argument("--smoke", action="store_true", help="Run 1-epoch smoke test of T1 and report time estimate")
    parser.add_argument("--all", action="store_true", help="Execute all tuning configs in batch")
    parser.add_argument("--run", type=str, choices=["T1", "T2", "T3", "T4"], help="Execute a specific config only")
    parser.add_argument("--table-only", action="store_true", help="Generate tuning table from existing completed experiments")
    parser.add_argument("--log-file", type=str, default=DEFAULT_LOG_PATH, help="Path to log file")
    args = parser.parse_args()

    logger = setup_logger(args.log_file)

    if args.smoke:
        run_smoke_test(logger)
        return

    if args.table_only:
        results = collect_tuning_results(logger)
        write_tuning_table(results, logger)
        return

    configs_to_run = CONFIGS
    if args.run:
        configs_to_run = [c for c in CONFIGS if c["id"] == args.run]

    logger.info("=======================================================")
    logger.info(f" Starting Hyperparameter Tuning Batch ({len(configs_to_run)} configs)")
    logger.info("=======================================================")

    for cfg in configs_to_run:
        success = execute_config(cfg, logger)
        if not success:
            logger.warning(f"Experiment {cfg['id']} did not complete successfully; continuing to next config.")

    # Generate summary table and reports
    results = collect_tuning_results(logger)
    write_tuning_table(results, logger)


if __name__ == "__main__":
    main()
