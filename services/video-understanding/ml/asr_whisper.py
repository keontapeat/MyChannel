from __future__ import annotations
from typing import List, Tuple, Dict

from faster_whisper import WhisperModel


def transcribe_audio(audio_path: str, model_size: str = "small") -> Tuple[str, List[Dict]]:
    """
    Transcribe an audio file with faster-whisper.
    Returns full transcript text and a list of segment dicts: {start, end, text}.
    """
    model = WhisperModel(model_size, device="auto")
    segments_iter, _ = model.transcribe(audio_path, vad_filter=True)

    segments: List[Dict] = []
    text_parts: List[str] = []
    for seg in segments_iter:
        item = {"start": float(seg.start), "end": float(seg.end), "text": seg.text.strip()}
        segments.append(item)
        if item["text"]:
            text_parts.append(item["text"])

    full_text = " ".join(text_parts).strip()
    return full_text, segments



