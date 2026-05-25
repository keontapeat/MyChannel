-- ChannelMind schema

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TABLE IF NOT EXISTS videos (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    gcs_uri TEXT NOT NULL,
    duration_sec INT,
    width INT,
    height INT,
    transcript TEXT,
    status TEXT,
    created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS segments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    video_id UUID REFERENCES videos(id) ON DELETE CASCADE,
    t_start REAL,
    t_end REAL,
    keyframe_gcs TEXT,
    text_snippet TEXT,
    nsfw_score REAL,
    tags TEXT[],
    created_at TIMESTAMPTZ DEFAULT now()
);



