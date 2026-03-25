import coremltools as ct
from coremltools.optimize.coreml import OptimizationConfig

model = ct.models.MLModel("WHAM_ViT.mlpackage")

config = OptimizationConfig(
    global_config=ct.optimize.coreml.OpLinearQuantizerConfig(
        mode="linear_symmetric",
        weight_threshold=512  # optional
    )
)

compressed_model = ct.optimize.coreml.linear_quantize_weights(
    model,
    config=config
)

compressed_model.save("model_int8.mlpackage")

