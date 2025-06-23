import os
from dataclasses import dataclass


@dataclass
class Config:
    num_of_layers: int = 5

    base_dir: str = os.path.dirname(os.path.realpath(__file__))

    model_dir: str = "weights"

    model_name: str = "DnCNN_5_layers.pt"
    model_path: str = os.path.join(base_dir, model_dir, model_name)

    quantized_model_name: str = "DnCNN_5_layers_int8.pt"
    quantized_model_path: str = os.path.join(base_dir, model_dir, quantized_model_name)

    data_dir: str = os.path.join(base_dir, "data")
    train_data_path: str = os.path.join(data_dir, "train")

    extracted_weights_dir: str = os.path.join(base_dir, "output")
