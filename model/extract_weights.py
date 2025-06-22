import os

import numpy as np
import pandas as pd
import torch
from config import Config
from quantize import CustomQConfig
from utils import load_model

from model import DnCNN


def extract_weights(model: torch.nn.Module):
    scale_a = {}  # activation scale
    scale_w = {}  # weight scale

    os.makedirs(Config.extracted_weights_dir, exist_ok=True)

    layer = 0
    for name, modules in model.named_modules():
        if hasattr(modules, "scale"):
            scale_a[layer] = modules.scale

        if not hasattr(modules, "weight"):
            continue

        weight: torch.Tensor = modules.weight()

        # Store scale and zero point
        scale_w[layer] = weight.q_scale()

        # Convert weight to int
        weight = weight.int_repr().numpy()

        in_channels, out_channels, h, w = weight.shape

        if layer != 0:
            # Reshape to (9, in_channels*out_channels)
            weight = weight.reshape(in_channels * out_channels, h * w).T
            weight = np.hsplit(weight, in_channels * out_channels // 4)

            with open(
                os.path.join(Config.extracted_weights_dir, f"layer{layer}_weight.hex"),
                "w",
            ) as f:
                for i in range(len(weight)):
                    for j in range(9):
                        w = weight[i][j]
                        w = np.flip(w, axis=0)
                        w_hex = w.tobytes().hex().upper()

                        f.write(f"{w_hex}\n")
        else:
            # For the first layer, we need to handle the weight differently
            weight = weight.reshape(in_channels * out_channels, h * w)
            out_channels, kernel_size = weight.shape

            with open(
                os.path.join(Config.extracted_weights_dir, f"layer{layer}_weight.hex"),
                "w",
            ) as f:
                for i in range(out_channels):
                    for j in range(kernel_size):
                        w = weight[i][j]
                        w_hex = w.tobytes().hex().upper()

                        f.write(f"{w_hex}\n")

        layer += 1

    return scale_a, scale_w


def extract_bias(model: torch.nn.Module, scale_a, scale_w):
    df = pd.DataFrame()

    layer = 0
    for name, param in model.state_dict().items():
        if "bias" not in name:
            continue

        if param is not None:
            bias = param.numpy()
            bias = np.round(bias / (scale_a[layer - 1] * scale_w[layer]))
            bias = bias.astype(np.int32)

            # Store bias in a DataFrame
            df[f"layer{layer}"] = bias

        layer += 1

    df.to_csv(os.path.join(Config.extracted_weights_dir, "bias_int32.csv"), index=False)


def main():
    channels = 1
    num_of_layers = 5

    model = load_model(
        model=DnCNN(channels=channels, num_of_layers=num_of_layers),
        filename=Config.quantized_model_path,
        qconfig=CustomQConfig.POWER2.value,
        fuse_modules=True,
    )

    scale_a, scale_w = extract_weights(model)
    extract_bias(model, scale_a, scale_w)

    print("Weights and biases extracted successfully.")


if __name__ == "__main__":
    main()
