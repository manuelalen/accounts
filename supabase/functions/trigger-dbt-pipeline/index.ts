import { serve } from "https://deno.land/std@0.224.0/http/server.ts"

const GITHUB_TOKEN = Deno.env.get('GITHUB_TOKEN')
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? ''
const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
const GITHUB_OWNER = "manuelalen"
const GITHUB_REPO = "accounts"

interface CSVRow {
  id: string
  monto: string
  concepto: string
}

function parseCSV(text: string): CSVRow[] {
  const normalized = text.replace(/\r\n/g, '\n').trim()
  const lines = normalized.split('\n')
  if (lines.length < 2) return []

  const result: CSVRow[] = []
  for (let i = 1; i < lines.length; i++) {
    const line = lines[i].trim()
    if (!line) continue

    const cols = line.split(',')
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
  if (!res.ok) throw new Error(`Error descargando CSV (${res.status}): ${await res.text()}`)
  return await res.text()
}

async function ensureTable(): Promise<void> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/rpc/ensure_bronze_table_exists`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
    },
  })
  if (!res.ok && res.status !== 404) {
    const body = await res.text()
    console.error(`Error llamando ensure_bronze_table_exists: ${body}`)
  }
}

async function insertIntoBronze(records: Record<string, unknown>[]): Promise<number> {
  const res = await fetch(`${SUPABASE_URL}/rest/v1/stg_movimientos`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Content-Profile': 'bronze',
      Authorization: `Bearer ${SUPABASE_SERVICE_KEY}`,
      Prefer: 'return=representation',
    },
    body: JSON.stringify(records),
  })
  if (!res.ok) {
    const body = await res.text()
    throw new Error(`Error insertando en bronze.stg_movimientos (${res.status}): ${body}`)
  }
  return (await res.json()).length
}

async function triggerGitHubActions(ingestionDay: string, filePath: string): Promise<void> {
  if (!GITHUB_TOKEN) {
    console.warn('GITHUB_TOKEN no configurado, se salta GitHub Actions')
    return
  }
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
    console.warn(`GitHub API error (${res.status}): ${errText}`)
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

      // 1. Asegurar que la tabla existe
      await ensureTable()

      // 2. Descargar CSV
      const csvText = await downloadCSV(filePath)

      // 3. Parsear CSV
      const rows = parseCSV(csvText)
      if (rows.length === 0) {
        return new Response(JSON.stringify({
          success: false,
          error: `No se encontraron filas en el CSV (formato esperado: id,monto,concepto)`,
        }), {
          status: 422,
          headers: { 'Content-Type': 'application/json' },
        })
      }

      // 4. Insertar en bronze.stg_movimientos
      const now = new Date().toISOString()
      const records = rows.map((r) => ({
        id: r.id,
        monto: parseFloat(r.monto),
        concepto: r.concepto,
        parsed_at: now,
        ingestion_day: ingestionDay,
      }))
      const inserted = await insertIntoBronze(records)

      // 5. Disparar dbt (best-effort)
      await triggerGitHubActions(ingestionDay, filePath)

      return new Response(JSON.stringify({ success: true, rows: inserted }), {
        headers: { 'Content-Type': 'application/json' },
      })
    }

    return new Response(JSON.stringify({ success: true, rows: 0 }), {
      headers: { 'Content-Type': 'application/json' },
    })
  } catch (error) {
    return new Response(JSON.stringify({ success: false, error: error.message }), {
      status: 500,
      headers: { 'Content-Type': 'application/json' },
    })
  }
})
