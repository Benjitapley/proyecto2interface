# Proyecto 2 INFO1128: guía de instalación y desarrollo

Este proyecto implementa la pauta de Interfaces Gráficas. Está pensado para Windows
de 64 bits y Python 3.13. Usa los mismos 12 campos, las cinco UMA y la URL
`http://127.0.0.1:7070/data` del tutorial. Revisa cada etapa y entiende su
función antes de la defensa.

**Para abrir la ventana de escritorio, haz doble clic en
`ABRIR_ESCRITORIO.cmd`.** Se abrirá el DataLogger hecho en Lazarus, que muestra
las tres curvas PM, las seis barras, temperatura y humedad al recibir datos
por el COM. `http://127.0.0.1:7070/` es el panel web adicional. El IDE Lazarus
sirve para editar y compilar; el programa que ejecutas es `datalogger.exe`.

Lee [EXPLICACION_DEL_PROYECTO.md](EXPLICACION_DEL_PROYECTO.md) para entender el
código paso a paso y preparar la defensa. Las comprobaciones realizadas y la
prueba manual pendiente están en [VERIFICACION.md](VERIFICACION.md).

## 1. Qué tienes que entregar

La pauta pide un sistema funcionando con estas partes:

1. Un programa de escritorio en Lazarus Pascal que reciba datos seriales.
2. Selección de UMA1 a UMA5, temperatura y humedad.
3. Tres series de PM1.0, PM2.5 y PM10, con una ventana de 12 muestras.
4. Seis barras con los conteos de partículas de 0.3, 0.5, 1.0, 2.5, 5.0 y 10 µm.
5. Envío de las mediciones mediante HTTP POST y JSON a un servidor Flask.
6. Una base SQLite con los registros y su fecha y hora.
7. Una API REST para consultar registros desde el navegador en JSON.
8. Una gráfica creada con Matplotlib y visible en el navegador.

La pauta señala entrega y defensa el viernes 30 de octubre a las 09:00,
trabajo individual o en pareja, sin informe impreso. Confirma cualquier
cambio de fecha que haya comunicado tu profesor fuera del PDF.

El simulador reemplaza al sensor físico. No necesitas comprar un sensor para
seguir este tutorial: son mediciones aleatorias para demostrar el sistema.

## 2. Cómo se conectan las partes

**Python simulador → puerto serial virtual → Lazarus → HTTP/JSON → Flask → SQLite.**

El navegador consulta a Flask y recibe JSON o una imagen PNG generada por
Matplotlib. La gráfica del navegador y la de Lazarus se dibujan con herramientas
distintas: Matplotlib en Python y TAChart en Lazarus.

Ejemplo de una vuelta completa:

1. Python genera la trama de UMA4 y la escribe en COM2.
2. VSPE permite que Lazarus lea esa información desde el mismo COM2.
3. Lazarus separa los 12 números y verifica que la UMA elegida sea la 4.
4. Actualiza temperatura, humedad, líneas y barras.
5. Si está marcada la casilla de envío, construye JSON y hace POST a `/data`.
6. Flask valida el JSON, agrega `fecha_hora` e inserta una fila en SQLite.
7. Un GET desde el navegador recupera esa fila o una gráfica.

## 3. Qué instalar

| Elemento | Para qué se usa | Dónde obtenerlo |
|---|---|---|
| Lazarus, versión estable para Windows 64 bits, con Free Pascal | Compilar y ejecutar el DataLogger | https://www.lazarus-ide.org/index.php?page=download |
| Paquete TAChartLazarusPkg | `TChart`, `TLineSeries`, `TBarSeries` | Incluido en la distribución completa de Lazarus; activar si falta |
| Paquete LazSerialPort | Componente `TLazSerial` para leer el COM | Fuentes incluidas en `lazarus/vendor/TLazSerial` |
| Python 3.13 de 64 bits | Simulador y servidor | https://www.python.org/downloads/windows/ |
| VSPE para Windows x64 | Crear el puerto virtual | https://eterlogic.com/Products.VSPE_Download.html |
| Flask, pySerial y Matplotlib | API, serial y gráfica | Se instalan juntos con el archivo `requirements.txt` |

`sqlite3`, `json`, `datetime`, `random`, `time` y `venv` ya son parte de Python.
La base SQLite es un archivo que este servidor crea automáticamente. Un editor
visual de bases es opcional; puedes demostrar las consultas usando el navegador.

VSPE para Windows de 64 bits es comercial y ofrece una versión sin registrar
para evaluación. La documentación indica restricciones como no cargar archivos
de configuración y un máximo de cinco dispositivos. Esta práctica usa un solo
Connector que puedes crear manualmente. Las condiciones vigentes están en:
https://eterlogic.com/Products.VSPE_License.html

### 3.1. Compilar con Lazarus y sus componentes

Usa una instalación completa de Lazarus para Windows de 64 bits con Free Pascal.
En este computador ya está instalada en `C:\lazarus`. Desde la carpeta principal:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\lazarus\compilar.ps1
```

El script genera `lazarus\datalogger.exe` con FPC, las unidades de Lazarus y las
fuentes TLazSerial incluidas. No requiere descargar ese componente ni instalarlo
globalmente en el IDE. Si Lazarus está en otra carpeta, agrega
`-LazarusDir 'C:\ruta\de\lazarus'`. La opción de PowerShell se aplica sólo al
proceso de compilación; no cambia la política permanente del equipo.

Para trabajar desde el IDE, abre primero
`lazarus\vendor\TLazSerial\LazSerialPort.lpk` con **Paquete / Abrir archivo de
paquete**, compílalo y abre después `lazarus\datalogger.lpi`. El proyecto ya
declara `LCL`, `TAChartLazarusPkg` y `LazSerialPort` como dependencias. TAChart
viene con la distribución completa de Lazarus. Si quieres usar TLazSerial en
el diseñador de otros proyectos, puedes instalar su paquete en la paleta;
la ventana de este proyecto se construye por código y no necesita ese paso.

`TFPHTTPClient` y `TJSONObject` se usan desde código, mediante las unidades
`fphttpclient` y `fpjson` incluidas en Free Pascal. No tienes que arrastrarlos
desde una paleta.

### 3.2. Preparar Python

Primero extrae TODO el ZIP. El ejemplo supone que los archivos están en:

```text
C:\proyecto_info1128
```

Dentro de esa carpeta deben verse `requirements.txt`, `simulador.py` y la
carpeta `servidor`. Si quedaron dentro de otra carpeta con el mismo nombre,
entra a la que realmente contiene esos archivos.

Abre PowerShell en esa carpeta y ejecuta:

```powershell
py -3.13 --version
```

Si ya aparece Python 3.13, úsalo. Si `py` no está disponible y Python ya está
instalado, puedes crear el entorno con su ruta; por ejemplo, en este equipo:

```powershell
& 'C:\Users\benja\AppData\Local\Programs\Python\Python313\python.exe' -m venv .venv
```

Si todavía no tienes Python, instala una versión 3.13.x de
64 bits desde Python.org con el lanzador `py` y pip. Después vuelve a abrir
PowerShell.

Ejecuta lo siguiente UNA VEZ para preparar este proyecto:

```powershell
cd C:\proyecto_info1128
py -3.13 -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
```

El entorno `.venv` guarda las librerías de este proyecto. Usamos directamente
su `python.exe`, por lo que no necesitas ejecutar un script de activación ni
modificar la política de ejecución de PowerShell.

Comprueba los imports:

```powershell
.\.venv\Scripts\python.exe -c "import flask, serial, matplotlib, sqlite3; print('Todo OK')"
```

El nombre que se instala es **pyserial** y el módulo que se importa es
**serial**. Son nombres distintos.

## 4. Primero comprueba Flask, SQLite y Matplotlib

Esta etapa permite aislar la parte del servidor antes de conectar el COM.

En una primera terminal, desde la carpeta principal:

```powershell
.\.venv\Scripts\python.exe -m servidor.app
```

Deja esa terminal abierta. Deberías ver el puerto 7070 y la ruta del archivo
de base de datos. El servidor crea la carpeta `servidor\datos` y la tabla
`mediciones` si todavía no existen.

Abre en tu navegador:

```text
http://127.0.0.1:7070/api/estado
```

Debe responder un JSON con `estado: "ok"`.

En una SEGUNDA terminal, dentro de la misma carpeta principal:

```powershell
.\.venv\Scripts\python.exe prueba_api.py
```

Esta prueba inserta cinco mediciones de demostración, una por UMA. Las
respuestas deben indicar **HTTP 201** y un `registro_id`. Prueba estas URLs:

| URL | Resultado esperado |
|---|---|
| http://127.0.0.1:7070/ | Página con gráfica, selector de UMA y tabla |
| http://127.0.0.1:7070/api/registros | Registros en JSON |
| http://127.0.0.1:7070/api/registros?uma=1&limite=12 | Últimas 12 mediciones guardadas de UMA1 |
| http://127.0.0.1:7070/api/registros/1 | Medición cuyo registro_id sea 1, si existe |
| http://127.0.0.1:7070/grafica.png?uma=1 | PNG generado por Matplotlib para UMA1 |

La API devuelve como máximo 100 filas por defecto. `limite` permite pedir
entre 1 y 500; `total` informa cuántas mediciones coinciden con el filtro.
La lista contiene las últimas N filas, ordenadas de antigua a nueva.
El panel HTML y la gráfica muestran doce por defecto; la tabla incluye todos
los campos y se actualiza junto con los indicadores y la imagen.

La prueba manual sólo verifica servidor, base y navegador. La conexión serial
y Lazarus se comprueban en las etapas siguientes.

## 5. Crear el puerto virtual en VSPE

Para seguir la misma configuración del PDF:

1. Instala y abre VSPE para tu Windows x64.
2. Crea un dispositivo de tipo **Connector**.
3. Asígnale **COM2**, siempre que esté libre. Si COM2 ya existe, elige otro
   nombre disponible y cambia ese mismo nombre en Python y en Lazarus.
4. Finaliza la creación e inicia la emulación si está detenida.
5. Mantén el dispositivo disponible durante la prueba.

Un Connector crea UN puerto que dos aplicaciones pueden abrir para
intercambiar datos:

| Programa | Puerto con Connector |
|---|---|
| Simulador Python | COM2 |
| Lazarus TLazSerial | COM2 |

Si eliges **Pair**, la configuración cambia: crea, por ejemplo, COM2 y COM3,
usa COM2 en Python y COM3 en Lazarus. Una pareja conecta dos puertos distintos.
No mezcles ambas configuraciones. La documentación de VSPE recomienda probar
Pair si una aplicación tiene problemas con Connector.

Los dos extremos deben usar **9600 baudios, 8 bits de datos, sin paridad,
1 bit de parada y sin control de flujo**: abreviado `9600-8N1`.

## 6. Abrir y ejecutar el DataLogger en Lazarus

Si compilaste con `compilar.ps1`, abre `lazarus\datalogger.exe` y continúa desde
el paso 5. Para compilar desde el IDE:

1. Abre **Proyecto / Abrir proyecto**.
2. Selecciona `lazarus\datalogger.lpi` de este paquete.
3. Revisa en **Proyecto / Inspector del proyecto / Paquetes requeridos** que
   estén `LCL`, `TAChartLazarusPkg` y `LazSerialPort`. El `.lpi` ya los declara;
   si alguno falta, instala el paquete indicado en la etapa 3.
4. Compila con **Ejecutar / Compilar** y ejecuta el programa.
5. Se abrirá una ventana con el COM, un selector de UMA, casilla de envío,
   temperatura, humedad, dos gráficos y un registro de eventos.
6. Deja `COM2` si usaste Connector. Con Pair usa el otro extremo.
7. Selecciona `UMA 1`.
8. Comprueba que la URL sea `http://127.0.0.1:7070/data`.
9. Pulsa **Conectar**. Debe informar que espera tramas.
10. Activa **Enviar UMA seleccionada a Flask** cuando el servidor esté listo.

La interfaz está construida en código dentro de `principal.pas`; no usa
archivo `.lfm`. Por eso se puede abrir y compilar el proyecto directamente sin
dibujar antes la ventana. Si quieres personalizar tamaños, textos y colores,
empieza por el constructor `TPrincipal.Create`.

## 7. Ejecutar el simulador y cerrar el circuito

Con Flask funcionando, VSPE configurado y Lazarus conectado, abre otra
terminal en la carpeta principal:

```powershell
.\.venv\Scripts\python.exe simulador.py --puerto COM2
```

Empezarás a ver líneas de 12 números. El simulador rota por UMA1, UMA2, UMA3,
UMA4 y UMA5, enviando una trama cada 0.2 segundos. La UMA seleccionada recibe
aproximadamente una muestra por segundo.

En Lazarus deben cambiar temperatura, humedad, las tres líneas y las seis
barras. Una vez acumuladas 12 muestras, cada nueva muestra desplaza la más
antigua hacia la izquierda. Si la casilla de envío está activa, el estado
debe mencionar **HTTP 201** y los registros deben aumentar en la API.

Si cambias a UMA4, el historial local se limpia para no mezclar estaciones.
Los registros anteriores de SQLite se conservan. Tal como en el tutorial,
sólo se envía la UMA seleccionada cuando la casilla está marcada.

Si quieres mirar tramas sin abrir un COM:

```powershell
.\.venv\Scripts\python.exe simulador.py --ver --cantidad 5
```

Si quieres emitir únicamente UMA3:

```powershell
.\.venv\Scripts\python.exe simulador.py --puerto COM2 --uma 3 --intervalo 1
```

En ese último caso debes seleccionar UMA3 en Lazarus.

Detén el simulador con `Ctrl+C`. Para detener Flask, usa `Ctrl+C` en su propia
terminal. Cierra el puerto con **Desconectar** al terminar.

## 8. Entender los 12 campos

Ejemplo tomado de la trama que muestra el tutorial:

```text
4,97,20,52,5593,1398,9349,1868,5142,6684,13,37
```

| Índice Pascal | Clave JSON | Significado | Ejemplo |
|---|---|---|---|
| 0 | id | Identificador de UMA, del 1 al 5 | 4 |
| 1 | mp01 | Concentración PM1.0 en µg/m³ | 97 |
| 2 | mp02 | Concentración PM2.5 en µg/m³ | 20 |
| 3 | mp03 | Concentración PM10 en µg/m³ | 52 |
| 4 | hi01 | Conteo para el umbral 0.3 µm | 5593 |
| 5 | hi02 | Conteo para el umbral 0.5 µm | 1398 |
| 6 | hi03 | Conteo para el umbral 1.0 µm | 9349 |
| 7 | hi04 | Conteo para el umbral 2.5 µm | 1868 |
| 8 | hi05 | Conteo para el umbral 5.0 µm | 5142 |
| 9 | hi06 | Conteo para el umbral 10 µm | 6684 |
| 10 | te | Temperatura en °C | 13 |
| 11 | hr | Humedad relativa en % | 37 |

**Una trama tiene 12 campos; la ventana del gráfico tiene hasta 12 muestras.**
Son dos cantidades distintas. Cada trama agrega un punto a cada una de las
tres series. Una ventana llena necesita 12 tramas de la UMA seleccionada.

Las claves `mp02` y `mp03` mantienen los nombres del PDF: representan PM2.5 y
PM10 respectivamente. Los conteos se generan al azar siguiendo el ejercicio;
no deben interpretarse como mediciones físicas reales ni límites sanitarios.

En el envío HTTP, esa misma trama se transforma en este objeto:

```json
{
  "id": 4,
  "mp01": 97,
  "mp02": 20,
  "mp03": 52,
  "hi01": 5593,
  "hi02": 1398,
  "hi03": 9349,
  "hi04": 1868,
  "hi05": 5142,
  "hi06": 6684,
  "te": 13,
  "hr": 37
}
```

Los números son enteros, no cadenas entre comillas. Lazarus usa
`Content-Type: application/json` para que Flask interprete el cuerpo.

## 9. Qué hace cada archivo y en qué orden estudiarlo

| Archivo | Responsabilidad |
|---|---|
| `protocolo.py` | Define el orden de campos, valida y convierte CSV a bytes |
| `simulador.py` | Genera valores aleatorios, rota las UMA y escribe en el COM |
| `lazarus/datalogger.lpr` | Inicia la aplicación de escritorio |
| `lazarus/datalogger.lpi` | Declara el proyecto y los paquetes de Lazarus |
| `lazarus/principal.pas` | Construye la ventana, recibe, grafica y envía JSON |
| `lazarus/protocolo_uma.pas` | Valida las tramas, extrae líneas y mantiene las doce muestras |
| `lazarus/compilar.ps1` | Compila para Windows x64 sin cambiar la configuración del IDE |
| `lazarus/pruebas_cliente.lpr` | Comprueba buffer, validación y desplazamiento del historial |
| `servidor/esquema.sql` | Define la tabla SQLite y el índice por UMA |
| `servidor/app.py` | Implementa POST, consultas GET y la gráfica PNG |
| `servidor/templates/index.html` | Panel con filtros, indicadores, gráfica y todos los campos |
| `servidor/static/dashboard.js` | Actualiza los datos cada cinco segundos y comunica errores |
| `servidor/static/dashboard.css` | Estilos del panel y adaptación a pantallas pequeñas |
| `prueba_api.py` | Inserta cinco registros para probar el servidor antes del COM |
| `tests/test_proyecto.py` | Pruebas automáticas con una base temporal |

### 9.1. El simulador, paso a paso

1. `generar_datos()` construye un diccionario con los 12 valores.
2. `numero % 5 + 1` produce 1, 2, 3, 4, 5 y vuelve a empezar.
3. `codificar()` recorre `CAMPOS` para respetar siempre el mismo orden.
4. `join()` une los números separados por comas.
5. Se agrega `\n` como fin de trama y se convierte a bytes ASCII.
6. `puerto.write(trama)` transmite esos bytes y `time.sleep()` controla la
   frecuencia de envío.

### 9.2. Lazarus, paso a paso

- `Create`: construye los controles y configura `TLazSerial` con 9600-8N1.
- `Conectar`: abre o cierra el dispositivo indicado por el usuario.
- `Recibir`: agrega el fragmento recibido a `FBuffer`. Busca el salto de
  línea `#10`, extrae una trama completa y conserva el fragmento pendiente.
- `ProcesarTrama`: usa `DecodificarTrama` para exigir doce enteros decimales
  válidos y comprueba el identificador de la UMA.
- `Graficar`: usa `AgregarMuestra` para mantener doce muestras por serie y
  actualiza las seis barras. El estado se guarda en `THistorialPM`.
- `EnviarAFlask`: crea `TJSONObject`, configura el encabezado HTTP y hace POST.
- Los bloques `try/finally` liberan listas, streams, JSON y cliente HTTP.

La comunicación serial es un flujo de bytes. Un evento de recepción puede
traer media trama o varias juntas; no significa necesariamente una medición.
El buffer y el salto de línea permiten reconstruirlas correctamente.

Cuando la ventana ya tiene 12 muestras, el bucle mueve la posición 1 a la 0,
la 2 a la 1 y así sucesivamente. Luego pone la nueva muestra en la posición 11.
Esto mantiene el historial local de tamaño fijo y evita accesos fuera del arreglo.

### 9.3. Flask y SQLite, paso a paso

1. `create_app()` prepara Flask y ejecuta `esquema.sql` si la tabla no existe.
2. `guardar()` acepta `POST /data` o `POST /api/registros`.
3. `validar()` revisa campos, enteros, UMA, temperatura y humedad.
4. `datetime.now(timezone.utc)` asigna la fecha y hora de recepción.
5. `INSERT ... VALUES (?, ...)` inserta valores usando parámetros SQL.
6. La transacción se confirma y la conexión se cierra.
7. El servidor responde `201 Created`, la fila y un enlace `Location`.
8. `listar()` permite consultar con `GET /api/registros` y filtro por UMA.
9. `obtener()` devuelve una medición por su `registro_id` o un error 404.

`id` es el número de la estación. Puede repetirse miles de veces porque una
misma UMA envía muchas mediciones. `registro_id` es la clave primaria única de
cada fila; SQLite la asigna automáticamente.

La columna `fecha_hora` se declara `DATETIME`. SQLite guarda aquí una cadena
ISO 8601 con zona horaria, porque no tiene un tipo nativo de fecha y hora como
otros motores. La API y el gráfico la presentan en UTC y la conservan al
reiniciar. Puedes ver, por ejemplo, el sufijo `+00:00`.

### 9.4. Matplotlib y el navegador, paso a paso

1. `GET /grafica.png?uma=1` consulta las últimas mediciones de UMA1.
2. `Figure` crea una figura sin abrir una ventana gráfica de escritorio.
3. Se dibujan tres líneas de concentración y seis barras de la última trama.
4. `FigureCanvasAgg` convierte la figura a PNG dentro de `BytesIO`.
5. Flask responde con tipo `image/png`.
6. El HTML muestra esa URL mediante `<img>`. JavaScript vuelve a consultar la
   API y el PNG cada cinco segundos, actualiza tabla e indicadores y conserva
   la última consulta si hay un fallo de conexión.

Los datos de esa gráfica provienen de SQLite. Esto demuestra que el sistema
puede consultar mediciones almacenadas y no sólo mostrar lo que llega al COM.

## 10. Cambios necesarios frente a las capturas del PDF

- En Python 3, escribe `5`, no `05`: los enteros decimales con cero inicial
  de ese modo producen un error de sintaxis.
- `serial.write()` requiere bytes. Por eso convertimos la línea con
  `.encode('ascii')`.
- Se agrega `\n` al final de cada trama para marcar su límite.
- Se acumulan fragmentos seriales antes de convertirlos a números.
- Se comprueba la cantidad de campos y se descartan tramas inválidas.
- La ventana guarda 12 muestras reales, sin inicializar el gráfico con
  mediciones ficticias ni desplazar una posición fuera del arreglo.
- Se liberan los objetos temporales de Lazarus.
- Flask almacena los datos y la fecha en SQLite, además de permitir consultas
  y producir la gráfica pedidas en el apartado final de la pauta.

La petición HTTP de Lazarus es síncrona con esperas de hasta 2 segundos por
conexión/lectura. Si falla, se desmarca el envío y se informa en el registro.
Inicia Flask y vuelve a marcar la casilla. No hay reenvío automático de la
medición que falló ni una cola persistente de pendientes. Para esta práctica
local, la configuración normal manda aproximadamente una medición por segundo
de la UMA elegida.

## 11. Comprobación antes de entregar

Haz esta demostración completa en tu computador:

1. Abre VSPE con el Connector configurado y arranca Flask.
2. Ejecuta Lazarus, elige UMA1 y conecta el COM.
3. Inicia el simulador y observa temperatura, humedad, tres series y seis barras.
4. Espera al menos 13 mediciones de UMA1 para mostrar el desplazamiento.
5. Activa el envío y verifica el mensaje HTTP 201.
6. Abre `/api/registros?uma=1` y muestra los campos y `fecha_hora`.
7. Muestra `/` y `/grafica.png?uma=1` en el navegador.
8. Cambia a UMA4 en Lazarus, espera datos y activa/continúa el envío.
9. Consulta `/api/registros?uma=4` y muestra que contiene la UMA correcta.
10. Apaga y enciende Flask; consulta de nuevo para demostrar persistencia.
11. Desmarca el envío: el gráfico local continúa y no se agregan nuevas filas
    por Lazarus hasta que vuelvas a marcarlo.

Puedes ejecutar las pruebas automáticas desde la carpeta principal:

```powershell
.\.venv\Scripts\python.exe -m unittest discover -s tests -v
```

Las pruebas usan una base temporal; no borran ni modifican tus mediciones.
El archivo `VERIFICACION.md` detalla lo que se comprobó al preparar esta base
y lo que aún debe comprobarse en Windows.

## 12. Problemas frecuentes

| Problema | Qué revisar |
|---|---|
| `py` no se reconoce o no encuentra 3.13 | Instala Python con su lanzador o usa la ruta real de tu Python 3.13 para crear `.venv` |
| `No module named flask/serial/matplotlib` | Ejecuta pip y el programa con el mismo `.venv\Scripts\python.exe` |
| `No module named servidor` | Ejecuta desde la carpeta que contiene `servidor`, usando `-m servidor.app` |
| No encuentra `requirements.txt` | La terminal debe estar en la carpeta extraída del proyecto, no en el ZIP |
| No encuentra `LazSerial` | Instala `LazSerialPort.lpk` y revisa el paquete requerido en el inspector del proyecto |
| No encuentra `TAGraph` o `TASeries` | Instala/activa `TAChartLazarusPkg` y comprueba su dependencia en el proyecto |
| No encuentra `fphttpclient` o `fpjson` | Revisa que tu instalación completa de Free Pascal incluya sus unidades FCL |
| Error al abrir COM o acceso denegado | Comprueba VSPE activo, nombre de puerto y que sólo los dos programas previstos lo estén usando |
| Python y Lazarus usan el mismo COM y falla | Verifica que creaste Connector. Con Pair hay que usar los dos extremos distintos |
| Lazarus no cambia de valores | Comprueba trama con `\n`, 9600-8N1 y que la UMA seleccionada se esté enviando |
| Error HTTP o conexión rechazada | Arranca Flask; comprueba URL, puerto 7070 y vuelve a marcar el envío |
| Datos locales pero API vacía | Marca la casilla de envío y consulta la misma UMA que está elegida en Lazarus |
| La casilla se desmarcó sola | Hubo un fallo HTTP. Revisa el registro inferior y restablece Flask antes de marcarla |
| La tabla del navegador parece detenida | Revisa el mensaje de actualización, que Flask siga abierto y que JavaScript esté habilitado |
| El puerto 7070 está ocupado | Cierra el servidor duplicado o cambia el puerto en Python y en la URL de Lazarus |
| El gráfico de otra UMA está vacío | Selecciona esa UMA en Lazarus y guarda algunas tramas de ella |

## 13. Preguntas que conviene poder responder en la defensa

**¿Para qué sirve VSPE?** Para comunicar dos programas mediante un puerto
serial virtual, sin cable ni sensor físico.

**¿Qué diferencia hay entre serial y HTTP?** Serial transporta la trama de
Python a Lazarus. HTTP transporta el JSON de Lazarus a Flask.

**¿Por qué usar JSON?** Porque permite asociar nombres de campos con valores y
es fácil de interpretar desde lenguajes distintos.

**¿Por qué el header `Content-Type`?** Indica al servidor el formato del cuerpo:
en este caso `application/json`.

**¿Qué hacen POST y GET?** POST incorpora una medición. GET consulta una o varias
mediciones o solicita la imagen del gráfico.

**¿Dónde quedan los datos al cerrar?** En `servidor/datos/mediciones.sqlite3`.
Los arreglos de Lazarus son un historial corto en memoria; SQLite conserva
los registros entre ejecuciones.

**¿Cómo saben a qué UMA pertenecen?** El primer campo, `id`, identifica la UMA.
Lazarus compara ese identificador con la estación elegida.

**¿Dónde se genera la gráfica del navegador?** En el servidor Python con
Matplotlib. El navegador recibe una imagen PNG.

**¿Qué pasa si se corta una trama?** Lazarus espera el resto dentro del buffer
hasta recibir `\n`. Luego valida que haya 12 números.

## Fuentes para las instalaciones y APIs

- Pauta adjunta: Proyecto #2 (Unidad II), INFO1128, páginas 1 a 6.
- Lazarus: https://www.lazarus-ide.org/index.php?page=download
- LazSerial, código y paquete: https://github.com/JurassicPork/TLazSerial
- Componentes TAChart: https://gitlab.com/freepascal.org/lazarus/lazarus/-/tree/main/components/tachart
- TFPHTTPClient: https://www.freepascal.org/daily/doc/fcl/fphttpclient/index.html
- VSPE Connector: https://eterlogic.com/help/vspe/DeviceConnectorPage.html
- VSPE licencias: https://eterlogic.com/Products.VSPE_License.html
- Entornos Python: https://docs.python.org/3.13/library/venv.html
- SQLite en Python: https://docs.python.org/3.13/library/sqlite3.html
- Fechas SQLite: https://www.sqlite.org/lang_datefunc.html
- Flask: https://flask.palletsprojects.com/en/stable/installation/
- pySerial: https://pyserial.readthedocs.io/en/latest/shortintro.html
- Matplotlib con Flask: https://matplotlib.org/stable/gallery/user_interfaces/web_application_server_sgskip.html
