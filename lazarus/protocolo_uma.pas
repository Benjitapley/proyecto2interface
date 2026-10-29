unit protocolo_uma;

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses Classes, SysUtils;

const
  NUM_CAMPOS = 12;
  MAX_MUESTRAS = 12;
  MAX_LONGITUD_TRAMA = 512;
  Campos: array[0..NUM_CAMPOS - 1] of string = (
    'id', 'mp01', 'mp02', 'mp03', 'hi01', 'hi02', 'hi03',
    'hi04', 'hi05', 'hi06', 'te', 'hr'
  );

type
  TTrama = array[0..NUM_CAMPOS - 1] of Integer;
  THistorialPM = record
    Cantidad: Integer;
    Valores: array[0..2, 0..MAX_MUESTRAS - 1] of Integer;
  end;

// Un evento serial puede contener fragmentos o varias líneas completas.
function ExtraerLinea(var Buffer: string; out Linea: string): Boolean;
function DecodificarTrama(const Linea: string; out Datos: TTrama;
  out Error: string): Boolean;
procedure ReiniciarHistorial(var Historial: THistorialPM);
procedure AgregarMuestra(var Historial: THistorialPM; const Datos: TTrama);

implementation

function ExtraerLinea(var Buffer: string; out Linea: string): Boolean;
var
  PosFin: SizeInt;
begin
  PosFin := Pos(#10, Buffer);
  Result := PosFin > 0;
  Linea := '';
  if not Result then Exit;
  Linea := Trim(Copy(Buffer, 1, PosFin - 1));
  Delete(Buffer, 1, PosFin);
end;

function EsEnteroDecimal(const Texto: string; out Valor: Integer): Boolean;
var
  I, Inicio: SizeInt;
begin
  Result := False;
  if Texto = '' then Exit;
  Inicio := 1;
  if Texto[1] in ['-', '+'] then Inicio := 2;
  if Inicio > Length(Texto) then Exit;
  for I := Inicio to Length(Texto) do
    if not (Texto[I] in ['0'..'9']) then Exit;
  Result := TryStrToInt(Texto, Valor);
end;

function DecodificarTrama(const Linea: string; out Datos: TTrama;
  out Error: string): Boolean;
var
  Partes: TStringList;
  I: Integer;
begin
  Result := False;
  Error := '';
  if Length(Linea) > MAX_LONGITUD_TRAMA then
  begin
    Error := 'la trama supera 512 caracteres.';
    Exit;
  end;
  Partes := TStringList.Create;
  try
    Partes.StrictDelimiter := True;
    Partes.Delimiter := ',';
    Partes.QuoteChar := #0;
    Partes.DelimitedText := Linea;
    if Partes.Count <> NUM_CAMPOS then
    begin
      Error := 'se necesitan exactamente 12 campos.';
      Exit;
    end;
    for I := 0 to NUM_CAMPOS - 1 do
      if not EsEnteroDecimal(Trim(Partes[I]), Datos[I]) then
      begin
        Error := Campos[I] + ' debe ser un entero decimal.';
        Exit;
      end;
  finally
    Partes.Free;
  end;
  if (Datos[0] < 1) or (Datos[0] > 5) then
    Error := 'id debe identificar una UMA entre 1 y 5.';
  for I := 1 to 9 do
    if (Datos[I] < 0) or (Datos[I] > 10000000) then
      Error := Campos[I] + ' debe estar entre 0 y 10000000.';
  if (Datos[10] < -80) or (Datos[10] > 80) then
    Error := 'te debe estar entre -80 y 80 grados.';
  if (Datos[11] < 0) or (Datos[11] > 100) then
    Error := 'hr debe estar entre 0 y 100.';
  Result := Error = '';
end;

procedure ReiniciarHistorial(var Historial: THistorialPM);
begin
  FillChar(Historial, SizeOf(Historial), 0);
end;

procedure AgregarMuestra(var Historial: THistorialPM; const Datos: TTrama);
var
  I, J, Ultimo: Integer;
begin
  if Historial.Cantidad < MAX_MUESTRAS then
  begin
    Ultimo := Historial.Cantidad;
    Inc(Historial.Cantidad);
  end
  else
  begin
    for I := 0 to 2 do
      for J := 0 to MAX_MUESTRAS - 2 do
        Historial.Valores[I, J] := Historial.Valores[I, J + 1];
    Ultimo := MAX_MUESTRAS - 1;
  end;
  for I := 0 to 2 do Historial.Valores[I, Ultimo] := Datos[I + 1];
end;

end.
