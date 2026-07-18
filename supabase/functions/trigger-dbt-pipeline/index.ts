import { serve } from "https://deno.land/std@0.224.0/http/server.ts"

const GITHUB_TOKEN = Deno.env.get('GITHUB_TOKEN')
const GITHUB_OWNER = "manuelalen"
const GITHUB_REPO = "accounts"

serve(async (req) => {
  try {
    const payload = await req.json()
    
    // Validar procedencia del bucket correcto
    if (payload.type === 'INSERT' && payload.record.bucket_id === 'raw-data-lake') {
      const filePath = payload.record.name // "YYYY/MM/DD/archivo.csv"
      
      const pathParts = filePath.split('/')
      if (pathParts.length >= 3) {
        const executionDate = `${pathParts[0]}-${pathParts[1]}-${pathParts[2]}` // "YYYY-MM-DD"
        
        // Llamada a la API de GitHub Actions
        const res = await fetch(`https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/dispatches`, {
          method: 'POST',
          headers: {
            'Authorization': `Bearer ${GITHUB_TOKEN}`,
            'Accept': 'application/vnd.github+json',
            'Content-Type': 'application/json',
            'User-Agent': 'Supabase-Edge-Function'
          },
          body: JSON.stringify({
            event_type: 'storage_file_uploaded',
            client_payload: {
              file_path: filePath,
              execution_date: executionDate
            }
          })
        })

        if (!res.ok) {
          const errText = await res.text()
          throw new Error(`GitHub API devolvió status ${res.status}: ${errText}`)
        }
      }
    }

    return new Response(JSON.stringify({ success: true }), { 
      headers: { "Content-Type": "application/json" } 
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { 
      status: 500, 
      headers: { "Content-Type": "application/json" } 
    })
  }
})