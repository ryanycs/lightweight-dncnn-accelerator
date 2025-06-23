import os
import shutil

# Prebuild file path
PREBUILD_BITSTREAM_PATH = os.path.join("src", "pynq", "design_1.bit")
PREBUILD_HWH_PATH       = os.path.join("src", "pynq", "design_1.hwh")
PREBUILD_WEIGHTS_DIR    = os.path.join("src", "pynq", "weights")
PREBUILD_BIAS_PATH      = os.path.join("src", "pynq", "bias", "bias_int32.csv")
PREBUILD_NOTEBOOK_PATH  = os.path.join("src", "pynq", "DnCNN_pynq_run.ipynb")
PREBUILD_INPUT_DIR      = os.path.join("src", "pynq", "input")

# Original file paths
ORIGINAL_BITSTREAM_PATH = os.path.join("vivado", "output", "design_1.bit")
ORIGINAL_HWH_PATH       = os.path.join("vivado", "output", "design_1.hwh")
ORIGINAL_WEIGHTS_DIR    = os.path.join("model", "output")
ORIGINAL_BIAS_PATH      = os.path.join("model", "output", "bias_int32.csv")
ORIGINAL_NOTEBOOK_PATH  = os.path.join("src", "pynq", "DnCNN_pynq_run.ipynb")
ORIGINAL_INPUT_DIR      = os.path.join("src", "pynq", "input")

# Build file paths
BUILD_BITSTREAM_PATH = os.path.join("build", "design_1.bit")
BUILD_HWH_PATH       = os.path.join("build", "design_1.hwh")
BUILD_WEIGHTS_DIR    = os.path.join("build", "weights")
BUILD_BIAS_DIR       = os.path.join("build", "bias")
BUILD_BIAS_PATH      = os.path.join(BUILD_BIAS_DIR, "bias_int32.csv")
BUILD_NOTEBOOK_PATH  = os.path.join("build", "DnCNN_pynq_run.ipynb")
BUILD_INPUT_DIR      = os.path.join("build", "input")

WEIGHTS_FILES = [
    "layer0_weight.hex",
    "layer1_weight.hex",
    "layer2_weight.hex",
    "layer3_weight.hex",
    "layer4_weight.hex",
]
BIAS_FILES = "bias_int32.csv"

COLOR_WARNING = "\033[93m"
COLOR_INFO = "\033[94m"
COLOR_END = "\033[0m"


def copy_overlay():
    if not os.path.exists(ORIGINAL_BITSTREAM_PATH) or not os.path.exists(
        ORIGINAL_HWH_PATH
    ):
        print(
            COLOR_WARNING
            + "Warning: "
            + COLOR_END
            + "No Vivado bitstream or HWH file found in 'vivado/output'. Using pre-built overlay."
        )
        shutil.copy(PREBUILD_BITSTREAM_PATH, BUILD_BITSTREAM_PATH)
        shutil.copy(PREBUILD_HWH_PATH, BUILD_HWH_PATH)
    else:
        shutil.copy(ORIGINAL_BITSTREAM_PATH, BUILD_BITSTREAM_PATH)
        shutil.copy(ORIGINAL_HWH_PATH, BUILD_HWH_PATH)

    print(
        COLOR_INFO
        + "Info: "
        + COLOR_END
        + "Copied Vivado bitstream and HWH file to 'build' directory",
    )


def copy_weights():
    # Make sure the weights directory exists
    os.makedirs(BUILD_WEIGHTS_DIR, exist_ok=True)
    os.makedirs(BUILD_BIAS_DIR, exist_ok=True)

    # Check if weights files exist
    file_not_found = False
    for file in WEIGHTS_FILES:
        if not os.path.exists(os.path.join(ORIGINAL_WEIGHTS_DIR, file)):
            file_not_found = True
            break

    # Copy weights files
    if file_not_found:
        print(
            COLOR_WARNING
            + "Warning: "
            + COLOR_END
            + "No weights files found in 'model/output'. Using pre-built weights.",
        )
        for file in WEIGHTS_FILES:
            shutil.copy(
                os.path.join(PREBUILD_WEIGHTS_DIR, file),
                os.path.join(BUILD_WEIGHTS_DIR, file),
            )
    else:
        for file in WEIGHTS_FILES:
            shutil.copy(
                os.path.join(ORIGINAL_WEIGHTS_DIR, file),
                os.path.join(BUILD_WEIGHTS_DIR, file),
            )

    print(
        COLOR_INFO
        + "Info: "
        + COLOR_END
        + "Copied weights files to 'build/weights' directory.",
    )

    # Copy bias file
    if not os.path.exists(ORIGINAL_BIAS_PATH):
        print(
            COLOR_WARNING
            + "Warning: "
            + COLOR_END
            + "No bias file found in 'model/output'. Using pre-built bias file.",
        )
        shutil.copy(PREBUILD_BIAS_PATH, BUILD_BIAS_PATH)
    else:
        shutil.copy(ORIGINAL_BIAS_PATH, BUILD_BIAS_PATH)

    print(
        COLOR_INFO
        + "Info: "
        + COLOR_END
        + "Copied bias file to 'build/bias' directory.",
    )


def copy_notebooks():
    shutil.copy(ORIGINAL_NOTEBOOK_PATH, BUILD_NOTEBOOK_PATH)
    print(
        COLOR_INFO
        + "Info: "
        + COLOR_END
        + "Copied Jupyter notebook to 'build' directory.",
    )


def copy_input():
    shutil.copytree(ORIGINAL_INPUT_DIR, BUILD_INPUT_DIR, dirs_exist_ok=True)
    print(
        COLOR_INFO
        + "Info: "
        + COLOR_END
        + "Copied input files to 'build/input' directory.",
    )


def main():
    # Ensure the build directory exists
    os.makedirs("build", exist_ok=True)

    copy_overlay()
    copy_weights()
    copy_notebooks()
    copy_input()


if __name__ == "__main__":
    main()
