"""Prueba manual previa al COM: inserta 5 mediciones DEMO, una por UMA."""

import json
from urllib.error import URLError
from urllib.request import Request, urlopen

from simulador import generar_datos


def main():
    try:
        print("Esta prueba agrega cinco registros de demostración a la base activa.")
        for uma in range(1, 6):
            solicitud = Request(
                "http://127.0.0.1:7070/data",
                data=json.dumps(generar_datos(uma)).encode("utf-8"),
                headers={"Content-Type": "application/json"}, method="POST",
            )
            with urlopen(solicitud, timeout=5) as respuesta:
                fila = json.load(respuesta)
                print(f"UMA {uma}: HTTP {respuesta.status}, registro {fila['registro_id']}, {fila['fecha_hora']}")
        with urlopen("http://127.0.0.1:7070/api/registros?limite=5", timeout=5) as respuesta:
            print(json.dumps(json.load(respuesta), ensure_ascii=False, indent=2))
        print("Abre http://127.0.0.1:7070 para revisar la gráfica.")
    except URLError as error:
        raise SystemExit(f"No se pudo completar la prueba: {error}. Inicia primero python -m servidor.app.") from error


if __name__ == "__main__":
    main()
