# Transcoder job templates for HLS ladders

variable "enable_transcoder_templates" {
  type        = bool
  description = "Whether to create Transcoder job templates"
  default     = false
}

resource "google_transcoder_job_template" "sd_ladder" {
  count = var.enable_transcoder_templates ? 1 : 0
  job_template_id = "sd-ladder"
  location = var.region

  config {
    inputs { key = "input0" }

    elementary_streams {
      key = "video_480"
      video_stream {
        h264 {
          height_pixels = 480
          width_pixels  = 854
          bitrate_bps   = 1200000
          frame_rate    = 30
          profile       = "high"
          gop_duration  = "3s"
        }
      }
    }

    elementary_streams {
      key = "audio_aac"
      audio_stream {
        codec               = "aac"
        bitrate_bps         = 128000
        channel_count       = 2
        sample_rate_hertz   = 48000
      }
    }

    mux_streams {
      key                 = "hls_480"
      container           = "ts"
      elementary_streams  = ["video_480", "audio_aac"]
    }

    manifests {
      file_name  = "master.m3u8"
      type       = "HLS"
      mux_streams = ["hls_480"]
    }
  }
}

resource "google_transcoder_job_template" "hd_ladder" {
  count = var.enable_transcoder_templates ? 1 : 0
  job_template_id = "hd-ladder"
  location = var.region

  config {
    inputs { key = "input0" }

    elementary_streams {
      key = "video_720"
      video_stream {
        h264 {
          height_pixels = 720
          width_pixels  = 1280
          bitrate_bps   = 2500000
          frame_rate    = 30
          profile       = "high"
          gop_duration  = "3s"
        }
      }
    }

    elementary_streams {
      key = "audio_aac"
      audio_stream {
        codec               = "aac"
        bitrate_bps         = 128000
        channel_count       = 2
        sample_rate_hertz   = 48000
      }
    }

    mux_streams {
      key                 = "hls_720"
      container           = "ts"
      elementary_streams  = ["video_720", "audio_aac"]
    }

    manifests {
      file_name  = "master.m3u8"
      type       = "HLS"
      mux_streams = ["hls_720"]
    }
  }
}

resource "google_transcoder_job_template" "uhd-ladder" {
  count = var.enable_transcoder_templates ? 1 : 0
  job_template_id = "uhd-ladder"
  location = var.region

  config {
    inputs { key = "input0" }

    elementary_streams {
      key = "video_1080"
      video_stream {
        h264 {
          height_pixels = 1080
          width_pixels  = 1920
          bitrate_bps   = 5000000
          frame_rate    = 30
          profile       = "high"
          gop_duration  = "3s"
        }
      }
    }
    elementary_streams {
      key = "audio_aac"
      audio_stream {
        codec               = "aac"
        bitrate_bps         = 128000
        channel_count       = 2
        sample_rate_hertz   = 48000
      }
    }

    mux_streams {
      key                 = "hls_1080"
      container           = "ts"
      elementary_streams  = ["video_1080", "audio_aac"]
    }
    manifests {
      file_name  = "master.m3u8"
      type       = "HLS"
      mux_streams = ["hls_1080"]
    }
  }
}


