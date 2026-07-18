-- 1. Eliminar políticas antiguas si existieran para evitar duplicados
DROP POLICY IF EXISTS "Permitir insercion anonima" ON storage.objects;
DROP POLICY IF EXISTS "Permitir update anonimo" ON storage.objects;
DROP POLICY IF EXISTS "Permitir select anonimo" ON storage.objects;

-- 2. Permitir la creación de nuevos archivos (INSERT)
CREATE POLICY "Permitir insercion anonima" 
ON storage.objects 
FOR INSERT 
TO anon 
WITH CHECK (bucket_id = 'raw-data-lake');

-- 3. Permitir la comprobación y sustitución (SELECT y UPDATE) necesaria para el 'upsert: true'
CREATE POLICY "Permitir update anonimo" 
ON storage.objects 
FOR UPDATE 
TO anon 
USING (bucket_id = 'raw-data-lake');

CREATE POLICY "Permitir select anonimo" 
ON storage.objects 
FOR SELECT 
TO anon 
USING (bucket_id = 'raw-data-lake');