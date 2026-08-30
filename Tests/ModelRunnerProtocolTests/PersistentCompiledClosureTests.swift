import Testing

@testable import MLX

#if DEBUG
  @Suite("Persistent MLX compiled closures", .serialized)
  struct PersistentCompiledClosureTests {
    @Test("The persistent stateless path is disabled by default")
    func defaultOffUsesTransientCompile() {
      setPersistentCompiledClosuresEnabled(false)
      defer { setPersistentCompiledClosuresEnabled(false) }

      let function = CompiledFunction(inputs: [], outputs: [], shapeless: false) { inputs in
        [inputs[0] * 2 + 1]
      }
      let output = function.call([MLXArray([Float(1), 2, 3])])[0]
      eval(output)

      #expect(!persistentCompiledClosuresEnabled())
      #expect(!function.hasPersistentCompiledClosureForTesting)
      #expect(output.asArray(Float.self) == [3, 5, 7])
    }

    @Test("An enabled stateless function reuses one persistent handle")
    func enabledStatelessFunctionReusesHandle() throws {
      setPersistentCompiledClosuresEnabled(true)
      defer { setPersistentCompiledClosuresEnabled(false) }

      let function = CompiledFunction(inputs: [], outputs: [], shapeless: false) { inputs in
        [inputs[0].square() + 3]
      }

      let first = function.call([MLXArray([Float(1), 2, 3])])[0]
      eval(first)
      let firstIdentity = try #require(function.persistentCompiledClosureIdentityForTesting)

      let second = function.call([MLXArray([Float(4), 5])])[0]
      eval(second)
      let secondIdentity = try #require(function.persistentCompiledClosureIdentityForTesting)

      #expect(function.hasPersistentCompiledClosureForTesting)
      #expect(firstIdentity == secondIdentity)
      #expect(first.asArray(Float.self) == [4, 7, 12])
      #expect(second.asArray(Float.self) == [19, 28])
    }

    @Test("Observed state always keeps the existing transient path")
    func statefulFunctionStaysTransient() {
      setPersistentCompiledClosuresEnabled(true)
      defer { setPersistentCompiledClosuresEnabled(false) }

      let observedState = MLXArray(Float(2))
      let function = CompiledFunction(
        inputs: [observedState], outputs: [], shapeless: false
      ) { inputs in
        [inputs[0] * 3 + observedState]
      }
      let output = function.call([MLXArray([Float(1), 2, 3])])[0]
      eval(output)

      #expect(!function.hasPersistentCompiledClosureForTesting)
      #expect(function.persistentCompiledClosureIdentityForTesting == nil)
      #expect(output.asArray(Float.self) == [5, 8, 11])
    }

    @Test("Releasing the function tears down its persistent closure graph")
    func persistentHandleDoesNotCreateOwnerCycle() {
      setPersistentCompiledClosuresEnabled(true)
      defer { setPersistentCompiledClosuresEnabled(false) }

      weak var releasedFunction: CompiledFunction?
      weak var releasedProbe: LifetimeProbe?

      do {
        let probe = LifetimeProbe()
        let function = CompiledFunction(
          inputs: [], outputs: [], shapeless: false
        ) { [probe] inputs in
          _ = probe
          return [inputs[0] + 1]
        }
        releasedFunction = function
        releasedProbe = probe

        let output = function.call([MLXArray(Float(41))])[0]
        eval(output)
        #expect(output.item(Float.self) == 42)
        #expect(function.hasPersistentCompiledClosureForTesting)
      }

      #expect(releasedFunction == nil)
      #expect(releasedProbe == nil)
    }
  }

  private final class LifetimeProbe {}
#endif
