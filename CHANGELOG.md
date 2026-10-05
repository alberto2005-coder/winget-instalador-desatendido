# Changelog

Todo lo notable de este proyecto, con el formato de
[Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el versionado
[SemVer](https://semver.org/lang/es/).

## 1.0.0 - 2026-10-05

Primera versión publicada.

### Añadido

- **Menú por categorías**: la opción 1 ahora tiene dos pasos (elige categoría →
  solo se listan sus programas). Listas cortas que se navegan de corrida.
- **Menú gráfico con casillas**: flechas, `Espacio` para marcar, `Enter`, `Esc`,
  `A`/`N`/`I` (todos/ninguno/invertir), `G` (añadir un ID de winget a mano) y
  `X` (guardar la selección como perfil JSON).
- **Perfiles rápidos** con las teclas `1`–`9` (Básico, Gaming, Desarrollo,
  Ofimática, Comunicación, Streaming).
- **Perfiles JSON** para instalación desatendida en otro PC, con 5 ejemplos en
  `perfiles\`.
- **Des-bloat** (opción 4): quita apps preinstaladas; por defecto solo vienen
  marcadas las que son ruido.
- **Comprobación de IDs** (opción 5 / `-Modo Verificar`): valida uno a uno los
  IDs del catálogo, los perfiles rápidos y `perfiles\*.json` y te dice cuáles
  han dejado de existir.
- **Actualización masiva** (opción 3): `winget upgrade --all` con confirmación.
- **Letra de consola**: el script agranda la fuente (mínimo 18 px) y ajusta la
  ventana a la pantalla; configurable con `-Fuente`.
- **Instalación de winget ausente**: si no hay *App Installer*, lo descarga de
  la release oficial con sus dependencias, con reintentos y verificación.
- **`INICIAR.bat`**: pide administrador, salta la política de ejecución y
  informa del código de salida si algo falla.
- **Códigos de salida**: `0` todo bien, `1` hubo fallos, `2` error de
  configuración.
- Documentación en `docs/` (catálogo, perfiles, solución de problemas).

### Corregido

- **9 IDs rotos** que ya no existían en winget (`NodeJS.NodeJS` →
  `OpenJS.NodeJS`, `Notepad++ Notepad++` → `Notepad++.Notepad++`,
  `VivaldiTechnologies.Vivaldi`, `PeaZip.PeaZip`, `IrfanView.IrfanView`,
  `dotPDN.paintdotnet`, `RockstarGames.RockstarGamesLauncher`,
  `Blizzard.Battle.net`, `WhatsApp.WhatsApp` → `9NKSQGP7F2NH`).
- **`INICIAR.bat` no arrancaba** cuando se lanzaba sin argumentos: `-ArgumentList '%*'`
  recibía una cadena vacía y PowerShell abortaba antes de pedir UAC.
- **No se veía nada durante la instalación**: la salida de winget se capturaba
  entera y solo se mostraba al terminar. Ahora se reenvía línea a línea.
- **La consola se congelaba al hacer clic** (el título ponía "Seleccionar"): se
  desactiva el modo de selección rápida mientras corre el script y se restaura
  al salir.
- **El menú se quedaba pillado**: la lista se calculaba con el buffer de la
  consola (cientos de filas) en vez de con la ventana, así que la mitad se
  pintaba fuera de pantalla: no se veía desplazar el cursor ni aparecer las
  marcas `[x]`. Ahora la geometría se ajusta a la ventana y solo se repinta lo
  que cambia (más fluido con listas largas).
