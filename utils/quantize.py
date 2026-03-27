import coremltools as ct
from coremltools.optimize.coreml import OptimizationConfig
import gc

print("1. Đang chui vào RAM để bịt mõm 'fuse_stack_split' của Apple...")
try:
    import coremltools.converters.mil.mil.passes.defs.common
except:
    pass

patched = False
for obj in gc.get_objects():
    if isinstance(obj, type):
        name = getattr(obj, '__name__', '').lower()
        if 'fuse_stack_split' in name:
            setattr(obj, '__call__', lambda self, *args, **kwargs: None)
            setattr(obj, 'apply', lambda self, *args, **kwargs: None)
            patched = True
            print("🔥 Đã khóa mõm fuse_stack_split thành công!")

print("2. Load model và bắt đầu lượng tử hóa (Int8)...")
model = ct.models.MLModel("WHAM.mlpackage")

# --- SỬA LỖI TREO MÁY Ở ĐÂY ---
# Chỉ định luật lượng tử hóa
op_config = ct.optimize.coreml.OpLinearQuantizerConfig(
    mode="linear_symmetric",
    weight_threshold=512
)

# Áp dụng luật này ĐỘC QUYỀN cho các layer Linear và MatMul (tránh các layer 0-weight)
config = OptimizationConfig(
    op_type_configs={
        "linear": op_config,
        "matmul": op_config
    }
)

compressed_model = ct.optimize.coreml.linear_quantize_weights(
    model,
    config=config
)

print("3. Đang lưu lại bản siêu nhẹ...")
compressed_model.save("WHAM_Int8.mlpackage")
print("🎉 ĐẠI CÔNG CÁO THÀNH! Lấy WHAM_Int8.mlpackage ném vào Xcode đi.")
