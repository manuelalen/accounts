INSERT INTO storage.buckets (id, name, public)
VALUES ('raw-data-lake', 'raw-data-lake', false)
ON CONFLICT (id) DO NOTHING;

UPDATE storage.buckets
SET allowed_mime_types = '{text/csv, application/json, application/octet-stream}'
WHERE id = 'raw-data-lake';