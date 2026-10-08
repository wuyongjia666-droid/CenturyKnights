"""Batch F (Hunyuan3D-v2 shape, farm :8327): FRONT half of each style-locked turnaround -> background keyed to white,
padded to a centred square (CLIPVisionEncode crops the centre) -> GeneRanch 'peak' graph -> SaveGLB.
  gen_hunyuan_v87.py <sheets_dir> <batch_dir> [names...]"""
import sys, os, json, glob
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_qwen import Batch, seed_of

def front_square(sheet_p, out_p, size=768):
    im = np.array(Image.open(sheet_p).convert("RGB")).astype(np.float32)
    h, w, _ = im.shape
    half = im[:, : w // 2]
    border = np.concatenate([half[0], half[-1], half[:, 0], half[:, -1]])
    bg = np.median(border, 0)
    d = np.abs(half - bg).sum(-1)
    m = d > 30
    # flood from the border so interior light colours stay
    import cv2
    mm = (~m).astype(np.uint8)
    n, lbl = cv2.connectedComponents(mm, 4)
    edge = set(np.unique(np.concatenate([lbl[0], lbl[-1], lbl[:, 0], lbl[:, -1]]))) - {0}
    bgmask = np.isin(lbl, list(edge))
    bgmask = cv2.erode(bgmask.astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool)
    out = half.copy(); out[bgmask] = 255
    ys, xs = np.where(~bgmask)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    crop = out[y0:y1 + 1, x0:x1 + 1]
    side = int(max(crop.shape[0], crop.shape[1]) * 1.08)
    canvas = np.full((side, side, 3), 255, np.float32)
    oy = (side - crop.shape[0]) // 2; ox = (side - crop.shape[1]) // 2
    canvas[oy:oy + crop.shape[0], ox:ox + crop.shape[1]] = crop
    im = Image.fromarray(canvas.astype(np.uint8)).resize((size, size), Image.LANCZOS)
    if out_p.endswith(".jpg"):
        im.save(out_p, quality=88)  # small enough for the relay copy limit
    else:
        im.save(out_p)

def hy_job(image, prefix, seed, res=8192, steps=50):
    g = {
        "1": {"class_type": "ImageOnlyCheckpointLoader", "inputs": {"ckpt_name": "hunyuan3d-dit-v2_fp16.safetensors"}},
        "2": {"class_type": "LoadImage", "inputs": {"image": image}},
        "3": {"class_type": "CLIPVisionEncode", "inputs": {"clip_vision": ["1", 1], "image": ["2", 0], "crop": "center"}},
        "4": {"class_type": "Hunyuan3Dv2Conditioning", "inputs": {"clip_vision_output": ["3", 0]}},
        "5": {"class_type": "EmptyLatentHunyuan3Dv2", "inputs": {"resolution": res, "batch_size": 1}},
        "6": {"class_type": "KSampler", "inputs": {"model": ["1", 0], "seed": seed, "steps": steps, "cfg": 8.0, "sampler_name": "euler",
                                                    "scheduler": "normal", "positive": ["4", 0], "negative": ["4", 1], "latent_image": ["5", 0], "denoise": 1.0}},
        "7": {"class_type": "VAEDecodeHunyuan3D", "inputs": {"samples": ["6", 0], "vae": ["1", 2], "num_chunks": 32000, "octree_resolution": 512}},
        "8": {"class_type": "VoxelToMesh", "inputs": {"voxel": ["7", 0], "algorithm": "surface net", "threshold": 0.6}},
        "9": {"class_type": "SaveGLB", "inputs": {"mesh": ["8", 0], "filename_prefix": prefix}},
    }
    return {"front": True, "prompt": g, "client_id": "ck_v87"}

if __name__ == "__main__":
    src, root = sys.argv[1], sys.argv[2]
    want = set(sys.argv[3:])
    b = Batch(root)
    for p in sorted(glob.glob(os.path.join(src, "*.png"))):
        name = os.path.basename(p).split("__")[1] if "__" in os.path.basename(p) else os.path.splitext(os.path.basename(p))[0]
        if want and name not in want: continue
        if name.startswith("face_"): continue  # 2D only
        inp = f"ck87_hy_{name}.jpg"
        front_square(p, os.path.join(root, "inputs", inp))
        b.add("hy_" + name, hy_job(inp, "ck87_hy_" + name, seed_of(name) % 1000000), port=8327)
    print("hunyuan jobs", b.n)
