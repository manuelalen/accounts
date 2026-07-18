#!/usr/bin/env python3
import os
import sys
import csv
import io
import hashlib
from datetime import date, datetime
import requests
import psycopg2
from psycopg2.extras import execute_values

SUPABASE_URL = os.environ["SUPABASE_URL"]
ANON_KEY = os.environ["SUPABASE_ANON_KEY"]
DB_PASSWORD = os.environ["DBT_DB_PASSWORD"]

DB_HOST = "aws-1-eu-central-2.pooler.supabase.com"
DB_PORT = 6543
DB_USER = "postgres.fzdpeakdudjfyvgrhrqq"
DB_NAME = "postgres"

TODAY = date.today()
PREFIX = f"{TODAY.year}/{TODAY.month:02d}/{TODAY.day:02d}"
INGESTION_DAY = f"{TODAY.year}-{TODAY.month:02d}-{TODAY.day:02d}"

HEADERS = {"Authorization": f"Bearer {ANON_KEY}"}


def get_files_from_db() -> list[str]:
    conn = psycopg2.connect(
        host=DB_HOST, port=DB_PORT, user=DB_USER,
        password=DB_PASSWORD, dbname=DB_NAME,
    )
    with conn.cursor() as cur:
        cur.execute("""
            SELECT name FROM storage.objects
            WHERE bucket_id = 'raw-data-lake'
            AND name LIKE %s
            ORDER BY created_at DESC
        """, (f"{PREFIX}%",))
        rows = cur.fetchall()
    conn.close()
    return [r[0] for r in rows]


def download_csv(path: str) -> str:
    url = f"{SUPABASE_URL}/storage/v1/object/raw-data-lake/{path}"
    resp = requests.get(url, headers=HEADERS)
    resp.raise_for_status()
    return resp.text


def parse_importe(val: str) -> float:
    """Convierte formato español ('-29,20' o '-29.20') a float."""
    val = val.strip().replace('.', '').replace(',', '.')
    return float(val)


def parse_csv(text: str) -> list[dict]:
    reader = csv.DictReader(io.StringIO(text))
    fieldnames = reader.fieldnames or []

    print(f"  Columnas detectadas: {fieldnames}")

    if 'Concepto' in fieldnames and 'Importe' in fieldnames:
        print(f"  Mapeo directo: Concepto → concepto, Importe → monto")
        rows = []
        for row in reader:
            concepto = (row.get('Concepto') or '').strip()
            importe_raw = (row.get('Importe') or '0').strip()
            try:
                monto = parse_importe(importe_raw)
            except ValueError:
                print(f"  Importe inválido: '{importe_raw}'")
                continue
            if not concepto and monto == 0:
                continue
            # Generar id único por fila
            raw = f"{concepto}{monto}{INGESTION_DAY}"
            fid = hashlib.md5(raw.encode()).hexdigest()[:12]
            rows.append({"id": fid, "monto": str(monto), "concepto": concepto})
        return rows

    print(f"  Columnas no reconocidas, intentando parseo posicional...")
    lines = text.strip().split('\n')
    rows = []
    for i in range(1, len(lines)):
        cols = lines[i].split(',')
        if len(cols) >= 3:
            rid = hashlib.md5(lines[i].encode()).hexdigest()[:12]
            rows.append({
                "id": rid,
                "monto": cols[0].strip(),
                "concepto": cols[1].strip(),
            })
    return rows


def ensure_table(conn):
    with conn.cursor() as cur:
        cur.execute("CREATE SCHEMA IF NOT EXISTS bronze")
        cur.execute("""
            CREATE TABLE IF NOT EXISTS bronze.stg_movimientos (
                id TEXT,
                monto NUMERIC,
                concepto TEXT,
                parsed_at TIMESTAMPTZ DEFAULT NOW(),
                ingestion_day TEXT
            )
        """)
    conn.commit()


def main():
    files = get_files_from_db()
    if not files:
        print(f"files=0")
        return

    all_rows = []
    for path in files:
        print(f"Descargando {path}...")
        try:
            text = download_csv(path)
        except Exception as e:
            print(f"  Error: {e}")
            continue
        rows = parse_csv(text)
        if rows:
            print(f"  {len(rows)} filas")
            all_rows.extend(rows)
        else:
            print(f"  0 filas")

    if not all_rows:
        print(f"rows=0")
        return

    conn = psycopg2.connect(
        host=DB_HOST, port=DB_PORT, user=DB_USER,
        password=DB_PASSWORD, dbname=DB_NAME,
    )
    ensure_table(conn)

    now = datetime.utcnow().isoformat()
    records = [
        (r["id"], r["monto"], r["concepto"], now, INGESTION_DAY)
        for r in all_rows
    ]
    # Reemplazar datos de hoy para evitar duplicados
    with conn.cursor() as cur:
        cur.execute("DELETE FROM bronze.stg_movimientos WHERE ingestion_day = %s", (INGESTION_DAY,))
    execute_values(conn.cursor(), """
        INSERT INTO bronze.stg_movimientos (id, monto, concepto, parsed_at, ingestion_day)
        VALUES %s
    """, records)
    conn.commit()
    conn.close()

    print(f"rows={len(records)}")


if __name__ == "__main__":
    main()
