import os

import numpy as np
from PIL import Image

INPUT_SCALE = 0.0078125  # 1 / 128
INPUT_ZERO_POINT = 128

OUTPUT_SCALE = 0.00390625  # 1 / 256
OUTPUT_ZERO_POINT = 128

NOISE_HEX_IMAGE_PATH = os.path.join("dat", "layer0_dat", "layer0_input_image_pad.hex")
RESIDUAL_PATH = os.path.join("out_dat", "layer4_ofmap_out.hex")

NOISE_IMAGE_PATH = os.path.join("out_dat", "noise_image.png")
OUTPUT_IMAGE_PATH = os.path.join("out_dat", "denoise_image.png")


def read_noise_file(file_path):
    image = []
    with open(file_path, "r") as f:
        for line in f:
            pixel_hex = bytes.fromhex(line.split()[0])
            pixel = int.from_bytes(pixel_hex)
            image.append(pixel)

    image_np = np.array(image, dtype=np.uint8)

    # Remove padding
    image_np = image_np[256:-256]
    image_np = image_np.reshape((256, 256))

    # de-quantization
    # Note: the de-quantized image will be a little bit different from the original noise image
    image_np = (image_np.astype(np.float32) - INPUT_ZERO_POINT) * INPUT_SCALE

    # Save the noise image
    Image.fromarray((image_np * 255).astype(np.uint8), mode="L").save(NOISE_IMAGE_PATH)

    return image_np


def read_residual_file(file_path):
    residual = []
    with open(file_path, "r") as f:
        for line in f:
            pixel_hex = bytes.fromhex("".join(line.split()[0].split("_")))
            pixel = int.from_bytes(pixel_hex, signed=True)
            residual.append(pixel % 256)

    residual = np.array(residual, dtype=np.uint8)
    residual = residual.reshape((256, 256))

    # de-quantization
    residual = (residual.astype(np.float32) - OUTPUT_ZERO_POINT) * OUTPUT_SCALE

    return residual


def main():
    image = read_noise_file(NOISE_HEX_IMAGE_PATH)
    residual = read_residual_file(RESIDUAL_PATH)

    out = np.clip(image - residual, 0.0, 1.0)
    out = (out * 255).round().astype(np.uint8)

    Image.fromarray(out, mode="L").save(OUTPUT_IMAGE_PATH)


if __name__ == "__main__":
    main()
