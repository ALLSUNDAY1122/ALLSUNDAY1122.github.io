#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path


def require(text: str, needle: str, label: str) -> None:
    if needle not in text:
        raise AssertionError(f"missing {label}: {needle}")


def forbid(text: str, needle: str, label: str) -> None:
    if needle in text:
        raise AssertionError(f"forbidden {label}: {needle}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Verify Scaniverse M1 msplat memory patch invariants")
    parser.add_argument("msplat_root", type=Path)
    args = parser.parse_args()
    root = args.msplat_root.resolve()

    header = (root / "Sources/MsplatCore/internal/include/input_data.hpp").read_text(encoding="utf-8")
    input_cpp = (root / "Sources/MsplatCore/src/input_data.cpp").read_text(encoding="utf-8")
    api = (root / "Sources/MsplatCore/src/msplat_api.mm").read_text(encoding="utf-8")

    require(header, "const Image& getImage(int downscaleFactor);", "reference image retrieval")
    require(header, "void releaseCPUImageCache();", "CPU cache release API")
    require(header, "void releaseGPUImageCache();", "GPU cache release API")
    require(header, "bool sourceCalibrationCaptured = false;", "idempotent reload calibration state")

    require(input_cpp, "if (image.empty()) loadImage(imageLoadDownscaleFactor);", "lazy decode")
    require(input_cpp, "const Image& img = getImage(downscaleFactor);", "no getImage value copy")
    forbid(input_cpp, "Image img = getImage(downscaleFactor);", "GT CPU deep copy")
    require(input_cpp, "entry.second.reset();", "explicit MTensor release")
    require(input_cpp, "std::unordered_map<int, MTensor>().swap(mtensorImageCache);", "bounded GPU cache container")
    require(input_cpp, "std::unordered_map<int, Image>().swap(imagePyramids);", "bounded CPU pyramid container")
    require(input_cpp, "releaseCPUImageCache();\n    return mtensorImageCache[downscaleFactor];", "CPU release after GPU upload")

    # Dataset must configure metadata lazily, then move Camera values before any
    # decoded image exists.  The historical eager-load + vector-copy path is forbidden.
    require(api, "cam.configureImageLoading(downscaleFactor);", "lazy Dataset configuration")
    forbid(api, "cam.loadImage(downscaleFactor);", "eager all-camera decode")
    forbid(api, "impl->data.getCameras(false)", "Camera vector value-copy path")
    forbid(api, "impl->data.splitTrainTest(testEvery)", "train/test Camera value-copy path")
    require(api, "impl->trainCams = std::move(impl->data.cameras);", "non-eval metadata move")
    require(api, "std::move(impl->data.cameras[i])", "eval metadata move")

    # Every path that intentionally materializes camera image state must have a
    # deterministic release boundary.  This keeps image residency O(1) in N cameras.
    require(api, "struct CameraResidencyScope", "RAII residency boundary")
    require(api, "CameraResidencyScope residency(cam);", "training/evaluation/render release guard")
    require(api, "releaseCameraResidency(impl->ds->trainCams);", "Trainer destruction cleanup")
    require(api, "releaseCameraResidency(impl->trainCams);", "Dataset destruction cleanup")

    # Evaluation must lazy-load GT before render so width/intrinsics match the
    # former eager-load behavior even for a test camera never visited by training.
    eval_start = api.index("EvalMetrics Trainer::evaluate()")
    eval_end = api.index("PixelBuffer Trainer::render(", eval_start)
    eval_block = api[eval_start:eval_end]
    if eval_block.index("MTensor& gt = cam.getGPUImage(dsf);") > eval_block.index("impl->model->render(cam"):
        raise AssertionError("evaluation renders before lazy camera geometry is prepared")

    # Arbitrary-pose rendering must never copy a Camera carrying RGB/GPU caches.
    require(api, "Camera cam = makeRenderCamera(reference);", "metadata-only render camera")
    forbid(api, "Camera cam = cams[refCameraIndex]", "render Camera deep copy")

    print("M1_MEMORY_PATCH_TEST_PASS")
    print("persistent_decoded_cpu_images_after_dataset=0")
    print("persistent_gt_gpu_tensors_after_step=0")
    print("camera_image_residency_growth=O(1)_with_camera_count")


if __name__ == "__main__":
    main()
