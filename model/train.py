import os

import numpy as np
import torch
import torch.nn as nn
import torch.optim as optim
import torchvision.utils as utils
from config import Config
from dataset import Dataset, prepare_data
from tensorboardX import SummaryWriter
from torch.autograd import Variable
from torch.utils.data import DataLoader
from utils import batch_PSNR, get_args, save_model, weights_init_kaiming

from model import DnCNN

os.environ["CUDA_DEVICE_ORDER"] = "PCI_BUS_ID"
os.environ["CUDA_VISIBLE_DEVICES"] = "0"


def main(opt):
    # Load dataset
    print("Loading dataset ...\n")
    dataset_train = Dataset(train=True)
    dataset_val = Dataset(train=False)
    loader_train = DataLoader(
        dataset=dataset_train, num_workers=4, batch_size=opt.batchSize, shuffle=True
    )

    print("# of training samples: %d\n" % int(len(dataset_train)))

    # Build model
    net = DnCNN(channels=1, num_of_layers=opt.num_of_layers)
    net.apply(weights_init_kaiming)
    criterion = nn.MSELoss(size_average=False)

    # Move to GPU
    device_ids = [0]
    model = nn.DataParallel(net, device_ids=device_ids).cuda()
    criterion.cuda()

    # Optimizer
    optimizer = optim.Adam(model.parameters(), lr=opt.lr)

    # training
    writer = SummaryWriter(opt.outf)
    step = 0
    noiseL_B = [0, 55]  # ingnored when opt.mode=='S'
    for epoch in range(opt.epochs):
        if epoch < opt.milestone:
            current_lr = opt.lr
        else:
            current_lr = opt.lr / 10.0

        # set learning rate
        for param_group in optimizer.param_groups:
            param_group["lr"] = current_lr
        print("learning rate %f" % current_lr)

        # train
        for i, data in enumerate(loader_train, 0):
            # training step
            model.train()
            model.zero_grad()
            optimizer.zero_grad()
            img_train = data
            if opt.mode == "S":
                noise = torch.FloatTensor(img_train.size()).normal_(
                    mean=0, std=opt.noiseL / 255.0
                )
            if opt.mode == "B":
                noise = torch.zeros(img_train.size())
                stdN = np.random.uniform(noiseL_B[0], noiseL_B[1], size=noise.size()[0])
                for n in range(noise.size()[0]):
                    sizeN = noise[0, :, :, :].size()
                    noise[n, :, :, :] = torch.FloatTensor(sizeN).normal_(
                        mean=0, std=stdN[n] / 255.0
                    )
            imgn_train = img_train + noise
            img_train, imgn_train = (
                Variable(img_train.cuda()),
                Variable(imgn_train.cuda()),
            )
            noise = Variable(noise.cuda())
            out_train = model(imgn_train)
            loss = criterion(out_train, noise) / (imgn_train.size()[0] * 2)
            loss.backward()
            optimizer.step()

            # results
            model.eval()
            out_train = torch.clamp(imgn_train - model(imgn_train), 0.0, 1.0)
            psnr_train = batch_PSNR(out_train, img_train, 1.0)
            print(
                "[epoch %d][%d/%d] loss: %.4f PSNR_train: %.4f"
                % (epoch + 1, i + 1, len(loader_train), loss.item(), psnr_train)
            )

            # if you are using older version of PyTorch, you may need to change loss.item() to loss.data[0]
            if step % 10 == 0:
                # Log the scalar values
                writer.add_scalar("loss", loss.item(), step)
                writer.add_scalar("PSNR on training data", psnr_train, step)
            step += 1
        ## the end of each epoch

        model.eval()
        # validate
        psnr_val = 0
        for k in range(len(dataset_val)):
            img_val = torch.unsqueeze(dataset_val[k], 0)
            noise = torch.FloatTensor(img_val.size()).normal_(
                mean=0, std=opt.val_noiseL / 255.0
            )
            imgn_val = img_val + noise
            img_val, imgn_val = (
                Variable(img_val.cuda(), volatile=True),
                Variable(imgn_val.cuda(), volatile=True),
            )
            out_val = torch.clamp(imgn_val - model(imgn_val), 0.0, 1.0)
            psnr_val += batch_PSNR(out_val, img_val, 1.0)
        psnr_val /= len(dataset_val)
        print("\n[epoch %d] PSNR_val: %.4f" % (epoch + 1, psnr_val))
        writer.add_scalar("PSNR on validation data", psnr_val, epoch)

        # log the images
        out_train = torch.clamp(imgn_train - model(imgn_train), 0.0, 1.0)
        Img = utils.make_grid(img_train.data, nrow=8, normalize=True, scale_each=True)
        Imgn = utils.make_grid(imgn_train.data, nrow=8, normalize=True, scale_each=True)
        Irecon = utils.make_grid(
            out_train.data, nrow=8, normalize=True, scale_each=True
        )
        writer.add_image("clean image", Img, epoch)
        writer.add_image("noisy image", Imgn, epoch)
        writer.add_image("reconstructed image", Irecon, epoch)

        # save model
        save_model(model, Config.model_path, existed="overwrite")


if __name__ == "__main__":
    opt = get_args()
    if opt.preprocess:
        if opt.mode == "S":
            prepare_data(
                data_path=Config.data_dir, patch_size=40, stride=10, aug_times=1
            )
        if opt.mode == "B":
            prepare_data(
                data_path=Config.data_dir, patch_size=50, stride=10, aug_times=2
            )
    main(opt)
