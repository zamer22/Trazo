"""
Carga elevaciones del Área Metropolitana de Monterrey a Supabase.

Lee el GeoTIFF de Nuevo León (15 m), recorta a la caja del AMM,
baja la resolución a ~90 m y carga (lat, lon, elevacion) a la tabla
public.elevaciones vía COPY (rápido).

Uso:
  set SUPABASE_DB_URL=postgresql://postgres:CONTRASENA@db.xxxx.supabase.co:5432/postgres
  python cargar_elevaciones.py

Si no defines SUPABASE_DB_URL solo genera el CSV (elevaciones_amm.csv)
para que lo importes manualmente.
"""
import os
import csv
import io

import rasterio
from rasterio.windows import from_bounds

TIF = "19_Nuevo León_r15m_v4.tif"
CSV = "elevaciones_amm.csv"

# Caja del Área Metropolitana de Monterrey
LAT_MIN, LAT_MAX = 25.40, 26.05
LON_MIN, LON_MAX = -100.70, -99.85

STRIDE = 6          # 15 m × 6 ≈ 90 m
NODATA = -32768     # sin dato en el .hgt/.tif


def extraer():
    with rasterio.open(TIF) as src:
        win = from_bounds(LON_MIN, LAT_MIN, LON_MAX, LAT_MAX,
                          src.transform).round_offsets().round_lengths()
        data = src.read(1, window=win)
        t = src.window_transform(win)

    filas = []
    for i in range(0, data.shape[0], STRIDE):
        for j in range(0, data.shape[1], STRIDE):
            elev = int(data[i, j])
            if elev == NODATA:
                continue
            # centro de la celda
            lon = t.c + (j + 0.5) * t.a
            lat = t.f + (i + 0.5) * t.e
            filas.append((round(lat, 6), round(lon, 6), elev))
    return filas


def guardar_csv(filas):
    with open(CSV, "w", newline="") as f:
        w = csv.writer(f)
        w.writerow(["latitud", "longitud", "elevacion"])
        w.writerows(filas)
    print(f"CSV generado: {CSV}  ({len(filas):,} filas)")


def cargar_db(filas, url):
    import psycopg2
    buf = io.StringIO()
    for lat, lon, elev in filas:
        buf.write(f"{lat}\t{lon}\t{elev}\n")
    buf.seek(0)

    conn = psycopg2.connect(url)
    try:
        with conn.cursor() as cur:
            cur.execute("truncate public.elevaciones restart identity;")
            cur.copy_expert(
                "copy public.elevaciones (latitud, longitud, elevacion) "
                "from stdin with (format text)", buf)
        conn.commit()
        print(f"Cargadas {len(filas):,} filas a public.elevaciones")
    finally:
        conn.close()


if __name__ == "__main__":
    filas = extraer()
    print(f"Puntos extraídos del AMM (~90 m): {len(filas):,}")
    guardar_csv(filas)

    url = os.environ.get("SUPABASE_DB_URL")
    if url:
        cargar_db(filas, url)
    else:
        print("SUPABASE_DB_URL no definida -> solo se genero el CSV.")
