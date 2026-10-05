@echo off
chcp 65001 >nul
title Instalador de software con winget

rem ---------------------------------------------------------------
rem  El .ps1 tiene que estar en la misma carpeta que este .bat
rem ---------------------------------------------------------------
if not exist "%~dp0Instalar-Software.ps1" (
    echo.
    echo  No se encuentra "Instalar-Software.ps1" en la misma carpeta que este .bat.
    echo  Los dos archivos tienen que estar juntos.
    echo.
    pause
    exit /b 2
)

rem ---------------------------------------------------------------
rem  Eleva a administrador si hace falta (una sola ventana).
rem  S-1-16-12288 = nivel de integridad Alto (ya eres admin)
rem ---------------------------------------------------------------
whoami /groups 2>nul | findstr /c:"S-1-16-12288" >nul
if errorlevel 1 (
    echo.
    echo  Se necesitan permisos de administrador: acepta la ventana UAC.
    echo.
    if "%~1"=="" (
        powershell.exe -NoProfile -Command "try { Start-Process -FilePath '%~f0' -Verb RunAs -ErrorAction Stop } catch { exit 1 }"
    ) else (
        powershell.exe -NoProfile -Command "try { Start-Process -FilePath '%~f0' -ArgumentList '%*' -Verb RunAs -ErrorAction Stop } catch { exit 1 }"
    )
    if errorlevel 1 (
        echo  No se pudo abrir la ventana elevada: comprueba que aceptaste el UAC.
        echo.
        pause
    )
    exit /b
)

pushd "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Instalar-Software.ps1" %*
set "RC=%ERRORLEVEL%"
popd

echo.
if not "%RC%"=="0" echo  El script termino con el codigo %RC% (revisa la carpeta log\).
pause
exit /b %RC%
