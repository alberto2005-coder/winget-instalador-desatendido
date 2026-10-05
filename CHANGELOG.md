# Changelog

Todo lo notable de este proyecto, con el formato de
[Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/) y el versionado
[SemVer](https://semver.org/lang/es/).

## 1.0.1 - 2026-10-05

Corrección de fallos detectados en la revisión de código.

### Corregido

- **El script se guardó sin BOM UTF-8** (fallo crítico). PowerShell 5.1 lee los
  `.ps1` sin BOM con la página de códigos de Windows, así que todos los acentos
  se interpretaban mal: los menús enseñaban `Bǭsico`, `CompresiǦn`,
  `Configuraci??n` y los textos de resumen salían rotos. Ahora el archivo
  empieza por BOM UTF-8 y se lee bien en cualquier equipo.
- **`-Ayuda` no funcionaba**: llamaba a `Get-Help -LiteralPath`, un parámetro
  que no existe, así que salía un error y no se mostraba nada.
- **La ayuda del script era invisible**: PowerShell no reconoce el bloque
  `<# ... #>` si queda pegado a la línea `#Requires`. Al pedir
  `Get-Help .\Instalar-Software.ps1 -Full` solo salía la sintaxis. Ahora hay
  una línea en blanco de separación y se muestra sinopsis, descripción,
  parámetros, notas y ejemplos.
- **`-Modo Limpieza` no pedía administrador**: sin `-Perfil`, el des-bloat se
  lanzaba sin elevación y `Remove-AppxProvisionedPackage` /
  `Remove-AppxPackage -AllUsers` fallaban con `Acceso denegado`.
- **`-Modo Limpieza -Perfil <ruta inexistente>` se tragaba el error** y abría
  el menú interactivo como si nada. Ahora avisa y sale con código `2`.
- **Códigos de salida fuera del contrato**: varias funciones devolvían el
  número de fallos (3, 7, 12…) y el script hacía `exit` con ese valor, mientras
  que la documentación prometía `0 / 1 / 2`. Ahora se normaliza al final.
- **La ayuda del menú escondía atajos vivos**: con perfiles rápidos la línea
  se sobrescribía y dejaba de anunciar `a`/`n`/`i`/`g`, que seguían funcionando.
- **Dos guardados en el mismo segundo se pisaban**: `Export-Perfil` nombraba el
  archivo `seleccion-AAAAmmdd-HHmmss.json` (sin milisegundos) y usaba
  `Set-Content`, de modo que el segundo perfil sobrescribía al primero y se
  perdía. Ahora, si el archivo ya existe, se añade `-2`, `-3`…; el nombre
  documentado sigue siendo el habitual en el caso normal.
- **El menú de respaldo no sabía guardar**: si el menú gráfico no está
  disponible (consola redirigida), `Invoke-MenuSimple` ignoraba `-Exportable`
  y la tecla `X` no existía, aunque el menú nativo sí la tenía. Ahora acepta
  el comando `x` en el propio prompt y guarda `paquetes` o `bloat` igual.
- **`Show-Resumen` comparaba dos veces lo mismo**
  (`-like 'YA ESTABA*' -or -like 'YA ESTABA*'`): condición muerta de copiar y
  pegar.
- **La consola no se restauraba al salir**: se forzaba la "selección rápida"
  a activada aunque el usuario la tuviera desactivada. Ahora se guarda el
  estado original y se devuelve tal cual.
- **`Get-EstaInstalado` dependía del idioma**: solo buscaba el texto inglés
  `No installed package found`, que en Windows en español no aparece. Ahora
  comprueba además el código fijo `0x8A150014`, que winget no localiza.
- **Reintentos inútiles ante un ID caducado**: si el paquete ya no existe,
  `Install-Paquete` repetía la instalación entera (y el segundo intento se
  lanzaba sin `--disable-interactivity`). Ahora corta al primer `0x8A150014`.
- **Los logs crecían sin límite**: una ejecución = un archivo `.log`. Se
  conservan los 20 más recientes.

### Añadido

- **`-Modo Catalogo`**: regenera `docs/catalogo.md` desde el propio script.
  El documento decía ser "generado automáticamente" y no había ningún
  generador; ahora el catálogo nunca se queda desfasado del código.
- **`.gitignore`**: los `log/*.log` dejan de versionarse.
- **Des-bloat también al instalar un perfil**: `-Modo Instalar -Perfil` y la
  **opción 2** (importar JSON) aplican ahora la lista `bloat` del perfil además
  de sus paquetes, que era lo que ya prometían `README.md` y
  `docs/perfiles.md` sin que el código lo hiciera. En la opción 2 se pide
  confirmación aparte, por si el usuario cancela la instalación.
- **La opción 4 puede guardar su selección**: el menú de des-bloat recibe
  `-Exportable -ExportarBloat`, así que la tecla `X` escribe un perfil con el
  array `bloat` (y `paquetes` vacío), como documenta `docs/perfiles.md`.
- **Función `Invoke-DesBloatPerfil`** compartida por los tres caminos que
  aplican bloat de un perfil (`-Modo Instalar`, opción 2 y
  `-Modo Limpieza -Perfil`); antes cada uno repetía su propio bloque.
- **`.PARAMETER Ayuda`** en la ayuda del script.
- Los 83 IDs del catálogo se han comprobado con `-Modo Verificar`:
  **83 correctos, 0 rotos**.

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
