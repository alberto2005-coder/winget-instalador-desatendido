# Solución de problemas

Lo más frecuente, con el síntoma delante. Casi todo deja rastro en
`log\instalacion-AAAAmmdd-HHmmss.log` (la última ejecución): **míralo antes de
nada**, es un texto plano y se puede pegar en un issue.

---

## 1. Un programa no se instala: `0x8A150014` / `No package found`

**Causa**: winget ha renombrado o retirado ese paquete (le pasa a cualquiera:
antes era `NodeJS.NodeJS` y ahora es `OpenJS.NodeJS`).

**Solución**:

1. Menú principal → **5) Comprobar que los IDs del catálogo sigan valiendo**
   (o `.\Instalar-Software.ps1 -Modo Verificar`).
2. Te lista los IDs rotos y el comando exacto para buscar el sustituto:
   `winget search <nombre>`.
3. Cambia el ID en `Instalar-Software.ps1` (y en `perfiles\*.json` si aparece).

---

## 2. La ventana no responde o se queda en blanco

**Causa típica**: has hecho **clic dentro de la ventana**. Windows entra en
modo "Seleccionar" y **congela** todo hasta que pulsas `Esc` o `Enter`.

**Solución**: pulsa `Esc`. El script ya desactiva ese modo mientras corre
(eso era lo que ponía "Seleccionar" en el título), así que si vuelve a pasar:

- comprueba que estás ejecutando la versión actual del repo, y
- cierra las **ventanas viejas** del instalador: varias a la vez compiten por
  winget y una puede quedarse esperando.

---

## 3. Sale `[1/1] <ID>` y no pasa nada

**Causa**: estaba capturándose toda la salida de winget y solo se mostraba al
terminar (ahora sale línea a línea, en gris, bajo `winget trabajando...`).

Si con la versión actual sigue sin salir nada:

- mira si hay **otro `winget.exe`** abierto (el anterior puede estar colgado);
- revisa el `log\` de esa ejecución: si no aparece la línea
  `Instalado:` ni `FALLO`, el proceso no ha terminado.

---

## 4. `Otra instancia de winget está en ejecución`

**Causa**: dos ventanas del instalador a la vez, o un `winget` anterior sin
cerrar.

**Solución**: cierra las demás ventanas y reintenta. Solo debe haber un
`winget.exe` en cada momento.

---

## 5. `Acceso denegado` / `0x80070005` / no aparece UAC

**Causa**: el paquete pide instalación para **todos los usuarios** y no hay
administrador.

**Solución**:

- Lanza `INICIAR.bat` y acepta la ventana de control de cuentas de usuario, o
- instala solo para tu cuenta: `.\Instalar-Software.ps1 -NoAdmin -Alcance User`.

---

## 6. `No se puede cargar el archivo ... porque está restringido por la ejecución de scripts`

**Causa**: la política de ejecución de PowerShell bloquea los `.ps1`.

**Solución**: usa **`INICIAR.bat`** (ya lo evita con `-ExecutionPolicy Bypass`).
Si lanzas el script a mano:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Instalar-Software.ps1
```

---

## 7. Falta winget / `App Installer`

**Causa**: PC recién instalado o actualizado sin *App Installer*.

**Solución**: el propio script lo detecta, lo descarga desde la **release
oficial de GitHub** con sus dependencias (VCLibs + Windows App Runtime), reintenta
y verifica el tamaño antes de usarlo. Solo hace falta conexión.

---

## 8. Apps de la Microsoft Store (IDs `9...`)

Netflix, Prime Video, Disney+, Crunchyroll, Apple TV, WhatsApp y Revo Uninstaller
solo se distribuyen en la tienda, por eso llevan ID de tienda (`9NKSQGP7F2NH`…)
y usan la fuente `msstore`, que Windows ya trae activada.

- Si fallan: comprueba la conexión y que no haya una actualización de tienda
  pendiente; prueba a mano: `winget install --id 9NKSQGP7F2NH -e`.

---

## 9. El instalador se abre igualmente (no hace nada en silencio)

Algunos instaladores ignoran `--silent` (Steam, por ejemplo) y muestran su
asistente. Es comportamiento **del instalador**, no del script: sigue adelante
y termina.

---

## 10. Código de salida del script

| Código | Significado |
|--:|:---|
| `0` | todo bien |
| `1` | hubo fallos (mira el resumen final y el `log\`) |
| `2` | error de configuración (falta `-Perfil`, winget no disponible…) |

---

## Reportar un fallo

Abre un issue y adjunta:

1. el **`log\instalacion-*.log`** de la ejecución fallida,
2. la salida de `.\Instalar-Software.ps1 -Modo Verificar`,
3. qué esperabas y qué viste (código de error concreto, si aparece).

Con eso suele bastar: el log ya trae el comando exacto de winget que se lanzó.
