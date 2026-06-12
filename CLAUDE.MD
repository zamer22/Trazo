# Trazo — Contexto del Proyecto

## Descripción
App de iOS para generar rutas de running personalizadas con capa social y comunidad de corredores. Enfoque **Human Centered AI** resolviendo **ODS 11** (Ciudades y comunidades sostenibles).

---

## Features confirmadas

### Core — Generación de Rutas
- **Ruta por distancia** — el usuario indica km, se genera una ruta circular que sale y regresa al mismo punto
- **Ruta con destino** — el usuario indica destino + km, la app genera un camino que termine en ese punto
- **Clasificación por dificultad** — plana (<50m desnivel), moderada (50–150m), exigente (>150m) usando datos de elevación
- **Briefing de ruta con IA** — Foundation Models genera resumen en lenguaje natural antes de salir: desnivel, pines activos en la zona, tiempo estimado

### Social — Running Clubs
- Crear o unirse a un club
- Proponer rutas dentro del club
- Ruleta o votación entre rutas propuestas
- Chat del club via Supabase Realtime

### Comunidad — Pines de Runners
- Reportar obstáculo/daño con foto — Vision framework clasifica automáticamente (bache, obra, agua, obstáculo, peligro)
- Pines visibles en el mapa antes y durante la carrera
- Alertas cuando el corredor se acerca a un pin
- Decay automático — pines desaparecen después de X horas

### Perfil
- Historial de rutas completadas
- Nivel del corredor inferido del historial (sin formulario)
- Puntos por pines reportados

---

## Roadmap (no entra en el hackathon)
- Apple Watch + HealthKit
- Plan de entrenamiento para maratón
- Mapa de restaurantes y cafés post-carrera
- Grabación de rendimiento en tiempo real tipo Strava

---

## Stack Tecnológico

| Feature | Tecnología |
|---|---|
| Mapa y rutas | MapKit |
| GPS | CoreLocation |
| Clasificación de pines | Vision framework |
| Briefing de ruta | Foundation Models (on-device) |
| Backend y realtime | Supabase |
| Auth | Supabase Auth |
| Dataset calles | OSM (descargado, local) |
| Dataset elevación | INEGI CEM / SRTM NASA |

---

## Datasets

### Red de calles — OpenStreetMap (OSM)
- Fuente: `openstreetmap.org`
- Formato: `.osm` / `.pbf`
- Uso: grafo de calles para generación de waypoints
- Se descarga una vez y se cachea localmente — no es API en runtime

### Elevación — INEGI CEM (Continuo de Elevaciones Mexicano)
- Fuente: `inegi.org.mx/app/geo2/elevacionesmex/`
- Formato original: `.tif` (GeoTIFF)
- Resolución: 15m (mejor que SRTM para México)
- Estado actual: convirtiendo a `.hgt` con script Python + rasterio
- Tile para Monterrey: `N25W101.hgt`

#### Script de conversión (Windows)
```python
import rasterio
import numpy as np
import struct

with rasterio.open("tu_archivo.tif") as src:
    data = src.read(1).astype(np.int16)
    transform = src.transform
    rows, cols = data.shape

hgt_data = data[::-1]
total = rows * cols
processed = 0
last_percent = -1

with open("N25W101.hgt", "wb") as f:
    for i, row in enumerate(hgt_data):
        for val in row:
            f.write(struct.pack('>h', val))
        processed += cols
        percent = int((processed / total) * 100)
        if percent != last_percent and percent % 5 == 0:
            print(f"  {percent}% completado...")
            last_percent = percent

print(f"Shape: {rows}x{cols}")
print(f"Origin lat: {transform.f}")
print(f"Origin lon: {transform.c}")
print(f"Pixel size: {transform.a}")
```

#### Lectura del .hgt en Swift
```swift
func loadHGT(filename: String) -> [Int16] {
    guard let url = Bundle.main.url(forResource: filename, withExtension: "hgt"),
          let data = try? Data(contentsOf: url) else { return [] }
    return data.withUnsafeBytes { ptr in
        ptr.bindMemory(to: Int16.self).map { Int16(bigEndian: $0) }
    }
}

func elevation(lat: Double, lon: Double,
               tileLat: Int, tileLon: Int,
               data: [Int16]) -> Int16 {
    let row = Int((lat - Double(tileLat)) * 3600)
    let col = Int((lon - Double(tileLon)) * 3600)
    let index = (3600 - row) * 3601 + col
    return data[index]
}

func slope(from: CLLocationCoordinate2D,
           to: CLLocationCoordinate2D,
           data: [Int16]) -> Double {
    let e1 = Double(elevation(lat: from.latitude, lon: from.longitude,
                               tileLat: 25, tileLon: -101, data: data))
    let e2 = Double(elevation(lat: to.latitude, lon: to.longitude,
                               tileLat: 25, tileLon: -101, data: data))
    let distance = CLLocation(latitude: from.latitude, longitude: from.longitude)
        .distance(from: CLLocation(latitude: to.latitude, longitude: to.longitude))
    return ((e2 - e1) / distance) * 100
}
```

---

## Reglas del hackathon relevantes
- Solo frameworks de Apple + on-device AI
- Supabase y Firebase permitidos
- APIs gratuitas externas NO permitidas — datasets descargados sí
- APIs propias permitidas
- Deadline entrega: **viernes 12 de junio, 2:00 pm**
- Pitch: **4:00 pm – 6:00 pm**
- Presentación en Keynote, demo en simulador o dispositivo
- Rúbrica: Técnico (25pts) · Relevancia (15pts) · Originalidad (15pts) · Pitch (15pts) · UX/UI (15pts) · IA/ML (15pts)