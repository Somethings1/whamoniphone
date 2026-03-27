import coremltools as ct
from coremltools.optimize.coreml import OptimizationConfig

print("1. Đang nạp con quái vật WHAM 123MB...")
model = ct.models.MLModel("WHAM.mlpackage")

print("2. Đang chặt đôi dung lượng (Cast sang Float16)...")
# Cấu hình ép toàn bộ trọng số từ Float32 xuống Float16
op_config = ct.optimize.coreml.OpCastConfig(weight_dtype="float16")
config = OptimizationConfig(global_config=op_config)

# Thực thi
compressed_model = ct.optimize.coreml.cast_weights(model, config=config)

print("3. Đang lưu lại...")
compressed_model.save("WHAM_FP16.mlpackage")
print("🎉 Xong! Hãy check xem thư mục hiện tại có file WHAM_FP16.mlpackage nặng tầm 60MB không.")
