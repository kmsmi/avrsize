program avrsize;

{$IFNDEF DEBUG}
  {$WEAKLINKRTTI ON}        // если вам не нужны новые возможности RTTI!
  {$RTTI EXPLICIT METHODS([]) FIELDS([]) PROPERTIES([])}    // если вам не нужны новые возможности RTTI!
{$ENDIF}

uses
  Winapi.Windows,
  Vcl.Forms,
  main in 'main.pas' {frmMain};

{$IFNDEF DEBUG}
  {$SetPEFlags IMAGE_FILE_RELOCS_STRIPPED} // Удаление из exe таблицы релокаций.
  {$SetPEFlags IMAGE_FILE_DEBUG_STRIPPED} //  Удаление из ехе Debug информации
  {$SetPEFlags IMAGE_FILE_LINE_NUMS_STRIPPED} // Удаление из exe информации о номерах строк
  {$SetPEFlags IMAGE_FILE_LOCAL_SYMS_STRIPPED} // Удаление local symbols
  //{$SetPEFlags IMAGE_FILE_REMOVABLE_RUN_FROM_SWAP} //При запуске exe с компакта, флэшки, других извлекаемых устройств, считать exe в свап и запустить оттуда. Полезно, если нужно запустить программу с компакта, а потом попросить вставить другой...
  //{$SetPEFlags IMAGE_FILE_NET_RUN_FROM_SWAP} // Аналогично предыдущей, только для сетевых дисков
  {$SetPEFlags IMAGE_FILE_EXECUTABLE_IMAGE}
{$ENDIF}

{$R avrsize_l.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmMain, frmMain);
  Application.Run;
end.

