# Captura de red automática con PowerShell

Este script automatiza una captura de red en Windows usando `netsh trace`, y después convierte el resultado a:

- `.etl`
- `.pcapng`
- `.csv`
- `.log`

Está basado en script PowerShell.

## Qué hace

1. Se autoejecuta como administrador.
2. Verifica que `etl2pcapng.exe` esté en la misma carpeta.
3. Pide el tiempo de captura en minutos.
4. Inicia la captura con `netsh trace`.
5. Espera el tiempo indicado.
6. Detiene la captura.
7. Convierte el archivo `.etl` a `.pcapng`.
8. Convierte el archivo `.etl` a `.csv`.
9. Guarda un log con todo el proceso.

## Requisitos

- Windows PowerShell 5.1 o superior.
- Ejecutarlo en Windows con privilegios de administrador.
- Tener `etl2pcapng.exe` en la misma carpeta que el script.

## Estructura esperada

```text
/tu-carpeta/
├── captura_red_automatica.ps1
└── etl2pcapng.exe
```

## Uso

### Opción 1: interactivo

```powershell
powershell -ExecutionPolicy Bypass -File .\captura_red_automatica.ps1
```

El script te pedirá los minutos de captura.

### Opción 2: pasar minutos por parámetro

```powershell
powershell -ExecutionPolicy Bypass -File .\captura_red_automatica.ps1 -Minutos 5
```

## Archivos generados

Se crean con fecha y hora en el nombre, por ejemplo:

```text
captura_2026-04-17_09-30-00.etl
captura_2026-04-17_09-30-00.pcapng
captura_2026-04-17_09-30-00.csv
captura_2026-04-17_09-30-00.log
```

## Notas

- Si `netsh trace` no inicia, normalmente es por permisos o políticas del equipo.
- Si no se genera el `.pcapng`, puede que el `.etl` no contenga paquetes convertibles.
- El `.csv` se genera con `tracerpt`.

## Comportamiento importante

- El script usa elevación automática a administrador.
- Guarda todos los archivos en la misma carpeta donde se encuentra el `.ps1`.
- Mantiene un log para revisión posterior.


