unit principal;

{$mode objfpc}{$H+}{$codepage utf8}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Graphics,
  TAGraph, TASeries, TATypes, TAChartUtils, LazSerial, fphttpclient, fpjson;

type
  TTrama = array[0..11] of Integer;

  TPrincipal = class(TForm)
  private
    FSerial: TLazSerial;
    FCom, FUrl: TEdit;
    FBoton: TButton;
    FEnviar: TCheckBox;
    FUma: TComboBox;
    FTemp, FHum, FEstado: TLabel;
    FMemo: TMemo;
    FChart, FHist: TChart;
    FSeries: array[0..2] of TLineSeries;
    FBarras: TBarSeries;
    FValores: array[0..2, 0..11] of Integer;
    FNumMuestras: Integer;
    FBuffer: string;
    procedure Conectar(Sender: TObject);
    procedure CambiarUma(Sender: TObject);
    procedure Recibir(Sender: TObject);
    procedure ProcesarTrama(const Linea: string);
    procedure Graficar(const Datos: TTrama);
    procedure EnviarAFlask(const Datos: TTrama);
    procedure Registrar(const Texto: string);
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  end;

var
  PrincipalForm: TPrincipal;

implementation

const
  Campos: array[0..11] of string = (
    'id', 'mp01', 'mp02', 'mp03', 'hi01', 'hi02', 'hi03',
    'hi04', 'hi05', 'hi06', 'te', 'hr'
  );
  Categorias: array[0..5] of string = ('0.3', '0.5', '1.0', '2.5', '5.0', '10');
  Colores: array[0..5] of TColor = (clBlue, clTeal, clPurple, clOlive, clRed, clGray);
  NombresPM: array[0..2] of string = ('PM1.0', 'PM2.5', 'PM10');

constructor TPrincipal.Create(AOwner: TComponent);
var
  Superior, Inferior, Centro: TPanel;
  Etiqueta: TLabel;
  Separador: TSplitter;
  I: Integer;
begin
  // CreateNew permite construir la ventana en código, sin archivo .lfm.
  inherited CreateNew(AOwner, 1);
  Caption := 'INFO1128 - DataLogger ambiental';
  Position := poScreenCenter;
  Width := 1180;
  Height := 760;
  Constraints.MinWidth := 1050;
  Constraints.MinHeight := 650;

  Superior := TPanel.Create(Self);
  Superior.Parent := Self;
  Superior.Align := alTop;
  Superior.Height := 130;
  Superior.BevelOuter := bvNone;

  Etiqueta := TLabel.Create(Self);
  Etiqueta.Parent := Superior;
  Etiqueta.SetBounds(16, 10, 800, 22);
  Etiqueta.Caption := 'Monitoreo de material particulado - datos simulados';
  Etiqueta.Font.Style := [fsBold];
  Etiqueta.Font.Size := 12;

  Etiqueta := TLabel.Create(Self);
  Etiqueta.Parent := Superior;
  Etiqueta.SetBounds(16, 43, 45, 20);
  Etiqueta.Caption := 'COM:';

  FCom := TEdit.Create(Self);
  FCom.Parent := Superior;
  FCom.SetBounds(64, 39, 140, 28);
  FCom.Text := 'COM2';

  FBoton := TButton.Create(Self);
  FBoton.Parent := Superior;
  FBoton.SetBounds(216, 38, 120, 30);
  FBoton.Caption := 'Conectar';
  FBoton.OnClick := @Conectar;

  FUma := TComboBox.Create(Self);
  FUma.Parent := Superior;
  FUma.SetBounds(352, 39, 100, 28);
  FUma.Style := csDropDownList;
  for I := 1 to 5 do FUma.Items.Add('UMA ' + IntToStr(I));
  FUma.ItemIndex := 0;
  FUma.OnChange := @CambiarUma;

  FEnviar := TCheckBox.Create(Self);
  FEnviar.Parent := Superior;
  FEnviar.SetBounds(472, 41, 270, 24);
  FEnviar.Caption := 'Enviar UMA seleccionada a Flask';
  FEnviar.Checked := False;

  FTemp := TLabel.Create(Self);
  FTemp.Parent := Superior;
  FTemp.SetBounds(770, 38, 180, 28);
  FTemp.Caption := 'Temp: -- C';
  FTemp.Font.Size := 13;

  FHum := TLabel.Create(Self);
  FHum.Parent := Superior;
  FHum.SetBounds(960, 38, 150, 28);
  FHum.Caption := 'HR: -- %';
  FHum.Font.Size := 13;

  Etiqueta := TLabel.Create(Self);
  Etiqueta.Parent := Superior;
  Etiqueta.SetBounds(16, 88, 70, 20);
  Etiqueta.Caption := 'URL POST:';

  FUrl := TEdit.Create(Self);
  FUrl.Parent := Superior;
  FUrl.SetBounds(94, 82, 480, 28);
  FUrl.Text := 'http://127.0.0.1:7070/data';

  Etiqueta := TLabel.Create(Self);
  Etiqueta.Parent := Superior;
  Etiqueta.SetBounds(594, 87, 530, 22);
  Etiqueta.Caption := '9600 baudios - 8 bits - sin paridad - 1 bit de parada';

  Inferior := TPanel.Create(Self);
  Inferior.Parent := Self;
  Inferior.Align := alBottom;
  Inferior.Height := 170;
  Inferior.BevelOuter := bvNone;

  FEstado := TLabel.Create(Self);
  FEstado.Parent := Inferior;
  FEstado.Align := alTop;
  FEstado.AutoSize := False;
  FEstado.Height := 28;
  FEstado.Caption := '  Desconectado. Inicia Flask y configura el puerto virtual.';
  FEstado.Layout := tlCenter;

  FMemo := TMemo.Create(Self);
  FMemo.Parent := Inferior;
  FMemo.Align := alClient;
  FMemo.ReadOnly := True;
  FMemo.ScrollBars := ssAutoVertical;
  FMemo.Font.Name := 'Consolas';

  Centro := TPanel.Create(Self);
  Centro.Parent := Self;
  Centro.Align := alClient;
  Centro.BevelOuter := bvNone;

  FChart := TChart.Create(Self);
  FChart.Parent := Centro;
  FChart.Align := alLeft;
  FChart.Width := 670;
  FChart.Title.Visible := True;
  FChart.Title.Text.Add('UMA 1 - ultimas 12 muestras');
  FChart.Legend.Visible := True;
  FChart.LeftAxis.Title.Caption := 'Concentracion (ug/m3)';
  FChart.LeftAxis.Title.Visible := True;
  FChart.BottomAxis.Title.Caption := 'Muestras de la UMA seleccionada';
  FChart.BottomAxis.Title.Visible := True;

  for I := 0 to 2 do
  begin
    FSeries[I] := TLineSeries.Create(Self);
    FSeries[I].Title := NombresPM[I];
    FSeries[I].SeriesColor := Colores[I];
    FSeries[I].LinePen.Width := 2;
    FSeries[I].ShowPoints := True;
    FChart.AddSeries(FSeries[I]);
  end;

  Separador := TSplitter.Create(Self);
  Separador.Parent := Centro;
  Separador.Align := alLeft;
  Separador.Left := FChart.Width;

  FHist := TChart.Create(Self);
  FHist.Parent := Centro;
  FHist.Align := alClient;
  FHist.Title.Visible := True;
  FHist.Title.Text.Add('Conteo de particulas - ultima trama');
  FHist.LeftAxis.Title.Caption := 'Conteo simulado';
  FHist.LeftAxis.Title.Visible := True;
  FHist.BottomAxis.Title.Caption := 'Umbral de diametro (um)';
  FHist.BottomAxis.Title.Visible := True;
  FBarras := TBarSeries.Create(Self);
  FHist.AddSeries(FBarras);
  FHist.BottomAxis.Marks.Source := FBarras.ListSource;
  FHist.BottomAxis.Marks.Style := smsLabel;

  FSerial := TLazSerial.Create(Self);
  FSerial.BaudRate := br__9600;
  FSerial.DataBits := db8bits;
  FSerial.Parity := pNone;
  FSerial.StopBits := sbOne;
  FSerial.FlowControl := fcNone;
  // Recibimos trozos arbitrarios y reconstruimos líneas nosotros mismos.
  FSerial.RcvLineCRLF := False;
  FSerial.OnRxData := @Recibir;
  FNumMuestras := 0;
  FBuffer := '';
  Registrar('CSV de 12 enteros + salto de linea. Sólo se grafica y envia la UMA seleccionada.');
end;

destructor TPrincipal.Destroy;
begin
  if Assigned(FSerial) then
  begin
    FSerial.OnRxData := nil;
    FSerial.Close;
  end;
  inherited Destroy;
end;

procedure TPrincipal.Registrar(const Texto: string);
begin
  if FMemo.Lines.Count >= 150 then FMemo.Lines.Delete(0);
  FMemo.Lines.Add(FormatDateTime('hh:nn:ss', Now) + '  ' + Texto);
  FMemo.SelStart := Length(FMemo.Text);
end;

procedure TPrincipal.Conectar(Sender: TObject);
begin
  try
    if FSerial.Active then
    begin
      FSerial.Close;
      FBoton.Caption := 'Conectar';
      FCom.Enabled := True;
      FEstado.Caption := '  Puerto cerrado.';
    end
    else
    begin
      FBuffer := '';
      FSerial.Device := Trim(FCom.Text);
      FSerial.Open;
      FBoton.Caption := 'Desconectar';
      FCom.Enabled := False;
      FEstado.Caption := '  Puerto abierto. Esperando las tramas del simulador...';
      Registrar('Conectado a ' + FSerial.Device + ' (9600-8N1).');
    end;
  except
    on E: Exception do
    begin
      FEstado.Caption := '  Error al abrir/cerrar el COM. Revisa VSPE y el nombre del puerto.';
      Registrar(E.Message);
    end;
  end;
end;

procedure TPrincipal.CambiarUma(Sender: TObject);
var
  I: Integer;
begin
  // Evitamos mezclar el historial de dos estaciones distintas.
  FNumMuestras := 0;
  for I := 0 to 2 do FSeries[I].Clear;
  FBarras.Clear;
  FTemp.Caption := 'Temp: -- C';
  FHum.Caption := 'HR: -- %';
  FChart.Title.Text.Text := FUma.Text + ' - ultimas 12 muestras';
  Registrar('Ahora se grafica y envia ' + FUma.Text + '. Historial local reiniciado.');
end;

procedure TPrincipal.Recibir(Sender: TObject);
var
  PosFin: SizeInt;
  Linea: string;
begin
  try
    FBuffer := FBuffer + FSerial.ReadData;
    // Un evento puede traer media trama, una trama o varias juntas.
    PosFin := Pos(#10, FBuffer);
    while PosFin > 0 do
    begin
      Linea := Trim(Copy(FBuffer, 1, PosFin - 1));
      Delete(FBuffer, 1, PosFin);
      if Linea <> '' then ProcesarTrama(Linea);
      PosFin := Pos(#10, FBuffer);
    end;
    if Length(FBuffer) > 65536 then
    begin
      FBuffer := '';
      Registrar('Buffer reiniciado: faltan los saltos de linea del simulador.');
    end;
  except
    on E: Exception do Registrar('Error serial: ' + E.Message);
  end;
end;

procedure TPrincipal.ProcesarTrama(const Linea: string);
var
  Partes: TStringList;
  Datos: TTrama;
  I: Integer;
begin
  Partes := TStringList.Create;
  try
    Partes.StrictDelimiter := True;
    Partes.Delimiter := ',';
    Partes.DelimitedText := Linea;
    if Partes.Count <> 12 then
    begin
      Registrar('Trama descartada: se necesitan 12 campos. ' + Linea);
      Exit;
    end;
    for I := 0 to 11 do
      if not TryStrToInt(Trim(Partes[I]), Datos[I]) then
      begin
        Registrar('Trama descartada: hay un campo que no es entero.');
        Exit;
      end;
  finally
    Partes.Free;
  end;
  if (Datos[0] < 1) or (Datos[0] > 5) then Exit;
  for I := 1 to 9 do
    if (Datos[I] < 0) or (Datos[I] > 10000000) then Exit;
  if (Datos[10] < -80) or (Datos[10] > 80) or
     (Datos[11] < 0) or (Datos[11] > 100) then Exit;
  if Datos[0] <> FUma.ItemIndex + 1 then Exit;

  FTemp.Caption := 'Temp: ' + IntToStr(Datos[10]) + ' C';
  FHum.Caption := 'HR: ' + IntToStr(Datos[11]) + ' %';
  Graficar(Datos);
  Registrar(Linea);
  FEstado.Caption := '  Trama recibida de ' + FUma.Text + '. Ventana de hasta 12 muestras.';
  if FEnviar.Checked then
    try
      EnviarAFlask(Datos);
      FEstado.Caption := '  ' + FUma.Text + ': recibida y guardada por Flask (HTTP 201).';
    except
      on E: Exception do
      begin
        FEnviar.Checked := False;
        FEstado.Caption := '  Fallo HTTP. Envio desactivado: inicia Flask y vuelve a marcar la casilla.';
        Registrar('Error HTTP: ' + E.Message);
      end;
    end;
end;

procedure TPrincipal.Graficar(const Datos: TTrama);
var
  I, J, Ultimo: Integer;
begin
  if FNumMuestras < 12 then
  begin
    Ultimo := FNumMuestras;
    Inc(FNumMuestras);
  end
  else
  begin
    // Al llegar la muestra 13, eliminamos la más antigua de la ventana.
    for I := 0 to 2 do
      for J := 0 to 10 do FValores[I, J] := FValores[I, J + 1];
    Ultimo := 11;
  end;
  for I := 0 to 2 do
  begin
    FValores[I, Ultimo] := Datos[I + 1];
    FSeries[I].Clear;
    for J := 0 to FNumMuestras - 1 do FSeries[I].AddXY(J + 1, FValores[I, J]);
  end;
  FBarras.Clear;
  for I := 0 to 5 do FBarras.AddXY(I, Datos[I + 4], Categorias[I], Colores[I]);
end;

procedure TPrincipal.EnviarAFlask(const Datos: TTrama);
var
  Json: TJSONObject;
  Cliente: TFPHTTPClient;
  Cuerpo: TStringStream;
  I: Integer;
begin
  Json := TJSONObject.Create;
  Cliente := TFPHTTPClient.Create(nil);
  Cuerpo := nil;
  try
    for I := 0 to 11 do Json.Add(Campos[I], Datos[I]);
    Cuerpo := TStringStream.Create(Json.AsJSON);
    Cliente.AddHeader('Content-Type', 'application/json');
    Cliente.ConnectTimeout := 2000;
    Cliente.IOTimeout := 2000;
    Cliente.RequestBody := Cuerpo;
    Cliente.Post(Trim(FUrl.Text));
    if Cliente.ResponseStatusCode <> 201 then
      raise Exception.Create('Flask no confirmo el guardado con HTTP 201.');
  finally
    Cliente.RequestBody := nil;
    Cuerpo.Free;
    Cliente.Free;
    Json.Free;
  end;
end;

end.
