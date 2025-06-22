import argparse
import os

import numpy as np
import pandas as pd
import torch
from config import Config
from quantize import CustomQConfig
from utils import load_model

from model import DnCNN


def extract_weights(model: torch.nn.Module, debug: bool = False):
    scale_a = {}  # activation scale
    scale_w = {}  # weight scale

    os.makedirs(Config.extracted_weights_dir, exist_ok=True)

    layer = 0
    for name, modules in model.named_modules():
        if hasattr(modules, "scale"):
            scale_a[layer] = modules.scale

        if not hasattr(modules, "weight"):
            continue

        weights: torch.Tensor = modules.weight()

        # Store scale and zero point
        scale_w[layer] = weights.q_scale()

        # Convert weight to int
        weights = weights.int_repr().numpy()

        in_channels, out_channels, h, w = weights.shape

        if layer != 0:
            # Reshape to (9, in_channels * out_channels)
            weights = weights.reshape(in_channels * out_channels, h * w).T
            weights = np.hsplit(weights, in_channels * out_channels // 4)

            with open(
                os.path.join(Config.extracted_weights_dir, f"layer{layer}_weight.hex"),
                "w",
            ) as f:
                for i in range(len(weights)):
                    for j in range(h * w):
                        weight = weights[i][j]
                        weight = np.flip(weight, axis=0)
                        weight_hex = weight.tobytes().hex().upper()

                        if debug:
                            # Example: FD04F8FF // (  -3,   4,  -8,  -1)
                            f.write(
                                f"{weight_hex} // ({','.join('{:>4}'.format(str(w)) for w in weight)})\n"
                            )
                        else:
                            f.write(f"{weight_hex}\n")
        else:
            # For the first layer, we need to handle the weight differently
            weights = weights.reshape(in_channels * out_channels, h * w)
            out_channels, kernel_size = weights.shape

            with open(
                os.path.join(Config.extracted_weights_dir, f"layer{layer}_weight.hex"),
                "w",
            ) as f:
                for i in range(out_channels):
                    for j in range(kernel_size):
                        weight = weights[i][j]
                        weight_hex = weight.tobytes().hex().upper()

                        if debug:
                            f.write(f"{weight_hex} // ({weight})\n")
                        else:
                            f.write(f"{weight_hex}\n")

        layer += 1

    return scale_a, scale_w


def extract_bias(
    model: torch.nn.Module, scale_a: list, scale_w: list, debug: bool = False
):
    df = pd.DataFrame()

    layer = 0
    for name, param in model.state_dict().items():
        if "bias" not in name:
            continue

        if param is not None:
            biases = param.numpy()
            biases = np.round(biases / (scale_a[layer - 1] * scale_w[layer]))
            biases = biases.astype(np.int32)

            # Store bias in a DataFrame
            df[f"layer{layer}"] = biases

            # Save bias to a hex file
            with open(
                os.path.join(Config.extracted_weights_dir, f"layer{layer}_bias.hex"),
                "w",
            ) as f:
                for bias in biases:
                    bias_hex = bias.tobytes().hex().upper()

                    # To big-endian
                    bias_hex = (
                        bias_hex[6:8] + bias_hex[4:6] + bias_hex[2:4] + bias_hex[0:2]
                    )

                    if debug:
                        f.write(f"{bias_hex} // ({'+' if bias > 0 else ''}{bias})\n")
                    else:
                        f.write(f"{bias_hex}\n")

        layer += 1

    df.to_csv(os.path.join(Config.extracted_weights_dir, "bias_int32.csv"), index=False)


def main():
    parser = argparse.ArgumentParser(
        description="Extract weights and biases from DnCNN model."
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Enable debug mode for detailed output.",
    )
    args = parser.parse_args()

    model = load_model(
        model=DnCNN(channels=1, num_of_layers=Config.num_of_layers),
        filename=Config.quantized_model_path,
        qconfig=CustomQConfig.POWER2.value,
        fuse_modules=True,
    )

    scale_a, scale_w = extract_weights(model, debug=args.debug)
    extract_bias(model, scale_a, scale_w, debug=args.debug)

    print("Weights and biases extracted successfully.")


if __name__ == "__main__":
    main()
