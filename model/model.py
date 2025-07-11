import torch.ao.quantization as tq
import torch.nn as nn


class DnCNN(nn.Module):
    def __init__(self, channels, num_of_layers=17, do_fuse: bool = False):
        super(DnCNN, self).__init__()
        self.do_fuse = do_fuse

        kernel_size = 3
        padding = 1
        features = 64
        layers = []
        layers.append(
            nn.Conv2d(
                in_channels=channels,
                out_channels=features,
                kernel_size=kernel_size,
                padding=padding,
                bias=False,
            )
        )
        layers.append(nn.ReLU(inplace=True))
        for _ in range(num_of_layers - 2):
            layers.append(
                nn.Conv2d(
                    in_channels=features,
                    out_channels=features,
                    kernel_size=kernel_size,
                    padding=padding,
                    bias=False,
                )
            )
            layers.append(nn.BatchNorm2d(features))
            layers.append(nn.ReLU(inplace=True))
        layers.append(
            nn.Conv2d(
                in_channels=features,
                out_channels=channels,
                kernel_size=kernel_size,
                padding=padding,
                bias=False,
            )
        )
        self.dncnn = nn.Sequential(*layers)

        if self.do_fuse:
            self.eval()
            self.fuse_layers()

    def fuse_layers(self):
        # Assume the following pattern: Conv -> BatchNorm -> ReLU
        fuse_list = []
        fuse_list.append(["0", "1"])
        # Collect the fusion patterns
        for i in range(2, len(self.dncnn) - 2, 3):
            fuse_list.append([str(i), str(i + 1), str(i + 2)])  # Conv, BN, ReLU

        tq.fuse_modules(self.dncnn, fuse_list, inplace=True)

    def forward(self, x):
        out = self.dncnn(x)
        return out
