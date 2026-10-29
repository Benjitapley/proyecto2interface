# Verificación del proyecto

Comprobaciones realizadas el 29 de octubre de 2026 en Windows x64, con
Python 3.13.15 y Free Pascal 3.2.2 de la instalación local de Lazarus.
El código y las dependencias necesarias para compilar están preparados.
La demostración completa con el puerto virtual requiere la comprobación
manual descrita al final.

## Requisitos de la pauta y su implementación

| Requisito | Implementación | Verificación |
|---|---|---|
| DataLogger Lazarus Pascal | `lazarus/datalogger.lpi`, `principal.pas` | Compilación Windows x64 y arranque del ejecutable |
| Selector UMA1 a UMA5, temperatura y humedad | Controles y filtro de `ProcesarTrama` | Revisión del código; observación visual pendiente |
| Tres series PM y ventana de doce muestras | `protocolo_uma.pas`, `AgregarMuestra`, TAChart | Compilación y pruebas Pascal preparadas; ejecución de esas pruebas bloqueada |
| Seis barras de conteos de partículas | `Graficar` con `TBarSeries` | Revisión del código; observación visual pendiente |
| Serial Python y puerto virtual 9600-8N1 | `simulador.py`, `TLazSerial`, VSPE Connector | Simulador probado; circuito VSPE pendiente |
| POST de los doce campos como JSON | `EnviarAFlask`, `/data` | Contratos revisados; servidor probado con HTTP real |
| SQLite con fecha y hora DateTime | `esquema.sql`, `guardar` | Guardado, recuperación y persistencia comprobados |
| Consultas REST en JSON | `/api/registros`, filtros y detalle | Pruebas automáticas y HTTP real |
| Matplotlib visible desde navegador | `/grafica.png`, panel `/` | PNG generado e inspeccionado; HTML y recursos responden correctamente |
| Componentes y librerías | `requirements.txt`, TLazSerial incluido, script de compilación | Imports y ambas formas de compilación comprobados |

## Pruebas Python y HTTP

Pasaron **13 pruebas automáticas**, usando bases temporales. Cubren el orden
y conservación de los doce campos, datos inválidos, POST 201, fecha con zona
horaria, recuperación individual, persistencia, filtros, límites y orden.
También comprueban el panel vacío, sus catorce columnas (doce campos más
registro y fecha), las últimas doce filas y la entrega de CSS, JavaScript y PNG.

```powershell
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
```

Se corrigió una conexión de la prueba de persistencia que permanecía abierta:
el contexto de `sqlite3.connect()` confirma la transacción, pero no cierra la
conexión. Ahora se usa `closing()`, lo que permite limpiar la base en Windows.
La ejecución final terminó sin advertencias de recursos abiertos.

Además se levantó un servidor HTTP real en un puerto local temporal y se
enviaron **65 mediciones**, trece por cada UMA. Se verificaron los doce campos,
fecha UTC, respuesta 201, enlaces de detalle, filtros y límite doce, cinco PNG,
HTML y recursos estáticos. Una petición incompleta recibió 400 sin agregar
filas. Otra instancia del servidor recuperó las 65 filas del mismo archivo.
La base temporal se cerró y eliminó; estas comprobaciones no modificaron
`servidor/datos/mediciones.sqlite3`.

También se ejecutó el simulador con `--ver --cantidad 5 --intervalo 0.1`:
produjo una trama válida para cada UMA sin abrir un COM.

## Cliente Lazarus

Se comprobó la compilación con el script incluido:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\lazarus\compilar.ps1
```

También se compiló el `.lpi` con `lazbuild`, usando una configuración limpia
aislada. La dependencia se resuelve desde `vendor/TLazSerial`; no se alteró
la configuración global del IDE. El ejecutable `lazarus/datalogger.exe`
arrancó y quedó desconectado.

`pruebas_cliente.lpr` comparte las funciones reales de `protocolo_uma.pas`.
Comprueba la trama del PDF, fragmentos, CRLF, varias líneas juntas, resto
pendiente, once casos inválidos, veinticinco entradas de tres series,
desplazamiento y reinicio. Compiló con comprobaciones de rangos y
desbordamientos. **Su ejecución fue bloqueada por Control de aplicaciones de
Windows**; no se afirma que estos casos hayan pasado en este entorno.
Para ejecutarlos en un equipo que permita el binario:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\lazarus\compilar.ps1 -Probar
```

## Panel y gráficas

Se inspeccionaron visualmente los PNG de doce muestras, una muestra y una UMA
sin datos. Los ejes, leyendas, unidades, tres series y seis barras son legibles.
Se mejoró el eje temporal cuando sólo existe una muestra.

Se ejecutó el JavaScript con un DOM simulado para verificar catorce columnas,
enlaces individuales, indicadores, actualización PNG, estado vacío,
conservación de datos ante un fallo y recuperación posterior. Esta comprobación
no sustituye una prueba de diseño en un navegador real.

El control visual de aplicaciones y navegadores no estuvo disponible: el
servicio de automatización no pudo conectarse a su canal nativo. Por tanto no
se afirma haber inspeccionado la ventana Lazarus ni el diseño web renderizado.

## Comprobación manual antes de la defensa

VSPE está instalado, pero al consultar los puertos disponibles no había un
Connector del proyecto activo. Sigue los pasos completos de
[LEEME_PRIMERO.md](LEEME_PRIMERO.md), apartado 11:

1. Crea e inicia un Connector COM2 en VSPE; usa otro nombre si está ocupado.
2. Inicia Flask, abre el DataLogger y conecta el COM con el mismo nombre.
3. Ejecuta el simulador y espera al menos trece muestras de la UMA elegida.
4. Comprueba temperatura, humedad, tres líneas, desplazamiento y seis barras.
5. Activa el envío y verifica HTTP 201, JSON y gráfica en el navegador.
6. Cambia de UMA y comprueba que el historial local se reinicia y el filtro
   del navegador muestra las mediciones de esa estación.
7. Reinicia Flask para demostrar persistencia y desmarca el envío para
   demostrar que la recepción local continúa sin guardar nuevas filas.

El envío HTTP de Lazarus es síncrono, con tiempos de conexión y lectura
configurados en dos segundos cada uno. Ante un fallo se desactiva el envío
y se informa en pantalla; no hay cola ni reenvío automático de esa medición.

Los ejecutables, el entorno virtual, las mediciones locales y los archivos
temporales están excluidos de Git. El ejecutable puede generarse con el script;
la base y la tabla se crean automáticamente al iniciar Flask.
