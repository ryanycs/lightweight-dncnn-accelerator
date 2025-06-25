import glob
import os
from collections import OrderedDict
from enum import Enum

import torch
import torch.ao.quantization as tq
from config import Config
from PIL import Image
from torch.utils.data import DataLoader, Dataset
from torchvision import transforms
from utils import save_model

from model import DnCNN


class PowerOfTwoObserver(tq.MinMaxObserver):
    """
    Observer module for power-of-two quantization (dyadic quantization with b = 1).
    """

    def scale_approximate(self, scale: float, max_shift_amount=8) -> float:
        """
        Finding the nearest power of two by converting the scale to its binary representation
        """
        scale_log2 = torch.ceil(torch.log2(torch.tensor(scale)))
        scale_log2 = torch.clamp(scale_log2, max=max_shift_amount)
        power_of_two_scale = 2**scale_log2

        return power_of_two_scale

    def calculate_qparams(self):
        """Calculates the quantization parameters with scale as power of two."""
        min_val, max_val = self.min_val.item(), self.max_val.item()

        """ Calculate zero_point as in the base class """
        # Compute scale
        scale = max(abs(min_val), abs(max_val)) / (
            2**7 - 1
        )  # For 8-bit symmetric quantization

        if self.dtype == torch.qint8:
            zero_point = 0
        else:
            zero_point = 128

        scale = self.scale_approximate(scale)
        zero_point = torch.tensor(zero_point, dtype=torch.int64)

        return scale, zero_point

    def extra_repr(self):
        return f"min_val={self.min_val}, max_val={self.max_val}, scale=PowerOfTwo"


class CustomQConfig(Enum):
    POWER2 = tq.QConfig(
        activation=PowerOfTwoObserver.with_args(
            dtype=torch.quint8, qscheme=torch.per_tensor_symmetric
        ),
        weight=PowerOfTwoObserver.with_args(
            dtype=torch.qint8, qscheme=torch.per_tensor_symmetric
        ),
    )
    DEFAULT = None


class ImageFolderDataset(Dataset):
    def __init__(self, image_dir, transform=None, noise_std=25.0):
        self.image_paths = sorted(glob.glob(os.path.join(image_dir, "*.png")))
        self.transform = transform
        self.noise_std = noise_std / 255.0

    def __len__(self):
        return len(self.image_paths)

    def __getitem__(self, idx):
        img = Image.open(self.image_paths[idx]).convert("L")
        if self.transform:
            clean_tensor = self.transform(img)
        else:
            clean_tensor = transforms.ToTensor()(img)
        noise = torch.FloatTensor(clean_tensor.size()).normal_(
            mean=0, std=self.noise_std
        )
        noisy_tensor = clean_tensor + noise
        return noisy_tensor


def get_calibration_loader(
    image_dir="./data/train", image_size=40, batch_size=1, noise_std=25.0
):
    transform = transforms.Compose(
        [transforms.Resize((image_size, image_size)), transforms.ToTensor()]
    )
    dataset = ImageFolderDataset(image_dir, transform=transform, noise_std=noise_std)
    return DataLoader(dataset, batch_size=batch_size, shuffle=False)


def calibrate(model, loader, device="cpu"):
    """Calibrate Method"""
    model.eval().to(device)
    for x in loader:
        model(x.to(device))
        break


def main():
    # Load Pretrained Model
    channels = 1
    num_of_layers = 5

    Pretrained_model = DnCNN(channels=channels, num_of_layers=num_of_layers)
    Pretrained_model.eval()
    Pretrained_model.cpu()

    state_dict = torch.load(Config.model_path, map_location="cpu")

    new_state_dict = OrderedDict()
    for k, v in state_dict.items():
        name = k.replace("module.", "")
        new_state_dict[name] = v
    Pretrained_model.load_state_dict(new_state_dict)

    # Fuse Modules
    Pretrained_model.fuse_layers()

    # Configure Quantization
    fused_model = tq.QuantWrapper(Pretrained_model)
    fused_model.qconfig = CustomQConfig.POWER2.value
    print(f"Quantization backend: {fused_model.qconfig}")

    # Apply Quantization Preparation
    tq.prepare(fused_model, inplace=True)

    # Calibration
    calibrate(fused_model, get_calibration_loader(image_dir=Config.train_data_path))

    # Convert Model to Quantized Version
    tq.convert(fused_model.cpu(), inplace=True)

    # Save Quantized Model
    save_model(fused_model, Config.quantized_model_path, existed="overwrite")


if __name__ == "__main__":
    main()
