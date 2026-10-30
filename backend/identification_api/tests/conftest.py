import os
import shutil
import pytest
from filelock import FileLock

REAL_BASE_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
REAL_DATA_DIR = os.path.join(REAL_BASE_DIR, "data")


@pytest.fixture(autouse=True)
def isolate_test_data(tmp_path, monkeypatch):
    """
    Autouse fixture that isolates all filesystem mutations during test execution.
    Redirects all data directories, image paths, metadata indexes, and locks to an
    ephemeral tmp_path, preventing any test from polluting production data.
    """
    # 1. Prepare temporary data structure
    tmp_data = tmp_path / "data"
    tmp_raw = tmp_data / "images" / "raw"
    tmp_proc = tmp_data / "images" / "processed"
    tmp_raw.mkdir(parents=True, exist_ok=True)
    tmp_proc.mkdir(parents=True, exist_ok=True)

    # 2. Seed metadata files from real data (read-only copy) if present
    for fname in [
        "labels.json",
        "image_hashes.json",
        "training_state.json",
        "training_state_ripeness.json",
        "raw_index.json",
        "pinned_versions.json",
        "sync_status.json",
    ]:
        src = os.path.join(REAL_DATA_DIR, fname)
        dst = str(tmp_data / fname)
        if os.path.exists(src):
            shutil.copy2(src, dst)

    src_diag = os.path.join(REAL_DATA_DIR, "diagnostics")
    if os.path.isdir(src_diag):
        shutil.copytree(src_diag, str(tmp_data / "diagnostics"), dirs_exist_ok=True)

    tmp_data_str = str(tmp_data)
    tmp_raw_str = str(tmp_raw)
    tmp_proc_str = str(tmp_proc)

    labels_json_str = str(tmp_data / "labels.json")
    labels_lock_str = str(tmp_data / ".labels.lock")
    hashes_json_str = str(tmp_data / "image_hashes.json")
    state_json_str = str(tmp_data / "training_state.json")
    state_rip_str = str(tmp_data / "training_state_ripeness.json")
    raw_idx_str = str(tmp_data / "raw_index.json")
    pipe_lock_str = str(tmp_data / ".pipeline.lock")
    sync_status_str = str(tmp_data / "sync_status.json")
    sync_log_str = str(tmp_data / "sync.log")

    # 3. Patch app.ml.dataset
    import app.ml.dataset as dataset_mod
    monkeypatch.setattr(dataset_mod, "DATA_DIR", tmp_data_str)
    monkeypatch.setattr(dataset_mod, "IMAGES_RAW_DIR", tmp_raw_str)
    monkeypatch.setattr(dataset_mod, "IMAGES_PROCESSED_DIR", tmp_proc_str)
    monkeypatch.setattr(dataset_mod, "HASH_INDEX_PATH", hashes_json_str)
    monkeypatch.setattr(dataset_mod, "STATE_PATH", state_json_str)
    monkeypatch.setattr(dataset_mod, "STATE_RIPENESS_PATH", state_rip_str)
    monkeypatch.setattr(dataset_mod, "PIPELINE_LOCK_PATH", pipe_lock_str)
    monkeypatch.setattr(dataset_mod, "_pipeline_lock", FileLock(pipe_lock_str, timeout=60.0))
    monkeypatch.setattr(dataset_mod, "get_pipeline_lock", lambda: FileLock(pipe_lock_str, timeout=60.0))

    # 4. Patch app.ml.labels
    import app.ml.labels as labels_mod
    monkeypatch.setattr(labels_mod, "DATA_DIR", tmp_data_str)
    monkeypatch.setattr(labels_mod, "IMAGES_RAW_DIR", tmp_raw_str)
    monkeypatch.setattr(labels_mod, "IMAGES_PROCESSED_DIR", tmp_proc_str)
    monkeypatch.setattr(labels_mod, "LABELS_PATH", labels_json_str)
    monkeypatch.setattr(labels_mod, "LABELS_LOCK_PATH", labels_lock_str)
    monkeypatch.setattr(labels_mod, "RAW_INDEX_PATH", raw_idx_str)
    monkeypatch.setattr(labels_mod, "get_labels_lock", lambda: FileLock(labels_lock_str, timeout=60.0))

    # 5. Patch app.routers.dataset
    import app.routers.dataset as router_dataset_mod
    monkeypatch.setattr(router_dataset_mod, "DATA_DIR", tmp_data_str)
    monkeypatch.setattr(router_dataset_mod, "IMAGES_PROCESSED_DIR", tmp_proc_str)
    monkeypatch.setattr(router_dataset_mod, "SYNC_STATUS_PATH", sync_status_str)
    monkeypatch.setattr(router_dataset_mod, "SYNC_LOG_PATH", sync_log_str)

    # 6. Patch app.ml.registry
    import app.ml.registry as registry_mod
    monkeypatch.setattr(registry_mod, "DATA_DIR", tmp_data_str)
    monkeypatch.setattr(registry_mod, "TRAINING_STATE_PATH", state_json_str)
    monkeypatch.setattr(registry_mod, "TRAINING_STATE_RIPENESS_PATH", state_rip_str)

    # 7. Patch app.ml.trainer
    import app.ml.trainer as trainer_mod
    monkeypatch.setattr(trainer_mod, "IMAGES_PROCESSED_DIR", tmp_proc_str)

    # 8. Patch auxiliary modules if loaded or needed
    try:
        import app.ml.sync_raw as sync_raw_mod
        monkeypatch.setattr(sync_raw_mod, "DATA_DIR", tmp_data_str)
        monkeypatch.setattr(sync_raw_mod, "IMAGES_RAW_DIR", tmp_raw_str)
        monkeypatch.setattr(sync_raw_mod, "IMAGES_PROCESSED_DIR", tmp_proc_str)
        monkeypatch.setattr(sync_raw_mod, "RAW_INDEX_PATH", raw_idx_str)
        monkeypatch.setattr(sync_raw_mod, "HASH_INDEX_PATH", hashes_json_str)
        monkeypatch.setattr(sync_raw_mod, "STATE_PATH", state_json_str)
        monkeypatch.setattr(sync_raw_mod, "PIPELINE_LOCK_PATH", pipe_lock_str)
    except Exception:
        pass

    try:
        import app.ml.groups as groups_mod
        monkeypatch.setattr(groups_mod, "DATA_DIR", tmp_data_str)
        monkeypatch.setattr(groups_mod, "RAW_DIR", tmp_raw_str)
        monkeypatch.setattr(groups_mod, "PROCESSED_DIR", tmp_proc_str)
    except Exception:
        pass

    try:
        import app.ml.prepare_size as prepare_size_mod
        monkeypatch.setattr(prepare_size_mod, "DATA_DIR", tmp_data_str)
        monkeypatch.setattr(prepare_size_mod, "IMAGES_RAW_DIR", tmp_raw_str)
        monkeypatch.setattr(prepare_size_mod, "RAW_INDEX_PATH", raw_idx_str)
    except Exception:
        pass

    try:
        import app.ml.leakage_audit as leakage_mod
        monkeypatch.setattr(leakage_mod, "DATA_DIR", tmp_data_str)
        monkeypatch.setattr(leakage_mod, "PROCESSED_DIR", tmp_proc_str)
    except Exception:
        pass

    try:
        import app.ml.ripeness_presort as ripeness_presort_mod
        monkeypatch.setattr(ripeness_presort_mod, "DATA_DIR", tmp_data_str)
        monkeypatch.setattr(ripeness_presort_mod, "PROCESSED_DIR", tmp_proc_str)
    except Exception:
        pass

    # 9. Redirect current working directory to tmp_path so relative "data" paths resolve to tmp_path/data
    monkeypatch.chdir(tmp_path)
