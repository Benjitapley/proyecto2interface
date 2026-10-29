"""Simula cinco UMA y escribe sus tramas por un puerto serial virtual."""

import argparse
import random
import time

import serial  # Se instala con pip install pyserial, no con pip install serial.

from protocolo import codificar


def generar_datos(uma, rng=None):
    rng = rng or random
    return {
        "id": uma,
        "mp01": rng.randint(5, 100),
        "mp02": rng.randint(5, 100),
        "mp03": rng.randint(5, 100),
        **{f"hi{i:02d}": rng.randint(10, 10_000) for i in range(1, 7)},
        "te": rng.randint(5, 30),
        "hr": rng.randint(20, 70),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--puerto", default="COM2", help="COM2 con VSPE Connector")
    parser.add_argument("--intervalo", type=float, default=0.2, help="Segundos entre tramas")
    parser.add_argument("--cantidad", type=int, default=0, help="0 significa enviar hasta Ctrl+C")
    parser.add_argument("--uma", type=int, choices=range(1, 6), help="Omitir para rotar UMA1 a UMA5")
    parser.add_argument("--ver", action="store_true", help="Sólo imprimir; no abrir el puerto")
    args = parser.parse_args()
    if args.intervalo < 0.1 or args.cantidad < 0:
        parser.error("Usa intervalo >= 0.1 y cantidad >= 0.")
    puerto = None
    try:
        if not args.ver:
            puerto = serial.Serial(
                port=args.puerto, baudrate=9600, bytesize=serial.EIGHTBITS,
                parity=serial.PARITY_NONE, stopbits=serial.STOPBITS_ONE,
                timeout=1, write_timeout=2, xonxoff=False, rtscts=False,
            )
        print("Simulación: datos aleatorios, no mediciones reales. Ctrl+C para salir.")
        numero = 0
        while args.cantidad == 0 or numero < args.cantidad:
            uma = args.uma or (numero % 5 + 1)
            trama = codificar(generar_datos(uma))
            if puerto is not None:
                puerto.write(trama)
            print(trama.decode("ascii").strip(), flush=True)
            numero += 1
            time.sleep(args.intervalo)
    except KeyboardInterrupt:
        print("\nSimulación detenida.")
    except serial.SerialException as error:
        parser.exit(1, f"Error serial: {error}\nRevisa VSPE, el COM y que no haya otro programa ocupándolo.\n")
    finally:
        if puerto is not None:
            puerto.close()


if __name__ == "__main__":
    main()
