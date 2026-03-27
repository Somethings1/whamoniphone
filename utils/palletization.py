import coremltools as ct
from coremltools.optimize.coreml import (
    OpLinearQuantizerConfig,
    OptimizationConfig,
    linear_quantize_weights
)
import gc
import warnings

warnings.filterwarnings("ignore")

print("0. Bắt đầu niệm chú khóa mõm 'fuse_stack_split'...")
try:
    import coremltools.converters.mil.mil.passes.defs.common
except:
    pass

# Nếu không có đoạn này, Python sẽ tự tử trước khi nhả ra được file
patched = False
for obj in gc.get_objects():
    if isinstance(obj, type) and 'fuse_stack_split' in getattr(obj, '__name__', '').lower():
        setattr(obj, '__call__', lambda self, *args, **kwargs: None)
        setattr(obj, 'apply', lambda self, *args, **kwargs: None)
        patched = True

if patched:
    print("🔥 Đã khóa mõm fuse_stack_split thành công!")

print("1. Đang nạp model WHAM gốc...")
model = ct.models.MLModel("WHAM.mlpackage")

print("2. Thiết lập ranh giới bảo vệ Bias (Threshold = 25000)...")
op_config = OpLinearQuantizerConfig(
    mode="linear_symmetric",
    dtype="int8",
    weight_threshold=25000
)

config = OptimizationConfig(global_config=op_config)

print("3. Đang ép cân xuống INT8...")
compressed_model = linear_quantize_weights(model, config=config)

print("4. Đang dọn rác RAM...")
del model
gc.collect()

print("5. Đang lưu file...")
compressed_model.save("WHAM_INT8_SAFE.mlpackage")
print("🎉 XONG! Quăng vào Xcode và Clean Build đi ông giáo.")
