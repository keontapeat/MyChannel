"""
Speech-to-Text AI Service
Real-time transcription for search, captions, and accessibility
"""
import os
import json
from flask import Flask, request, jsonify
from google.cloud import speech_v2
from google.cloud import storage
import tempfile

app = Flask(__name__)
speech_client = speech_v2.SpeechClient()
storage_client = storage.Client()
PROJECT_ID = os.environ.get('GOOGLE_CLOUD_PROJECT', 'mychannel-ca26d')

def transcribe_audio_gcs(gcs_uri: str, language: str = 'en-US') -> dict:
    """Transcribe audio from GCS using Google Speech-to-Text v2"""
    config = speech_v2.RecognitionConfig(
        auto_decoding_config=speech_v2.AutoDetectDecodingConfig(),
        language_codes=[language],
        model='long',
        features=speech_v2.RecognitionFeatures(
            enable_word_time_offsets=True,
            enable_word_confidence=True,
            enable_automatic_punctuation=True,
            enable_spoken_punctuation=True,
            profanity_filter=False,
            multi_channel_mode=speech_v2.RecognitionFeatures.MultiChannelMode.SEPARATE_CHANNEL_RECOGNITION,
        )
    )
    
    recognizer = f'projects/{PROJECT_ID}/locations/global/recognizers/_'
    
    request_obj = speech_v2.BatchRecognizeRequest(
        recognizer=recognizer,
        config=config,
        files=[speech_v2.BatchRecognizeFileMetadata(uri=gcs_uri)],
        recognition_output_config=speech_v2.RecognitionOutputConfig(
            inline_response_config=speech_v2.InlineOutputConfig()
        )
    )
    
    operation = speech_client.batch_recognize(request=request_obj)
    response = operation.result(timeout=300)
    
    words = []
    full_transcript = []
    
    for result in response.results.values():
        for res in result.inline_result.transcript.results:
            if res.alternatives:
                alt = res.alternatives[0]
                full_transcript.append(alt.transcript)
                
                for word_info in alt.words:
                    words.append({
                        'word': word_info.word,
                        'start': word_info.start_offset.total_seconds(),
                        'end': word_info.end_offset.total_seconds(),
                        'confidence': word_info.confidence
                    })
    
    return {
        'transcript': ' '.join(full_transcript),
        'words': words
    }

def generate_srt_captions(words: list) -> str:
    """Generate SRT subtitle file from word timestamps"""
    if not words:
        return ''
    
    srt_lines = []
    chunk_size = 8  # words per caption
    
    for i in range(0, len(words), chunk_size):
        chunk = words[i:i + chunk_size]
        if not chunk:
            continue
        
        idx = (i // chunk_size) + 1
        start = chunk[0]['start']
        end = chunk[-1]['end']
        text = ' '.join(w['word'] for w in chunk)
        
        srt_lines.append(f"{idx}")
        srt_lines.append(f"{_srt_time(start)} --> {_srt_time(end)}")
        srt_lines.append(text)
        srt_lines.append('')
    
    return '\n'.join(srt_lines)

def generate_vtt_captions(words: list) -> str:
    """Generate WebVTT subtitle file"""
    if not words:
        return ''
    
    vtt_lines = ['WEBVTT', '']
    chunk_size = 8
    
    for i in range(0, len(words), chunk_size):
        chunk = words[i:i + chunk_size]
        if not chunk:
            continue
        
        start = chunk[0]['start']
        end = chunk[-1]['end']
        text = ' '.join(w['word'] for w in chunk)
        
        vtt_lines.append(f"{_vtt_time(start)} --> {_vtt_time(end)}")
        vtt_lines.append(text)
        vtt_lines.append('')
    
    return '\n'.join(vtt_lines)

def _srt_time(seconds: float) -> str:
    h = int(seconds // 3600)
    m = int((seconds % 3600) // 60)
    s = int(seconds % 60)
    ms = int((seconds % 1) * 1000)
    return f"{h:02d}:{m:02d}:{s:02d},{ms:03d}"

def _vtt_time(seconds: float) -> str:
    h = int(seconds // 3600)
    m = int((seconds % 3600) // 60)
    s = int(seconds % 60)
    ms = int((seconds % 1) * 1000)
    return f"{h:02d}:{m:02d}:{s:02d}.{ms:03d}"

@app.route('/transcribe', methods=['POST'])
def transcribe():
    data = request.json
    video_id = data.get('videoId', '')
    audio_uri = data.get('audioUri', '')
    language = data.get('language', 'en-US')
    
    if not audio_uri:
        # Return sample transcription for testing
        return jsonify({
            'videoId': video_id,
            'transcript': 'Sample transcription text for testing purposes.',
            'words': [],
            'srt': '',
            'vtt': '',
            'language': language,
            'confidence': 0.95
        })
    
    result = transcribe_audio_gcs(audio_uri, language)
    
    srt = generate_srt_captions(result['words'])
    vtt = generate_vtt_captions(result['words'])
    
    avg_confidence = sum(w['confidence'] for w in result['words']) / max(len(result['words']), 1)
    
    return jsonify({
        'videoId': video_id,
        'transcript': result['transcript'],
        'words': result['words'],
        'wordCount': len(result['words']),
        'srt': srt,
        'vtt': vtt,
        'language': language,
        'confidence': round(avg_confidence, 3)
    })

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy', 'service': 'speech-to-text-ai'})

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 8080))
    app.run(host='0.0.0.0', port=port)
