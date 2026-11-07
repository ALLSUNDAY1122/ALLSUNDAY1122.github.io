#!/usr/bin/env python3
from __future__ import annotations

import argparse
from pathlib import Path

PINNED_REVISION = "d620d9c58d270e7de9e34a9d8a85dcf938a5070d"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise RuntimeError(f"{label}: expected exactly one source match, found {count}")
    return text.replace(old, new, 1)


def patch_input_header(root: Path) -> None:
    path = root / "Sources/MsplatCore/internal/include/input_data.hpp"
    text = path.read_text(encoding="utf-8")
    old = '''    Image image;
    std::unordered_map<int, Image> imagePyramids;
    std::unordered_map<int, MTensor> mtensorImageCache;
    MTensor cachedViewMat, cachedProjViewMat;
    float cachedCamPos[3] = {};
    float cachedFovX = 0, cachedFovY = 0;

    void loadImage(float downscaleFactor);
    Image getImage(int downscaleFactor);
    MTensor& getGPUImage(int downscaleFactor);
    bool hasDistortion() const { return k1 != 0 || k2 != 0 || k3 != 0 || p1 != 0 || p2 != 0; }
'''
    new = '''    Image image;
    std::unordered_map<int, Image> imagePyramids;
    std::unordered_map<int, MTensor> mtensorImageCache;
    MTensor cachedViewMat, cachedProjViewMat;
    float cachedCamPos[3] = {};
    float cachedFovX = 0, cachedFovY = 0;

    // M1 residency policy: retain only camera metadata between steps.  The
    // source calibration is captured once so decoded images can be released
    // and reloaded without repeatedly scaling intrinsics or zeroing distortion.
    float imageLoadDownscaleFactor = 1.0f;
    bool sourceCalibrationCaptured = false;
    bool geometryPrepared = false;
    int sourceWidth = 0, sourceHeight = 0;
    float sourceFx = 0, sourceFy = 0, sourceCx = 0, sourceCy = 0;
    float sourceK1 = 0, sourceK2 = 0, sourceK3 = 0, sourceP1 = 0, sourceP2 = 0;

    void configureImageLoading(float downscaleFactor);
    void loadImage(float downscaleFactor);
    const Image& getImage(int downscaleFactor);
    MTensor& getGPUImage(int downscaleFactor);
    void releaseCPUImageCache();
    void releaseGPUImageCache();
    void releaseImageCaches();
    bool hasDistortion() const { return k1 != 0 || k2 != 0 || k3 != 0 || p1 != 0 || p2 != 0; }
'''
    path.write_text(replace_once(text, old, new, "input_data.hpp Camera residency API"), encoding="utf-8")


def patch_input_cpp(root: Path) -> None:
    path = root / "Sources/MsplatCore/src/input_data.cpp"
    text = path.read_text(encoding="utf-8")
    start_marker = "// ── Image loading ───────────────────────────────────────────────────────────\n"
    end_marker = "// ── Scale & center ──────────────────────────────────────────────────────────\n"
    start = text.find(start_marker)
    end = text.find(end_marker)
    if start < 0 or end < 0 or end <= start:
        raise RuntimeError("input_data.cpp: image-loading section markers not found")

    replacement = '''// ── Image loading ───────────────────────────────────────────────────────────

void Camera::configureImageLoading(float downscaleFactor) {
    imageLoadDownscaleFactor = std::max(1.0f, downscaleFactor);
    if (sourceCalibrationCaptured) return;

    sourceWidth = width;
    sourceHeight = height;
    sourceFx = fx; sourceFy = fy;
    sourceCx = cx; sourceCy = cy;
    sourceK1 = k1; sourceK2 = k2; sourceK3 = k3;
    sourceP1 = p1; sourceP2 = p2;
    sourceCalibrationCaptured = true;
}

void Camera::loadImage(float downscaleFactor) {
    configureImageLoading(downscaleFactor);

    // Always restart from loader-provided calibration.  This makes lazy
    // decode/release/reload idempotent across repeated visits to one camera.
    width = sourceWidth;
    height = sourceHeight;
    fx = sourceFx; fy = sourceFy;
    cx = sourceCx; cy = sourceCy;
    k1 = sourceK1; k2 = sourceK2; k3 = sourceK3;
    p1 = sourceP1; p2 = sourceP2;

    Image raw = imreadRGB(filePath);
    if (raw.empty()) return;

    // If actual image dimensions differ from metadata, rescale intrinsics.
    if (width > 0 && height > 0 && (raw.width != width || raw.height != height)) {
        float sx = (float)raw.width / (float)width;
        float sy = (float)raw.height / (float)height;
        fx *= sx; fy *= sy; cx *= sx; cy *= sy;
        width = raw.width; height = raw.height;
    } else if (width == 0 || height == 0) {
        width = raw.width; height = raw.height;
    }

    // Preserve the configured dataset downscale exactly; M1 never changes the
    // quality contract, it only changes when image memory is resident.
    if (imageLoadDownscaleFactor > 1.0f) {
        int newW = (int)(width / imageLoadDownscaleFactor);
        int newH = (int)(height / imageLoadDownscaleFactor);
        raw = resizeArea(raw, newW, newH);
        float s = 1.0f / imageLoadDownscaleFactor;
        fx *= s; fy *= s; cx *= s; cy *= s;
        width = newW; height = newH;
    }

    // Undistort if needed.  sourceK* / sourceP* remain unchanged so a later
    // lazy reload performs the same transform instead of accumulating edits.
    if (hasDistortion()) {
        auto result = undistortImage(raw, fx, fy, cx, cy, k1, k2, p1, p2, k3);
        raw = std::move(result.image);
        fx = result.fx; fy = result.fy;
        cx = result.cx; cy = result.cy;
        width = result.width; height = result.height;
        k1 = k2 = k3 = p1 = p2 = 0;
    }

    geometryPrepared = true;
    image = std::move(raw);
}

const Image& Camera::getImage(int downscaleFactor) {
    if (image.empty()) loadImage(imageLoadDownscaleFactor);
    if (downscaleFactor <= 1 || image.empty()) return image;

    auto it = imagePyramids.find(downscaleFactor);
    if (it != imagePyramids.end()) return it->second;

    int newW = image.width / downscaleFactor;
    int newH = image.height / downscaleFactor;
    Image scaled = resizeArea(image, newW, newH);
    auto inserted = imagePyramids.emplace(downscaleFactor, std::move(scaled));
    return inserted.first->second;
}

void Camera::releaseCPUImageCache() {
    image = Image{};
    std::unordered_map<int, Image>().swap(imagePyramids);
}

void Camera::releaseGPUImageCache() {
    for (auto& entry : mtensorImageCache)
        entry.second.reset();
    std::unordered_map<int, MTensor>().swap(mtensorImageCache);
}

void Camera::releaseImageCaches() {
    releaseGPUImageCache();
    releaseCPUImageCache();
}

MTensor& Camera::getGPUImage(int downscaleFactor) {
    auto it = mtensorImageCache.find(downscaleFactor);
    if (it != mtensorImageCache.end()) return it->second;

    // Never retain one GT tensor for every camera/downscale.  At most the
    // currently requested GT tensor remains owned by Camera until the caller's
    // residency scope ends.
    releaseGPUImageCache();
    const Image& img = getImage(downscaleFactor);
    if (img.empty())
        throw std::runtime_error("Failed to load camera image: " + filePath);

    MTensor mt = gpu_empty({img.height, img.width, 3}, DType::Float32);
    memcpy(mt.data_ptr(), img.ptr(), img.width * img.height * 3 * sizeof(float));
    mtensorImageCache[downscaleFactor] = mt;

    // GPU upload is complete from the CPU point of view; drop decoded float32
    // RGB and pyramid buffers immediately instead of retaining N-camera copies.
    releaseCPUImageCache();
    return mtensorImageCache[downscaleFactor];
}

'''
    path.write_text(text[:start] + replacement + text[end:], encoding="utf-8")


def patch_api(root: Path) -> None:
    path = root / "Sources/MsplatCore/src/msplat_api.mm"
    text = path.read_text(encoding="utf-8")

    old_dataset = '''struct Dataset::Impl {
    InputData data;
    std::vector<Camera> trainCams;
    std::vector<Camera> testCams;
};

Dataset::Dataset(const std::string& path, float downscaleFactor,
                 bool evalMode, int testEvery)
    : impl(std::make_unique<Impl>())
{
    impl->data = inputDataFromX(path);

    for (auto& cam : impl->data.cameras)
        cam.loadImage(downscaleFactor);

    if (evalMode) {
        auto split = impl->data.splitTrainTest(testEvery);
        impl->trainCams = std::get<0>(split);
        impl->testCams = std::get<1>(split);
    } else {
        auto t = impl->data.getCameras(false);
        impl->trainCams = std::get<0>(t);
    }
}

Dataset::~Dataset() = default;
'''
    new_dataset = '''struct Dataset::Impl {
    InputData data;
    std::vector<Camera> trainCams;
    std::vector<Camera> testCams;
};

namespace {

void releaseCameraResidency(std::vector<Camera>& cameras) {
    for (auto& camera : cameras)
        camera.releaseImageCaches();
}

struct CameraResidencyScope {
    explicit CameraResidencyScope(Camera& camera) : camera(camera) {}
    ~CameraResidencyScope() { camera.releaseImageCaches(); }
    Camera& camera;
};

void prepareCameraGeometry(Camera& camera) {
    if (!camera.geometryPrepared)
        (void)camera.getImage(1);
}

Camera makeRenderCamera(const Camera& source) {
    Camera camera;
    camera.width = source.width;
    camera.height = source.height;
    camera.fx = source.fx; camera.fy = source.fy;
    camera.cx = source.cx; camera.cy = source.cy;
    camera.k1 = source.k1; camera.k2 = source.k2; camera.k3 = source.k3;
    camera.p1 = source.p1; camera.p2 = source.p2;
    memcpy(camera.camToWorld, source.camToWorld, sizeof(camera.camToWorld));
    camera.filePath = source.filePath;
    camera.geometryPrepared = true;
    return camera;
}

} // namespace

Dataset::Dataset(const std::string& path, float downscaleFactor,
                 bool evalMode, int testEvery)
    : impl(std::make_unique<Impl>())
{
    impl->data = inputDataFromX(path);

    // Capture the exact dataset image policy without decoding every RGB frame.
    for (auto& cam : impl->data.cameras)
        cam.configureImageLoading(downscaleFactor);

    // Move metadata-only Camera objects instead of copying a vector that may
    // later contain multi-megabyte image/cache payloads.
    if (evalMode) {
        impl->trainCams.reserve(impl->data.cameras.size());
        impl->testCams.reserve(impl->data.cameras.size() / std::max(testEvery, 1) + 1);
        for (int i = 0; i < (int)impl->data.cameras.size(); ++i) {
            if (testEvery > 0 && i % testEvery == 0)
                impl->testCams.emplace_back(std::move(impl->data.cameras[i]));
            else
                impl->trainCams.emplace_back(std::move(impl->data.cameras[i]));
        }
        impl->data.cameras.clear();
        impl->data.cameras.shrink_to_fit();
    } else {
        impl->trainCams = std::move(impl->data.cameras);
    }
}

Dataset::~Dataset() {
    if (!impl) return;
    releaseCameraResidency(impl->trainCams);
    releaseCameraResidency(impl->testCams);
    releaseCameraResidency(impl->data.cameras);
}
'''
    text = replace_once(text, old_dataset, new_dataset, "msplat_api.mm Dataset construction")

    text = replace_once(
        text,
        "Trainer::~Trainer() = default;\n",
        '''Trainer::~Trainer() {
    if (!impl || !impl->ds) return;
    releaseCameraResidency(impl->ds->trainCams);
    releaseCameraResidency(impl->ds->testCams);
}
''',
        "msplat_api.mm Trainer destructor",
    )

    old_step = '''Stats Trainer::step() {
    impl->currentStep++;
    size_t camIdx = impl->nextCamera();
    Camera& cam = impl->ds->trainCams[camIdx];

    int ds = impl->model->getDownscaleFactor(impl->currentStep);
    MTensor& gt = cam.getGPUImage(ds);

    auto t0 = std::chrono::high_resolution_clock::now();

    impl->model->fullIteration(cam, impl->currentStep, gt, impl->config.ssimWeight);
    impl->model->schedulersStep(impl->currentStep);
    impl->model->afterTrain(impl->currentStep);
    msplat_commit();

    auto t1 = std::chrono::high_resolution_clock::now();
    float ms = std::chrono::duration_cast<std::chrono::microseconds>(t1 - t0).count() / 1000.0f;

    Stats s;
    s.iteration = impl->currentStep;
    s.splatCount = (int)impl->model->means.size(0);
    s.msPerStep = ms;
    return s;
}
'''
    new_step = '''Stats Trainer::step() {
    impl->currentStep++;
    size_t camIdx = impl->nextCamera();
    Camera& cam = impl->ds->trainCams[camIdx];
    CameraResidencyScope residency(cam);

    int ds = impl->model->getDownscaleFactor(impl->currentStep);
    MTensor& gt = cam.getGPUImage(ds);

    auto t0 = std::chrono::high_resolution_clock::now();

    impl->model->fullIteration(cam, impl->currentStep, gt, impl->config.ssimWeight);
    impl->model->schedulersStep(impl->currentStep);
    impl->model->afterTrain(impl->currentStep);
    msplat_commit();

    auto t1 = std::chrono::high_resolution_clock::now();
    float ms = std::chrono::duration_cast<std::chrono::microseconds>(t1 - t0).count() / 1000.0f;

    Stats s;
    s.iteration = impl->currentStep;
    s.splatCount = (int)impl->model->means.size(0);
    s.msPerStep = ms;
    return s;
}
'''
    text = replace_once(text, old_step, new_step, "msplat_api.mm Trainer::step")

    old_evaluate = '''EvalMetrics Trainer::evaluate() {
    auto& testCams = impl->ds->testCams;
    if (testCams.empty())
        return {};

    double sumPsnr = 0, sumSsim = 0, sumL1 = 0;
    int n = (int)testCams.size();

    for (int i = 0; i < n; i++) {
        Camera& cam = testCams[i];
        MTensor rgb = impl->model->render(cam, impl->config.iterations);
        msplat_gpu_sync();
        MTensor rgbCpu = rgb.cpu();
        int dsf = impl->model->getDownscaleFactor(impl->config.iterations);
        MTensor gtCpu = cam.getGPUImage(dsf).cpu();

        sumPsnr += psnr(rgbCpu, gtCpu);
        sumSsim += ssim_eval(rgbCpu, gtCpu);
        sumL1 += l1_loss(rgbCpu, gtCpu);
    }

    EvalMetrics m;
    m.psnr = (float)(sumPsnr / n);
    m.ssim = (float)(sumSsim / n);
    m.l1 = (float)(sumL1 / n);
    m.numTest = n;
    m.numGaussians = (int)impl->model->means.size(0);
    return m;
}
'''
    new_evaluate = '''EvalMetrics Trainer::evaluate() {
    auto& testCams = impl->ds->testCams;
    if (testCams.empty())
        return {};

    double sumPsnr = 0, sumSsim = 0, sumL1 = 0;
    int n = (int)testCams.size();

    for (int i = 0; i < n; i++) {
        Camera& cam = testCams[i];
        CameraResidencyScope residency(cam);
        int dsf = impl->model->getDownscaleFactor(impl->config.iterations);

        // Load GT first so lazy decode finalizes the same calibrated geometry
        // that eager Dataset construction used before M1.
        MTensor& gt = cam.getGPUImage(dsf);
        MTensor rgb = impl->model->render(cam, impl->config.iterations);
        msplat_gpu_sync();
        MTensor rgbCpu = rgb.cpu();
        MTensor gtCpu = gt.cpu();

        sumPsnr += psnr(rgbCpu, gtCpu);
        sumSsim += ssim_eval(rgbCpu, gtCpu);
        sumL1 += l1_loss(rgbCpu, gtCpu);
    }

    EvalMetrics m;
    m.psnr = (float)(sumPsnr / n);
    m.ssim = (float)(sumSsim / n);
    m.l1 = (float)(sumL1 / n);
    m.numTest = n;
    m.numGaussians = (int)impl->model->means.size(0);
    return m;
}
'''
    text = replace_once(text, old_evaluate, new_evaluate, "msplat_api.mm Trainer::evaluate")

    old_render = '''PixelBuffer Trainer::render(int cameraIndex, bool useTest) {
    auto& cams = useTest ? impl->ds->testCams : impl->ds->trainCams;
    if (cameraIndex < 0 || cameraIndex >= (int)cams.size())
        return {};

    Camera& cam = cams[cameraIndex];
    MTensor rgb = impl->model->render(cam, impl->currentStep);
    msplat_gpu_sync();
    MTensor rgbCpu = rgb.cpu();

    int h = (int)rgbCpu.size(0);
    int w = (int)rgbCpu.size(1);
    // Use malloc so callers can free() — PixelBuffer destructor handles both
    float* buf = (float*)malloc(h * w * 3 * sizeof(float));
    memcpy(buf, rgbCpu.data_ptr(), h * w * 3 * sizeof(float));

    return PixelBuffer(buf, w, h);
}
'''
    new_render = '''PixelBuffer Trainer::render(int cameraIndex, bool useTest) {
    auto& cams = useTest ? impl->ds->testCams : impl->ds->trainCams;
    if (cameraIndex < 0 || cameraIndex >= (int)cams.size())
        return {};

    Camera& cam = cams[cameraIndex];
    CameraResidencyScope residency(cam);
    prepareCameraGeometry(cam);
    MTensor rgb = impl->model->render(cam, impl->currentStep);
    msplat_gpu_sync();
    MTensor rgbCpu = rgb.cpu();

    int h = (int)rgbCpu.size(0);
    int w = (int)rgbCpu.size(1);
    // Use malloc so callers can free() — PixelBuffer destructor handles both
    float* buf = (float*)malloc(h * w * 3 * sizeof(float));
    memcpy(buf, rgbCpu.data_ptr(), h * w * 3 * sizeof(float));

    return PixelBuffer(buf, w, h);
}
'''
    text = replace_once(text, old_render, new_render, "msplat_api.mm Trainer::render")

    old_render_pose = '''PixelBuffer Trainer::renderFromPose(const float camToWorld[16], int refCameraIndex) {
    auto& cams = impl->ds->trainCams;
    if (refCameraIndex < 0 || refCameraIndex >= (int)cams.size())
        return {};

    Camera cam = cams[refCameraIndex];  // copy intrinsics
    memcpy(cam.camToWorld, camToWorld, 16 * sizeof(float));
    // Invalidate cached matrices so prepareCam recomputes from the new pose
    cam.cachedViewMat = MTensor();
    cam.cachedProjViewMat = MTensor();

    MTensor rgb = impl->model->render(cam, impl->currentStep);
    msplat_gpu_sync();
    MTensor rgbCpu = rgb.cpu();

    int h = (int)rgbCpu.size(0);
    int w = (int)rgbCpu.size(1);
    float* buf = (float*)malloc(h * w * 3 * sizeof(float));
    memcpy(buf, rgbCpu.data_ptr(), h * w * 3 * sizeof(float));
    return PixelBuffer(buf, w, h);
}
'''
    new_render_pose = '''PixelBuffer Trainer::renderFromPose(const float camToWorld[16], int refCameraIndex) {
    auto& cams = impl->ds->trainCams;
    if (refCameraIndex < 0 || refCameraIndex >= (int)cams.size())
        return {};

    Camera& reference = cams[refCameraIndex];
    prepareCameraGeometry(reference);
    reference.releaseImageCaches();
    Camera cam = makeRenderCamera(reference);  // metadata only; never copy RGB/GPU caches
    memcpy(cam.camToWorld, camToWorld, 16 * sizeof(float));

    MTensor rgb = impl->model->render(cam, impl->currentStep);
    msplat_gpu_sync();
    MTensor rgbCpu = rgb.cpu();

    int h = (int)rgbCpu.size(0);
    int w = (int)rgbCpu.size(1);
    float* buf = (float*)malloc(h * w * 3 * sizeof(float));
    memcpy(buf, rgbCpu.data_ptr(), h * w * 3 * sizeof(float));
    return PixelBuffer(buf, w, h);
}
'''
    text = replace_once(text, old_render_pose, new_render_pose, "msplat_api.mm Trainer::renderFromPose")

    old_render_buffer = '''void Trainer::renderFromPoseToBuffer(const float camToWorld[16], int refCameraIndex,
                                  uint8_t* outRGBA, int* outWidth, int* outHeight) {
    auto& cams = impl->ds->trainCams;
    if (refCameraIndex < 0 || refCameraIndex >= (int)cams.size()) {
        *outWidth = 0; *outHeight = 0; return;
    }

    Camera cam = cams[refCameraIndex];
    memcpy(cam.camToWorld, camToWorld, 16 * sizeof(float));
    cam.cachedViewMat = MTensor();
    cam.cachedProjViewMat = MTensor();

    MTensor rgb = impl->model->render(cam, impl->currentStep);
    msplat_gpu_sync();

    int h = (int)rgb.size(0), w = (int)rgb.size(1);
    *outWidth = w;
    *outHeight = h;
    if (!outRGBA) return;

    // Read directly from GPU tensor (unified memory on Apple Silicon)
    const float* src = (const float*)rgb.data_ptr();
    int n = w * h;
    for (int i = 0; i < n; i++) {
        outRGBA[i * 4]     = (uint8_t)(fminf(fmaxf(src[i*3],   0.f), 1.f) * 255.f);
        outRGBA[i * 4 + 1] = (uint8_t)(fminf(fmaxf(src[i*3+1], 0.f), 1.f) * 255.f);
        outRGBA[i * 4 + 2] = (uint8_t)(fminf(fmaxf(src[i*3+2], 0.f), 1.f) * 255.f);
        outRGBA[i * 4 + 3] = 255;
    }
}
'''
    new_render_buffer = '''void Trainer::renderFromPoseToBuffer(const float camToWorld[16], int refCameraIndex,
                                  uint8_t* outRGBA, int* outWidth, int* outHeight) {
    auto& cams = impl->ds->trainCams;
    if (refCameraIndex < 0 || refCameraIndex >= (int)cams.size()) {
        *outWidth = 0; *outHeight = 0; return;
    }

    Camera& reference = cams[refCameraIndex];
    prepareCameraGeometry(reference);
    reference.releaseImageCaches();
    Camera cam = makeRenderCamera(reference);
    memcpy(cam.camToWorld, camToWorld, 16 * sizeof(float));

    MTensor rgb = impl->model->render(cam, impl->currentStep);
    msplat_gpu_sync();

    int h = (int)rgb.size(0), w = (int)rgb.size(1);
    *outWidth = w;
    *outHeight = h;
    if (!outRGBA) return;

    // Read directly from GPU tensor (unified memory on Apple Silicon)
    const float* src = (const float*)rgb.data_ptr();
    int n = w * h;
    for (int i = 0; i < n; i++) {
        outRGBA[i * 4]     = (uint8_t)(fminf(fmaxf(src[i*3],   0.f), 1.f) * 255.f);
        outRGBA[i * 4 + 1] = (uint8_t)(fminf(fmaxf(src[i*3+1], 0.f), 1.f) * 255.f);
        outRGBA[i * 4 + 2] = (uint8_t)(fminf(fmaxf(src[i*3+2], 0.f), 1.f) * 255.f);
        outRGBA[i * 4 + 3] = 255;
    }
}
'''
    text = replace_once(text, old_render_buffer, new_render_buffer, "msplat_api.mm Trainer::renderFromPoseToBuffer")

    path.write_text(text, encoding="utf-8")


def main() -> None:
    parser = argparse.ArgumentParser(description="Apply Scaniverse M1 memory residency patch to pinned msplat source")
    parser.add_argument("msplat_root", type=Path)
    args = parser.parse_args()
    root = args.msplat_root.resolve()
    if not (root / "Package.swift").is_file():
        raise SystemExit(f"not an msplat package root: {root}")

    patch_input_header(root)
    patch_input_cpp(root)
    patch_api(root)
    print(f"M1_PATCH_APPLIED revision={PINNED_REVISION} root={root}")


if __name__ == "__main__":
    main()
