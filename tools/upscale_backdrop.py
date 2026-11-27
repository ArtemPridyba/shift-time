#!/usr/bin/env python3
"""Upscale a painted room x2 so the camera never stretches it (27.11, D185).

    python3 tools/upscale_backdrop.py IN.jpg OUT.jpg
        Lanczos x2, then an unsharp mask (radius 2, 70 %, threshold 1): what
        level 01 uses. Needs only Pillow.
    python3 tools/upscale_backdrop.py IN.jpg OUT.jpg --esrgan WEIGHTS [--blend 0.5]
        Real-ESRGAN instead (RealESRGAN_x2plus.pth of the Real-ESRGAN release
        v0.2.1, https://github.com/xinntao/Real-ESRGAN/releases, BSD-3-Clause,
        sha256 49fafd45f8fd7aa8d31ab2a22d14d91b536c34494a5cfe31eb5d89c2fa266abb)
        on the CPU, mixed with the Lanczos picture by --blend (1: the network
        only). Needs torch and numpy; the network (RRDBNet of BasicSR,
        Apache-2.0) is written out below. Tried on level 01 (27.11): it smooths
        away the painted chain links and brick joints, so the game uses Lanczos.

The dark and the lit picture of a room go through the same steps and stay
pixel for pixel alike. A .jpg is saved at quality 95.
"""
import argparse

from PIL import Image, ImageFilter


def esrgan(weights: str, img: Image.Image, tile: int = 384, pad: int = 24) -> Image.Image:
    import numpy as np
    import torch
    from torch import nn
    from torch.nn import functional as F

    class DenseBlock(nn.Module):
        def __init__(self, nf: int = 64, gc: int = 32) -> None:
            super().__init__()
            self.conv1 = nn.Conv2d(nf, gc, 3, 1, 1)
            self.conv2 = nn.Conv2d(nf + gc, gc, 3, 1, 1)
            self.conv3 = nn.Conv2d(nf + 2 * gc, gc, 3, 1, 1)
            self.conv4 = nn.Conv2d(nf + 3 * gc, gc, 3, 1, 1)
            self.conv5 = nn.Conv2d(nf + 4 * gc, nf, 3, 1, 1)
            self.lrelu = nn.LeakyReLU(0.2, True)

        def forward(self, x):
            x1 = self.lrelu(self.conv1(x))
            x2 = self.lrelu(self.conv2(torch.cat((x, x1), 1)))
            x3 = self.lrelu(self.conv3(torch.cat((x, x1, x2), 1)))
            x4 = self.lrelu(self.conv4(torch.cat((x, x1, x2, x3), 1)))
            x5 = self.conv5(torch.cat((x, x1, x2, x3, x4), 1))
            return x5 * 0.2 + x


    class RRDB(nn.Module):
        def __init__(self) -> None:
            super().__init__()
            self.rdb1 = DenseBlock()
            self.rdb2 = DenseBlock()
            self.rdb3 = DenseBlock()

        def forward(self, x):
            return self.rdb3(self.rdb2(self.rdb1(x))) * 0.2 + x


    class RRDBNetX2(nn.Module):
        """RRDBNet with scale 2: the input is pixel-unshuffled, then x4 inside."""

        def __init__(self, blocks: int = 23, nf: int = 64) -> None:
            super().__init__()
            self.conv_first = nn.Conv2d(12, nf, 3, 1, 1)
            self.body = nn.Sequential(*[RRDB() for _ in range(blocks)])
            self.conv_body = nn.Conv2d(nf, nf, 3, 1, 1)
            self.conv_up1 = nn.Conv2d(nf, nf, 3, 1, 1)
            self.conv_up2 = nn.Conv2d(nf, nf, 3, 1, 1)
            self.conv_hr = nn.Conv2d(nf, nf, 3, 1, 1)
            self.conv_last = nn.Conv2d(nf, 3, 3, 1, 1)
            self.lrelu = nn.LeakyReLU(0.2, True)

        def forward(self, x):
            feat = self.conv_first(F.pixel_unshuffle(x, 2))
            feat = feat + self.conv_body(self.body(feat))
            feat = self.lrelu(self.conv_up1(F.interpolate(feat, scale_factor=2, mode="nearest")))
            feat = self.lrelu(self.conv_up2(F.interpolate(feat, scale_factor=2, mode="nearest")))
            return self.conv_last(self.lrelu(self.conv_hr(feat)))


    def upscale(net: nn.Module, img: np.ndarray, tile: int, pad: int) -> np.ndarray:
        # Pixel unshuffle needs even sizes: an even picture, tile and margin keep
        # every tile even.
        assert img.shape[0] % 2 == 0 and img.shape[1] % 2 == 0 and tile % 2 == 0 and pad % 2 == 0
        h, w, _ = img.shape
        x = torch.from_numpy(img.transpose(2, 0, 1)).float().unsqueeze(0) / 255.0
        out = np.zeros((h * 2, w * 2, 3), dtype=np.float32)
        tiles = [(ty, tx) for ty in range(0, h, tile) for tx in range(0, w, tile)]
        for i, (ty, tx) in enumerate(tiles):
            y0, x0 = max(ty - pad, 0), max(tx - pad, 0)
            y1, x1 = min(ty + tile + pad, h), min(tx + tile + pad, w)
            with torch.no_grad():
                y = net(x[:, :, y0:y1, x0:x1])[0].numpy().transpose(1, 2, 0)
            th, tw = min(tile, h - ty), min(tile, w - tx)
            oy, ox = (ty - y0) * 2, (tx - x0) * 2
            out[ty * 2:(ty + th) * 2, tx * 2:(tx + tw) * 2] = y[oy:oy + th * 2, ox:ox + tw * 2]
            print(f"tile {i + 1}/{len(tiles)}", flush=True)
        return np.clip(out * 255.0 + 0.5, 0, 255).astype(np.uint8)

    net = RRDBNetX2()
    state = torch.load(weights, map_location="cpu", weights_only=True)
    net.load_state_dict(state.get("params_ema", state.get("params", state)))
    net.eval()
    return Image.fromarray(upscale(net, np.asarray(img), tile, pad))


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source")
    parser.add_argument("out")
    parser.add_argument("--esrgan", metavar="WEIGHTS")
    parser.add_argument("--blend", type=float, default=1.0)
    args = parser.parse_args()
    img = Image.open(args.source).convert("RGB")
    size = (img.width * 2, img.height * 2)
    out = img.resize(size, Image.LANCZOS)
    if args.esrgan:
        out = Image.blend(out, esrgan(args.esrgan, img), args.blend)
    else:
        out = out.filter(ImageFilter.UnsharpMask(radius=2, percent=70, threshold=1))
    out.save(args.out, quality=95, subsampling=0) if args.out.lower().endswith((".jpg", ".jpeg")) else out.save(args.out)
    print(f"{args.source} {img.width}x{img.height} -> {args.out} {size[0]}x{size[1]}")


if __name__ == "__main__":
    main()
