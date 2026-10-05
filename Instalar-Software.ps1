#Requires -Version 5.1

<#
.SYNOPSIS
    Instalador de software desatendido con winget (menú con casillas).

.DESCRIPTION
    Herramienta de consola que permite marcar con casillas qué programas
    quieres instalar (Chrome, VLC, Steam, 7-Zip, ...) y los instala todos
    en silencio y de un tirón. Además incluye:

      - Perfiles guardados en JSON (exportar/importar selección)
      - Perfiles rápidos: Básico, Gaming, Desarrollo, Ofimática, Comunicación
      - Modo desatendido total (-Modo Instalar -Perfil x.json)
      - Actualización de todo lo instalado (winget upgrade --all)
      - Des-bloat: quitar apps preinstaladas de Windows
      - Log con marca de tiempo y resumen final con códigos de salida

.PARAMETER Modo
    Menu (por defecto), Instalar, Actualizar, Limpieza, Verificar o Catalogo
    (regenera docs/catalogo.md desde el propio script).

.PARAMETER Perfil
    Ruta de un perfil JSON. En -Modo Instalar instala su lista sin preguntar.

.PARAMETER Alcance
    Auto (por defecto, sin --scope), Machine (todos los usuarios) o User.

.PARAMETER Todo
    Pre-marca todos los programas del menú.

.PARAMETER NoAdmin
    No pide elevación a administrador.

.PARAMETER Ayuda
    Muestra esta ayuda completa (Get-Help) y sale sin hacer nada.

.NOTES
    El bloque de ayuda debe ir DESPUÉS de una línea en blanco separándolo del
    #Requires: si queda pegado a la primera línea, PowerShell no lo reconoce y
    Get-Help solo enseña la sintaxis.

.EXAMPLE
    .\Instalar-Software.ps1

.EXAMPLE
    .\Instalar-Software.ps1 -Modo Instalar -Perfil .\perfiles\gaming.json

.EXAMPLE
    .\Instalar-Software.ps1 -Modo Actualizar
#>
[CmdletBinding()]
param(
    [ValidateSet('Menu', 'Instalar', 'Actualizar', 'Limpieza', 'Verificar', 'Catalogo')]
    [string]$Modo = 'Menu',

    [string]$Perfil,

    [ValidateSet('Auto', 'Machine', 'User')]
    [string]$Alcance = 'Auto',

    # Alto de la letra en pixeles. 0 = automatico (minimo 18 px si la letra es diminuta)
    [ValidateRange(0, 48)]
    [int]$Fuente = 0,

    [switch]$Todo,

    [switch]$NoAdmin,

    [switch]$Ayuda
)

# La ayuda se pide con -Name (Get-Help NO tiene -LiteralPath: con ese nombre
# daba error y nunca se llegaba a mostrar nada).
if ($Ayuda) {
    try { Get-Help -Name $MyInvocation.MyCommand.Path -Full -ErrorAction Stop }
    catch { Write-Warning ('No se pudo mostrar la ayuda: {0}' -f $_.Exception.Message) }
    exit 0
}

$ErrorActionPreference = 'Continue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

# Parámetros con los que se lanzó el script (para re-lanzarlo elevado)
$script:ArgsIniciales = @{}
foreach ($k in $PSBoundParameters.Keys) { $script:ArgsIniciales[$k] = $PSBoundParameters[$k] }

# ---------------------------------------------------------------------------
#  CATÁLOGO DE PROGRAMAS  (verifica cualquier ID con:  winget search <nombre>)
# ---------------------------------------------------------------------------
$script:Catalogo = [ordered]@{
    'Navegadores' = @(
        [pscustomobject]@{ Nombre = 'Google Chrome';     Id = 'Google.Chrome' }
        [pscustomobject]@{ Nombre = 'Mozilla Firefox';   Id = 'Mozilla.Firefox' }
        [pscustomobject]@{ Nombre = 'Brave';             Id = 'Brave.Brave' }
        [pscustomobject]@{ Nombre = 'Vivaldi';           Id = 'Vivaldi.Vivaldi' }
        [pscustomobject]@{ Nombre = 'Opera';             Id = 'Opera.Opera' }
        [pscustomobject]@{ Nombre = 'Opera GX';          Id = 'Opera.OperaGX' }
        [pscustomobject]@{ Nombre = 'Zen Browser';       Id = 'Zen-Team.Zen-Browser' }
        [pscustomobject]@{ Nombre = 'LibreWolf';         Id = 'LibreWolf.LibreWolf' }
        [pscustomobject]@{ Nombre = 'Tor Browser';       Id = 'TorProject.TorBrowser' }
        [pscustomobject]@{ Nombre = 'Floorp';            Id = 'Ablaze.Floorp' }
    )
    'Compresión' = @(
        [pscustomobject]@{ Nombre = '7-Zip';             Id = '7zip.7zip' }
        [pscustomobject]@{ Nombre = 'WinRAR';            Id = 'RARLab.WinRAR' }
        [pscustomobject]@{ Nombre = 'PeaZip';            Id = 'Giorgiotani.Peazip' }
    )
    'Multimedia' = @(
        [pscustomobject]@{ Nombre = 'VLC';               Id = 'VideoLAN.VLC' }
        [pscustomobject]@{ Nombre = 'GIMP';              Id = 'GIMP.GIMP' }
        [pscustomobject]@{ Nombre = 'OBS Studio';        Id = 'OBSProject.OBSStudio' }
        [pscustomobject]@{ Nombre = 'IrfanView';         Id = 'IrfanSkiljan.IrfanView' }
        [pscustomobject]@{ Nombre = 'Audacity';          Id = 'Audacity.Audacity' }
        [pscustomobject]@{ Nombre = 'Spotify';           Id = 'Spotify.Spotify' }
    )
    'Streaming' = @(
        [pscustomobject]@{ Nombre = 'Netflix';           Id = '9WZDNCRFJ3TJ' }
        [pscustomobject]@{ Nombre = 'Prime Video';       Id = '9P6RC76MSMMJ' }
        [pscustomobject]@{ Nombre = 'Disney+';           Id = '9NXQXXLFST89' }
        [pscustomobject]@{ Nombre = 'Crunchyroll';       Id = '9WZDNCRFJ15T' }
        [pscustomobject]@{ Nombre = 'Apple TV';          Id = '9NM4T8B9JQZ1' }
    )
    'Diseño y vídeo' = @(
        [pscustomobject]@{ Nombre = 'Figma';             Id = 'Figma.Figma' }
        [pscustomobject]@{ Nombre = 'Canva';             Id = 'Canva.Canva' }
        [pscustomobject]@{ Nombre = 'Blender (3D)';      Id = 'BlenderFoundation.Blender' }
        [pscustomobject]@{ Nombre = 'Krita (dibujo)';    Id = 'KDE.Krita' }
        [pscustomobject]@{ Nombre = 'Inkscape (vector)'; Id = 'Inkscape.Inkscape' }
        [pscustomobject]@{ Nombre = 'HandBrake (vídeo)'; Id = 'HandBrake.HandBrake' }
    )
    'Utilidades' = @(
        [pscustomobject]@{ Nombre = 'Notepad++';         Id = 'Notepad++.Notepad++' }
        [pscustomobject]@{ Nombre = 'Everything (búsqueda)'; Id = 'voidtools.Everything' }
        [pscustomobject]@{ Nombre = 'PowerToys';         Id = 'Microsoft.PowerToys' }
        [pscustomobject]@{ Nombre = 'Windows Terminal';  Id = 'Microsoft.WindowsTerminal' }
        [pscustomobject]@{ Nombre = 'ShareX';            Id = 'ShareX.ShareX' }
        [pscustomobject]@{ Nombre = 'qBittorrent';       Id = 'qBittorrent.qBittorrent' }
        [pscustomobject]@{ Nombre = 'Bitwarden';         Id = 'Bitwarden.Bitwarden' }
        [pscustomobject]@{ Nombre = 'Paint.NET';         Id = 'dotPDN.PaintDotNet' }
        [pscustomobject]@{ Nombre = 'SumatraPDF';        Id = 'SumatraPDF.SumatraPDF' }
        [pscustomobject]@{ Nombre = 'Rainmeter';         Id = 'Rainmeter.Rainmeter' }
        [pscustomobject]@{ Nombre = 'AutoHotkey';        Id = 'AutoHotkey.AutoHotkey' }
        [pscustomobject]@{ Nombre = 'TranslucentTB';     Id = 'CharlesMilette.TranslucentTB' }
        [pscustomobject]@{ Nombre = 'Flow Launcher';     Id = 'Flow-Launcher.Flow-Launcher' }
        [pscustomobject]@{ Nombre = 'CPU-Z';             Id = 'CPUID.CPU-Z' }
        [pscustomobject]@{ Nombre = 'HWiNFO';            Id = 'REALiX.HWiNFO' }
        [pscustomobject]@{ Nombre = 'Revo Uninstaller';  Id = 'XPFFVD4CMXN8VN' }
    )
    'Juegos' = @(
        [pscustomobject]@{ Nombre = 'Steam';             Id = 'Valve.Steam' }
        [pscustomobject]@{ Nombre = 'Epic Games Launcher'; Id = 'EpicGames.EpicGamesLauncher' }
        [pscustomobject]@{ Nombre = 'Ubisoft Connect';   Id = 'Ubisoft.Connect' }
        [pscustomobject]@{ Nombre = 'Rockstar Games';    Id = 'RockstarGames.Launcher' }
        [pscustomobject]@{ Nombre = 'Battle.net';        Id = 'Blizzard.BattleNet' }
        [pscustomobject]@{ Nombre = 'GOG Galaxy';        Id = 'GOG.Galaxy' }
        [pscustomobject]@{ Nombre = 'Minecraft Launcher'; Id = 'Mojang.MinecraftLauncher' }
    )
    'Desarrollo' = @(
        [pscustomobject]@{ Nombre = 'Git';               Id = 'Git.Git' }
        [pscustomobject]@{ Nombre = 'Visual Studio Code'; Id = 'Microsoft.VisualStudioCode' }
        [pscustomobject]@{ Nombre = 'Python 3.12';       Id = 'Python.Python.3.12' }
        [pscustomobject]@{ Nombre = 'Node.js';           Id = 'OpenJS.NodeJS' }
        [pscustomobject]@{ Nombre = 'Java 25 JDK (LTS)'; Id = 'EclipseAdoptium.Temurin.25.JDK' }
        [pscustomobject]@{ Nombre = 'PowerShell 7';      Id = 'Microsoft.PowerShell' }
        [pscustomobject]@{ Nombre = 'Docker Desktop';    Id = 'Docker.DockerDesktop' }
        [pscustomobject]@{ Nombre = 'WinSCP';            Id = 'WinSCP.WinSCP' }
        [pscustomobject]@{ Nombre = 'Postman';           Id = 'Postman.Postman' }
        [pscustomobject]@{ Nombre = 'DBeaver (bases de datos)'; Id = 'DBeaver.DBeaver.Community' }
        [pscustomobject]@{ Nombre = 'Android Studio';    Id = 'Google.AndroidStudio' }
        [pscustomobject]@{ Nombre = 'Unity Hub';         Id = 'Unity.UnityHub' }
        [pscustomobject]@{ Nombre = 'Rust (rustup)';     Id = 'Rustlang.Rustup' }
        [pscustomobject]@{ Nombre = 'GitHub Desktop';    Id = 'GitHub.GitHubDesktop' }
        [pscustomobject]@{ Nombre = 'Ollama (IA local)'; Id = 'Ollama.Ollama' }
        [pscustomobject]@{ Nombre = 'OpenCode (escritorio)'; Id = 'SST.OpenCodeDesktop' }
    )
    'Estudio' = @(
        [pscustomobject]@{ Nombre = 'Zotero (referencias)'; Id = 'DigitalScholar.Zotero' }
        [pscustomobject]@{ Nombre = 'Notion';            Id = 'Notion.Notion' }
        [pscustomobject]@{ Nombre = 'Obsidian (notas)';  Id = 'Obsidian.Obsidian' }
    )
    'Ofimática' = @(
        [pscustomobject]@{ Nombre = 'LibreOffice';       Id = 'TheDocumentFoundation.LibreOffice' }
        [pscustomobject]@{ Nombre = 'ONLYOFFICE';        Id = 'ONLYOFFICE.DesktopEditors' }
        [pscustomobject]@{ Nombre = 'Microsoft 365';     Id = 'Microsoft.Office' }
    )
    'Comunicación' = @(
        [pscustomobject]@{ Nombre = 'Discord';           Id = 'Discord.Discord' }
        [pscustomobject]@{ Nombre = 'Telegram';          Id = 'Telegram.TelegramDesktop' }
        [pscustomobject]@{ Nombre = 'Slack';             Id = 'SlackTechnologies.Slack' }
        [pscustomobject]@{ Nombre = 'Zoom';              Id = 'Zoom.Zoom' }
        [pscustomobject]@{ Nombre = 'WhatsApp';          Id = '9NKSQGP7F2NH' }
        [pscustomobject]@{ Nombre = 'Microsoft Teams';   Id = 'Microsoft.Teams' }
        [pscustomobject]@{ Nombre = 'Thunderbird (correo)'; Id = 'Mozilla.Thunderbird' }
        [pscustomobject]@{ Nombre = 'Signal';            Id = 'OpenWhisperSystems.Signal' }
    )
}

# ---------------------------------------------------------------------------
#  PERFILES RÁPIDOS  (teclas 1-5 dentro del menú)
# ---------------------------------------------------------------------------
$script:Preajustes = [ordered]@{
    'Básico' = @('Google.Chrome', '7zip.7zip', 'VideoLAN.VLC', 'Notepad++.Notepad++',
                 'voidtools.Everything', 'Microsoft.PowerToys', 'Bitwarden.Bitwarden')
    'Gaming' = @('Valve.Steam', 'EpicGames.EpicGamesLauncher', 'Discord.Discord',
                 'Spotify.Spotify', 'qBittorrent.qBittorrent')
    'Desarrollo' = @('Git.Git', 'Microsoft.VisualStudioCode', 'Python.Python.3.12',
                     'OpenJS.NodeJS', 'Microsoft.WindowsTerminal', 'Microsoft.PowerShell')
    'Ofimática' = @('TheDocumentFoundation.LibreOffice', 'GIMP.GIMP', 'IrfanSkiljan.IrfanView')
    'Comunicación' = @('Discord.Discord', 'Telegram.TelegramDesktop', 'SlackTechnologies.Slack', 'Zoom.Zoom')
    'Streaming' = @('9WZDNCRFJ3TJ', '9P6RC76MSMMJ', '9NXQXXLFST89', '9WZDNCRFJ15T', '9NM4T8B9JQZ1')
}

# ---------------------------------------------------------------------------
#  CATÁLOGO DE APPS PREINSTALADAS A QUITAR (des-bloat)
# ---------------------------------------------------------------------------
$script:BloatCatalogo = [ordered]@{
    'Patrocinadas / anuncios' = @(
        [pscustomobject]@{ Nombre = 'Candy Crush Saga';    Patron = 'king.com.CandyCrushSaga';          PorDefecto = $true }
        [pscustomobject]@{ Nombre = 'Candy Crush Friends'; Patron = 'king.com.CandyCrushFriendsSaga*';   PorDefecto = $true }
        [pscustomobject]@{ Nombre = 'TikTok';              Patron = 'Bytedance.TikTok*';                PorDefecto = $true }
        [pscustomobject]@{ Nombre = 'Disney+';             Patron = 'Disney.37853FC22B2CE';             PorDefecto = $true }
        [pscustomobject]@{ Nombre = 'Amazon';              Patron = 'Amazon*';                          PorDefecto = $true }
        [pscustomobject]@{ Nombre = 'Clipchamp';           Patron = 'Clipchamp.Clipchamp';              PorDefecto = $true }
        [pscustomobject]@{ Nombre = 'Spotify (preinstalado)'; Patron = 'SpotifyAB.SpotifyMusic';        PorDefecto = $false }
    )
    'Apps de Microsoft (opcionales)' = @(
        [pscustomobject]@{ Nombre = 'Cortana';             Patron = 'Microsoft.549981C3F5F10';          PorDefecto = $true }
        [pscustomobject]@{ Nombre = 'Noticias (Bing)';     Patron = 'Microsoft.BingNews';               PorDefecto = $true }
        [pscustomobject]@{ Nombre = 'El clima (Bing)';     Patron = 'Microsoft.BingWeather';            PorDefecto = $true }
        [pscustomobject]@{ Nombre = 'Obtener ayuda';       Patron = 'Microsoft.GetHelp';                PorDefecto = $true }
        [pscustomobject]@{ Nombre = 'Introducción';        Patron = 'Microsoft.Getstarted';             PorDefecto = $true }
        [pscustomobject]@{ Nombre = 'Solitario';           Patron = 'Microsoft.MicrosoftSolitaireCollection'; PorDefecto = $true }
        [pscustomobject]@{ Nombre = 'Centro de opiniones'; Patron = 'Microsoft.WindowsFeedbackHub';      PorDefecto = $true }
        [pscustomobject]@{ Nombre = 'Power Automate';      Patron = 'Microsoft.PowerAutomateDesktop';   PorDefecto = $true }
        [pscustomobject]@{ Nombre = 'Mapas de Windows';    Patron = 'Microsoft.WindowsMaps';            PorDefecto = $true }
        [pscustomobject]@{ Nombre = 'Mixed Reality Portal'; Patron = 'Microsoft.MixedReality.Portal';   PorDefecto = $true }
        [pscustomobject]@{ Nombre = 'Office Hub';          Patron = 'Microsoft.MicrosoftOfficeHub';     PorDefecto = $true }
        [pscustomobject]@{ Nombre = 'People';              Patron = 'Microsoft.People';                 PorDefecto = $true }
        [pscustomobject]@{ Nombre = '3D Viewer';           Patron = 'Microsoft.Microsoft3DViewer';      PorDefecto = $true }
        [pscustomobject]@{ Nombre = 'Print 3D';            Patron = 'Microsoft.Print3D';                PorDefecto = $true }
        [pscustomobject]@{ Nombre = 'Skype';               Patron = 'Microsoft.SkypeApp';               PorDefecto = $true }
        [pscustomobject]@{ Nombre = 'Notas rápidas';       Patron = 'Microsoft.MicrosoftStickyNotes';   PorDefecto = $false }
        [pscustomobject]@{ Nombre = 'Alarmas y reloj';     Patron = 'Microsoft.WindowsAlarms';          PorDefecto = $false }
        [pscustomobject]@{ Nombre = 'Phone Link';          Patron = 'Microsoft.YourPhone';              PorDefecto = $false }
        [pscustomobject]@{ Nombre = 'Microsoft To Do';     Patron = 'Microsoft.Todos';                  PorDefecto = $false }
    )
    'Xbox y multimedia (déjalos si los usas)' = @(
        [pscustomobject]@{ Nombre = 'Xbox Game Bar';       Patron = 'Microsoft.XboxGamingOverlay';      PorDefecto = $false }
        [pscustomobject]@{ Nombre = 'Xbox TCUI';           Patron = 'Microsoft.Xbox.TCUI';              PorDefecto = $false }
        [pscustomobject]@{ Nombre = 'Xbox Identity';       Patron = 'Microsoft.XboxIdentityProvider';   PorDefecto = $false }
        [pscustomobject]@{ Nombre = 'Xbox (app)';          Patron = 'Microsoft.GamingApp';              PorDefecto = $false }
        [pscustomobject]@{ Nombre = 'Media Player (Zune)'; Patron = 'Microsoft.ZuneMusic';              PorDefecto = $false }
        [pscustomobject]@{ Nombre = 'Películas y TV';      Patron = 'Microsoft.ZuneVideo';              PorDefecto = $false }
        [pscustomobject]@{ Nombre = 'Teams (consumidor)';  Patron = 'MicrosoftTeams';                   PorDefecto = $true }
    )
}

# ---------------------------------------------------------------------------
#  ENTORNO
# ---------------------------------------------------------------------------
$script:DirBase    = $PSScriptRoot
$script:DirLog     = Join-Path $script:DirBase 'log'
$script:DirPerfile = Join-Path $script:DirBase 'perfiles'
$script:LogPath    = Join-Path $script:DirLog ('instalacion-{0}.log' -f (Get-Date -Format 'yyyyMMdd-HHmmss'))
$script:RutaWinget = $null

function Inicializar-Entorno {
    foreach ($d in @($script:DirLog, $script:DirPerfile)) {
        if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    }
    # Los logs se acumulan sin limite (una ejecucion = un archivo): se quedan
    # con los 20 mas recientes.
    $antiguos = @(Get-ChildItem -LiteralPath $script:DirLog -Filter 'instalacion-*.log' -ErrorAction SilentlyContinue |
                  Sort-Object LastWriteTime -Descending | Select-Object -Skip 20)
    foreach ($f in $antiguos) { Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue }
    Write-Log ('Inicio. Modo={0} Perfil={1} Alcance={2}' -f $Modo, $Perfil, $Alcance) 'INFO'
}

function Write-Log {
    param([string]$Mensaje, [string]$Nivel = 'INFO')
    $linea = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Nivel, $Mensaje
    try { Add-Content -LiteralPath $script:LogPath -Value $linea -Encoding UTF8 } catch { }
}

function Write-Paso {
    param([string]$Mensaje, [string]$Color = 'White')
    Write-Host $Mensaje -ForegroundColor $Color
    Write-Log $Mensaje
}

# ---------------------------------------------------------------------------
#  LETRA DE LA VENTANA (por defecto Windows pone una letra diminuta)
# ---------------------------------------------------------------------------
function Add-TipoConsola {
    if ('Instalador.ConsolaWin32' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace Instalador {
    public static class ConsolaWin32 {
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct Fuente {
            public uint cbSize;
            public uint nFont;
            public short dwFontSizeX;
            public short dwFontSizeY;
            public uint FontFamily;
            public uint FontWeight;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
            public string FaceName;
        }
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern IntPtr GetStdHandle(int nStdHandle);
        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern bool GetCurrentConsoleFontEx(IntPtr h, bool bMax, ref Fuente f);
        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern bool SetCurrentConsoleFontEx(IntPtr h, bool bMax, ref Fuente f);
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool GetConsoleMode(IntPtr h, out uint modo);
        [DllImport("kernel32.dll", SetLastError = true)]
        public static extern bool SetConsoleMode(IntPtr h, uint modo);
    }
}
'@
}

function Get-SeleccionRapida {
    # Devuelve $true/$false si la "seleccion rapida" esta activada, o $null si
    # no se puede leer (para restaurar el estado original al salir).
    try {
        Add-TipoConsola
        $h = [Instalador.ConsolaWin32]::GetStdHandle(-10)   # STD_INPUT_HANDLE
        if ($h -eq [IntPtr]::Zero -or $h -eq [IntPtr](-1)) { return $null }
        $modo = [uint32]0
        if (-not [Instalador.ConsolaWin32]::GetConsoleMode($h, [ref]$modo)) { return $null }
        return (($modo -band 0x40) -ne 0)
    } catch { return $null }
}

function Set-SeleccionRapida {
    # La "seleccion rapida" hace que un simple clic dentro de la ventana deje la
    # consola en PAUSA (el titulo pone "Seleccionar"): no responde a las teclas ni
    # escribe nada hasta que pulsas Esc. Desactivandolo el menu nunca se queda
    # pillado por un clic accidental.
    param([bool]$Activado)
    try {
        Add-TipoConsola
        $h = [Instalador.ConsolaWin32]::GetStdHandle(-10)   # STD_INPUT_HANDLE
        if ($h -eq [IntPtr]::Zero -or $h -eq [IntPtr](-1)) { return }
        $modo = [uint32]0
        if (-not [Instalador.ConsolaWin32]::GetConsoleMode($h, [ref]$modo)) { return }
        $nuevo = [uint32]$modo
        if ($Activado) { $nuevo = [uint32]($nuevo -bor 0x40) }         # ENABLE_QUICK_EDIT
        else           { $nuevo = [uint32]($nuevo -bxor ($nuevo -band 0x40)) }
        $nuevo = [uint32]($nuevo -bor 0x80)                            # ENABLE_EXTENDED_FLAGS
        if ($nuevo -ne $modo) { [void][Instalador.ConsolaWin32]::SetConsoleMode($h, $nuevo) }
    } catch { }
}

function Get-ConsolaFuente {
    param([IntPtr]$Mano)
    $f = New-Object Instalador.ConsolaWin32+Fuente
    $f.cbSize = [uint32][Runtime.InteropServices.Marshal]::SizeOf([type][Instalador.ConsolaWin32+Fuente])
    if (-not [Instalador.ConsolaWin32]::GetCurrentConsoleFontEx($Mano, $false, [ref]$f)) { return $null }
    return $f
}

function Set-ConsolaTamano {
    # Orden correcto: encoger ventana -> encoger buffer -> crecer buffer -> crecer ventana
    param([int]$Ancho, [int]$Alto)
    if ($Ancho -lt 40 -or $Alto -lt 10) { return }
    try {
        if ([Console]::WindowWidth  -gt $Ancho) { [Console]::WindowWidth  = $Ancho }
        if ([Console]::BufferWidth  -gt $Ancho) { [Console]::BufferWidth  = $Ancho }
        if ([Console]::BufferWidth  -lt $Ancho) { [Console]::BufferWidth  = $Ancho }
        if ([Console]::WindowWidth  -lt $Ancho) { [Console]::WindowWidth  = $Ancho }
        if ([Console]::WindowHeight -gt $Alto)  { [Console]::WindowHeight = $Alto }
        if ([Console]::BufferHeight -lt $Alto)  { [Console]::BufferHeight = $Alto }
        if ([Console]::WindowHeight -lt $Alto)  { [Console]::WindowHeight = $Alto }
    } catch { }
}

function Set-ConsolaFuente {
    # $Alto = 0  -> automatico: solo agranda si la letra es muy pequeña (minimo 18 px)
    # $Alto = 24 -> fuerza ese alto en pixeles
    param([int]$Alto = 0)
    $minimo = 18
    try {
        Add-TipoConsola
        $h = [Instalador.ConsolaWin32]::GetStdHandle(-11)
        if ($h -eq [IntPtr]::Zero -or $h -eq [IntPtr](-1)) { return }
        $f = Get-ConsolaFuente -Mano $h
        if (-not $f) { return }

        if ($Alto -gt 0) { $objetivo = $Alto }
        elseif ($f.dwFontSizeY -lt $minimo) { $objetivo = $minimo }
        else { $objetivo = 0 }
        if ($objetivo -le 0) { return }

        $f.nFont = 0
        $f.dwFontSizeX = 0
        $f.dwFontSizeY = [int16]$objetivo
        if (-not $f.FaceName) {                 # fuente de mapa de bits -> TrueType
            $f.FaceName   = 'Consolas'
            $f.FontFamily = 54                  # FF_MODERN | TMPF_VECTOR | TMPF_TRUETYPE
            $f.FontWeight = 400
        }
        if (-not [Instalador.ConsolaWin32]::SetCurrentConsoleFontEx($h, $false, [ref]$f)) { return }
        Write-Log ('Consola: letra "{0}" a {1} px' -f $f.FaceName, $objetivo) 'OK'

        # Ajusta el tamano de la ventana para que quepa en la pantalla
        $g = Get-ConsolaFuente -Mano $h
        $fw = 10; $fh = 20
        if ($g) { if ($g.dwFontSizeX -gt 0) { $fw = $g.dwFontSizeX }; if ($g.dwFontSizeY -gt 0) { $fh = $g.dwFontSizeY } }
        try {
            Add-Type -AssemblyName System.Windows.Forms
            $area = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
            $ancho = [Math]::Min(160, [Math]::Max(60,  [Math]::Floor($area.Width  / $fw)))
            $alto  = [Math]::Min(45,  [Math]::Max(24, [Math]::Floor($area.Height / $fh)))
            Set-ConsolaTamano -Ancho ([int]$ancho) -Alto ([int]$alto)
            Write-Log ('Consola: ventana {0}x{1}' -f $ancho, $alto) 'OK'
        } catch { }
    } catch {
        Write-Log ('No se pudo ajustar la letra de la consola: {0}' -f $_.Exception.Message) 'AVISO'
    }
}

# ---------------------------------------------------------------------------
#  COMPROBACIÓN DE IDs (winget renombra paquetes de vez en cuando)
# ---------------------------------------------------------------------------
function Get-IdsCatalogo {
    # Todos los IDs conocidos: catálogo, perfiles rápidos y perfiles JSON
    $lista = New-Object System.Collections.ArrayList
    foreach ($g in $script:Catalogo.Keys) {
        foreach ($p in $script:Catalogo[$g]) {
            if (-not ($lista | Where-Object { $_.Id -eq $p.Id })) {
                [void]$lista.Add([pscustomobject]@{ Id = $p.Id; Nombre = $p.Nombre; Origen = 'catalogo' })
            }
        }
    }
    foreach ($k in $script:Preajustes.Keys) {
        foreach ($i in $script:Preajustes[$k]) {
            if (-not ($lista | Where-Object { $_.Id -eq $i })) {
                [void]$lista.Add([pscustomobject]@{ Id = $i; Nombre = $i; Origen = ('perfil rapido: ' + $k) })
            }
        }
    }
    foreach ($f in @(Get-ChildItem -LiteralPath $script:DirPerfile -Filter '*.json' -ErrorAction SilentlyContinue)) {
        try {
            $p = Get-Perfil -Ruta $f.FullName
            foreach ($i in $p.Paquetes) {
                if ($i -and -not ($lista | Where-Object { $_.Id -eq $i })) {
                    [void]$lista.Add([pscustomobject]@{ Id = $i; Nombre = $i; Origen = ('perfil: ' + $f.Name) })
                }
            }
        } catch {
            Write-Log ('Perfil ilegible {0}: {1}' -f $f.Name, $_.Exception.Message) 'AVISO'
        }
    }
    return , $lista
}

function Invoke-Verificacion {
    Write-Paso 'Comprobando los IDs del programa contra winget (puede tardar un minuto)...' 'Cyan'
    $ids = Get-IdsCatalogo
    if ($ids.Count -eq 0) { Write-Warning 'No hay ningun ID que comprobar.'; return 0 }

    $resultados = New-Object System.Collections.ArrayList
    $n = 0
    foreach ($e in $ids) {
        $n++
        Write-Host ('  [{0}/{1}] {2}' -f $n, $ids.Count, $e.Id) -ForegroundColor DarkGray
        $r = Invoke-Winget -Argumentos @('show', '--id', $e.Id, '-e',
                                         '--accept-source-agreements', '--disable-interactivity')
        $estado = 'OK'
        if ($r.Codigo -ne 0) {
            if ($r.Salida -match 'No package found|No se encontr') { $estado = 'ID NO EXISTE' }
            else { $estado = 'SIN RESPUESTA' }   # fallo de red/fuente, no necesariamente roto
        }
        [void]$resultados.Add([pscustomobject]@{ Id = $e.Id; Nombre = $e.Nombre; Origen = $e.Origen; Estado = $estado })
        Write-Log ('VERIFICAR | {0} | {1}' -f $e.Id, $estado)
    }

    $malos  = @($resultados | Where-Object { $_.Estado -eq 'ID NO EXISTE' })
    $dudosos = @($resultados | Where-Object { $_.Estado -eq 'SIN RESPUESTA' })

    Write-Host ''
    Write-Host ('================== COMPROBACION DE IDS ==================') -ForegroundColor Cyan
    Write-Host ('  Comprobados: {0}   Correctos: {1}   Rotos: {2}   Sin respuesta: {3}' -f `
        $resultados.Count, ($resultados.Count - $malos.Count - $dudosos.Count), $malos.Count, $dudosos.Count) -ForegroundColor Cyan

    if ($malos.Count -gt 0) {
        Write-Host ''
        Write-Host '  Estos IDs ya no existen en winget (hay que sustituirlos):' -ForegroundColor Red
        foreach ($m in $malos) {
            Write-Host ('    - {0}   ({1}, {2})' -f $m.Id, $m.Nombre, $m.Origen) -ForegroundColor Red
            Write-Host ('        busca el nuevo con:  winget search {0}' -f $m.Nombre) -ForegroundColor DarkYellow
        }
        Write-Host '  Edita el ID en Instalar-Software.ps1 (y en perfiles\*.json si aparece ahi).' -ForegroundColor DarkYellow
    }
    if ($dudosos.Count -gt 0) {
        Write-Host ''
        Write-Host '  No se pudo comprobar (conexion o fuente); vuelve a intentarlo:' -ForegroundColor Yellow
        foreach ($d in $dudosos) { Write-Host ('    - {0}' -f $d.Id) -ForegroundColor Yellow }
    }
    if ($malos.Count -eq 0 -and $dudosos.Count -eq 0) {
        Write-Host '  Todo correcto: los IDs siguen valiendo.' -ForegroundColor Green
    }
    Write-Host '==========================================================' -ForegroundColor Cyan
    Write-Log ('VERIFICACION | total={0} rotos={1} sin-respuesta={2}' -f $resultados.Count, $malos.Count, $dudosos.Count) 'FIN'
    return $malos.Count
}

# ---------------------------------------------------------------------------
#  PERMISOS Y WINGET
# ---------------------------------------------------------------------------
function Test-Elevado {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $p = New-Object Security.Principal.WindowsPrincipal($id)
        return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Invoke-Elevacion {
    if ($script:ArgsIniciales.ContainsKey('NoAdmin')) { return }
    if (Test-Elevado) { return }
    if (-not $PSCommandPath) { return }
    $exe = 'powershell.exe'
    try { $exe = (Get-Process -Id $PID).Path } catch { }
    $argumentos = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"{0}"' -f $PSCommandPath))
    foreach ($k in @('Modo', 'Perfil', 'Alcance', 'Fuente')) {
        if ($script:ArgsIniciales.ContainsKey($k)) {
            $argumentos += @(('-{0}' -f $k), ('"{0}"' -f $script:ArgsIniciales[$k]))
        }
    }
    foreach ($k in @('Todo', 'NoAdmin')) { if ($script:ArgsIniciales.ContainsKey($k)) { $argumentos += ('-{0}' -f $k) } }
    Write-Host ''
    Write-Host '  Se necesitan permisos de administrador: acepta la ventana UAC.' -ForegroundColor Yellow
    try {
        Start-Process -FilePath $exe -Verb RunAs -ArgumentList $argumentos -ErrorAction Stop | Out-Null
        exit 0
    } catch {
        Write-Warning 'Elevacion cancelada. Se continuara solo para el usuario actual (algunas instalaciones pueden fallar).'
    }
}

function Invoke-DescargaFiable {
    # Descarga con reintentos, reanudacion (curl -C -) y verificacion de tamano.
    param(
        [Parameter(Mandatory)][string]$Uri,
        [Parameter(Mandatory)][string]$Destino,
        [long]$Tamano = 0,
        [int]$Reintentos = 4
    )
    $parcial = $Destino + '.descarga'

    if (Test-Path -LiteralPath $Destino) {
        $actual = (Get-Item -LiteralPath $Destino).Length
        if ($Tamano -le 0 -or $actual -eq $Tamano) { return $true }
        # Reutiliza lo descargado como base para reanudar
        Move-Item -LiteralPath $Destino -Destination $parcial -Force -ErrorAction SilentlyContinue
        Write-Host ('      reanudando descarga ({0:N1} de {1:N1} MB)...' -f ($actual / 1MB), ($Tamano / 1MB)) -ForegroundColor DarkYellow
    }

    # Si lo parcial no parece un zip/msix, se tira y se empieza de cero
    if (Test-Path -LiteralPath $parcial) {
        $fs = [IO.File]::OpenRead($parcial)
        $cab = New-Object byte[] 2
        [void]$fs.Read($cab, 0, 2)
        $fs.Close()
        if ([char]$cab[0] -ne 'P' -or [char]$cab[1] -ne 'K') {
            Remove-Item -LiteralPath $parcial -Force -ErrorAction SilentlyContinue
        }
    }

    $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
    for ($intento = 1; $intento -le $Reintentos; $intento++) {
        if ($curl) {
            & curl.exe -L -f -sS --retry 3 --retry-delay 2 -C - -o $parcial $Uri | Out-Null
        } else {
            if (Test-Path -LiteralPath $parcial) { Remove-Item -LiteralPath $parcial -Force -ErrorAction SilentlyContinue }
            try {
                Invoke-WebRequest -Uri $Uri -OutFile $parcial -UseBasicParsing -ErrorAction Stop
            } catch {
                Write-Log ('descarga fallida: {0}' -f $_.Exception.Message) 'AVISO'
            }
        }
        if (Test-Path -LiteralPath $parcial) {
            $len = (Get-Item -LiteralPath $parcial).Length
            if ($Tamano -le 0 -or $len -eq $Tamano) {
                Move-Item -LiteralPath $parcial -Destination $Destino -Force
                Write-Log ('descargado {0} ({1:N1} MB)' -f (Split-Path -Leaf $Destino), ($len / 1MB)) 'OK'
                return $true
            }
            Write-Host ('      incompleto {0:N1}/{1:N1} MB (intento {2})...' -f ($len / 1MB), ($Tamano / 1MB), $intento) -ForegroundColor DarkYellow
        }
        Start-Sleep -Seconds 2
    }
    Remove-Item -LiteralPath $parcial -Force -ErrorAction SilentlyContinue
    return $false
}

function Test-ZipValido {
    param([Parameter(Mandatory)][string]$Ruta)
    try {
        Add-Type -AssemblyName System.IO.Compression.FileSystem -ErrorAction SilentlyContinue
        $z = [System.IO.Compression.ZipFile]::OpenRead($Ruta)
        $n = $z.Entries.Count
        $z.Dispose()
        return ($n -gt 0)
    } catch { return $false }
}

function Get-RutaWinget {
    # Devuelve la ruta completa de winget.exe (funciona aunque la sesion
    # todavia no haya cacheado el alias de ejecucion de la app).
    $cmd = Get-Command winget -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($ruta in @((Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe'),
                        (Join-Path $env:ProgramFiles 'WindowsApps\winget.exe'))) {
        if (Test-Path -LiteralPath $ruta) { return $ruta }
    }
    return $null
}

function Test-Winget {
    if (Get-RutaWinget) { return $true }
    Write-Warning 'No se encontro winget. Intentando instalar "App Installer"...'

    # Dependencias declaradas por App Installer (VCLibs y Windows App Runtime).
    # Sin ellas la instalacion falla con 0x80073CF3.
    $arquitectura = 'x64'
    switch ($env:PROCESSOR_ARCHITECTURE) {
        'AMD64' { $arquitectura = 'x64' }
        'ARM64' { $arquitectura = 'arm64' }
        'x86'   { $arquitectura = 'x86' }
    }

    $rel = $null
    try {
        $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/microsoft/winget-cli/releases/latest' -ErrorAction Stop
    } catch {
        Write-Warning ('No se pudo consultar GitHub: {0}' -f $_.Exception.Message)
        return $false
    }

    $bundle = $rel.assets | Where-Object { $_.name -like '*.msixbundle' } | Select-Object -First 1
    $deps   = $rel.assets | Where-Object { $_.name -like '*Dependencies.zip' } | Select-Object -First 1
    if (-not $bundle) { Write-Warning 'No se encontro el paquete .msixbundle en la release.'; return $false }

    $tmp = Join-Path $env:TEMP ('winget-cli-' + $rel.tag_name)
    if (-not (Test-Path -LiteralPath $tmp)) { New-Item -ItemType Directory -Path $tmp -Force | Out-Null }

    try {
        # 1) Dependencias primero (VCLibs + Microsoft.WindowsAppRuntime)
        if ($deps) {
            $zip = Join-Path $tmp $deps.name
            if (-not (Test-ZipValido -Ruta $zip)) {
                Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
                Write-Host ('  Descargando dependencias ({0:N0} MB)...' -f ($deps.size / 1MB)) -ForegroundColor Yellow
                if (-not (Invoke-DescargaFiable -Uri $deps.browser_download_url -Destino $zip -Tamano ([long]$deps.size))) {
                    throw 'No se pudieron descargar las dependencias (conexion inestable).'
                }
                if (-not (Test-ZipValido -Ruta $zip)) {
                    Remove-Item -LiteralPath $zip -Force -ErrorAction SilentlyContinue
                    throw 'El archivo de dependencias llego corrompido.'
                }
            }

            $destino = Join-Path $tmp 'deps'
            $hayPaquetes = $false
            if (Test-Path -LiteralPath $destino) {
                $hayPaquetes = @(Get-ChildItem -LiteralPath $destino -Recurse -File -ErrorAction SilentlyContinue |
                    Where-Object { $_.Extension -eq '.msix' -or $_.Extension -eq '.appx' }).Count -gt 0
            }
            if (-not $hayPaquetes) {
                Write-Host '  Extrayendo dependencias...' -ForegroundColor Yellow
                Expand-Archive -LiteralPath $zip -DestinationPath $destino -Force -ErrorAction Stop
            }

            # Los paquetes pueden venir como  ..._x64.appx  o  ..._x64__8wekyb3d8bbwe.msix
            $patronArq = '(_' + [regex]::Escape($arquitectura) + '(_|\.))'
            $paquetes = @(Get-ChildItem -LiteralPath $destino -Recurse -File -ErrorAction SilentlyContinue |
                Where-Object { ($_.Extension -eq '.msix' -or $_.Extension -eq '.appx' -or $_.Extension -eq '.msixbundle') -and
                               ($_.Name -match $patronArq -or $_.Name -match '_neutral(_|\.)') })
            if ($paquetes.Count -eq 0) { throw 'No se encontraron dependencias para esta arquitectura.' }
            foreach ($p in $paquetes) {
                try {
                    Add-AppxPackage -Path $p.FullName -ErrorAction Stop | Out-Null
                    Write-Host ('      + ' + $p.Name) -ForegroundColor DarkGray
                } catch {
                    Write-Log ('Dependencia omitida {0}: {1}' -f $p.Name, $_.Exception.Message) 'AVISO'
                }
            }
        }

        # 2) App Installer (winget)
        $bundlePath = Join-Path $tmp $bundle.name
        if (-not (Test-Path -LiteralPath $bundlePath)) {
            Write-Host ('  Descargando {0} ...' -f $bundle.name) -ForegroundColor Yellow
        }
        if (-not (Invoke-DescargaFiable -Uri $bundle.browser_download_url -Destino $bundlePath -Tamano ([long]$bundle.size))) {
            throw 'No se pudo descargar App Installer (conexion inestable).'
        }
        Write-Host '  Instalando App Installer...' -ForegroundColor Yellow
        Add-AppxPackage -Path $bundlePath -ErrorAction Stop | Out-Null
        Start-Sleep -Seconds 3
    } catch {
        Write-Warning ('No se pudo instalar App Installer automaticamente: {0}' -f $_.Exception.Message)
        Write-Host '  Solucion manual (cualquiera de las dos):' -ForegroundColor Yellow
        Write-Host '   1) Instala "App Installer" desde la Microsoft Store' -ForegroundColor Yellow
        Write-Host '   2) https://github.com/microsoft/winget-cli/releases' -ForegroundColor Yellow
        return $false
    }

    if (Get-RutaWinget) { return $true }
    Write-Warning 'winget instalado pero no visible en esta sesion. Reinicia la terminal y vuelve a ejecutar el script.'
    return $false
}

# ---------------------------------------------------------------------------
#  WRAPPER DE WINGET
# ---------------------------------------------------------------------------
function Invoke-Winget {
    param(
        [Parameter(Mandatory)][string[]]$Argumentos,
        # Muestra la salida de winget en la consola a medida que llega (para
        # instalaciones). Sin esta bandera la salida solo se acumula en memoria:
        # util para comprobaciones internas, que no deben ensuciar la pantalla.
        [switch]$EnVivo
    )
    if (-not $script:RutaWinget) { $script:RutaWinget = Get-RutaWinget }
    if (-not $script:RutaWinget) { return @{ Codigo = -1; Salida = 'winget no esta disponible' } }
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    $acum = New-Object System.Text.StringBuilder
    try {
        # Cada linea se captura en cuanto llega. Antes se hacia un Out-String con
        # toda la salida: mientras winget trabajaba no se veia NADA y parecia
        # que el script estaba colgado.
        $null = & $script:RutaWinget @Argumentos 2>&1 | ForEach-Object {
            $linea = [string]$_
            if ($linea -ne '') {
                [void]$acum.AppendLine($linea)
                if ($EnVivo) { try { Write-Host $linea -ForegroundColor DarkGray } catch { } }
            }
        }
        $codigo = $LASTEXITCODE
    } catch {
        [void]$acum.AppendLine($_.Exception.Message)
        $codigo = -1
    } finally {
        $ErrorActionPreference = $prev
    }
    return @{ Codigo = $codigo; Salida = $acum.ToString() }
}

function Get-EstaInstalado {
    param([Parameter(Mandatory)][string]$Id)
    $r = Invoke-Winget -Argumentos @('list', '--id', $Id, '-e', '--accept-source-agreements', '--disable-interactivity')
    # 0x8A150014 (-1978335212) = "ningun paquete coincide". Es un codigo fijo,
    # asi que sirve en cualquier idioma: winget localiza el mensaje de texto
    # pero no el codigo de salida.
    if ($r.Codigo -eq -1978335212) { return $false }
    if ($r.Salida -match 'No installed package found' -or $r.Salida -match 'No se encontr') { return $false }
    if ($r.Salida -match [regex]::Escape($Id)) { return $true }
    return $false
}

# ---------------------------------------------------------------------------
#  INSTALACIÓN
# ---------------------------------------------------------------------------
function Install-Paquete {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Id,
        [string]$Alcance = 'Auto',
        [int]$Reintentos = 2
    )

    if (Get-EstaInstalado -Id $Id) {
        Write-Log ("Ya estaba instalado: {0}" -f $Id) 'SKIP'
        return 'YA ESTABA INSTALADO'
    }

    $base = @('install', '--id', $Id, '-e', '--silent',
              '--accept-package-agreements', '--accept-source-agreements')
    switch ($Alcance) {
        'Machine' { $base += @('--scope', 'machine') }
        'User'    { $base += @('--scope', 'user') }
    }

    $ultimoCodigo = $null
    for ($intento = 1; $intento -le $Reintentos; $intento++) {
        $argumentos = @($base)
        # El primer intento exige modo no interactivo; si falla (winget antiguo
        # que no reconoce el flag) se reintenta sin el.
        if ($intento -eq 1) { $argumentos += '--disable-interactivity' }
        Write-Log ("Intento {0}/{1}: winget {2}" -f $intento, $Reintentos, ($argumentos -join ' ')) 'CMD'
        Write-Host ('      winget trabajando... (abajo ira saliendo su progreso)') -ForegroundColor DarkGray

        $r = Invoke-Winget -Argumentos $argumentos -EnVivo
        $ultimoCodigo = $r.Codigo

        if ($r.Codigo -eq 0) {
            Write-Log ("Instalado: {0}" -f $Id) 'OK'
            return 'INSTALADO'
        }
        if ($r.Salida -match 'already installed' -or $r.Salida -match 'ya est.{0,20}instalado') {
            return 'YA ESTABA INSTALADO'
        }
        # 0x8A150014 = el ID ya no existe en winget. Reintentar no va a cambiar
        # nada: solo hace perder el doble de tiempo (y el 2.º intento se lanza
        # sin --disable-interactivity, asi que podria quedarse esperando
        # entrada). Se falla directamente.
        if ($r.Codigo -eq -1978335212 -or $r.Salida -match 'No package found') {
            Write-Log ("ID inexistente en winget: {0}" -f $Id) 'ERROR'
            break
        }
        Write-Log ("Intento {0} fallo para {1} (codigo {2})" -f $intento, $Id, $r.Codigo) 'AVISO'
        Write-Host ('      codigo ' + $r.Codigo) -ForegroundColor DarkYellow
        Start-Sleep -Seconds 2
    }
    Write-Log ("FALLO {0} (codigo {1})" -f $Id, $ultimoCodigo) 'ERROR'
    return ('FALLÓ ({0})' -f $ultimoCodigo)
}

function Show-Resumen {
    param([System.Collections.IEnumerable]$Resultados, [string]$Titulo = 'RESUMEN')
    $lista = @($Resultados)
    if ($lista.Count -eq 0) { return }
    Write-Host ''
    Write-Host ('================== ' + $Titulo + ' ==================') -ForegroundColor Cyan
    $ok = 0; $ya = 0; $mal = 0
    foreach ($r in $lista) {
        $estado = [string]$r.Estado
        $color = 'Red'
        if ($estado -eq 'INSTALADO' -or $estado -eq 'QUITADO') { $color = 'Green'; $ok++ }
        elseif ($estado -like 'YA ESTABA*' -or $estado -eq 'NO ENCONTRADO') { $color = 'DarkGray'; $ya++ }
        else { $mal++ }
        Write-Host ('  {0,-26} {1}' -f $estado, $r.Paquete) -ForegroundColor $color
        Write-Log ('RESUMEN | {0} | {1}' -f $r.Paquete, $estado)
    }
    Write-Host ''
    Write-Host ('  Correctos: {0}   Sin accion: {1}   Fallidos: {2}' -f $ok, $ya, $mal) -ForegroundColor Cyan
    Write-Host ('================================================' + ('=' * $Titulo.Length)) -ForegroundColor Cyan
}

function Invoke-Instalacion {
    [CmdletBinding()]
    param(
        [string[]]$Ids,
        [string]$Alcance = 'Auto',
        [switch]$Confirmar
    )
    $Ids = @($Ids | Where-Object { $_ } | Select-Object -Unique)
    if ($Ids.Count -eq 0) {
        Write-Warning 'No hay programas seleccionados.'
        return 0
    }
    if ($Confirmar) {
        Write-Host ''
        Write-Host ('Se instalaran {0} programa(s):' -f $Ids.Count) -ForegroundColor Cyan
        foreach ($i in $Ids) { Write-Host ('   - ' + $i) }
        Write-Host ''
        $resp = Read-Host '  Continuar? (S/n)'
        if ($resp -and $resp -notmatch '^[sS]') {
            Write-Host '  Cancelado por el usuario.' -ForegroundColor Yellow
            return 0
        }
    }

    $resultados = New-Object System.Collections.ArrayList
    $n = 0
    foreach ($id in $Ids) {
        $n++
        Write-Host ''
        Write-Host ('[{0}/{1}] {2}' -f $n, $Ids.Count, $id) -ForegroundColor Cyan
        $estado = Install-Paquete -Id $id -Alcance $Alcance
        $color = 'Green'
        if ($estado -like 'YA ESTABA*') { $color = 'DarkGray' }
        elseif ($estado -like 'FALLÓ*') { $color = 'Red' }
        Write-Host ('      -> ' + $estado) -ForegroundColor $color
        Write-Log ('{0} -> {1}' -f $id, $estado)
        [void]$resultados.Add([pscustomobject]@{ Paquete = $id; Estado = $estado })
    }
    Show-Resumen -Resultados $resultados -Titulo 'RESUMEN DE INSTALACION'
    $fallas = @($resultados | Where-Object { $_.Estado -like 'FALLÓ*' }).Count
    return $fallas
}

# ---------------------------------------------------------------------------
#  DES-BLOAT (quitar apps preinstaladas)
# ---------------------------------------------------------------------------
function Remove-AppxBloat {
    param([Parameter(Mandatory)][string]$Patron, [string]$Nombre)
    Write-Log ("Des-bloat: {0} ({1})" -f $Nombre, $Patron)

    try {
        $prov = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop | Where-Object { $_.DisplayName -like $Patron })
        foreach ($p in $prov) {
            Remove-AppxProvisionedPackage -Online -PackageName $p.PackageFullName -ErrorAction Stop | Out-Null
            Write-Log ("  desaprovechado {0}" -f $p.DisplayName)
        }
    } catch {
        Write-Log ("  no se pudo desaprovisionar {0}: {1}" -f $Nombre, $_.Exception.Message) 'AVISO'
    }

    $paquetes = @()
    try {
        $paquetes = @(Get-AppxPackage -Name $Patron -AllUsers -ErrorAction Stop)
    } catch {
        try { $paquetes = @(Get-AppxPackage -Name $Patron -ErrorAction SilentlyContinue) } catch { }
    }
    if ($paquetes.Count -eq 0) { return 'NO ENCONTRADO' }

    $estado = 'QUITADO'
    foreach ($p in $paquetes) {
        $quitado = $false
        try {
            Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop
            $quitado = $true
        } catch {
            try {
                Remove-AppxPackage -Package $p.PackageFullName -ErrorAction Stop
                $quitado = $true
            } catch {
                Write-Log ("  fallo al quitar {0}: {1}" -f $p.Name, $_.Exception.Message) 'ERROR'
            }
        }
        if (-not $quitado) { $estado = 'FALLÓ' } else { Write-Log ("  quitado {0}" -f $p.Name) }
    }
    return $estado
}

# ---------------------------------------------------------------------------
#  ACTUALIZAR TODO
# ---------------------------------------------------------------------------
function Invoke-Actualizacion {
    Write-Paso 'Buscando actualizaciones disponibles...' 'Cyan'
    $prev = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        if (-not $script:RutaWinget) { $script:RutaWinget = Get-RutaWinget }
        if (-not $script:RutaWinget) { Write-Warning 'winget no esta disponible.'; return 1 }
        $disponibles = (& $script:RutaWinget upgrade 2>&1 | Out-String)
        Write-Host $disponibles
        Write-Log $disponibles

        Write-Host ''
        $resp = Read-Host '  Actualizar todo ahora? (S/n)'
        if ($resp -and $resp -notmatch '^[sS]') { Write-Host '  Cancelado.' -ForegroundColor Yellow; return 0 }

        Write-Host ''
        Write-Paso 'Actualizando (puede tardar varios minutos)...' 'Cyan'
        $argumentos = @('upgrade', '--all', '--include-unknown', '--silent',
                        '--accept-package-agreements', '--accept-source-agreements')
        if ($Alcance -ne 'Auto') { $argumentos += @('--scope', $Alcance.ToLower()) }
        $argumentos += '--disable-interactivity'

        $null = & $script:RutaWinget @argumentos 2>&1 | ForEach-Object {
            $linea = [string]$_
            if ($linea -ne '') { Write-Host $linea -ForegroundColor DarkGray; Write-Log $linea }
            $linea
        }
        $codigo = $LASTEXITCODE
        Write-Log ("winget upgrade --all => codigo {0}" -f $codigo) 'CMD'

        if ($codigo -eq 0) {
            Write-Host ''
            Write-Host '  Actualizacion completada.' -ForegroundColor Green
        } else {
            Write-Host ''
            Write-Host ('  winget termino con codigo ' + $codigo) -ForegroundColor Yellow
        }
        return $(if ($codigo -eq 0) { 0 } else { 1 })
    } finally {
        $ErrorActionPreference = $prev
    }
}

# ---------------------------------------------------------------------------
#  PERFILES JSON
# ---------------------------------------------------------------------------
function Export-Perfil {
    param([string[]]$Paquetes, [string[]]$Bloat = @())
    $nombre = 'seleccion-{0}' -f (Get-Date -Format 'yyyyMMdd-HHmmss')
    $ruta = Join-Path $script:DirPerfile ($nombre + '.json')
    $obj = [pscustomobject]@{
        nombre    = $nombre
        creado    = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss')
        alcance   = $Alcance
        paquetes  = @($Paquetes)
        bloat     = @($Bloat)
    }
    $obj | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $ruta -Encoding UTF8
    Write-Log ("Perfil exportado: {0}" -f $ruta) 'OK'
    return $ruta
}

function Get-Perfil {
    param([Parameter(Mandatory)][string]$Ruta)
    if (-not (Test-Path -LiteralPath $Ruta)) { throw ('No existe el archivo: ' + $Ruta) }
    $json = Get-Content -LiteralPath $Ruta -Raw -Encoding UTF8 | ConvertFrom-Json
    $paquetes = @()
    if ($json.paquetes) { $paquetes = @($json.paquetes | ForEach-Object { [string]$_ }) }
    $bloat = @()
    if ($json.bloat) { $bloat = @($json.bloat | ForEach-Object { [string]$_ }) }
    return [pscustomobject]@{ Paquetes = $paquetes; Bloat = $bloat; Alcance = [string]$json.alcance }
}

# ---------------------------------------------------------------------------
#  MENÚ CON CASILLAS
# ---------------------------------------------------------------------------
function Write-FilaMenu {
    param(
        [int]$Fila,
        [string]$Texto = '',
        [string]$Color = 'Gray',
        [hashtable]$Cache,      # solo se escribe la fila si ha cambiado
        [int]$Ancho = 0         # se calcula una sola vez por repintado
    )
    try {
        if ($Ancho -le 0) { $Ancho = [Console]::WindowWidth - 1 }
        if ($Ancho -lt 4) { return }
        if ($Fila -lt 0 -or $Fila -ge [Console]::WindowHeight) { return }   # fuera de pantalla
        if ($null -eq $Texto) { $Texto = '' }
        if ($Texto.Length -gt $Ancho) { $Texto = $Texto.Substring(0, $Ancho) }
        $Texto = $Texto.PadRight($Ancho)          # borra restos de la linea anterior

        $clave = $Color + [char]9 + $Texto
        if ($Cache -and $Cache.ContainsKey($Fila) -and $Cache[$Fila] -eq $clave) { return }  # ya esta

        [Console]::SetCursorPosition(0, $Fila)
        $anterior = [Console]::ForegroundColor
        $nuevo = [ConsoleColor]$Color
        if ($anterior -ne $nuevo) { [Console]::ForegroundColor = $nuevo }
        [Console]::Write($Texto)                  # sin salto de linea: evita scroll
        if ($anterior -ne $nuevo) { [Console]::ForegroundColor = $anterior }
        if ($Cache) { $Cache[$Fila] = $clave }
    } catch { }
}

function Get-IndiceItem {
    param([System.Collections.ArrayList]$Elementos, [int]$Desde, [int]$Direccion)
    $i = $Desde
    while ($i -ge 0 -and $i -lt $Elementos.Count -and $Elementos[$i].Tipo -ne 'item') { $i += $Direccion }
    if ($i -lt 0 -or $i -ge $Elementos.Count) { return -1 }
    return $i
}

function Get-MenuGeometria {
    # Decide donde se pinta el menu para que QUEPA ENTERO en la ventana visible.
    # Antes se usaba BufferHeight (suele tener cientos de filas): la mitad de la
    # lista salia por debajo de la ventana, no se veia y el cursor "se quedaba
    # pillado" sin que el listado se desplazara.
    param([int]$TotalElementos)
    $ancho = [Console]::WindowWidth - 1
    if ($ancho -lt 4) { $ancho = 4 }
    $alto = [Console]::WindowHeight
    if ($alto -lt 10) { $alto = 10 }
    $reserva = 3                              # titulo + contador + ayuda
    $top = 0
    try { $top = [Console]::CursorTop } catch { $top = 0 }
    $espacio = $alto - $reserva - $top
    if ($espacio -lt 8) { $top = 0; $espacio = $alto - $reserva }
    $visibles = [Math]::Min($TotalElementos, [Math]::Max(3, $espacio))
    return [pscustomobject]@{
        Top      = $top
        Visibles = $visibles
        Totales  = $visibles + $reserva
        Ancho    = $ancho
        Alto     = $alto
    }
}

function Invoke-MenuNativo {
    param(
        [string]$Titulo,
        [System.Collections.ArrayList]$Elementos,
        [int[]]$SeleccionInicial = @(),
        [System.Collections.Specialized.OrderedDictionary]$Preajustes,
        [switch]$Exportable,
        [switch]$TodoInicial
    )

    $seleccion = New-Object 'System.Collections.Generic.HashSet[int]'
    if ($TodoInicial) {
        for ($i = 0; $i -lt $Elementos.Count; $i++) { if ($Elementos[$i].Tipo -eq 'item') { [void]$seleccion.Add($i) } }
    } else {
        foreach ($i in $SeleccionInicial) { if ($i -ge 0 -and $i -lt $Elementos.Count) { [void]$seleccion.Add($i) } }
    }

    $totalItems = @($Elementos | Where-Object { $_.Tipo -eq 'item' }).Count
    if ($totalItems -eq 0) {
        return [pscustomobject]@{ Cancelado = $true; Indices = [int[]]@() }
    }

    $cursor = Get-IndiceItem -Elementos $Elementos -Desde 0 -Direccion 1
    $scroll = 0
    $modoInput = $false
    $buffer = ''
    $mensaje = ''
    $terminar = $false
    $cancelado = $true

    $g = Get-MenuGeometria -TotalElementos $Elementos.Count
    $top      = $g.Top
    $visibles = $g.Visibles
    $totales  = $g.Totales
    $ancho    = $g.Ancho
    $alto     = $g.Alto
    $cache = @{}
    for ($f = $top + $totales; $f -lt $alto; $f++) {
        Write-FilaMenu -Fila $f -Texto '' -Cache $cache -Ancho $ancho   # limpia el resto
    }

    while ($true) {
        if ($cursor -lt $scroll) { $scroll = $cursor }
        if ($cursor -ge ($scroll + $visibles)) { $scroll = $cursor - $visibles + 1 }
        $maxScroll = [Math]::Max(0, $Elementos.Count - $visibles)
        if ($scroll -gt $maxScroll) { $scroll = $maxScroll }
        if ($scroll -lt 0) { $scroll = 0 }

        Write-FilaMenu -Fila $top -Texto ('  ' + $Titulo) -Color 'Cyan' -Cache $cache -Ancho $ancho
        for ($k = 0; $k -lt $visibles; $k++) {
            $i = $scroll + $k
            $fila = $top + 1 + $k
            if ($i -ge $Elementos.Count) { Write-FilaMenu -Fila $fila -Texto '' -Cache $cache -Ancho $ancho; continue }
            $e = $Elementos[$i]
            if ($e.Tipo -eq 'cab') {
                Write-FilaMenu -Fila $fila -Texto ('    --- ' + $e.Nombre + ' ---') -Color 'DarkCyan' -Cache $cache -Ancho $ancho
            } else {
                $marc = '  '
                if ($seleccion.Contains($i)) { $marc = '[x]' } else { $marc = '[ ]' }
                $punt = '   '
                if ($i -eq $cursor) { $punt = ' > ' }
                $texto = $punt + $marc + ' ' + $e.Nombre
                if ($e.Id -ne $e.Nombre) { $texto += ('   (' + $e.Id + ')') }
                $color = 'Gray'
                if ($i -eq $cursor) { $color = 'White' }
                Write-FilaMenu -Fila $fila -Texto ('  ' + $texto) -Color $color -Cache $cache -Ancho $ancho
            }
        }

        if ($mensaje) {
            Write-FilaMenu -Fila ($top + 1 + $visibles) -Texto ('  ' + $mensaje) -Color 'Green' -Cache $cache -Ancho $ancho
        } else {
            Write-FilaMenu -Fila ($top + 1 + $visibles) -Texto ('  {0} marcado(s) de {1}' -f $seleccion.Count, $totalItems) -Color 'Yellow' -Cache $cache -Ancho $ancho
        }
        if ($modoInput) {
            $ayuda = '  ID de winget: ' + $buffer + ' | Enter=anadir, Retroceso=borrar, Esc=cancelar'
        } else {
            # El .= es importante: antes el "1-9=perfil" SOBRESCRIBIA la linea y
            # dejaba de anunciar a/n/i/g, que siguen funcionando igual.
            $ayuda = '  Flechas=mover  Esp=marcar  Enter=aceptar  Esc=salir'
            if ($Preajustes) { $ayuda += '  1-9=perfil' }
            $ayuda += '  a=todas n=ninguna i=invertir g=ID'
            if ($Exportable) { $ayuda += '  x=JSON' }
        }
        Write-FilaMenu -Fila ($top + 2 + $visibles) -Texto $ayuda -Color 'DarkGray' -Cache $cache -Ancho $ancho

        $tecla = [Console]::ReadKey($true)

        if ($modoInput) {
            $mensaje = ''
            if ($tecla.Key -eq [ConsoleKey]::Enter) {
                $id = $buffer.Trim()
                if ($id) {
                    $idx = $Elementos.Add([pscustomobject]@{ Tipo = 'item'; Nombre = $id; Id = $id; Grupo = 'Personalizados' })
                    [void]$seleccion.Add($idx)
                    $cursor = $idx
                    $totalItems++
                }
                $modoInput = $false
                $buffer = ''
            } elseif ($tecla.Key -eq [ConsoleKey]::Escape) {
                $modoInput = $false
                $buffer = ''
            } elseif ($tecla.Key -eq [ConsoleKey]::Backspace) {
                if ($buffer.Length -gt 0) { $buffer = $buffer.Substring(0, $buffer.Length - 1) }
            } elseif ($tecla.KeyChar -and -not [char]::IsControl($tecla.KeyChar)) {
                $buffer += [string]$tecla.KeyChar
            }
            continue
        }

        $mensaje = ''
        if ($tecla.Key -eq [ConsoleKey]::UpArrow) {
            $n = Get-IndiceItem -Elementos $Elementos -Desde ($cursor - 1) -Direccion -1
            if ($n -ge 0) { $cursor = $n }
        } elseif ($tecla.Key -eq [ConsoleKey]::DownArrow) {
            $n = Get-IndiceItem -Elementos $Elementos -Desde ($cursor + 1) -Direccion 1
            if ($n -ge 0) { $cursor = $n }
        } elseif ($tecla.Key -eq [ConsoleKey]::Home) {
            $n = Get-IndiceItem -Elementos $Elementos -Desde 0 -Direccion 1
            if ($n -ge 0) { $cursor = $n }
        } elseif ($tecla.Key -eq [ConsoleKey]::End) {
            $n = Get-IndiceItem -Elementos $Elementos -Desde ($Elementos.Count - 1) -Direccion -1
            if ($n -ge 0) { $cursor = $n }
        } elseif ($tecla.Key -eq [ConsoleKey]::PageUp) {
            $n = Get-IndiceItem -Elementos $Elementos -Desde ([Math]::Max(0, $cursor - $visibles)) -Direccion -1
            if ($n -ge 0) { $cursor = $n }
        } elseif ($tecla.Key -eq [ConsoleKey]::PageDown) {
            $n = Get-IndiceItem -Elementos $Elementos -Desde ([Math]::Min($Elementos.Count - 1, $cursor + $visibles)) -Direccion 1
            if ($n -ge 0) { $cursor = $n }
        } elseif ($tecla.Key -eq [ConsoleKey]::Spacebar) {
            if ($seleccion.Contains($cursor)) { [void]$seleccion.Remove($cursor) } else { [void]$seleccion.Add($cursor) }
        } elseif ($tecla.Key -eq [ConsoleKey]::Enter) {
            $terminar = $true; $cancelado = $false
        } elseif ($tecla.Key -eq [ConsoleKey]::Escape) {
            $terminar = $true; $cancelado = $true
        } elseif ($tecla.Key -eq [ConsoleKey]::A) {
            for ($i = 0; $i -lt $Elementos.Count; $i++) { if ($Elementos[$i].Tipo -eq 'item') { [void]$seleccion.Add($i) } }
        } elseif ($tecla.Key -eq [ConsoleKey]::N) {
            $seleccion.Clear()
        } elseif ($tecla.Key -eq [ConsoleKey]::I) {
            for ($i = 0; $i -lt $Elementos.Count; $i++) {
                if ($Elementos[$i].Tipo -ne 'item') { continue }
                if ($seleccion.Contains($i)) { [void]$seleccion.Remove($i) } else { [void]$seleccion.Add($i) }
            }
        } elseif ($tecla.Key -eq [ConsoleKey]::G) {
            $modoInput = $true
            $buffer = ''
        } elseif ($tecla.Key -eq [ConsoleKey]::X -and $Exportable) {
            $ids = @()
            foreach ($i in ($seleccion | Sort-Object)) {
                if ($Elementos[$i].Tipo -eq 'item') { $ids += $Elementos[$i].Id }
            }
            if ($ids.Count -gt 0) {
                try { $ruta = Export-Perfil -Paquetes $ids; $mensaje = 'Guardado: ' + (Split-Path -Leaf $ruta) }
                catch { $mensaje = 'Error al guardar: ' + $_.Exception.Message }
            } else { $mensaje = 'Nada marcado que guardar' }
        } elseif ($Preajustes -and
                 (($tecla.Key -ge [ConsoleKey]::D1 -and $tecla.Key -le [ConsoleKey]::D9) -or
                  ($tecla.Key -ge [ConsoleKey]::NumPad1 -and $tecla.Key -le [ConsoleKey]::NumPad9))) {
            $num = 0
            if ($tecla.Key -ge [ConsoleKey]::D1 -and $tecla.Key -le [ConsoleKey]::D9) {
                $num = [int]$tecla.Key - [int][ConsoleKey]::D1 + 1
            } elseif ($tecla.Key -ge [ConsoleKey]::NumPad1 -and $tecla.Key -le [ConsoleKey]::NumPad9) {
                $num = [int]$tecla.Key - [int][ConsoleKey]::NumPad1 + 1
            }
            $claves = @($Preajustes.Keys)
            if ($num -ge 1 -and $num -le $claves.Count) {
                $ids = @($Preajustes[$claves[$num - 1]])
                $seleccion.Clear()
                for ($i = 0; $i -lt $Elementos.Count; $i++) {
                    if ($Elementos[$i].Tipo -eq 'item' -and ($ids -contains $Elementos[$i].Id)) { [void]$seleccion.Add($i) }
                }
                $mensaje = 'Perfil "' + $claves[$num - 1] + '" aplicado'
                $n = Get-IndiceItem -Elementos $Elementos -Desde 0 -Direccion 1
                if ($n -ge 0) { $cursor = $n }
            }
        }

        if ($terminar) { break }
    }

    try {
        $ultima = [Math]::Min($top + $totales - 1, [Console]::BufferHeight - 1)
        [Console]::SetCursorPosition(0, $ultima)
        [Console]::WriteLine('')
    } catch { }

    $arr = @($seleccion | Sort-Object)
    return [pscustomobject]@{ Cancelado = $cancelado; Indices = [int[]]$arr }
}

function Invoke-MenuSimple {
    param(
        [string]$Titulo,
        [System.Collections.ArrayList]$Elementos,
        [int[]]$SeleccionInicial = @(),
        [System.Collections.Specialized.OrderedDictionary]$Preajustes,
        [switch]$Exportable,
        [switch]$TodoInicial
    )
    Write-Host ''
    Write-Host ('  ' + $Titulo) -ForegroundColor Cyan
    $numeros = @{}
    $n = 0
    for ($i = 0; $i -lt $Elementos.Count; $i++) {
        $e = $Elementos[$i]
        if ($e.Tipo -eq 'cab') { Write-Host ('  --- ' + $e.Nombre + ' ---') -ForegroundColor DarkCyan; continue }
        $n++
        $numeros[$n] = $i
        $marca = ' '
        if ($TodoInicial -or ($SeleccionInicial -contains $i)) { $marca = 'x' }
        Write-Host ('  {0,2}) [{1}] {2}' -f $n, $marca, $e.Nombre)
    }
    $resp = Read-Host '  Marca los numeros (ej: 1,3,5), a=todo, n=ninguno, Enter=cancelar'
    $idx = @()
    if ($resp -match '^[aA]$') {
        $idx = @(0..($Elementos.Count - 1) | Where-Object { $Elementos[$_].Tipo -eq 'item' })
    } elseif ($resp) {
        foreach ($p in ($resp -split '[^\d]+')) {
            if ($p -and $numeros.ContainsKey([int]$p)) { $idx += $numeros[[int]$p] }
        }
    } else {
        return [pscustomobject]@{ Cancelado = $true; Indices = [int[]]@() }
    }
    return [pscustomobject]@{ Cancelado = $false; Indices = [int[]]$idx }
}

function Invoke-MenuConsola {
    param(
        [string]$Titulo,
        [System.Collections.ArrayList]$Elementos,
        [int[]]$SeleccionInicial = @(),
        [System.Collections.Specialized.OrderedDictionary]$Preajustes,
        [switch]$Exportable,
        [switch]$TodoInicial
    )
    $argumentos = @{
        Titulo            = $Titulo
        Elementos         = $Elementos
        SeleccionInicial  = $SeleccionInicial
        Preajustes        = $Preajustes
        Exportable        = $Exportable
        TodoInicial       = $TodoInicial
    }
    $nativo = $true
    try {
        if ([Console]::IsInputRedirected -or [Console]::IsOutputRedirected) { $nativo = $false }
        $res = Invoke-MenuNativo @argumentos
    } catch {
        $nativo = $false
        Write-Host ''
        Write-Host ('  (menu grafico no disponible: ' + $_.Exception.Message + ')') -ForegroundColor DarkYellow
    }
    if ($nativo) { return $res }
    return Invoke-MenuSimple @argumentos
}

# ---------------------------------------------------------------------------
#  CONSTRUCCIÓN DE LISTAS
# ---------------------------------------------------------------------------
function Get-ElementosProgramas {
    $lista = New-Object System.Collections.ArrayList
    foreach ($grupo in $script:Catalogo.Keys) {
        [void]$lista.Add([pscustomobject]@{ Tipo = 'cab'; Nombre = $grupo; Id = ''; Grupo = $grupo })
        foreach ($p in $script:Catalogo[$grupo]) {
            [void]$lista.Add([pscustomobject]@{ Tipo = 'item'; Nombre = $p.Nombre; Id = $p.Id; Grupo = $grupo })
        }
    }
    return , $lista
}

function Get-ElementosBloat {
    param([string[]]$PorDefecto = @())
    $lista = New-Object System.Collections.ArrayList
    foreach ($grupo in $script:BloatCatalogo.Keys) {
        [void]$lista.Add([pscustomobject]@{ Tipo = 'cab'; Nombre = $grupo; Id = ''; Grupo = $grupo })
        foreach ($b in $script:BloatCatalogo[$grupo]) {
            [void]$lista.Add([pscustomobject]@{ Tipo = 'item'; Nombre = $b.Nombre; Id = $b.Patron; Grupo = $grupo })
        }
    }
    return , $lista
}

function Get-Preseleccion {
    param([System.Collections.ArrayList]$Elementos, [string[]]$Ids, [switch]$PorDefecto)
    $idx = @()
    for ($i = 0; $i -lt $Elementos.Count; $i++) {
        if ($Elementos[$i].Tipo -ne 'item') { continue }
        if ($PorDefecto) {
            $encontrado = $false
            foreach ($grupo in $script:BloatCatalogo.Keys) {
                foreach ($b in $script:BloatCatalogo[$grupo]) {
                    if ($b.Patron -eq $Elementos[$i].Id -and $b.PorDefecto) { $encontrado = $true }
                }
            }
            if ($encontrado) { $idx += $i }
        } elseif ($Ids -contains $Elementos[$i].Id) { $idx += $i }
    }
    return [int[]]$idx
}

function Show-Leyenda {
    param([System.Collections.Specialized.OrderedDictionary]$Preajustes)
    Write-Host ''
    Write-Host '  Flechas=mover   Espacio=marcar   Enter=aceptar   Esc=cancelar' -ForegroundColor DarkGray
    Write-Host '  a=todas  n=ninguna  i=invertir  g=ID de winget  x=guardar JSON' -ForegroundColor DarkGray
    if ($Preajustes) {
        $n = 0
        $linea = '  Perfiles: '
        foreach ($k in $Preajustes.Keys) { $n++; $linea += ('{0}={1}  ' -f $n, $k) }
        Write-Host $linea -ForegroundColor DarkGray
    }
    Write-Host ''
}

# ---------------------------------------------------------------------------
#  OPCIONES DEL MENÚ PRINCIPAL
# ---------------------------------------------------------------------------
function Get-ElementosDeGrupos {
    param([System.Collections.ArrayList]$Elementos, [string[]]$Grupos)
    $lista = New-Object System.Collections.ArrayList
    foreach ($e in $Elementos) {
        if ($Grupos -contains $e.Grupo) { [void]$lista.Add($e) }
    }
    return , $lista
}

function Opcion-Instalar {
    $elementos = Get-ElementosProgramas
    $grupos = @($script:Catalogo.Keys)

    while ($true) {
        # --- 1a) elegir categoria: listas cortas, se navegan de corrida --------
        $cats = New-Object System.Collections.ArrayList
        [void]$cats.Add([pscustomobject]@{ Tipo = 'item'; Nombre = 'Todas las categorias'; Id = '*TODAS*'; Grupo = '' })
        foreach ($g in $grupos) {
            $n = @($script:Catalogo[$g]).Count
            [void]$cats.Add([pscustomobject]@{ Tipo = 'item'; Nombre = ('{0}  ({1})' -f $g, $n); Id = $g; Grupo = '' })
        }
        $elegidos = $grupos
        if (-not $Todo) {
            Write-Host ''
            Write-Host '  Flechas=mover   Espacio=marcar varias categorias   Enter=aceptar   Esc=salir' -ForegroundColor DarkGray
            Write-Host ''
            $rc = Invoke-MenuConsola -Titulo 'PASO 1 - ELIGE LA CATEGORIA' -Elementos $cats
            if ($rc.Cancelado) { Write-Host '  Seleccion cancelada.' -ForegroundColor Yellow; return 0 }
            $marcadas = @()
            foreach ($i in $rc.Indices) { if ($i -ge 0 -and $i -lt $cats.Count -and $cats[$i].Tipo -eq 'item') { $marcadas += [string]$cats[$i].Id } }
            if ($marcadas.Count -eq 0 -or $marcadas -contains '*TODAS*') { $elegidos = $grupos }
            else { $elegidos = @($grupos | Where-Object { $marcadas -contains $_ }) }
            if ($elegidos.Count -eq 0) { $elegidos = $grupos }
        }

        # --- 1b) solo los programas de esas categorias -------------------------
        $filtrados = Get-ElementosDeGrupos -Elementos $elementos -Grupos $elegidos
        if ($filtrados.Count -eq 0) { Write-Warning 'Esa categoria no tiene programas.'; return 0 }
        $inicial = @()
        if ($Todo) { $inicial = @(0..($filtrados.Count - 1)) }
        Show-Leyenda -Preajustes $script:Preajustes
        $titulo = 'PASO 2 - PROGRAMAS: ' + ($elegidos -join ', ')
        $r = Invoke-MenuConsola -Titulo $titulo `
                                -Elementos $filtrados -SeleccionInicial $inicial `
                                -Preajustes $script:Preajustes -Exportable -TodoInicial:$Todo
        if ($r.Cancelado) { continue }        # Esc: vuelve a elegir categoria
        $ids = @()
        foreach ($i in $r.Indices) { if ($i -ge 0 -and $i -lt $filtrados.Count -and $filtrados[$i].Tipo -eq 'item') { $ids += $filtrados[$i].Id } }
        if ($ids.Count -eq 0) { Write-Warning 'No marcaste ningun programa.'; return 0 }
        return Invoke-Instalacion -Ids $ids -Alcance $Alcance -Confirmar
    }
    return 0
}

function Opcion-Importar {
    $archivos = @(Get-ChildItem -LiteralPath $script:DirPerfile -Filter '*.json' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending)
    if ($archivos.Count -eq 0) {
        Write-Host ''
        Write-Host '  No hay perfiles en la carpeta perfiles\' -ForegroundColor Yellow
        Write-Host ('  Guarda uno con la tecla "x" dentro del menu de instalacion.') -ForegroundColor DarkGray
        return 0
    }
    Write-Host ''
    Write-Host '  Perfiles disponibles:' -ForegroundColor Cyan
    for ($i = 0; $i -lt $archivos.Count; $i++) { Write-Host ('    {0}) {1}' -f ($i + 1), $archivos[$i].Name) }
    $op = Read-Host '  Cual? (numero, Enter=volver)'
    if (-not $op -or $op -notmatch '^\d+$') { return 0 }
    $n = [int]$op
    if ($n -lt 1 -or $n -gt $archivos.Count) { Write-Warning 'Opcion no valida.'; return 0 }
    try {
        $p = Get-Perfil -Ruta $archivos[$n - 1].FullName
    } catch {
        Write-Warning ('No se pudo leer el perfil: ' + $_.Exception.Message)
        return 0
    }
    if ($p.Paquetes.Count -eq 0) { Write-Warning 'El perfil no contiene paquetes.'; return 0 }
    $alc = $Alcance
    if ($p.Alcance -and $p.Alcance -ne 'Auto') { $alc = $p.Alcance }
    return Invoke-Instalacion -Ids $p.Paquetes -Alcance $alc -Confirmar
}

function Opcion-Limpieza {
    $elementos = Get-ElementosBloat
    $inicial = Get-Preseleccion -Elementos $elementos -PorDefecto
    Write-Host ''
    Write-Host '  DES-BLOAT: quita apps preinstaladas de Windows.' -ForegroundColor Cyan
    Write-Host '  Seleccion predeterminada = las que solo son ruido.' -ForegroundColor DarkGray
    Show-Leyenda -Preajustes $null
    $r = Invoke-MenuConsola -Titulo 'APPS A QUITAR  (dejadas las que no quieras tocar)' `
                            -Elementos $elementos -SeleccionInicial $inicial
    if ($r.Cancelado) { Write-Host '  Seleccion cancelada.' -ForegroundColor Yellow; return 0 }
    $patrones = @()
    foreach ($i in $r.Indices) { if ($elementos[$i].Tipo -eq 'item') { $patrones += $elementos[$i] } }
    if ($patrones.Count -eq 0) { Write-Warning 'No marcaste nada.'; return 0 }

    Write-Host ''
    Write-Host ('  Se quitaran {0} app(s):' -f $patrones.Count) -ForegroundColor Cyan
    foreach ($p in $patrones) { Write-Host ('   - ' + $p.Nombre) }
    $resp = Read-Host '  Continuar? (S/n)'
    if ($resp -and $resp -notmatch '^[sS]') { Write-Host '  Cancelado.' -ForegroundColor Yellow; return 0 }

    $resultados = New-Object System.Collections.ArrayList
    $n = 0
    foreach ($p in $patrones) {
        $n++
        Write-Host ('[{0}/{1}] {2}' -f $n, $patrones.Count, $p.Nombre) -ForegroundColor Cyan
        $estado = Remove-AppxBloat -Patron $p.Id -Nombre $p.Nombre
        $color = 'Green'
        if ($estado -eq 'NO ENCONTRADO') { $color = 'DarkGray' }
        elseif ($estado -eq 'FALLÓ') { $color = 'Red' }
        Write-Host ('      -> ' + $estado) -ForegroundColor $color
        [void]$resultados.Add([pscustomobject]@{ Paquete = $p.Nombre; Estado = $estado })
    }
    Show-Resumen -Resultados $resultados -Titulo 'RESUMEN DES-BLOAT'
    return @($resultados | Where-Object { $_.Estado -eq 'FALLÓ' }).Count
}

# ---------------------------------------------------------------------------
#  GENERADOR DE docs/catalogo.md
#  (el documento dice ser "generado automaticamente": aqui esta el generador)
# ---------------------------------------------------------------------------
function New-CatalogoDoc {
    $ruta = Join-Path (Join-Path $script:DirBase 'docs') 'catalogo.md'
    try {
        $dir = Split-Path -Parent $ruta
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

        # ID -> nombre, para escribir los preajustes en legible y no en IDs
        $nombres = @{}
        $totalProg = 0
        foreach ($g in $script:Catalogo.Keys) {
            foreach ($p in $script:Catalogo[$g]) { $nombres[$p.Id] = $p.Nombre; $totalProg++ }
        }
        $totalBloat = 0
        foreach ($g in $script:BloatCatalogo.Keys) { $totalBloat += @($script:BloatCatalogo[$g]).Count }

        $L = New-Object 'System.Collections.Generic.List[string]'
        $L.Add('# Catálogo de programas')
        $L.Add('')
        $L.Add('Lista completa de lo que ofrece el menú, con su **ID de winget**. Generada automáticamente desde `Instalar-Software.ps1` con `-Modo Catalogo` (no la edites a mano: si cambias el catálogo, vuelve a generarla).')
        $L.Add('')
        $L.Add(('Total: **{0} programas** en **{1} categorías**.' -f $totalProg, $script:Catalogo.Count))
        $L.Add('')
        $L.Add('Para instalar cualquiera de ellos suelto, fuera del menú:')
        $L.Add('')
        $L.Add('```powershell')
        $L.Add('winget install --id <ID> -e --accept-package-agreements --accept-source-agreements')
        $L.Add('```')
        $L.Add('')
        $L.Add('## Programas')
        $L.Add('')
        $L.Add('| # | Programa | ID de winget | Categoría |')
        $L.Add('|--:|:---------|:-------------|:----------|')
        $n = 0
        foreach ($g in $script:Catalogo.Keys) {
            foreach ($p in $script:Catalogo[$g]) {
                $n++
                $L.Add(('| {0} | {1} | `{2}` | {3} |' -f $n, $p.Nombre, $p.Id, $g))
            }
        }
        $L.Add('')
        $L.Add('## Perfiles rápidos (teclas 1-9 dentro del menú)')
        $L.Add('')
        $L.Add('| Tecla | Perfil | Programas |')
        $L.Add('|--:|:-------|:----------|')
        $t = 0
        foreach ($k in $script:Preajustes.Keys) {
            $t++
            $texto = @($script:Preajustes[$k] | ForEach-Object { if ($nombres[$_]) { $nombres[$_] } else { $_ } }) -join ', '
            $L.Add(('| {0} | {1} | {2} |' -f $t, $k, $texto))
        }
        $L.Add('')
        $L.Add('Los perfiles rápidos son listas de IDs: si marcas un programa nuevo y quieres')
        $L.Add('que salga en uno de ellos, se añade en `$script:Preajustes`.')
        $L.Add('')
        $L.Add('## Apps preinstaladas (opción 4: des-bloat)')
        $L.Add('')
        $L.Add(('{0} apps repartidas en {1} grupos. Cada entrada trae nombre, patrón de' -f $totalBloat, $script:BloatCatalogo.Count))
        $L.Add('búsqueda y si viene marcada por defecto (solo las que son ruido).')
        $L.Add('')
        $L.Add('| Grupo | Apps | Marcadas por defecto |')
        $L.Add('|:------|-----:|---------------------:|')
        foreach ($g in $script:BloatCatalogo.Keys) {
            $elems    = @($script:BloatCatalogo[$g])
            $marcadas = @($elems | Where-Object { $_.PorDefecto }).Count
            $L.Add(('| {0} | {1} | {2} |' -f $g, $elems.Count, $marcadas))
        }
        $L.Add('')

        # UTF-8 con BOM: los acentos se ven bien tambien en el Bloc de notas
        [IO.File]::WriteAllText($ruta, (($L -join "`r`n") + "`r`n"), (New-Object Text.UTF8Encoding($true)))
        Write-Log ("Catalogo regenerado: {0} ({1} programas)" -f $ruta, $totalProg) 'OK'
        Write-Paso ('  Catálogo regenerado: {0}  ({1} programas, {2} apps de bloat)' -f $ruta, $totalProg, $totalBloat) 'Green'
        return 0
    } catch {
        Write-Warning ('No se pudo generar el catálogo: ' + $_.Exception.Message)
        return 1
    }
}

function Show-MenuPrincipal {
    while ($true) {
        Write-Host ''
        Write-Host '==============================================' -ForegroundColor Cyan
        Write-Host '   INSTALADOR DE SOFTWARE DESENTENDIDO (winget)' -ForegroundColor Cyan
        Write-Host '==============================================' -ForegroundColor Cyan
        Write-Host '   1) Instalar programas (elige categoria)'
        Write-Host '   2) Importar perfil JSON e instalar (desatendido)'
        Write-Host '   3) Actualizar todo (winget upgrade --all)'
        Write-Host '   4) Quitar apps preinstaladas de Windows (des-bloat)'
        Write-Host '   5) Comprobar que los IDs del catalogo sigan valiendo'
        Write-Host '   6) Salir'
        Write-Host '==============================================' -ForegroundColor Cyan
        if (-not (Test-Elevado)) { Write-Host '   (sin admin: instalaciones limitadas al usuario actual)' -ForegroundColor DarkYellow }
        Write-Host ''
        $op = Read-Host '   Opcion'
        $fallas = 0
        switch ($op) {
            '1' { $fallas = Opcion-Instalar }
            '2' { $fallas = Opcion-Importar }
            '3' { $fallas = Invoke-Actualizacion }
            '4' { $fallas = Opcion-Limpieza }
            '5' { $fallas = Invoke-Verificacion }
            '6' { return 0 }
            default {
                if ($op) { Write-Warning 'Opcion no valida.' }
            }
        }
        if ($fallas -gt 0) { Write-Host ('   Se han producido ' + $fallas + ' error(es). Revisa el log.') -ForegroundColor Red }
        Write-Host ''
        try { $null = Read-Host '   Pulsa Enter para volver al menu' } catch { return $fallas }
    }
}

# ---------------------------------------------------------------------------
#  PRINCIPAL
# ---------------------------------------------------------------------------
Inicializar-Entorno

# -Modo Catalogo solo regenera docs/catalogo.md: no necesita winget, ni admin,
# ni tocar la consola. Va antes de todo lo demás por eso.
if ($Modo -eq 'Catalogo') { exit (New-CatalogoDoc) }

$script:QuickEditOriginal = Get-SeleccionRapida   # para restaurarlo al salir
Set-ConsolaFuente -Alto $Fuente
Set-SeleccionRapida $false      # un clic en la ventana no debe congelar el menu
if (-not (Test-Winget)) { Write-Log 'winget no disponible. Saliendo.' 'ERROR'; exit 2 }

$salida = 0
switch ($Modo) {
    'Menu' {
        Invoke-Elevacion
        $salida = Show-MenuPrincipal
    }
    'Instalar' {
        if (-not $Perfil) { Write-Warning 'Modo Instalar requiere -Perfil <archivo.json>'; exit 2 }
        try {
            $p = Get-Perfil -Ruta $Perfil
        } catch {
            Write-Warning $_.Exception.Message
            exit 2
        }
        Invoke-Elevacion
        $alc = $Alcance
        if ($p.Alcance -and $p.Alcance -ne 'Auto') { $alc = $p.Alcance }
        $salida = Invoke-Instalacion -Ids $p.Paquetes -Alcance $alc
    }
    'Actualizar' {
        Invoke-Elevacion
        $salida = Invoke-Actualizacion
    }
    'Verificar' {
        # No hace falta admin: solo consulta winget
        $salida = Invoke-Verificacion
    }
    'Limpieza' {
        if ($Perfil) {
            # Antes, un -Perfil inexistente caia sin mas en el menu interactivo
            # (y sin pedir administrador): ahora es un error de configuracion.
            if (-not (Test-Path -LiteralPath $Perfil)) {
                Write-Warning ('No existe el archivo de perfil: ' + $Perfil)
                exit 2
            }
            Invoke-Elevacion
            try { $p = Get-Perfil -Ruta $Perfil } catch { Write-Warning $_.Exception.Message; exit 2 }
            $resultados = New-Object System.Collections.ArrayList
            if ($p.Bloat.Count -gt 0) {
                foreach ($patron in $p.Bloat) {
                    $estado = Remove-AppxBloat -Patron $patron -Nombre $patron
                    Write-Host ('  {0} -> {1}' -f $patron, $estado)
                    [void]$resultados.Add([pscustomobject]@{ Paquete = $patron; Estado = $estado })
                }
                Show-Resumen -Resultados $resultados -Titulo 'RESUMEN DES-BLOAT'
                $salida = @($resultados | Where-Object { $_.Estado -eq 'FALLÓ' }).Count
            } else { Write-Warning 'El perfil no tiene lista "bloat".' }
        } else {
            Invoke-Elevacion          # quitar apps preinstaladas exige admin
            $salida = Opcion-Limpieza
        }
    }
}

Write-Log ('Fin. Codigo de salida={0}' -f $salida) 'FIN'
# Restaura la "seleccion rapida" COMO ESTABA antes (antes se forzaba a activada
# aunque el usuario la tuviera desactivada).
if ($null -ne $script:QuickEditOriginal) { Set-SeleccionRapida ([bool]$script:QuickEditOriginal) }
else { Set-SeleccionRapida $true }

# Contrato de codigos de salida (README y docs/problemas.md): 0 = todo bien,
# 1 = hubo fallos, 2 = error de configuracion. Las funciones devuelven el
# NUMERO de fallos para pintarlos en pantalla; aqui se normaliza.
if ($salida -gt 0) { exit 1 }
exit 0
