unit main;

{$APPTYPE CONSOLE}

interface

uses
  Winapi.Windows,
  Winapi.Messages,
  System.SysUtils,
  System.Variants,
  System.Classes,
  Vcl.Graphics,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.Dialogs,
  System.RegularExpressions,
  Vcl.StdCtrls,
  XSuperObject,
  XSuperJSON;

const
  FloatFormat: TFormatSettings = (DecimalSeparator: '.');

const
  // ÷вета текста (Foreground)
  FOREGROUND_RED = $0004;
  FOREGROUND_GREEN = $0002;
  FOREGROUND_BLUE = $0001;
  FOREGROUND_INTENSITY = $0008; // яркость

  // ÷вета фона (Background)
  BACKGROUND_RED = $0040;
  BACKGROUND_GREEN = $0020;
  BACKGROUND_BLUE = $0010;
  BACKGROUND_INTENSITY = $0080; // яркость фона

type
  TCcolor = (cDef, cRed, cYellow, cGreen, cBlue);

type
  TfrmMain = class(TForm)
    procedure FormCreate(Sender: TObject);
  private
    flash_size, ram_size: integer;
    mcu, app, elf: string;
    { Private declarations }
    function PercentToSymbol(const Percent: Single): string;
    procedure ParseParam(const param: string);
    procedure SetColor(color: TCcolor);
  public
    { Public declarations }
  end;

var
  frmMain: TfrmMain;
  hConsole: THandle;
  wAttributes: Word;

implementation

{$R *.dfm}

function ConsoleExec(const AppRun, CommandLine: string): string;
var
  SA: TSecurityAttributes;
  SI: TStartupInfo;
  PI: TProcessInformation;
  StdOutPipeRead, StdOutPipeWrite: THandle;
  WasOK: Boolean;
  Buffer: array [0 .. 255] of AnsiChar;
  BytesRead: Cardinal;
  Line: AnsiString;
begin
  Application.ProcessMessages;
  with SA do
  begin
    nLength := SizeOf(SA);
    bInheritHandle := True;
    lpSecurityDescriptor := nil;
  end;
  CreatePipe(StdOutPipeRead, StdOutPipeWrite, @SA, 0);
  try
    with SI do
    begin
      FillChar(SI, SizeOf(SI), 0);
      cb := SizeOf(SI);
      dwFlags := STARTF_USESHOWWINDOW or STARTF_USESTDHANDLES;
      wShowWindow := SW_HIDE;
      hStdInput := GetStdHandle(STD_INPUT_HANDLE);
      hStdOutput := StdOutPipeWrite;
      hStdError := StdOutPipeWrite;
    end;

    WasOK := CreateProcess(PChar(AppRun), PChar(CommandLine), nil, nil, True, 0,
      nil, nil, SI, PI);

    CloseHandle(StdOutPipeWrite);
    if not WasOK then
      raise Exception.Create('Could not execute command line!')
    else
      try
        Line := '';
        repeat
          WasOK := ReadFile(StdOutPipeRead, Buffer, 255, BytesRead, nil);
          if BytesRead > 0 then
          begin
            Buffer[BytesRead] := #0;
            Line := Line + Buffer;
          end;
        until not WasOK or (BytesRead < 255);
        WaitForSingleObject(PI.hProcess, INFINITE);
      finally
        CloseHandle(PI.hThread);
        CloseHandle(PI.hProcess);
      end;
  finally
    result := string(Line);
    CloseHandle(StdOutPipeRead);
  end;
end; { ConsoleExec }

procedure usage();
begin
  Writeln('usage:-----------------------------------');
  Writeln('');
  Writeln('calling without parameters shows help');
  Writeln('--mcu=     mcu e.g. ATmega16, atmega16');
  Writeln('--app=     path to avr-size.exe file');
  Writeln('--target=  path to *.elf file');
  Writeln('-----------------------------------------');
end;

procedure TfrmMain.FormCreate(Sender: TObject);
const
  REGEX_FLASH = '(\d+)\s+(\d+)\s+\d+\s';
  REGEX_DATA = '\d+\s+(\d+)\s+(\d+)\s+\d+';
var
  RegEx: TRegEx;
  M: TMatchCollection;
  Perc: Single;
  u1, u2: integer;
  Line: string;
  i: integer;
  SO: ISuperObject;
  fs: TFileStream;
begin
  Application.ShowMainForm := False;
  hConsole := GetStdHandle(STD_OUTPUT_HANDLE);

  if ParamCount = 0 then
  begin
    usage();
    Application.Terminate;
    Exit;
  end;

  if ParamCount < 3 then
  begin
    SetColor(cRed);
    Writeln('avrsize: Not enough parameters');
    SetColor(cDef);
    usage();
    Application.Terminate;
    Exit;
  end;

  for i := 1 to ParamCount do
    ParseParam(ParamStr(i));

  if (not FileExists(app)) then
  begin
    SetColor(cRed);
    Writeln('avrsize: avr-size not found');
    SetColor(cDef);
    usage();
    Application.Terminate;
    Exit;
  end;

  if (not FileExists(elf)) then
  begin
    SetColor(cRed);
    Writeln('avrsize: elf file not found');
    SetColor(cDef);
    usage();
    Application.Terminate;
    Exit;
  end;

  if not FileExists(ExtractFilePath(ParamStr(0)) + 'db.json') then
  begin
    SetColor(cRed);
    Writeln('avrsize: db.json file not found');
    SetColor(cDef);
    Application.Terminate;
    Exit;
  end;

  fs := TFileStream.Create(ExtractFilePath(ParamStr(0)) + 'db.json',
    fmOpenRead);

  try
    try
      SO := TSuperObject.ParseStream(fs);

      flash_size := SO.O[mcu].i['flash_size'];
      ram_size := SO.O[mcu].i['ram_size'];

      if flash_size = 0 then
      begin
        Writeln('fail');
        Application.Terminate;
        Exit;
      end;

      Writeln('Checking size ' + elf);
      Line := ConsoleExec(app, '-B -d ' + elf);

      if ram_size <> 0 then
      begin
        RegEx := TRegEx.Create(REGEX_DATA);
        M := RegEx.Matches(Line);

        u1 := M.Item[0].Groups[1].Value.ToInteger + M.Item[0].Groups[2]
          .Value.ToInteger;

        Perc := 100 / (ram_size / u1);
        Writeln(Format('RAM:   [%s]%6.1f%% (used %d bytes from %d bytes)',
          [PercentToSymbol(Perc), Perc, u1, ram_size], FloatFormat));
      end;

      RegEx := TRegEx.Create(REGEX_FLASH);
      M := RegEx.Matches(Line);

      u2 := M.Item[0].Groups[1].Value.ToInteger + M.Item[0].Groups[2]
        .Value.ToInteger;
      Perc := 100 / (flash_size / u2);

      Writeln(Format('FLASH: [%s]%6.1f%% (used %d bytes from %d bytes)',
        [PercentToSymbol(Perc), Perc, u2, flash_size], FloatFormat));

      if ram_size <> 0 then
        if ram_size < u1 then
        begin
          SetColor(cYellow);
          Writeln(Format
            ('Warning! The data size (%d bytes) is greater than maximum allowed (%d bytes)',
            [u1, ram_size]));
          SetColor(cDef);
        end;

      if flash_size < u2 then
      begin
        SetColor(cRed);
        Writeln(Format
          ('Error: The program size (%d bytes) is greater than maximum allowed (%d bytes)',
          [u2, flash_size]));
        SetColor(cDef);
      end;
    except
      Writeln('Error');
    end;
  finally
    fs.Free;
    Application.Terminate;
  end;
end;

procedure TfrmMain.ParseParam(const param: string);
begin
  if Pos('mcu', param) > 1 then
    mcu := Copy(param, 7, Length(param) - 6)
  else if Pos('app', param) > 1 then
    app := Copy(param, 7, Length(param) - 6)
  else if Pos('target', param) > 1 then
    elf := Copy(param, 10, Length(param) - 9);
end;

function TfrmMain.PercentToSymbol(const Percent: Single): string;
const
  symbol = '=';
var
  s: string;
  i: integer;
  n: integer;
begin
  SetLength(s, 10);
  n := Round(Percent / 10);
  for i := 1 to Length(s) do
    if n < i then
      s[i] := ' '
    else
      s[i] := symbol;

  result := s;
end;

procedure TfrmMain.SetColor(color: TCcolor);
begin
  case color of
    cDef:
      wAttributes := FOREGROUND_RED or FOREGROUND_GREEN or FOREGROUND_BLUE;
    cRed:
      wAttributes := FOREGROUND_RED or FOREGROUND_INTENSITY;
    cYellow:
      wAttributes := FOREGROUND_RED or FOREGROUND_GREEN;
    cGreen:
      ;
    cBlue:
      ;
  end;
  SetConsoleTextAttribute(hConsole, wAttributes);
end;

end.
