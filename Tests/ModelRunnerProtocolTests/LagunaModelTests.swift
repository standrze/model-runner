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
