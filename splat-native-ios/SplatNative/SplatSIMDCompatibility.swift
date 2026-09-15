import simd

// Modern Swift/Xcode exposes simd matrix-vector multiplication directly.
// Do not redeclare the global `*` overload here: doing so collides with the
// standard-library/simd overloads used by both Splat and Mesh code.
