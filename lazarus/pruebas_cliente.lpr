program pruebas_cliente;

{$mode objfpc}{$H+}{$codepage utf8}

uses SysUtils, protocolo_uma;

const
  Ejemplo = '4,97,20,52,5593,1398,9349,1868,5142,6684,13,37';

var
  Buffer, Linea, Error: string;
  Datos: TTrama;
  Historial: THistorialPM;
  I, J: Integer;
  Grupos: Integer = 0;

procedure Comprobar(Condicion: Boolean; const Mensaje: string);
begin
  if not Condicion then raise Exception.Create(Mensaje);
end;

procedure Rechazar(const Trama: string);
begin
  Comprobar(not DecodificarTrama(Trama, Datos, Error),
    'Se acepto una trama invalida: ' + Trama);
  Comprobar(Error <> '', 'La trama invalida debe explicar su error.');
end;

begin
  try
    Comprobar(DecodificarTrama(Ejemplo, Datos, Error), Error);
    Comprobar((Datos[0] = 4) and (Datos[2] = 20) and (Datos[9] = 6684)
      and (Datos[10] = 13) and (Datos[11] = 37), 'Orden de campos incorrecto.');
    Inc(Grupos);
    WriteLn('OK: trama del PDF y orden de los 12 campos.');

    Buffer := Copy(Ejemplo, 1, 15);
    Comprobar(not ExtraerLinea(Buffer, Linea), 'No se debe procesar media trama.');
    Buffer := Buffer + Copy(Ejemplo, 16, MaxInt) + #13#10 + Ejemplo + #10 + '1,2';
    Comprobar(ExtraerLinea(Buffer, Linea) and (Linea = Ejemplo), 'Fallo trama fragmentada CRLF.');
    Comprobar(ExtraerLinea(Buffer, Linea) and (Linea = Ejemplo), 'Fallo segunda trama en el evento.');
    Comprobar(not ExtraerLinea(Buffer, Linea) and (Buffer = '1,2'), 'Se perdio el resto pendiente.');
    Inc(Grupos);
    WriteLn('OK: buffer, fragmentos, CRLF, varias tramas y resto pendiente.');

    Rechazar('1,2,3');
    Rechazar(Ejemplo + ',9');
    Rechazar('6,97,20,52,5593,1398,9349,1868,5142,6684,13,37');
    Rechazar('4,-1,20,52,5593,1398,9349,1868,5142,6684,13,37');
    Rechazar('4,10000001,20,52,5593,1398,9349,1868,5142,6684,13,37');
    Rechazar('4,97,20,52,5593,1398,9349,1868,5142,6684,81,37');
    Rechazar('4,97,20,52,5593,1398,9349,1868,5142,6684,13,101');
    Rechazar('4,1.5,20,52,5593,1398,9349,1868,5142,6684,13,37');
    Rechazar('4,$10,20,52,5593,1398,9349,1868,5142,6684,13,37');
    Rechazar('4,9999999999999999999999,20,52,5593,1398,9349,1868,5142,6684,13,37');
    Rechazar(StringOfChar('9', MAX_LONGITUD_TRAMA + 1));
    Inc(Grupos);
    WriteLn('OK: campos faltantes, sobrantes, rangos, decimales y desbordamientos.');

    ReiniciarHistorial(Historial);
    Comprobar(Historial.Cantidad = 0, 'El historial debe iniciar vacio.');
    for I := 1 to 25 do
    begin
      Datos[1] := I;
      Datos[2] := I + 100;
      Datos[3] := I + 200;
      AgregarMuestra(Historial, Datos);
      if I <= MAX_MUESTRAS then
        Comprobar(Historial.Cantidad = I, 'Se agregaron muestras ficticias.')
      else
        Comprobar(Historial.Cantidad = MAX_MUESTRAS, 'La ventana supero 12 muestras.');
    end;
    for I := 0 to 2 do
      for J := 0 to MAX_MUESTRAS - 1 do
        Comprobar(Historial.Valores[I, J] = 14 + J + I * 100,
          'El desplazamiento no conserva las ultimas 12 muestras.');
    ReiniciarHistorial(Historial);
    Comprobar(Historial.Cantidad = 0, 'Cambiar de UMA debe reiniciar el historial.');
    Inc(Grupos);
    WriteLn('OK: tres series, 25 entradas, ventana de 12, desplazamiento y reinicio.');

    WriteLn(Grupos, ' grupos de pruebas del cliente completados.');
  except
    on E: Exception do
    begin
      WriteLn('ERROR: ', E.Message);
      Halt(1);
    end;
  end;
end.
