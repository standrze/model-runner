import Foundation
import MLX
import Testing

@testable import ModelRunnerCore

@Suite("Native Laguna model")
struct LagunaModelTests {
  @Test("Poolside's hybrid configuration decodes without Python metadata")
  func decodesHybridConfiguration() throws {
    let configuration = try decodeConfiguration()

    #expect(configuration.modelType == "laguna")
    #expect(configuration.layerTypes == ["full_attention", "sliding_attention"])
    #expect(configuration.mlpLayerTypes == ["dense", "sparse"])
    #expect(configuration.attentionHeadsPerLayer == [2, 4])
    #expect(configuration.gating == .perHead)
    #expect(
      configuration.ropeParameters?["full_attention"]?["rope_type"]
        == .string("yarn")
    )
  }

  @Test("Layer-specific configuration arrays must match the decoder depth")
  func rejectsMismatchedLayerMetadata() {
    let data = Data(
      """
      {
        "model_type": "laguna",
        "num_hidden_layers": 2,
        "layer_types": ["full_attention"],
        "mlp_layer_types": ["dense", "sparse"],
        "num_attention_heads_per_layer": [2, 4],
        "num_attention_heads": 2,
        "num_key_value_heads": 2,
        "head_dim": 4
      }
      """.utf8
    )

    #expect(throws: LagunaConfigurationError.self) {
      try JSONDecoder().decode(LagunaConfiguration.self, from: data)
    }
  }

  @Test("The local architecture is registered before model loading")
  func registersArchitecture() async {
    await LagunaModelRegistration.register()
    #expect(await LagunaModelRegistration.isRegistered())
  }

  @Test("MLX conversion prefixes match mixed-precision module paths")
  func normalizesLanguageModelPrefix() {
    #expect(
      LagunaModel.normalizedWeightKey(
        "language_model.model.norm.weight", tiedWordEmbeddings: false)
        == "language_model.model.norm.weight"
    )
    #expect(
      LagunaModel.normalizedWeightKey(
        "language_model.lm_head.weight", tiedWordEmbeddings: false)
        == "language_model.lm_head.weight"
    )
    #expect(
      LagunaModel.normalizedWeightKey(
        "model.norm.weight", tiedWordEmbeddings: false)
        == "language_model.model.norm.weight"
    )
    #expect(
      LagunaModel.normalizedWeightKey(
        "language_model.lm_head.weight", tiedWordEmbeddings: true) == nil
    )
  }

  @Test("Compiled MoE fusion preserves Laguna logits")
  func compiledMoEFusionPreservesLogits() throws {
    let configuration = try decodeConfiguration(
      numberOfExperts: 8,
      expertsPerToken: 8)
    let model = LagunaModel(configuration)
    let tokens = MLXArray([Int32(1), 2, 3])[.newAxis]

    let unfused = LagunaRuntimeTuning.$useCompiledMoEFusion.withValue(false) {
      model(tokens, cache: nil)
    }
    let fused = LagunaRuntimeTuning.$useCompiledMoEFusion.withValue(true) {
      model(tokens, cache: nil)
    }
    eval(unfused, fused)

    #expect(allClose(unfused, fused, rtol: 1e-2, atol: 1e-2).item(Bool.self))
  }

  @Test("Compiled per-head attention gate preserves Laguna logits")
  func compiledAttentionGatePreservesLogits() throws {
    let configuration = try decodeConfiguration()
    let model = LagunaModel(configuration)
    let tokens = MLXArray([Int32(1), 2, 3])[.newAxis]

    let eager = LagunaRuntimeTuning.$useCompiledAttentionGate.withValue(false) {
      model(tokens, cache: nil)
    }
    let compiled = LagunaRuntimeTuning.$useCompiledAttentionGate.withValue(true) {
      model(tokens, cache: nil)
    }
    eval(eager, compiled)

    #expect(allClose(eager, compiled, rtol: 1e-2, atol: 1e-2).item(Bool.self))
  }

  @Test("Compiled block tail is restricted to ordinary cached decode")
  func compiledBlockTailEligibilityIsDecodeOnly() {
    func allows(
      runtimeEnabled: Bool = true,
      capturesHiddenStates: Bool = false,
      batchSize: Int = 1,
      sequenceLength: Int = 1,
      cacheOffset: Int? = 3,
      useCompiledAttentionGate: Bool = true,
      useCompiledMoEFusion: Bool = true
    ) -> Bool {
      LagunaCompiledBlockTailEligibility.allows(
        runtimeEnabled: runtimeEnabled,
        capturesHiddenStates: capturesHiddenStates,
        batchSize: batchSize,
        sequenceLength: sequenceLength,
        cacheOffset: cacheOffset,
        useCompiledAttentionGate: useCompiledAttentionGate,
        useCompiledMoEFusion: useCompiledMoEFusion)
    }

    #expect(allows())
    #expect(!allows(runtimeEnabled: false))
    #expect(!allows(capturesHiddenStates: true))
    #expect(!allows(batchSize: 2))
    #expect(!allows(sequenceLength: 2))
    #expect(!allows(cacheOffset: nil))
    #expect(!allows(cacheOffset: 0))
    #expect(!allows(useCompiledAttentionGate: false))
    #expect(!allows(useCompiledMoEFusion: false))
  }

  @Test("Compiled attention prelude is restricted to ordinary cached decode")
  func compiledAttentionPreludeEligibilityIsDecodeOnly() {
    func allows(
      runtimeEnabled: Bool = true,
      capturesHiddenStates: Bool = false,
      batchSize: Int = 1,
      sequenceLength: Int = 1,
      cacheOffset: Int? = 3
    ) -> Bool {
      LagunaCompiledAttentionPreludeEligibility.allows(
        runtimeEnabled: runtimeEnabled,
        capturesHiddenStates: capturesHiddenStates,
        batchSize: batchSize,
        sequenceLength: sequenceLength,
        cacheOffset: cacheOffset)
    }

    #expect(allows())
    #expect(!allows(runtimeEnabled: false))
    #expect(!allows(capturesHiddenStates: true))
    #expect(!allows(batchSize: 2))
    #expect(!allows(sequenceLength: 2))
    #expect(!allows(cacheOffset: nil))
    #expect(!allows(cacheOffset: 0))
  }

  @Test("Compiled block tail preserves cached one-token decode logits")
  func compiledBlockTailPreservesCachedDecodeLogits() throws {
    let configuration = try decodeConfiguration()
    let model = LagunaModel(configuration)
    let eagerCache = try model.newCache(parameters: nil)
    let compiledCache = try model.newCache(parameters: nil)
    let prompt = MLXArray([Int32(1), 2, 3])[.newAxis]

    let eagerPrefill = LagunaRuntimeTuning.$useCompiledBlockTail.withValue(false) {
      model(prompt, cache: eagerCache)
    }
    let compiledPrefill = LagunaRuntimeTuning.$useCompiledBlockTail.withValue(true) {
      model(prompt, cache: compiledCache)
    }
    eval(eagerPrefill, compiledPrefill)
    eval(eagerCache)
    eval(compiledCache)

    #expect(eagerCache.allSatisfy { $0.offset == 3 })
    #expect(compiledCache.allSatisfy { $0.offset == 3 })
    #expect(
      allClose(eagerPrefill, compiledPrefill, rtol: 1e-2, atol: 1e-2)
        .item(Bool.self))

    let nextToken = MLXArray([Int32(4)])[.newAxis]
    let eager = LagunaRuntimeTuning.$useCompiledBlockTail.withValue(false) {
      model(nextToken, cache: eagerCache)
    }
    let compiled = LagunaRuntimeTuning.$useCompiledBlockTail.withValue(true) {
      model(nextToken, cache: compiledCache)
    }
    eval(eager, compiled)
    eval(eagerCache)
    eval(compiledCache)

    #expect(eagerCache.allSatisfy { $0.offset == 4 })
    #expect(compiledCache.allSatisfy { $0.offset == 4 })
    #expect(allClose(eager, compiled, rtol: 1e-2, atol: 1e-2).item(Bool.self))
  }

  @Test("Compiled block tail flag falls back for multi-token cached input")
  func compiledBlockTailFallsBackForMultiTokenInput() throws {
    let configuration = try decodeConfiguration()
    let model = LagunaModel(configuration)
    let eagerCache = try model.newCache(parameters: nil)
    let fallbackCache = try model.newCache(parameters: nil)
    let prompt = MLXArray([Int32(1), 2])[.newAxis]

    let eagerPrefill = model(prompt, cache: eagerCache)
    let fallbackPrefill = model(prompt, cache: fallbackCache)
    eval(eagerPrefill, fallbackPrefill)
    eval(eagerCache)
    eval(fallbackCache)

    let continuation = MLXArray([Int32(3), 4])[.newAxis]
    let eager = LagunaRuntimeTuning.$useCompiledBlockTail.withValue(false) {
      model(continuation, cache: eagerCache)
    }
    let fallback = LagunaRuntimeTuning.$useCompiledBlockTail.withValue(true) {
      model(continuation, cache: fallbackCache)
    }
    eval(eager, fallback)
    eval(eagerCache)
    eval(fallbackCache)

    #expect(eagerCache.allSatisfy { $0.offset == 4 })
    #expect(fallbackCache.allSatisfy { $0.offset == 4 })
    #expect(allClose(eager, fallback, rtol: 1e-2, atol: 1e-2).item(Bool.self))
  }

  @Test("Compiled attention prelude preserves cached logits and cache tensors exactly")
  func compiledAttentionPreludePreservesCachedDecodeExactly() throws {
    let configuration = try decodeConfiguration()
    let model = LagunaModel(configuration)
    let eagerCache = try model.newCache(parameters: nil)
    let compiledCache = try model.newCache(parameters: nil)
    let prompt = MLXArray([Int32(1), 2, 3])[.newAxis]

    let eagerPrefill = LagunaRuntimeTuning.$useCompiledAttentionPrelude.withValue(false) {
      LagunaRuntimeTuning.$useCompiledBlockTail.withValue(true) {
        model(prompt, cache: eagerCache)
      }
    }
    let compiledPrefill = LagunaRuntimeTuning.$useCompiledAttentionPrelude.withValue(true) {
      LagunaRuntimeTuning.$useCompiledBlockTail.withValue(true) {
        model(prompt, cache: compiledCache)
      }
    }
    eval(eagerPrefill, compiledPrefill)
    eval(eagerCache)
    eval(compiledCache)
    #expect(eagerPrefill.asArray(Float.self) == compiledPrefill.asArray(Float.self))

    for token: Int32 in [4, 5] {
      let nextToken = MLXArray([token])[.newAxis]
      let eager = LagunaRuntimeTuning.$useCompiledAttentionPrelude.withValue(false) {
        LagunaRuntimeTuning.$useCompiledBlockTail.withValue(true) {
          model(nextToken, cache: eagerCache)
        }
      }
      let compiled = LagunaRuntimeTuning.$useCompiledAttentionPrelude.withValue(true) {
        LagunaRuntimeTuning.$useCompiledBlockTail.withValue(true) {
          model(nextToken, cache: compiledCache)
        }
      }
      eval(eager, compiled)
      eval(eagerCache)
      eval(compiledCache)

      #expect(eager.asArray(Float.self) == compiled.asArray(Float.self))
      #expect(eagerCache.count == compiledCache.count)
      for (eagerEntry, compiledEntry) in zip(eagerCache, compiledCache) {
        let eagerState = eagerEntry.state
        let compiledState = compiledEntry.state
        #expect(eagerState.count == compiledState.count)
        for (eagerTensor, compiledTensor) in zip(eagerState, compiledState) {
          #expect(eagerTensor.asArray(Float.self) == compiledTensor.asArray(Float.self))
        }
      }
    }

    #expect(eagerCache.allSatisfy { $0.offset == 5 })
    #expect(compiledCache.allSatisfy { $0.offset == 5 })
  }

  private func decodeConfiguration(
    numberOfExperts: Int = 4,
    expertsPerToken: Int = 2
  ) throws -> LagunaConfiguration {
    let data = Data(
      """
      {
        "model_type": "laguna",
        "vocab_size": 32,
        "hidden_size": 8,
        "intermediate_size": 16,
        "num_hidden_layers": 2,
        "num_attention_heads": 2,
        "num_attention_heads_per_layer": [2, 4],
        "num_key_value_heads": 2,
        "head_dim": 4,
        "max_position_embeddings": 128,
        "rms_norm_eps": 0.000001,
        "attention_bias": false,
        "qkv_bias": false,
        "gating": "per-head",
        "tie_word_embeddings": false,
        "sliding_window": 8,
        "layer_types": ["full_attention", "sliding_attention"],
        "mlp_layer_types": ["dense", "sparse"],
        "num_experts": \(numberOfExperts),
        "num_experts_per_tok": \(expertsPerToken),
        "moe_intermediate_size": 8,
        "shared_expert_intermediate_size": 8,
        "moe_routed_scaling_factor": 2.5,
        "moe_router_score_func": "sigmoid",
        "rope_parameters": {
          "full_attention": {
            "rope_type": "yarn",
            "rope_theta": 500000.0,
            "factor": 2.0,
            "original_max_position_embeddings": 64,
            "partial_rotary_factor": 0.5
          },
          "sliding_attention": {
            "rope_type": "default",
            "rope_theta": 10000.0,
            "partial_rotary_factor": 1.0
          }
        }
      }
      """.utf8
    )
    return try JSONDecoder().decode(LagunaConfiguration.self, from: data)
  }
}
