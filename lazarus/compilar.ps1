param(
    [string]$LazarusDir = 'C:\lazarus',
    [switch]$Probar
)

$ErrorActionPreference = 'Stop'
$proyectoDir = $PSScriptRoot
$compilador = Get-ChildItem -LiteralPath (Join-Path $LazarusDir 'fpc') -Filter fpc.exe -Recurse |
    Where-Object { $_.Directory.Name -eq 'x86_64-win64' } |
    Sort-Object FullName -Descending | Select-Object -First 1 -ExpandProperty FullName
if (-not $compilador) { throw "No se encontro FPC de 64 bits dentro de $LazarusDir\fpc." }

# Compila directamente con FPC y las unidades que trae Lazarus. No instala
# paquetes, no recompila el IDE y no cambia su configuracion global.
$destino = 'x86_64-win64'
$salida = Join-Path $proyectoDir "lib\directo-$destino"
New-Item -ItemType Directory -Path $salida -Force | Out-Null
$rutas = @(
    $proyectoDir,
    (Join-Path $proyectoDir 'vendor\TLazSerial'),
    (Join-Path $LazarusDir "components\tachart\lib\$destino\win32"),
    (Join-Path $LazarusDir "components\ideintf\units\$destino\win32"),
    (Join-Path $LazarusDir "components\lazcontrols\lib\$destino\win32"),
    (Join-Path $LazarusDir "lcl\units\$destino\win32"),
    (Join-Path $LazarusDir "lcl\units\$destino"),
    (Join-Path $LazarusDir "components\freetype\lib\$destino"),
    (Join-Path $LazarusDir "components\debuggerintf\lib\$destino"),
    (Join-Path $LazarusDir "components\buildintf\units\$destino"),
    (Join-Path $LazarusDir "components\lazutils\lib\$destino"),
    (Join-Path $LazarusDir "components\lazdebuggers\lazdebuggerintf\lib\$destino"),
    (Join-Path $LazarusDir "packager\units\$destino")
)
foreach ($ruta in $rutas) {
    if (-not (Test-Path -LiteralPath $ruta -PathType Container)) {
        throw "Falta $ruta. Instala la distribucion completa de Lazarus para Windows x64."
    }
}
$opciones = @('-MObjFPC', '-Scghi', '-O1', '-gl', '-vewnhibq', '-dLCL', '-dLCLwin32')
$opciones += $rutas | ForEach-Object { "-Fu$_" }
$opciones += "-FU$salida"
$opciones += "-FE$proyectoDir"
$opciones += "-o$(Join-Path $proyectoDir 'datalogger.exe')"
$opciones += Join-Path $proyectoDir 'datalogger.lpr'
& $compilador @opciones
if ($LASTEXITCODE -ne 0) { throw 'Fallo la compilacion del DataLogger.' }
Write-Host "Cliente compilado: $(Join-Path $proyectoDir 'datalogger.exe')"

if ($Probar) {
    $salidaPruebas = Join-Path $proyectoDir "lib\pruebas-$destino"
    New-Item -ItemType Directory -Path $salidaPruebas -Force | Out-Null
    & $compilador '-B' '-MObjFPC' '-gl' '-Cr' '-Co' "-Fu$proyectoDir" "-FU$salidaPruebas" "-FE$salidaPruebas" (Join-Path $proyectoDir 'pruebas_cliente.lpr')
    if ($LASTEXITCODE -ne 0) { throw 'Fallo la compilacion de las pruebas del cliente.' }
    & (Join-Path $salidaPruebas 'pruebas_cliente.exe')
    if ($LASTEXITCODE -ne 0) { throw 'Fallaron las pruebas del cliente.' }
}
