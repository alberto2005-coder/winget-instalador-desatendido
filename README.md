# Instalador desatendido con winget

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1-5391FE?logo=powershell&logoColor=white)](https://learn.microsoft.com/powershell/)
[![Windows](https://img.shields.io/badge/Windows-10%201809%2B%20%7C%2011-0078D6?logo=windows&logoColor=white)](https://www.microsoft.com/windows)
[![winget](https://img.shields.io/badge/winget-App%20Installer-00B4D8)](https://learn.microsoft.com/windows/package-manager/)
[![MIT](https://img.shields.io/badge/Licencia-MIT-green)](LICENSE)

[Español](#español) · [English](#english)

---

## Español

### Índice

- [Descripción](#descripción)
- [Inicio rápido](#inicio-rápido)
- [Requisitos](#requisitos)
- [Teclas del menú](#teclas-del-menú)
- [Opciones del menú principal](#opciones-del-menú-principal)
- [Modos de línea de comandos](#modos-de-línea-de-comandos)
- [Perfiles JSON](#perfiles-json)
- [Des-bloat](#des-bloat)
- [Comprobación de IDs](#comprobación-de-ids)
- [Logs y códigos de salida](#logs-y-códigos-de-salida)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Documentación](#documentación)
- [Notas y límites](#notas-y-límites)
- [Licencia](#licencia)

### Descripción

Script de **PowerShell** para Windows que instala de golpe, **en silencio y sin interacción**, los programas que marques en un menú de consola con casillas. Incluye un **catálogo de 83 programas en 11 categorías**, cinco perfiles de ejemplo, eliminación de aplicaciones preinstaladas (*des-bloat*), actualización masiva, verificación de identificadores de winget y registro completo en `log/`.

La idea es reconstruir un equipo recién formateado en una sola pasada: marcas lo que quieres, pulsas `Enter` y el script instala todo con `--silent` y acepta los acuerdos de licencia por ti.

### Inicio rápido

1. Descarga el repositorio.
2. Doble clic en **`INICIAR.bat`**.
3. Acepta la ventana de UAC (el `.bat` ya pide administrador y evita bloqueos de la política de ejecución).
4. Marca con `Espacio`, confirma con `Enter`.

Desde PowerShell:

```powershell
cd $env:USERPROFILE\Downloads\InstaladorWinget
.\Instalar-Software.ps1
```

### Requisitos

| Requisito | Detalle |
|---|---|
| Windows | 10 (1809 o superior) o Windows 11 |
| PowerShell | 5.1 (viene con Windows) |
| winget | *App Installer*; el script lo instala si falta |
| Conexión | Solo para descargar los programas |

Si winget no está presente, el script descarga *App Installer* con sus dependencias (VCLibs y Windows App Runtime) desde la release oficial de GitHub.

### Teclas del menú

| Tecla | Acción |
|---|---|
| `↑` `↓` `PgUp` `PgDn` `Home` `End` | Mover el cursor |
| `Espacio` | Marcar / desmarcar |
| `Enter` | Instalar lo marcado |
| `Esc` | Cancelar (en el paso 2 vuelve a las categorías) |
| `A` | Marcar todos |
| `N` | Ninguno |
| `I` | Invertir selección |
| `G` | Añadir a mano un ID de winget |
| `X` | Guardar la selección como perfil JSON |
| `1`–`6` | Perfil rápido: Básico, Gaming, Desarrollo, Ofimática, Comunicación, Streaming |

La ventana ajusta la fuente automáticamente (mínimo 18 px) para que no aparezca diminuta. Puedes forzar el tamaño:

```powershell
.\Instalar-Software.ps1 -Fuente 24   # alto en píxeles (0 = automático)
```

### Opciones del menú principal

1. **Instalar programas (elige categoría)** — dos pasos: primero la categoría y después solo sus programas.
2. **Importar perfil JSON e instalar** — instala los paquetes del perfil y aplica su des-bloat, sin preguntar.
3. **Actualizar todo** — `winget upgrade --all` con confirmación previa.
4. **Quitar apps preinstaladas** — analiza el equipo y muestra solo las que están realmente instaladas (`Detectadas X de 33`); si no encuentra ninguna, lista las 33 completas. La selección por defecto marca las que son ruido.
5. **Comprobar los IDs del catálogo** — valida uno a uno con `winget show` y avisa de los que ya no existen.

### Modos de línea de comandos

```powershell
# Instalación desatendida completa desde un perfil (paquetes + des-bloat)
.\Instalar-Software.ps1 -Modo Instalar -Perfil .\perfiles\gaming.json

# Actualizar todo lo instalado
.\Instalar-Software.ps1 -Modo Actualizar

# Des-bloat interactivo (la tecla 'X' guarda la selección)
.\Instalar-Software.ps1 -Modo Limpieza

# Solo la limpieza de un perfil, sin instalar sus paquetes
.\Instalar-Software.ps1 -Modo Limpieza -Perfil .\perfiles\gaming.json

# Comprobar que ningún ID del catálogo o de los perfiles ha cambiado
.\Instalar-Software.ps1 -Modo Verificar

# Regenerar docs/catalogo.md tras tocar el catálogo
.\Instalar-Software.ps1 -Modo Catalogo
```

Opciones adicionales:

```powershell
.\Instalar-Software.ps1 -Todo                # pre-marca todo el catálogo
.\Instalar-Software.ps1 -NoAdmin             # sin elevación (solo usuario actual)
.\Instalar-Software.ps1 -Alcance User        # Auto | Machine | User
.\Instalar-Software.ps1 -Fuente 24           # tamaño de letra en px (0 = automático)
.\Instalar-Software.ps1 -Ayuda               # ayuda completa (Get-Help)
```

**Alcance**: `Auto` (por defecto) no fuerza `--scope` y deja que cada instalador use su modo habitual; `Machine` instala para todos los usuarios (requiere admin) y `User` solo para la cuenta actual.

### Perfiles JSON

La tecla `X` guarda la selección actual como perfil reutilizable:

```json
{
  "nombre": "seleccion-20261005-141908",
  "creado": "2026-10-05T14:19:08",
  "alcance": "Auto",
  "paquetes": ["Google.Chrome", "7zip.7zip", "Valve.Steam"],
  "bloat": []
}
```

Copia el archivo a otro PC y ejecuta `-Modo Instalar -Perfil ...` para replicar la misma instalación. En `perfiles/` vienen cinco ejemplos: `basico`, `gaming`, `desarrollo`, `ofimatica` y `comunicacion`.

### Des-bloat

La opción 4 del menú y el modo `Limpieza` quitan aplicaciones preinstaladas que suelen ser ruido (Candy Crush, noticias, Cortana…). El script:

1. Analiza el equipo y filtra las que existen de verdad.
2. Propone una selección por defecto con las prescindibles.
3. Pide confirmación antes de desinstalar.

Puedes guardar tu propia lista de limpieza con la tecla `X` y aplicarla en otro equipo desde un perfil.

### Comprobación de IDs

winget renombra paquetes de vez en cuando (por ejemplo, `NodeJS.NodeJS` pasó a ser `OpenJS.NodeJS`). Cuando eso ocurre, la instalación falla con `0x8A150014 / No package found`.

La opción 5 del menú o `-Modo Verificar` recorre el catálogo, los perfiles rápidos y `perfiles/*.json`, lista los IDs rotos y muestra el `winget search` exacto para encontrar el sustituto.

Si tecleas un ID inexistente con la tecla `G`, el script comprueba si en realidad es una app del des-bloat y, si no lo es, lanza `winget search` y propone hasta tres parecidos.

### Logs y códigos de salida

- Cada ejecución escribe `log\instalacion-<fecha>.log`; se conservan los **20 últimos**.
- Códigos de salida: `0` = todo correcto, `1` = hubo fallos, `2` = error de configuración.

### Estructura del proyecto

```text
winget-instalador-desatendido/
├── INICIAR.bat              # Lanzador diario (UAC + PowerShell)
├── Instalar-Software.ps1    # Motor: catálogo, menú, instalación y des-bloat
├── README.md
├── CHANGELOG.md
├── LICENSE                  # MIT
├── .gitignore               # Excluye log/
├── docs/
│   ├── catalogo.md          # Los 83 programas con su ID
│   ├── perfiles.md          # Formato y uso de los perfiles
│   └── problemas.md         # Síntoma → causa → solución
├── log/                     # Registros (últimos 20)
└── perfiles/                # 5 perfiles de ejemplo + los exportados
```

### Documentación

| Documento | Contenido |
|---|---|
| [docs/catalogo.md](docs/catalogo.md) | Los 83 programas con su ID, perfiles rápidos y apps del des-bloat |
| [docs/perfiles.md](docs/perfiles.md) | Formato JSON, creación con la tecla `X` y uso en otro PC |
| [docs/problemas.md](docs/problemas.md) | IDs rotos, ventana congelada, UAC, winget ausente y más |
| [CHANGELOG.md](CHANGELOG.md) | Cambios de cada versión |

### Notas y límites

- **Versiones**: el script nunca fija una versión, solo pasa `--id`, así que winget instala siempre la última disponible. La opción 3 las actualiza todas.
- **Apps de Microsoft Store** (Netflix, Prime Video, Disney+, Crunchyroll, Apple TV, WhatsApp, Revo Uninstaller): usan IDs de tienda (`9...`) y la fuente `msstore`, que Windows trae activada. WhatsApp, por ejemplo, solo se distribuye allí (`9NKSQGP7F2NH`).
- **Instaladores que ignoran `--silent`**: algunos, como Steam, abren su asistente igualmente. Es comportamiento del instalador, no del script.
- **Descargas interrumpidas**: el script reintenta y reanuda, y verifica tamaño e integridad antes de usar el archivo.
- **Catálogo**: si añades o quitas programas en `$script:Catalogo`, regenera la documentación con `-Modo Catalogo` para que `docs/catalogo.md` no quede desfasada.
- **Sin conexión** no se puede instalar nada, aunque el menú y la ayuda funcionan.

### Licencia

**MIT** — consulta [LICENSE](LICENSE).

---

## English

### Table of contents

- [Overview](#overview)
- [Quick start](#quick-start)
- [Requirements](#requirements)
- [Menu keys](#menu-keys)
- [Main menu options](#main-menu-options)
- [Command-line modes](#command-line-modes)
- [JSON profiles](#json-profiles)
- [De-bloat](#de-bloat)
- [ID verification](#id-verification)
- [Logs and exit codes](#logs-and-exit-codes)
- [Project structure](#project-structure)
- [Documentation](#documentation)
- [Notes and limits](#notes-and-limits)
- [License](#license)

### Overview

A Windows **PowerShell** script that installs the programs you tick in a console checkbox menu **silently and in one go**. It ships a **catalogue of 83 programs across 11 categories**, five sample profiles, preinstalled-app removal (*de-bloat*), bulk updates, winget identifier verification and full logging to `log/`.

The goal is to rebuild a freshly formatted machine in a single pass: tick what you want, press `Enter`, and the script installs everything with `--silent` and accepts licence agreements for you.

### Quick start

1. Download the repository.
2. Double-click **`INICIAR.bat`**.
3. Accept the UAC prompt (the `.bat` requests elevation and bypasses execution-policy blocks).
4. Tick with `Space`, confirm with `Enter`.

From PowerShell:

```powershell
cd $env:USERPROFILE\Downloads\InstaladorWinget
.\Instalar-Software.ps1
```

### Requirements

| Requirement | Detail |
|---|---|
| Windows | 10 (1809 or later) or Windows 11 |
| PowerShell | 5.1 (bundled with Windows) |
| winget | *App Installer*; the script installs it when missing |
| Connection | Only to download the programs |

When winget is absent, the script downloads *App Installer* with its dependencies (VCLibs and Windows App Runtime) from the official GitHub release.

### Menu keys

| Key | Action |
|---|---|
| `↑` `↓` `PgUp` `PgDn` `Home` `End` | Move the cursor |
| `Space` | Tick / untick |
| `Enter` | Install the selection |
| `Esc` | Cancel (in step 2 it returns to categories) |
| `A` | Select all |
| `N` | Select none |
| `I` | Invert selection |
| `G` | Add a winget ID manually |
| `X` | Save the selection as a JSON profile |
| `1`–`6` | Quick profile: Basic, Gaming, Development, Office, Communication, Streaming |

The window scales its font automatically (minimum 18 px) so it does not open tiny. You can force a size:

```powershell
.\Instalar-Software.ps1 -Fuente 24   # height in pixels (0 = automatic)
```

### Main menu options

1. **Install programs (pick a category)** — two steps: category first, then only its programs.
2. **Import a JSON profile and install** — installs the profile's packages and applies its de-bloat with no prompts.
3. **Update everything** — `winget upgrade --all` after confirmation.
4. **Remove preinstalled apps** — scans the machine and shows only what is actually installed (`Detected X of 33`); when it finds none it lists all 33. The default selection ticks the bloat.
5. **Verify catalogue IDs** — checks each one with `winget show` and reports the ones that no longer exist.

### Command-line modes

```powershell
# Fully unattended install from a profile (packages + de-bloat)
.\Instalar-Software.ps1 -Modo Instalar -Perfil .\perfiles\gaming.json

# Update everything installed
.\Instalar-Software.ps1 -Modo Actualizar

# Interactive de-bloat (press 'X' to save the selection)
.\Instalar-Software.ps1 -Modo Limpieza

# Only a profile's cleanup, without installing its packages
.\Instalar-Software.ps1 -Modo Limpieza -Perfil .\perfiles\gaming.json

# Check that no catalogue or profile ID has changed
.\Instalar-Software.ps1 -Modo Verificar

# Regenerate docs/catalogo.md after editing the catalogue
.\Instalar-Software.ps1 -Modo Catalogo
```

Extra switches:

```powershell
.\Instalar-Software.ps1 -Todo                # pre-tick the whole catalogue
.\Instalar-Software.ps1 -NoAdmin             # no elevation (current user only)
.\Instalar-Software.ps1 -Alcance User        # Auto | Machine | User
.\Instalar-Software.ps1 -Fuente 24           # font size in px (0 = automatic)
.\Instalar-Software.ps1 -Ayuda               # full help (Get-Help)
```

**Scope**: `Auto` (default) does not force `--scope` and lets each installer use its usual mode; `Machine` installs for all users (admin required) and `User` only for the current account.

### JSON profiles

Press `X` to save the current selection as a reusable profile:

```json
{
  "nombre": "selection-20261005-141908",
  "creado": "2026-10-05T14:19:08",
  "alcance": "Auto",
  "paquetes": ["Google.Chrome", "7zip.7zip", "Valve.Steam"],
  "bloat": []
}
```

Copy the file to another PC and run `-Modo Instalar -Perfil ...` to replicate the same setup. `perfiles/` includes five examples: `basico`, `gaming`, `desarrollo`, `ofimatica` and `comunicacion`.

### De-bloat

Option 4 and the `Limpieza` mode remove preinstalled apps that usually amount to noise (Candy Crush, news, Cortana…). The script:

1. Scans the machine and filters the ones that really exist.
2. Proposes a default selection with the expendable ones.
3. Asks for confirmation before uninstalling.

You can save your own cleanup list with `X` and apply it on another machine from a profile.

### ID verification

winget renames packages from time to time (for example, `NodeJS.NodeJS` became `OpenJS.NodeJS`). When that happens, installation fails with `0x8A150014 / No package found`.

Option 5 or `-Modo Verificar` walks the catalogue, the quick profiles and `perfiles/*.json`, lists the broken IDs and prints the exact `winget search` to find the replacement.

If you type a non-existent ID with `G`, the script checks whether it is actually a de-bloat app and, if not, runs `winget search` and suggests up to three similar packages.

### Logs and exit codes

- Every run writes `log\instalacion-<date>.log`; the **last 20** are kept.
- Exit codes: `0` = all good, `1` = some failures, `2` = configuration error.

### Project structure

```text
winget-instalador-desatendido/
├── INICIAR.bat              # Daily launcher (UAC + PowerShell)
├── Instalar-Software.ps1    # Engine: catalogue, menu, install and de-bloat
├── README.md
├── CHANGELOG.md
├── LICENSE                  # MIT
├── .gitignore               # Ignores log/
├── docs/
│   ├── catalogo.md          # The 83 programs with their IDs
│   ├── perfiles.md          # Profile format and usage
│   └── problemas.md         # Symptom → cause → fix
├── log/                     # Logs (last 20)
└── perfiles/                # 5 sample profiles + exported ones
```

### Documentation

| Document | Contents |
|---|---|
| [docs/catalogo.md](docs/catalogo.md) | The 83 programs with their IDs, quick profiles and de-bloat apps |
| [docs/perfiles.md](docs/perfiles.md) | JSON format, creating one with `X` and using it on another PC |
| [docs/problemas.md](docs/problemas.md) | Broken IDs, frozen window, UAC, missing winget and more |
| [CHANGELOG.md](CHANGELOG.md) | Changes per release |

### Notes and limits

- **Versions**: the script never pins a version, it only passes `--id`, so winget always installs the latest available. Option 3 updates them all.
- **Microsoft Store apps** (Netflix, Prime Video, Disney+, Crunchyroll, Apple TV, WhatsApp, Revo Uninstaller): they use store IDs (`9...`) and the `msstore` source, which Windows enables by default. WhatsApp, for instance, is only distributed there (`9NKSQGP7F2NH`).
- **Installers that ignore `--silent`**: a few, such as Steam, still open their wizard. That is the installer's behaviour, not the script's.
- **Interrupted downloads**: the script retries, resumes and verifies size and integrity before using the file.
- **Catalogue**: if you add or remove programs in `$script:Catalogo`, regenerate the docs with `-Modo Catalogo` so `docs/catalogo.md` stays current.
- **Offline** you cannot install anything, although the menu and help still work.

### License

**MIT** — see [LICENSE](LICENSE).
