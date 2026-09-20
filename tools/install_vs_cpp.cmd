@echo off
rem ---------------------------------------------------------------------------
rem Instala la carga de trabajo "Desktop development with C++" en la
rem instalacion existente de Visual Studio. Flutter la necesita para compilar
rem la app de escritorio de OrionGo Platform.
rem
rem Notas de sintaxis (documentacion oficial de Microsoft):
rem  * --channelId es obligatorio cuando se usa el verbo "modify".
rem  * --wait NO lo soporta setup.exe (solo el bootstrapper vs_*.exe); usarlo
rem    provoca el error 87 "The parameter is incorrect".
rem  * Se usa --passive para ver el progreso sin pedir interaccion.
rem ---------------------------------------------------------------------------

set "LOGFILE=%~dp0vs_cpp_install.log"
set "SETUP=C:\Program Files (x86)\Microsoft Visual Studio\Installer\setup.exe"

echo ==== Inicio %DATE% %TIME% ==== > "%LOGFILE%"

if not exist "%SETUP%" (
  echo No se encontro el instalador de Visual Studio en "%SETUP%" >> "%LOGFILE%"
  goto :fin
)

"%SETUP%" modify ^
  --installPath "C:\Program Files\Microsoft Visual Studio\18\Community" ^
  --channelId VisualStudio.18.Release ^
  --productId Microsoft.VisualStudio.Product.Community ^
  --add Microsoft.VisualStudio.Workload.NativeDesktop ^
  --includeRecommended ^
  --passive --norestart >> "%LOGFILE%" 2>&1

echo ==== Fin %DATE% %TIME% (exit=%ERRORLEVEL%) ==== >> "%LOGFILE%"

:fin
type "%LOGFILE%"
