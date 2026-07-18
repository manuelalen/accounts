CREATE POLICY "Permitir subidas anonimas" 
ON storage.objects 
FOR INSERT 
TO anon 
WITH CHECK (bucket_id = 'raw-data-lake');