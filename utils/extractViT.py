import torch
import torch.nn as nn
import timm
import coremltools as ct


class FastViTStudent(nn.Module):
    def __init__(self, model_name='fastvit_sa24', target_dim=1280):
        super().__init__()
        # Load FastViT bản SA24 (cân bằng tốc độ/độ chính xác)
        # num_classes=0 để lấy feature trực tiếp
        self.backbone = timm.create_model(model_name, pretrained=True, num_classes=0)

        # Tự động lấy số chiều đầu ra của FastViT
        with torch.no_grad():
            dummy_input = torch.randn(1, 3, 224, 224)
            student_out_dim = self.backbone(dummy_input).shape[1]

        # Lớp "đầu chuyển" để ép từ dimension của Student về 1280 của ViT-L
        self.proj = nn.Linear(student_out_dim, target_dim)

    def forward(self, x):
        features = self.backbone(x)
        return self.proj(features)


# 1. Khởi tạo lại cấu trúc Student và nạp trọng số đã luyện
# Đảm bảo class FastViTStudent đã được định nghĩa ở trên
model = FastViTStudent().to('cpu')
model.load_state_dict(torch.load('fastvit_wham_epoch_5.pth', map_location='cpu'))
model.eval()

# 2. Tạo dữ liệu mẫu (Dummy input) để CoreML bắt hình dáng
example_input = torch.rand(1, 3, 224, 224)

# 3. Trace mô hình (Chuyển từ PyTorch sang TorchScript)
traced_model = torch.jit.trace(model, example_input)

# 4. Convert sang CoreML
mlmodel = ct.convert(
    traced_model,
    inputs=[ct.TensorType(shape=example_input.shape, name="image_input")],
    outputs=[ct.TensorType(name="features_1280")],
    minimum_deployment_target=ct.target.iOS16 # iPhone 15 Plus dư sức chạy
)

# 5. Lưu lại thành phẩm cuối cùng
mlmodel.save("FastViT_WHAM_Backbone.mlpackage")
print(">>> XONG! 'Tấm vé thông hành' FastViT_WHAM_Backbone.mlpackage đã sẵn sàng.")
