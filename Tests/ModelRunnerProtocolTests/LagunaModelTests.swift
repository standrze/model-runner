import Foundation
import MLX
import MLXNN
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

  @Test("QKVG fusion requires a compatible projection layout")
  func qkvgFusionRequiresCompatibleLayout() throws {
    let unquantized = try decodeConfiguration()
    #expect(unquantized.shouldFuseQKVGProjection(layerIndex: 0))
    #expect(unquantized.shouldFuseQKVGProjection(layerIndex: 1))

    let uniform = try decodeConfiguration(
      quantizationJSON:
        """
        {"group_size": 64, "bits": 4, "mode": "affine"}
        """)
    #expect(uniform.shouldFuseQKVGProjection(layerIndex: 0))

    let mixedGate = try decodeConfiguration(
      quantizationJSON:
        """
        {
          "group_size": 64,
          "bits": 4,
          "mode": "affine",
          "language_model.model.layers.0.self_attn.g_proj": {
            "group_size": 64,
            "bits": 8,
            "mode": "affine"
          }
        }
        """)
    #expect(!mixedGate.shouldFuseQKVGProjection(layerIndex: 0))
    #expect(mixedGate.shouldFuseQKVGProjection(layerIndex: 1))

    let globalScale = try decodeConfiguration(
      quantizationJSON:
        """
        {"group_size": 64, "bits": 4, "mode": "affine", "global_scale": 0.5}
        """)
    #expect(!globalScale.shouldFuseQKVGProjection(layerIndex: 0))

    let biased = try decodeConfiguration(qkvBias: true)
    #expect(!biased.shouldFuseQKVGProjection(layerIndex: 0))
  }

  @Test("QKVG sanitization duplicates every packed row without requantizing")
  func qkvgSanitizationDuplicatesPackedRows() throws {
    let configuration = try decodeConfiguration()
    let model = LagunaModel(configuration)
    let prefix = "language_model.model.layers.0.self_attn"
    let rowCounts = [8, 8, 8, 2]
    let names = ["q_proj", "k_proj", "v_proj", "g_proj"]
    var weights = [String: MLXArray]()

    for (suffixIndex, suffix) in ["weight", "scales", "biases"].enumerated() {
      let columns = suffix == "weight" ? 2 : 1
      var start: Int32 = Int32(1_000 * suffixIndex)
      for (name, rows) in zip(names, rowCounts) {
        let count = rows * columns
        weights["\(prefix).\(name).\(suffix)"] = MLXArray(
          (0..<count).map { start + Int32($0) }
        ).reshaped(rows, columns)
        start += Int32(count)
      }
    }

    let sanitized = model.sanitize(weights: weights)
    for suffix in ["weight", "scales", "biases"] {
      let originals = names.map { weights["\(prefix).\($0).\(suffix)"]! }
      let expected = concatenated(originals, axis: 0)
      let fused = sanitized["\(prefix).qkvg_proj.\(suffix)"]!
      eval(expected, fused)
      #expect(expected.shape == fused.shape)
      #expect(expected.asArray(Int32.self) == fused.asArray(Int32.self))
      #expect(names.allSatisfy { sanitized["\(prefix).\($0).\(suffix)"] != nil })
    }
  }

  @Test("Fused QKVG preserves cached decode logits and cache tensors")
  func fusedQKVGPreservesCachedDecode() throws {
    let configuration = try decodeConfiguration()
    let model = LagunaModel(configuration)
    var parameters = Dictionary(
      uniqueKeysWithValues: model.parameters().flattened())
    for layerIndex in 0..<configuration.hiddenLayers {
      let prefix = "language_model.model.layers.\(layerIndex).self_attn"
      let sources = ["q_proj", "k_proj", "v_proj", "g_proj"].map {
        parameters["\(prefix).\($0).weight"]!
      }
      parameters["\(prefix).qkvg_proj.weight"] = concatenated(sources, axis: 0)
    }
    try model.update(
      parameters: ModuleParameters.unflattened(parameters), verify: [.all])
    eval(model)

    let legacyCache = try model.newCache(parameters: nil)
    let fusedCache = try model.newCache(parameters: nil)
    let prompt = MLXArray([Int32(1), 2, 3])[.newAxis]
    let legacyPrefill = LagunaRuntimeTuning.$useFusedQKVGProjection.withValue(false) {
      model(prompt, cache: legacyCache)
    }
    let fusedPrefill = LagunaRuntimeTuning.$useFusedQKVGProjection.withValue(true) {
      model(prompt, cache: fusedCache)
    }
    eval(legacyPrefill, fusedPrefill)
    eval(legacyCache)
    eval(fusedCache)
    #expect(
      legacyPrefill.asArray(Float.self) == fusedPrefill.asArray(Float.self))

    let nextToken = MLXArray([Int32(4)])[.newAxis]
    let legacy = LagunaRuntimeTuning.$useFusedQKVGProjection.withValue(false) {
      LagunaRuntimeTuning.$useCompiledBlockTail.withValue(true) {
        model(nextToken, cache: legacyCache)
      }
    }
    let fused = LagunaRuntimeTuning.$useFusedQKVGProjection.withValue(true) {
      LagunaRuntimeTuning.$useCompiledBlockTail.withValue(true) {
        model(nextToken, cache: fusedCache)
      }
    }
    eval(legacy, fused)
    eval(legacyCache)
    eval(fusedCache)

    #expect(legacyCache.allSatisfy { $0.offset == 4 })
    #expect(fusedCache.allSatisfy { $0.offset == 4 })
    #expect(legacy.asArray(Float.self) == fused.asArray(Float.self))
    for (legacyEntry, fusedEntry) in zip(legacyCache, fusedCache) {
      let legacyState = legacyEntry.state
      let fusedState = fusedEntry.state
      eval(legacyState)
      eval(fusedState)
      #expect(legacyState.count == fusedState.count)
      for (legacyTensor, fusedTensor) in zip(legacyState, fusedState) {
        #expect(
          legacyTensor.asArray(Float.self) == fusedTensor.asArray(Float.self))
      }
    }
  }

  private func decodeConfiguration(
    numberOfExperts: Int = 4,
    expertsPerToken: Int = 2,
    qkvBias: Bool = false,
    quantizationJSON: String? = nil
  ) throws -> LagunaConfiguration {
    let quantizationField = quantizationJSON.map {
      ",\n        \"quantization\": \($0)"
    } ?? ""
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
        "qkv_bias": \(qkvBias),
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
        }\(quantizationField)
      }
      """.utf8
    )
    return try JSONDecoder().decode(LagunaConfiguration.self, from: data)
  }
}
