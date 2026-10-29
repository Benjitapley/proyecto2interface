program datalogger;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, principal;

begin
  RequireDerivedFormResource := False;
  Application.Initialize;
  Application.Title := 'INFO1128 - DataLogger';
  Application.Scaled := True;
  Application.CreateForm(TPrincipal, PrincipalForm);
  Application.Run;
end.
