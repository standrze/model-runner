import MLX
import Testing

@Suite("Metal command-encoder cache", .serialized)
struct MetalCommandEncoderCacheTests {
  @Test("Toggle preserves real MLX evaluation and can precede stream cleanup")
  func toggleAroundEvaluation() {
    setMetalCommandEncoderCacheEnabled(false)
    defer { setMetalCommandEncoderCacheEnabled(false) }

    #if canImport(Metal)
      exerciseToggleAroundEvaluation(device: .gpu)
    #else
      exerciseToggleAroundEvaluation(device: .cpu)
    #endif

    // clearStreams() is currently exposed by this package only on Linux. It is
    // terminal cleanup there, so keep it after the final real evaluation.
    #if os(Linux)
      clearStreams()
    #endif
  }

  private func exerciseToggleAroundEvaluation(device: Device) {
    let stream = Stream(device)
    let streamOrDevice = StreamOrDevice.stream(stream)
    #expect(!metalCommandEncoderCacheEnabled())
    let input = MLXArray([Float(1), 2, 3, 4])
    let cacheOff = add(multiply(input, 3, stream: streamOrDevice), 1, stream: streamOrDevice)
    eval(cacheOff)
    #expect(cacheOff.asArray(Float.self) == [4, 7, 10, 13])

    setMetalCommandEncoderCacheEnabled(true)
    #if canImport(Metal)
      #expect(metalCommandEncoderCacheEnabled())
    #else
      #expect(!metalCommandEncoderCacheEnabled())
    #endif

    let cacheOn = add(multiply(input, 3, stream: streamOrDevice), 1, stream: streamOrDevice)
    eval(cacheOn)
    #expect(cacheOn.asArray(Float.self) == cacheOff.asArray(Float.self))

    setMetalCommandEncoderCacheEnabled(false)
    #expect(!metalCommandEncoderCacheEnabled())
  }
}
