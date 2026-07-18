#!/usr/bin/env python3
import os
import sys
import csv
import io
import json
from datetime import date, datetime
import requests
import psycopg2

SUPABASE_URL = os.environ["SUPABASE_URL"]
ANON_KEY = os.environ["SUPABASE_ANON_KEY"]
DB_PASSWORD = os.environ["DBT_DB_PASSWORD"]

DB_HOST = "aws-1-eu-central-2.pooler.supabase.com"
DB_PORT = 6543
DB_USER = "postgres.fzdpeakdudjfyvgrhrqq"
DB_NAME = "postgres"

HEADERS = {"Authorization": f"Bearer {ANON_KEY}"}

TODAY = date.today()
PREFIX = f"{TODAY.year}/{TODAY.month:02d}/{TODAY.day:02d}"


def list_files() -> list[dict]:
    url = f"{SUPABASE_URL}/storage/v1/object/list/raw-data-lake"
    resp = requests.post(url, headers=HEADERS, json={
        "prefix": PREFIX, "limit": 100, "offset": 0,
        "sortBy": {"column": "name", "order": "asc"},
    })
    if resp.status_code == 404:
        print(f"No hay archivos en {PREFIX}")
        return []
    resp.raise_for_status()
    return resp.json()


def download_csv(path: str) -> str:
    url = f"{SUPABASE_URL}/storage/v1/object/raw-data-lake/{path}"
    resp = requests.get(url, headers=HEADERS)
    resp.raise_for_status()
    return resp.text


def parse_csv(text: str) -> list[dict]:
    reader = csv.DictReader(io.StringIO(text))
    rows = []
    for row in reader:
        rid = row.get("id", "").strip()
        monto = row.get("monto", "").strip()
        concepto = row.get("concepto", "").strip()
        if rid or monto or concepto:
            rows.append({"id": rid, "monto": monto, "concepto": concepto})
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


def insert_records(conn, records: list[tuple]):
    from psycopg2.extras import execute_values
    with conn.cursor() as cur:
        execute_values(cur, """
            INSERT INTO bronze.stg_movimientos (id, monto, concepto, parsed_at, ingestion_day)
            VALUES %s
        """, records)
    conn.commit()


def main():
    files = list_files()
    if not files:
        print(f"files=0")
        return

    all_rows = []
    for f in files:
        name = f["name"]
        print(f"Descargando {name}...")
        text = download_csv(name)
        rows = parse_csv(text)
        if rows:
            print(f"  {len(rows)} filas en {name}")
            all_rows.extend(rows)

    if not all_rows:
        print(f"rows=0")
        return

    conn = psycopg2.connect(
        host=DB_HOST, port=DB_PORT, user=DB_USER,
        password=DB_PASSWORD, dbname=DB_NAME,
    )
    ensure_table(conn)

    now = datetime.utcnow().isoformat()
    ingestion_day = f"{TODAY.year}-{TODAY.month:02d}-{TODAY.day:02d}"
    records = [
        (r["id"], r["monto"], r["concepto"], now, ingestion_day)
        for r in all_rows
    ]
    insert_records(conn, records)
    conn.close()

    print(f"rows={len(records)}")


if __name__ == "__main__":
    main()
