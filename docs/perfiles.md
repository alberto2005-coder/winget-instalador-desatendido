# Perfiles JSON

Un perfil es un archivo `.json` con la lista de programas que quieres instalar.
Sirve para **repetir la misma instalación en otro PC** (o tras reinstalar
Windows) sin tener que volver a marcar nada a mano.

## Crear un perfil

1. Ejecuta `INICIAR.bat` y entra en **1) Instalar programas**.
2. Elige la categoría, marca con `Espacio` lo que quieras y pulsa **`X`**.
3. Se guarda solo, en `perfiles\seleccion-AAAAmmdd-HHmmss.json`.

También puedes copiar uno de los de ejemplo y editarlo con el Bloc de notas.

> Perfil = "qué instalar". Si además quieres que un perfil también quite apps
> preinstaladas, rellena el campo `bloat` con sus patrones (ver más abajo).

## Campos

| Campo | Qué es | Ejemplo |
|:---|:---|:---|
| `nombre` | Nombre del perfil | `"basico"` |
| `creado` | Fecha de creación (informativo) | `"2026-10-05T18:20:00"` |
| `alcance` | `Auto`, `User` o `Machine` | `"Auto"` |
| `paquetes` | IDs de winget a instalar | `["Google.Chrome", "7zip.7zip"]` |
| `bloat` | Patrones de apps a quitar (opción 4) | `["Microsoft.BingNews"]` |

## Ejemplo

```json
{
  "nombre": "basico",
  "creado": "2026-10-05T18:20:00",
  "alcance": "Auto",
  "paquetes": [
    "Google.Chrome",
    "7zip.7zip",
    "VideoLAN.VLC",
    "Notepad++.Notepad++",
    "voidtools.Everything",
    "Microsoft.PowerToys",
    "Bitwarden.Bitwarden"
  ],
  "bloat": []
}
```

## Ejecutar un perfil

```powershell
# Opción cómoda: 2) Importar perfil JSON e instalar (desde el menú principal)

# O directamente, sin ventanas interactivas:
.\Instalar-Software.ps1 -Modo Instalar -Perfil .\perfiles\basico.json

# Con la lista "bloat" del propio perfil (des-bloat desatendido):
.\Instalar-Software.ps1 -Modo Limpieza -Perfil .\perfiles\basico.json
```

El script pide administrador por ti solo si hace falta.

## Perfiles incluidos

| Archivo | Programas | Para qué |
|:---|--:|:---|
| `basico.json` | 7 | Lo mínimo para un PC nuevo: navegador, 7-Zip, VLC, Notepad++, Everything, PowerToys, Bitwarden |
| `gaming.json` | 5 | Steam, Epic, Discord, Spotify, qBittorrent |
| `desarrollo.json` | 6 | Git, VS Code, Python, Node.js, Terminal, PowerShell 7 |
| `ofimatica.json` | 3 | LibreOffice, GIMP, IrfanView |
| `comunicacion.json` | 4 | Discord, Telegram, Slack, Zoom |

Los cinco traen `"bloat": []`: se rellenan solo si quieres que ese perfil también
haga des-bloat.

## Perfiles rápidos vs. perfiles JSON

| | Rápidos (teclas `1`–`9`) | JSON (tecla `X`) |
|:---|:---|:---|
| Dónde están | escritos en el script (`$script:Preajustes`) | en `perfiles\`, en disco |
| Sirven para | marcar un lote en un segundo | replicar la instalación en otro PC |
| Se pueden editar | sí, en el script | sí, con cualquier editor |

La lista completa de los rápidos está en [catalogo.md](catalogo.md).

## Notas

- Los IDs son los mismos en cualquier PC: la lista está en
  [catalogo.md](catalogo.md).
- **ID que no está en el catálogo**: en el paso 2 pulsa `G` y escríbelo a mano.
  Para que salga siempre en el menú, añádelo a `$script:Catalogo` en
  `Instalar-Software.ps1`.
- **`alcance`**: `Auto` (por defecto) no fuerza nada y cada instalador decide;
  `User` instala solo para tu cuenta; `Machine` para todos los usuarios
  (necesita administrador).
- **Errores de IDs** (`0x8A150014 / No package found`): un ID ha caducado.
  Compruébalo con la opción 5 del menú o `-Modo Verificar`. Ver
  [problemas.md](problemas.md).
