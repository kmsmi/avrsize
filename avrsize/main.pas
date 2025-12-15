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
  FG_RED = #$1B'[31;1m';
  FG_GREEN = #$1B'[32;1m';
  FG_YELLOW = #$1B'[33;1m';
  FG_BLUE = #$1B'[34;1m';
  FG_Cyan = #$1B'[36;1m';
  FG_END = #$1B'[0m';

  //Regular Colors
//  FG_Black = #$1B'[4;30m';
//  FG_Red = #$1B'[4;31m';
//  FG_Green = #$1B'[4;32m';
//  FG_Yellow = #$1B'[4;33m';
//  FG_Blue = #$1B'[4;34m';
//  FG_Purple = #$1B'[4;35m';
//  FG_Cyan = #$1B'[4;36m';
//  FG_White = #$1B'[4;37m';

  //High Intensity
//  Black = #$1B'[0;90m';
//  Red = #$1B'[0;91m';
//  Green = #$1B'[0;92m';
//  Yellow = #$1B'[0;93m';
//  Blue = #$1B'[0;94m';
//  Purple = #$1B'[0;95m';
//  Cyan = #$1B'[0;96m';
//  White = #$1B'[0;97m';
  // Reset
//  FG_END = #$1B'[0m';

type
  TCcolor = (cDef, cRed, cYellow, cGreen, cBlue);

  TTypeMsg = (mNone, mWarning, mError, mOk, mQuest, mInfo);

type
  TfrmMain = class(TForm)
    procedure FormCreate(Sender: TObject);
  private
    flash_size, ram_size: integer;
    mcu, app, elf: string;
    { Private declarations }
    function PercentToSymbol(const Percent: Single): string;
    procedure ParseParam(const param: string);
    procedure SendMsg(t: TTypeMsg; msg: string);
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
  Buffer: array[0..255] of AnsiChar;
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
  u: integer;
  ram_err, flash_err: string;
  Line: string;
  i: integer;
  SO: ISuperObject;
  fs: TFileStream;
begin
  Application.ShowMainForm := False;

  SendMsg(mInfo, 'Memory Usage...');

  if ParamCount = 0 then
  begin
    usage();
    Application.Terminate;
    Exit;
  end;

  if ParamCount < 3 then
  begin
    SendMsg(mError, 'Not enough parameters');
    usage();
    Application.Terminate;
    Exit;
  end;

  for i := 1 to ParamCount do
    ParseParam(ParamStr(i));

  if (not FileExists(app)) then
  begin
    SendMsg(mError, 'avr-size not found');
    usage();
    Application.Terminate;
    Exit;
  end;

  if (not FileExists(elf)) then
  begin
    SendMsg(mError, 'elf file "' + elf + '" not found');
    usage();
    Application.Terminate;
    Exit;
  end;

  if not FileExists(ExtractFilePath(ParamStr(0)) + 'db.json') then
  begin
    SendMsg(mError, 'db.json file not found');
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
        SendMsg(mError, 'avrsize: fail');
        Application.Terminate;
        Exit;
      end;
      Writeln('Checking size ' + elf);
      Line := ConsoleExec(app, '-B -d ' + elf);

      ram_err := '';
      flash_err := '';
      if ram_size <> 0 then
      begin
        RegEx := TRegEx.Create(REGEX_DATA);
        M := RegEx.Matches(Line);

        u := M.Item[0].Groups[1].Value.ToInteger + M.Item[0].Groups[2]
          .Value.ToInteger;

        Perc := 100 / (ram_size / u);
        Writeln(Format('RAM:   [%s]%6.1f%% (used %d bytes from %d bytes)',
            [PercentToSymbol(Perc), Perc, u, ram_size], FloatFormat));

        if ram_size < u then
          ram_err := Format('Warning! The data size (%d bytes) is greater than maximum allowed (%d bytes)',
            [u, ram_size]);
      end;

      RegEx := TRegEx.Create(REGEX_FLASH);
      M := RegEx.Matches(Line);

      u := M.Item[0].Groups[1].Value.ToInteger + M.Item[0].Groups[2]
        .Value.ToInteger;
      Perc := 100 / (flash_size / u);

      Writeln(Format('FLASH: [%s]%6.1f%% (used %d bytes from %d bytes)',
          [PercentToSymbol(Perc), Perc, u, flash_size], FloatFormat));

      if ram_err <> '' then
        SendMsg(mWarning, ram_err);

      if flash_size < u then
      begin
        SendMsg(mError, Format('Error: The program size (%d bytes) is greater than maximum allowed (%d bytes)',
            [u, flash_size]));
      end;
    except
      SendMsg(mError, 'Error');
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

procedure TfrmMain.SendMsg(t: TTypeMsg; msg: string);
var
  s: string;
begin
  case t of
    mWarning:
      s := FG_YELLOW + msg + FG_END;
    mError:
      s := FG_RED + msg + FG_END;
    mOk:
      s := FG_GREEN + msg + FG_END;
    mQuest:
      s := FG_BLUE + msg + FG_END;
    mInfo:
      s := FG_Cyan + msg + FG_END;
  else
    s := msg;
  end;
  Writeln(s);
end;

end.

