"""Ejecutar desde la carpeta principal: python -m servidor.app"""

from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
from io import BytesIO
from pathlib import Path
import sqlite3
import threading

from flask import Flask, jsonify, render_template, request, send_file, url_for
from matplotlib.backends.backend_agg import FigureCanvasAgg
from matplotlib.dates import AutoDateLocator, DateFormatter
from matplotlib.figure import Figure

from protocolo import CAMPOS, validar

BASE = Path(__file__).resolve().parent
GRAFICA_LOCK = threading.Lock()


def create_app(database_path=None):
    app = Flask(__name__)
    app.json.ensure_ascii = False
    app.json.sort_keys = False
    database = Path(database_path) if database_path else BASE / "datos" / "mediciones.sqlite3"
    database.parent.mkdir(parents=True, exist_ok=True)
    app.config["DATABASE"] = str(database)

    @contextmanager
    def conectar():
        conexion = sqlite3.connect(database, timeout=5)
        conexion.row_factory = sqlite3.Row
        try:
            with conexion:
                yield conexion
        finally:
            conexion.close()

    with conectar() as conexion:
        conexion.executescript((BASE / "esquema.sql").read_text(encoding="utf-8"))

    def opciones(default_uma=None, default_limite=100):
        try:
            raw = request.args.get("uma")
            uma = int(raw) if raw is not None else default_uma
            limite = int(request.args.get("limite", str(default_limite)))
        except ValueError:
            raise ValueError("uma y limite deben ser enteros.") from None
        if uma is not None and not 1 <= uma <= 5:
            raise ValueError("uma debe estar entre 1 y 5.")
        if not 1 <= limite <= 500:
            raise ValueError("limite debe estar entre 1 y 500.")
        return uma, limite

    def consultar(uma, limite):
        condicion = " WHERE id = ?" if uma is not None else ""
        parametros = (uma,) if uma is not None else ()
        with conectar() as conexion:
            total = conexion.execute(
                "SELECT COUNT(*) FROM mediciones" + condicion, parametros,
            ).fetchone()[0]
            filas = conexion.execute(
                "SELECT * FROM mediciones" + condicion + " ORDER BY registro_id DESC LIMIT ?",
                parametros + (limite,),
            ).fetchall()
        # Primero pedimos las últimas N y luego las mostramos de antigua a nueva.
        return total, [dict(fila) for fila in reversed(filas)]

    @app.errorhandler(ValueError)
    def dato_invalido(error):
        return jsonify(error=str(error)), 400

    @app.get("/api/estado")
    def estado():
        return jsonify(estado="ok", mensaje="Servidor listo para recibir datos.")

    @app.post("/data")
    @app.post("/api/registros")
    def guardar():
        if not request.is_json:
            return jsonify(error="Usa Content-Type: application/json."), 415
        datos = validar(request.get_json(silent=True))
        fecha = datetime.now(timezone.utc).isoformat(timespec="microseconds")
        columnas = ", ".join(CAMPOS) + ", fecha_hora"
        placeholders = ", ".join("?" for _ in range(len(CAMPOS) + 1))
        valores = tuple(datos[campo] for campo in CAMPOS) + (fecha,)
        with conectar() as conexion:
            cursor = conexion.execute(
                f"INSERT INTO mediciones ({columnas}) VALUES ({placeholders})", valores,
            )
            registro_id = cursor.lastrowid
        # id es la UMA; registro_id es la clave única de una medición guardada.
        resultado = {"registro_id": registro_id, **datos, "fecha_hora": fecha}
        return jsonify(resultado), 201, {"Location": url_for("obtener", registro_id=registro_id)}

    @app.get("/api/registros")
    @app.get("/data")
    def listar():
        uma, limite = opciones()
        total, filas = consultar(uma, limite)
        return jsonify(total=total, devueltos=len(filas), registros=filas)

    @app.get("/api/registros/<int:registro_id>")
    def obtener(registro_id):
        with conectar() as conexion:
            fila = conexion.execute(
                "SELECT * FROM mediciones WHERE registro_id = ?", (registro_id,),
            ).fetchone()
        if fila is None:
            return jsonify(error="No existe ese registro."), 404
        return jsonify(dict(fila))

    @app.get("/")
    def inicio():
        uma, limite = opciones(default_uma=1, default_limite=12)
        total, filas = consultar(uma, limite)
        return render_template(
            "index.html", uma=uma, limite=limite, total=total, filas=filas,
            ultima=filas[-1] if filas else None,
        )

    @app.get("/grafica.png")
    def grafica():
        uma, limite = opciones(default_uma=1, default_limite=12)
        _, filas = consultar(uma, limite)
        # Figure + Agg permite generar PNG sin abrir ventanas de escritorio.
        # Matplotlib no garantiza seguridad entre hilos: serializamos el dibujo.
        with GRAFICA_LOCK:
            figura = Figure(figsize=(10, 5.8), dpi=120, layout="constrained", facecolor="#f4f7fb")
            ax1, ax2 = figura.subplots(2, 1, gridspec_kw={"height_ratios": [2, 1]})
            if filas:
                tiempos = [datetime.fromisoformat(fila["fecha_hora"]) for fila in filas]
                for campo, nombre, color in (
                    ("mp01", "PM1.0", "#2563eb"),
                    ("mp02", "PM2.5", "#f59e0b"),
                    ("mp03", "PM10", "#e11d48"),
                ):
                    ax1.plot(tiempos, [fila[campo] for fila in filas], ".-", label=nombre, color=color)
                ax1.xaxis.set_major_locator(AutoDateLocator(minticks=3, maxticks=6))
                ax1.xaxis.set_major_formatter(DateFormatter("%H:%M:%S", tz=timezone.utc))
                # Una muestra aislada no debe producir un eje de varios días.
                if tiempos[0] == tiempos[-1]:
                    ax1.set_xlim(tiempos[0] - timedelta(seconds=1), tiempos[0] + timedelta(seconds=1))
                    ax1.set_xticks([tiempos[0]])
                ax1.legend(loc="upper left", ncol=3)
                ultima = filas[-1]
                barras = ax2.bar(
                    ["0.3", "0.5", "1.0", "2.5", "5.0", "10"],
                    [ultima[f"hi{i:02d}"] for i in range(1, 7)],
                    color=["#2563eb", "#0d9488", "#8b5cf6", "#f59e0b", "#e11d48", "#475569"],
                )
                ax2.bar_label(barras, padding=3, fontsize=8)
                ax2.margins(y=0.25)
                ax2.set_title(f"Última muestra · {ultima['te']} °C · HR {ultima['hr']} %", fontsize=10)
            else:
                ax1.text(0.5, 0.5, "Todavía no hay datos guardados para esta UMA.",
                         ha="center", va="center", transform=ax1.transAxes)
                ax1.set_xticks([])
                ax1.set_yticks([])
                ax2.set_xticks(range(6), ["0.3", "0.5", "1.0", "2.5", "5.0", "10"])
                ax2.set_yticks([])
                ax2.text(0.5, 0.5, "Sin conteos recibidos.", ha="center", va="center", transform=ax2.transAxes)
            ax1.set_title(f"UMA {uma} · Material particulado simulado", loc="left", fontweight="bold")
            ax1.set_ylabel("Concentración (µg/m³)")
            ax1.set_ylim(bottom=0)
            ax1.set_xlabel("Hora de recepción (UTC)")
            ax1.grid(alpha=0.2)
            ax2.set_xlabel("Umbral de diámetro de partícula (µm)")
            ax2.set_ylabel("Conteo simulado")
            ax2.set_ylim(bottom=0)
            imagen = BytesIO()
            FigureCanvasAgg(figura).print_png(imagen)
            imagen.seek(0)
        respuesta = send_file(imagen, mimetype="image/png", max_age=0)
        respuesta.headers["Cache-Control"] = "no-store"
        return respuesta

    return app


if __name__ == "__main__":
    app = create_app()
    print("API y gráfica: http://127.0.0.1:7070")
    print("Base de datos:", app.config["DATABASE"])
    app.run(host="127.0.0.1", port=7070, debug=False)
