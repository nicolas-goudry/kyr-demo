SELECT 'CREATE DATABASE "kyr-demo"'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = 'kyr-demo')\gexec

\c "kyr-demo"

CREATE TABLE IF NOT EXISTS media_metadata (
  id SERIAL PRIMARY KEY,
  file_path TEXT NOT NULL,
  duration NUMERIC,
  codec VARCHAR(50),
  bitrate BIGINT,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
