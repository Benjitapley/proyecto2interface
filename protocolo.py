"""Los mismos 12 campos del tutorial, en el mismo orden."""

CAMPOS = (
    "id", "mp01", "mp02", "mp03", "hi01", "hi02", "hi03",
    "hi04", "hi05", "hi06", "te", "hr",
)


def validar(datos):
    """Rechaza tramas incompletas o valores imposibles para esta simulación."""
    if not isinstance(datos, dict):
        raise ValueError("Se esperaba un objeto JSON con 12 campos.")
    faltan = [campo for campo in CAMPOS if campo not in datos]
    if faltan:
        raise ValueError("Faltan campos: " + ", ".join(faltan))
    for campo in CAMPOS:
        # bool es subclase de int en Python; type evita aceptar True como 1.
        if type(datos[campo]) is not int:
            raise ValueError(f"{campo} debe ser un número entero.")
    if not 1 <= datos["id"] <= 5:
        raise ValueError("id debe identificar una UMA entre 1 y 5.")
    for campo in CAMPOS[1:10]:
        if not 0 <= datos[campo] <= 10_000_000:
            raise ValueError(f"{campo} debe estar entre 0 y 10000000.")
    if not -80 <= datos["te"] <= 80:
        raise ValueError("te debe estar entre -80 y 80 grados Celsius.")
    if not 0 <= datos["hr"] <= 100:
        raise ValueError("hr debe estar entre 0 y 100 por ciento.")
    return {campo: datos[campo] for campo in CAMPOS}


def codificar(datos):
    """Una trama CSV termina en LF y se transmite como bytes ASCII."""
    datos = validar(datos)
    return (",".join(str(datos[c]) for c in CAMPOS) + "\n").encode("ascii")


def decodificar(linea):
    """Útil para estudiar y comprobar el contrato que implementa Lazarus."""
    if isinstance(linea, bytes):
        linea = linea.decode("ascii")
    partes = linea.strip().split(",")
    if len(partes) != len(CAMPOS):
        raise ValueError("Una trama debe tener exactamente 12 números.")
    return validar(dict(zip(CAMPOS, map(int, partes))))
