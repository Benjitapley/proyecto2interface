"""Pruebas de contrato, persistencia y gráfica sin necesidad de un COM virtual."""

from datetime import datetime
from io import BytesIO
from pathlib import Path
import random
import sqlite3
import tempfile
import unittest

from PIL import Image

from protocolo import CAMPOS, codificar, decodificar
from servidor.app import create_app
from simulador import generar_datos


class ProyectoTests(unittest.TestCase):
    def setUp(self):
        self.temporal = tempfile.TemporaryDirectory()
        self.database = Path(self.temporal.name) / "mediciones.sqlite3"
        self.app = create_app(self.database)
        self.app.config["TESTING"] = True
        self.client = self.app.test_client()
        self.muestra = generar_datos(1, random.Random(42))

    def tearDown(self):
        self.temporal.cleanup()

    def test_csv_del_pdf_conserva_orden_y_valores(self):
        trama = b"4,97,20,52,5593,1398,9349,1868,5142,6684,13,37\n"
        datos = decodificar(trama)
        self.assertEqual(datos["id"], 4)
        self.assertEqual(datos["mp02"], 20)
        self.assertEqual(datos["hi06"], 6684)
        self.assertEqual(datos["te"], 13)
        self.assertEqual(codificar(datos), trama)

    def test_tramas_simuladas_de_las_cinco_uma(self):
        rng = random.Random(72)
        for uma in range(1, 6):
            datos = generar_datos(uma, rng)
            self.assertEqual(tuple(datos), CAMPOS)
            trama = codificar(datos)
            self.assertEqual(trama.count(b"\n"), 1)
            self.assertEqual(decodificar(trama), datos)

    def test_csv_incompleto_se_rechaza(self):
        with self.assertRaises(ValueError):
            decodificar(b"1,2,3\n")

    def test_recibir_y_recuperar_con_datetime(self):
        respuesta = self.client.post("/data", json=self.muestra)
        self.assertEqual(respuesta.status_code, 201)
        fila = respuesta.get_json()
        self.assertEqual(fila["id"], 1)
        self.assertEqual(fila["registro_id"], 1)
        self.assertIsNotNone(datetime.fromisoformat(fila["fecha_hora"]).tzinfo)
        recuperada = self.client.get(respuesta.headers["Location"])
        self.assertEqual(recuperada.get_json(), fila)

    def test_persistencia_al_recrear_servidor(self):
        self.client.post("/data", json=self.muestra)
        otro_cliente = create_app(self.database).test_client()
        self.assertEqual(otro_cliente.get("/api/registros").get_json()["total"], 1)
        with sqlite3.connect(self.database) as conexion:
            fila = conexion.execute("SELECT id, mp01, fecha_hora FROM mediciones").fetchone()
        self.assertEqual(fila[:2], (1, self.muestra["mp01"]))
        self.assertIsInstance(fila[2], str)

    def test_filtrado_limite_y_orden_cronologico(self):
        for uma in (1, 2, 1, 3, 1):
            datos = {**self.muestra, "id": uma}
            self.client.post("/data", json=datos)
        respuesta = self.client.get("/api/registros?uma=1&limite=2").get_json()
        self.assertEqual(respuesta["total"], 3)
        self.assertEqual(respuesta["devueltos"], 2)
        self.assertEqual([r["registro_id"] for r in respuesta["registros"]], [3, 5])
        self.assertTrue(all(r["id"] == 1 for r in respuesta["registros"]))

    def test_datos_invalidos_no_se_insertan(self):
        faltante = self.muestra.copy()
        del faltante["hr"]
        casos = (
            [], None, faltante, {**self.muestra, "id": 6},
            {**self.muestra, "hr": 101}, {**self.muestra, "mp02": -1},
            {**self.muestra, "te": 100}, {**self.muestra, "mp01": "30"},
            {**self.muestra, "id": True},
        )
        for datos in casos:
            with self.subTest(datos=datos):
                # json=None no garantiza cuerpo JSON; usamos data explícitamente.
                import json
                respuesta = self.client.post("/data", data=json.dumps(datos), content_type="application/json")
                self.assertEqual(respuesta.status_code, 400)
                self.assertIn("error", respuesta.get_json())
        self.assertEqual(self.client.get("/api/registros").get_json()["total"], 0)

    def test_json_malformado_y_content_type(self):
        respuesta = self.client.post("/data", data="{", content_type="application/json")
        self.assertEqual(respuesta.status_code, 400)
        respuesta = self.client.post("/data", data="texto", content_type="text/plain")
        self.assertEqual(respuesta.status_code, 415)

    def test_consultas_invalidas(self):
        for ruta in ("/api/registros?uma=6", "/api/registros?limite=0", "/api/registros?limite=501",
                     "/api/registros?uma=abc", "/grafica.png?uma=0"):
            with self.subTest(ruta=ruta):
                self.assertEqual(self.client.get(ruta).status_code, 400)
        self.assertEqual(self.client.get("/api/registros/99").status_code, 404)

    def test_png_con_datos_y_sin_datos(self):
        for lleno in (False, True):
            with self.subTest(lleno=lleno):
                if lleno:
                    self.client.post("/api/registros", json=self.muestra)
                respuesta = self.client.get("/grafica.png?uma=1")
                self.assertEqual(respuesta.status_code, 200)
                self.assertEqual(respuesta.mimetype, "image/png")
                self.assertEqual(respuesta.headers["Cache-Control"], "no-store")
                with Image.open(BytesIO(respuesta.data)) as imagen:
                    self.assertEqual(imagen.format, "PNG")
                    self.assertGreater(imagen.width, 800)

    def test_pagina_html_y_enlaces(self):
        self.client.post("/data", json=self.muestra)
        respuesta = self.client.get("/?uma=1&limite=12")
        self.assertEqual(respuesta.status_code, 200)
        self.assertIn(b"/grafica.png?uma=1", respuesta.data)
        self.assertIn(b"/api/registros/1", respuesta.data)


if __name__ == "__main__":
    unittest.main()
