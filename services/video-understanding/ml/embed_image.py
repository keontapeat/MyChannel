from __future__ import annotations
from typing import List
import numpy as np
from PIL import Image
import open_clip
import torch


_model = None
_preprocess = None
_device = "cuda" if torch.cuda.is_available() else "cpu"


def _load_model():
    global _model, _preprocess
    if _model is None:
        model, _, preprocess = open_clip.create_model_and_transforms('ViT-B-32', pretrained='openai')
        model = model.to(_device).eval()
        _model = model
        _preprocess = preprocess
    return _model, _preprocess


def embed_images(image_paths: List[str]) -> np.ndarray:
    model, preprocess = _load_model()
    images = [preprocess(Image.open(p).convert('RGB')).unsqueeze(0) for p in image_paths]
    batch = torch.cat(images, dim=0).to(_device)
    with torch.no_grad():
        feats = model.encode_image(batch)
        feats = feats / feats.norm(dim=-1, keepdim=True)
    return feats.cpu().numpy().astype(np.float32)



