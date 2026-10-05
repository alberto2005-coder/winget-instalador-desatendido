# Instalador de software desatendido con winget

Instala todos los programas que marques, **en silencio y de un tirón**, desde un
menú de consola con casillas. Incluye des-bloat, perfiles JSON, actualización
masiva y log completo.

## Uso rápido

Doble clic en **`INICIAR.bat`** → acepta la ventana UAC → marcas con `Espacio` → `Enter`.

> El `.bat` ya pide administrador por ti (una sola ventana) y salta la política
> de ejecución de scripts, así que no hace falta tocar nada más.

O desde PowerShell:

```powershell
cd $env:USERPROFILE\Downloads\InstaladorWinget
.\Instalar-Software.ps1
```

**Requisitos**: Windows 10 (1809 o superior) o Windows 11 con PowerShell 5.1
(ambos vienen con Windows) y winget — que el propio script instala si falta.
No necesita conexión a internet salvo para descargar los programas.

## Tamaño de la letra

Windows abre la ventana con una letra diminuta. El script la agranda solo
(mínimo 18 px) y ajusta la ventana a tu pantalla; no toca la configuración de
otras ventanas. Para forzar un tamaño:

```powershell
.\Instalar-Software.ps1 -Fuente 24      # alto en píxeles (0 = automático)
```

## Teclas del menú

| Tecla | Acción |
|---|---|
| `↑` `↓` `PgUp` `PgDn` `Home` `End` | Mover el cursor |
| `Espacio` | Marcar / desmarcar |
| `Enter` | Instalar lo marcado |
| `Esc` | Cancelar |
| `A` | Marcar todos |
| `N` | Ninguno |
| `I` | Invertir selección |
| `G` | Añadir un ID de winget a mano (el que quieras) |
| `X` | Guardar la selección como perfil JSON |
| `1`–`6` | Perfil rápido (Básico, Gaming, Desarrollo, Ofimática, Comunicación, Streaming) — solo en el paso 2 |

## Opciones del menú principal

1. **Instalar programas (elige categoría)** — dos pasos: primero eliges la
   categoría (lista corta) y después solo se listan sus programas. `Esc` en el
   paso 2 vuelve a las categorías.
2. **Importar perfil JSON e instalar** — desatendido a partir de un perfil guardado (instala los paquetes y aplica el des-bloat automáticamente).
3. **Actualizar todo** — `winget upgrade --all` con confirmación previa.
4. **Quitar apps preinstaladas** — des-bloat (Candy Crush, noticias, Cortana…);
   la selección por defecto solo marca las que son ruido.
5. **Comprobar los IDs del catálogo** — valida uno a uno todos los IDs con
   `winget show` y te dice cuáles han dejado de existir (y cómo buscar el nuevo).

## Modos de línea de comandos

```powershell
# Instalación totalmente desatendida desde un perfil (instala los paquetes Y quita el bloat)
.\Instalar-Software.ps1 -Modo Instalar -Perfil .\perfiles\gaming.json

# Actualizar todo lo instalado
.\Instalar-Software.ps1 -Modo Actualizar

# Des-bloat interactivo (puedes guardar tu selección de limpieza pulsando la tecla 'X')
.\Instalar-Software.ps1 -Modo Limpieza

# Aplicar SOLO la limpieza "bloat" de un perfil, sin instalar sus paquetes
.\Instalar-Software.ps1 -Modo Limpieza -Perfil .\perfiles\gaming.json

# Comprobar que ningún ID del catálogo/perfiles haya cambiado en winget
.\Instalar-Software.ps1 -Modo Verificar

# Regenerar docs/catalogo.md tras añadir o quitar programas del catálogo
.\Instalar-Software.ps1 -Modo Catalogo

# Opciones extra
.\Instalar-Software.ps1 -Todo                # pre-marca todo el catálogo
.\Instalar-Software.ps1 -NoAdmin             # sin elevación (solo usuario actual)
.\Instalar-Software.ps1 -Alcance User        # Auto | Machine | User
.\Instalar-Software.ps1 -Fuente 24           # tamaño de letra en px (0 = automático)
.\Instalar-Software.ps1 -Ayuda               # ayuda completa (Get-Help)
```

Hay 5 perfiles de ejemplo en `perfiles\` (`basico`, `gaming`, `desarrollo`,
`ofimatica`, `comunicacion`); con la tecla `X` guardas los tuyos al lado.

Cada ejecución termina con un **código de salida**: `0` = todo bien,
`1` = hubo fallos, `2` = error de configuración.

## Estructura

```
InstaladorWinget/
├── INICIAR.bat              ← lo que se ejecuta a diario
├── Instalar-Software.ps1    ← todo el motor
├── README.md                ← este archivo
├── CHANGELOG.md             ← qué cambia en cada versión
├── LICENSE                  ← MIT
├── .gitignore               ← no versiona los logs
├── docs/
│   ├── catalogo.md          ← los 83 programas con su ID de winget (generado con -Modo Catalogo)
│   ├── perfiles.md          ← cómo se crean y se usan los perfiles JSON
│   └── problemas.md         ← errores frecuentes y cómo salir de ellos
├── log/                     ← un .log por ejecución (se conservan los 20 últimos)
└── perfiles/                ← 5 perfiles de ejemplo + los que exportes (JSON)
```

## Documentación

| Documento | Qué cuenta |
|:--|:--|
| [docs/catalogo.md](docs/catalogo.md) | Los 83 programas con su ID de winget, los perfiles rápidos y las apps del des-bloat |
| [docs/perfiles.md](docs/perfiles.md) | El formato JSON, cómo crear un perfil con la tecla `X` y cómo ejecutarlo en otro PC |
| [docs/problemas.md](docs/problemas.md) | Síntoma → causa → solución (IDs rotos, ventana congelada, UAC, winget ausente…) |
| [CHANGELOG.md](CHANGELOG.md) | Qué se ha añadido y corregido en cada versión |


## Perfil JSON

Se crea con la tecla `X` dentro del menú:

```json
{
  "nombre": "seleccion-20261005-141908",
  "creado": "2026-10-05T14:19:08",
  "alcance": "Auto",
  "paquetes": ["Google.Chrome", "7zip.7zip", "Valve.Steam"],
  "bloat": []
}
```

Cópialo a otro PC nuevo y ejecuta `-Modo Instalar -Perfil ...` para replicar la
misma instalación.

## Mantenimiento: versiones e IDs

- **Versiones**: no hay que tocar nada. El script nunca fija una versión, solo
  pone `--id`, así que winget instala siempre la última que haya en el repositorio
  y la opción 3 del menú las actualiza todas.
- **IDs**: winget de vez en cuando renombra un paquete (le pasa a cualquiera:
  antes era `NodeJS.NodeJS` y ahora es `OpenJS.NodeJS`). Si eso ocurre,
  la instalación falla con `0x8A150014 / No package found`. Comprueba cuando
  quieras con la **opción 5 del menú** o `-Modo Verificar`: recorre catálogo,
  perfiles rápidos y `perfiles\*.json`, te lista los IDs rotos y te da el
  `winget search` exacto para encontrar el sustituto.
- **Catálogo**: si añades o quitas programas en `$script:Catalogo`, vuelve a
  generar la documentación con `.\Instalar-Software.ps1 -Modo Catalogo` para
  que `docs/catalogo.md` no se quede desfasado.

## Notas y límites

- **Apps de la Microsoft Store** (Netflix, Prime Video, Disney+, Crunchyroll,
  Apple TV, WhatsApp, Revo Uninstaller): llevan ID de tienda (`9...`) porque
  solo se distribuyen allí. Van con la fuente `msstore`, que Windows trae
  activada; el script acepta los acuerdos solo. Ojo: para Revo hay dos IDs en
  winget y el del repositorio (`RevoUninstaller.RevoUninstaller`) va desde 2020,
  por eso usamos el de la tienda.
- **Nota WhatsApp**: va con el ID de la Microsoft Store (`9NKSQGP7F2NH`), ya
  que la app oficial solo se distribuye allí.
- **Instaladores que ignoran `--silent`**: algunos (Steam, por ejemplo) abren su
  asistente igualmente. Es comportamiento del instalador, no del script.
- **winget ausente**: si tu PC no tiene winget, el script descarga e instala
  *App Installer* con sus dependencias (VCLibs + Windows App Runtime) desde la
  release oficial de GitHub. Requiere conexión.
- **Si la descarga se corta**, el script reintenta y reanuda automáticamente;
  verifica el tamaño y la integridad antes de usar el archivo.
- **Alcance**: `Auto` (por defecto) no fuerza `--scope` y deja que cada
  instalador use su modo habitual; `Machine` instala para todos los usuarios
  (requiere admin) y `User` solo para tu cuenta.

## Contribuir y reportar fallos

1. Comprueba si es un ID caducado: opción **5** del menú (o `-Modo Verificar`).
2. Mira el `log\instalacion-*.log` de la ejecución fallida.
3. Abre un issue con ese log y con la salida de la comprobación de IDs.

Guía completa en [docs/problemas.md](docs/problemas.md).

## Licencia

[MIT](LICENSE). Úsalo, cópialo y modifícalo libremente.
