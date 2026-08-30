import MLX

/// Enable or disable the experimental persistent compiled-closure fast path.
///
/// The MLX patch defaults this process-global switch to `false`; benchmarks
/// toggle it only around one complete generation so production behavior is
/// unchanged unless a caller explicitly opts in.
public func setModelRunnerPersistentCompiledClosuresEnabled(_ enabled: Bool) {
  setPersistentCompiledClosuresEnabled(enabled)
}

/// Return whether the experimental persistent compiled-closure path is enabled.
public func modelRunnerPersistentCompiledClosuresEnabled() -> Bool {
  persistentCompiledClosuresEnabled()
}

/// Synchronize and release MLX stream command encoders before process teardown.
///
/// Current MLX-CUDA requires explicit cleanup while the CUDA driver is still
/// alive. The Linux backport releases both the calling thread's encoders and
/// mlx-swift's cross-thread global encoders. Metal does not need this backport,
/// so the call is a no-op on Apple platforms.
public func clearModelRunnerMLXStreams() {
  #if os(Linux)
    clearStreams()
  #endif
}
