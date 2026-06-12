"""
Sube elevaciones_amm.csv a public.elevaciones vía la API REST de Supabase
(PostgREST), en tandas. Evita la conexion directa a Postgres (IPv6).

Requiere variables de entorno:
  SUPABASE_URL       https://xxxx.supabase.co
  SUPABASE_ANON_KEY  llave anon/publishable
"""
import os
import csv
import json
import time
import urllib.request
import urllib.error

URL = os.environ["SUPABASE_URL"].rstrip("/") + "/rest/v1/elevaciones"
KEY = os.environ["SUPABASE_ANON_KEY"]
CSV = "elevaciones_amm.csv"
LOTE = 5000

HEADERS = {
    "apikey": KEY,
    "Authorization": "Bearer " + KEY,
    "Content-Type": "application/json",
    "Prefer": "return=minimal",
}


def leer():
    with open(CSV, newline="") as f:
        r = csv.reader(f)
        next(r)
        for lat, lon, elev in r:
            yield {"latitud": float(lat), "longitud": float(lon),
                   "elevacion": int(elev)}


def enviar(lote):
    data = json.dumps(lote).encode()
    req = urllib.request.Request(URL, data=data, headers=HEADERS, method="POST")
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.status


def main():
    buf, total, t0 = [], 0, time.time()
    for fila in leer():
        buf.append(fila)
        if len(buf) >= LOTE:
            enviar(buf)
            total += len(buf)
            print(f"  {total:,} filas...", flush=True)
            buf = []
    if buf:
        enviar(buf)
        total += len(buf)
    print(f"Listo: {total:,} filas en {time.time()-t0:.1f}s")


if __name__ == "__main__":
    main()
