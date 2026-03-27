import torch
import torch.nn as nn
import timm
import coremltools as ct

class FastViTStudent(nn.Module):
    # ĐỔI THÀNH 1024. Đừng có mơ tưởng về số 1280 nữa.
    def __init__(self, model_name='fastvit_sa24', target_dim=1024):
        super().__init__()
        self.backbone = timm.create_model(model_name, pretrained=True, num_classes=0)

        # Kích thước ảnh phải là 256x256 để khớp với lúc train
        with torch.no_grad():
            dummy_input = torch.randn(1, 3, 256, 256)
            student_out_dim = self.backbone(dummy_input).shape[1]

        self.proj = nn.Linear(student_out_dim, target_dim)

    def forward(self, x):
        features = self.backbone(x)
        return self.proj(features)

# 1. Khởi tạo lại cấu trúc Student. Nhớ truyền target_dim=1024 vào.
model = FastViTStudent(target_dim=1024).to('cpu')

# THAY TÊN FILE .pth NÀY thành cái file ông vừa train xong (ví dụ: fastvit_student_1024.pth)
# Nếu ông vẫn để fastvit_wham_epoch_5.pth của bản cũ thì lỗi ráng chịu.
model_weights_path = 'fastvit_student_1024.pth'
model.load_state_dict(torch.load(model_weights_path, map_location='cpu'))
model.eval()

# 2. Tạo dữ liệu mẫu: BẮT BUỘC LÀ 256x256.
# Báo cho thằng dev iOS (tức là ông) biết mà resize ảnh camera cho đúng.
example_input = torch.rand(1, 3, 256, 256)

# 3. Trace mô hình
traced_model = torch.jit.trace(model, example_input)

# 4. Convert sang CoreML
mlmodel = ct.convert(
    traced_model,
    inputs=[ct.ImageType(shape=example_input.shape, name="image_input")],
    # Đổi tên output cho chuẩn để code Swift trên iPhone dễ gọi
    outputs=[ct.TensorType(name="features_1024")],
    minimum_deployment_target=ct.target.iOS16
)

# 5. Lưu lại thành phẩm cuối cùng
mlmodel.save("FastViT_WHAM_1024.mlpackage")
print(">>> XONG! 'Quái thú' đã được nhốt vào FastViT_WHAM_1024.mlpackage. Sẵn sàng mang lên iPhone.")
