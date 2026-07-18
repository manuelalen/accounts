import { serve } from "https://deno.land/std@0.224.0/http/server.ts"

const GITHUB_TOKEN = Deno.env.get('GITHUB_TOKEN')
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const GITHUB_OWNER = "manuelalen"
const GITHUB_REPO = "accounts"

function parseCSV(text: string): { id: string; monto: string; concepto: string }[] {
  const lines = text.trim().split('\n')
  if (lines.length < 2) return []
  const result: { id: string; monto: string; concepto: string }[] = []
  for (let i = 1; i < lines.length; i++) {
    const cols = lines[i].split(',')
    if (cols.length >= 3) {
      result.push({
        id: cols[0].trim(),
        monto: cols[1].trim(),
        concepto: cols.slice(2).join(',').trim(),
      })
    }
  }
  return result
}

async function downloadCSV(path: string): Promise<string> {
  const url = `${SUPABASE_URL}/storage/v1/object/raw-data-lake/${path}`
  const res = await fetch(url, {
    headers: { Authorization: `Bearer ${SUPABASE_SERVICE_KEY}` },
  })
  if (!res.ok) throw new Error(`Storage download error: ${await res.text()}`)
  return await res.text()
}

async function insertIntoBronze(records: Record<string, unknown>[]) {
  const url = `${SUPABASE_URL}/rest/v1/stg_movimientos?schema=bronze`
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
      Prefer: 'return=minimal',
    },
    body: JSON.stringify(records),
  })
  if (!res.ok) {
    const body = await res.text()
    if (res.status === 404 && body.includes('relation') && body.includes('does not exist')) {
      console.error('La tabla bronze.stg_movimientos no existe. Ejecutá dbt primero o aplicá la migración.')
      return
    }
    throw new Error(`Insert error (${res.status}): ${body}`)
  }
}

async function triggerGitHubActions(ingestionDay: string, filePath: string) {
  const res = await fetch(`https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_REPO}/dispatches`, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${GITHUB_TOKEN}`,
      Accept: 'application/vnd.github+json',
      'Content-Type': 'application/json',
      'User-Agent': 'Supabase-Edge-Function',
    },
    body: JSON.stringify({
      event_type: 'storage_file_uploaded',
      client_payload: { file_path: filePath, execution_date: ingestionDay },
    }),
  })
  if (!res.ok) {
    const errText = await res.text()
    throw new Error(`GitHub API devolvió status ${res.status}: ${errText}`)
  }
}

serve(async (req) => {
  try {
    const payload = await req.json()

    if (payload.type === 'INSERT' && payload.record?.bucket_id === 'raw-data-lake') {
      const filePath: string = payload.record.name
      const pathParts = filePath.split('/')
      if (pathParts.length < 3) {
        return new Response(JSON.stringify({ success: false, error: 'ruta inválida' }), {
          status: 400,
          headers: { 'Content-Type': 'application/json' },
        })
      }

      const ingestionDay = `${pathParts[0]}-${pathParts[1]}-${pathParts[2]}`

      // 1. Descargar CSV
      const csvText = await downloadCSV(filePath)

      // 2. Parsear
      const rows = parseCSV(csvText)
      if (rows.length === 0) {
        console.log(`Sin filas en ${filePath}`)
        return new Response(JSON.stringify({ success: true, rows: 0 }), {
          headers: { 'Content-Type': 'application/json' },
        })
      }

      // 3. Insertar en bronze.stg_movimientos
      const now = new Date().toISOString()
      const records = rows.map((r) => ({
        id: r.id,
        monto: parseFloat(r.monto),
        concepto: r.concepto,
        parsed_at: now,
        ingestion_day: ingestionDay,
      }))
      await insertIntoBronze(records)

      // 4. Disparar dbt para capas superiores
      await triggerGitHubActions(ingestionDay, filePath)
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
