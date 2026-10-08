"""v8.7 Qwen-Image 2.1 job generator (farm :8322). Writes ComfyUI API prompts to <batch>/jobs and
reference images to <batch>/inputs. Text-only jobs and reference-conditioned (bust -> full body) jobs.
Job file names are "<port>__<name>.json"; output files come back as "<port>__<name>__<file>"."""
import json, os, shutil, sys, hashlib
_LOCK = json.load(open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "docs", "art", "style-lock-v87.json")))

STYLE = _LOCK["qwen"]["prefix"]
ALLY = _LOCK["qwen"]["ally_accent"]
ENEMY = _LOCK["qwen"]["enemy_accent"]
SHEET = ("Character turnaround reference sheet for 3D modeling: exactly two views side by side of the SAME character — "
         "FRONT view on the left half, BACK view on the right half. Full body from top of head to the soles of the feet, "
         "both feet fully visible, standing straight, symmetrical relaxed A-pose with arms angled about 35 degrees away "
         "from the body and open hands, legs slightly apart, orthographic camera at chest height, flat even studio light, "
         "no cast shadow, plain uniform light grey #D9DEE3 background, empty hands, no weapon, no props, no ground plane.")
NEG = _LOCK["qwen"]["negative"] + ", cropped feet, cropped head, weapon in hand, busy background"

def qwen_job(prompt, prefix, w, h, seed, refs=(), steps=28, neg=NEG, res=1024):
    g = {
        "1": {"class_type": "UNETLoader", "inputs": {"unet_name": "qwen_image_2.1_int8_convrot.safetensors", "weight_dtype": "default"}},
        "2": {"class_type": "CLIPLoader", "inputs": {"clip_name": "qwen3vl_8b_int8_convrot.safetensors", "type": "qwen_image", "device": "default"}},
        "3": {"class_type": "VAELoader", "inputs": {"vae_name": "qwen_image_2.1_vae_bf16.safetensors"}},
        "4": {"class_type": "TextEncodeQwenImage21", "inputs": {"clip": ["2", 0], "prompt": prompt, "negative_prompt": neg, "resolution": res}},
        "6": {"class_type": "EmptyLatentImage", "inputs": {"width": w, "height": h, "batch_size": 1}},
        "7": {"class_type": "KSampler", "inputs": {"seed": seed, "steps": steps, "cfg": 1.0, "sampler_name": "euler", "scheduler": "simple",
                                                    "denoise": 1.0, "model": ["1", 0], "positive": ["4", 0], "negative": ["4", 1], "latent_image": ["6", 0]}},
        "8": {"class_type": "VAEDecode", "inputs": {"samples": ["7", 0], "vae": ["3", 0]}},
        "9": {"class_type": "SaveImage", "inputs": {"filename_prefix": prefix, "images": ["8", 0]}},
    }
    if refs:
        g["4"]["inputs"]["vae"] = ["3", 0]
        for i, r in enumerate(refs):
            nid = str(20 + i)
            g[nid] = {"class_type": "LoadImage", "inputs": {"image": r}}
            g["4"]["inputs"]["images.image_%d" % (i + 1)] = [nid, 0]
    return {"prompt": g, "client_id": "ck_v87"}

def seed_of(name):
    return int(hashlib.md5(name.encode()).hexdigest()[:7], 16)

class Batch:
    def __init__(self, root):
        self.root = root
        os.makedirs(os.path.join(root, "jobs"), exist_ok=True)
        os.makedirs(os.path.join(root, "inputs"), exist_ok=True)
        self.n = 0
    def ref(self, src, name):
        shutil.copy(src, os.path.join(self.root, "inputs", name))
        return name
    def add(self, name, job, port=8322):
        with open(os.path.join(self.root, "jobs", "%d__%s.json" % (port, name)), "w") as f:
            json.dump(job, f, ensure_ascii=False)
        self.n += 1
