unit main;

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
  Vcl.StdCtrls,
  NativeXML,
  XSuperObject,
  XSuperJSON;

type
  TForm8 = class(TForm)
    Button1: TButton;
    OpenDialog1: TOpenDialog;
    SaveDialog1: TSaveDialog;
    procedure Button1Click(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  Form8: TForm8;

implementation

{$R *.dfm}

procedure TForm8.Button1Click(Sender: TObject);
var
  i, i2: Integer;
  So: ISuperObject;
  XMLDoc: TNativeXml;
  Node_Device, Node_Dname: TsdNodeList;
  name: string;
  flash, ram: Integer;
begin

  if not OpenDialog1.Execute then
    Exit;

  XMLDoc := TNativeXml.Create(nil);
  Node_Device := TsdNodeList.Create;
  Node_Dname := TsdNodeList.Create;
  So := TSuperObject.Create;
  try
    try
      XMLDoc.LoadFromFile(OpenDialog1.FileName);

      if Assigned(XMLDoc.Root) then
      begin
        XMLDoc.Root.FindNodes('device', Node_Device);
        if XMLDoc.IsEmpty then
          raise Exception.Create('Пустой XML! Работа прервана!');

        for i := 0 to Node_Device.Count - 1 do
        begin
          if Node_Device.Items[i].NodeByName('Dname') <> nil then
          begin
            name := '';
            flash := -1;
            ram := -1;
            name := Node_Device.Items[i].NodeByName('Dname').Value;
            Node_Device.Items[i].FindNodes('at:memory', Node_Dname);
            for i2 := 0 to Node_Dname.Count - 1 do
            begin
              if Node_Dname.Items[i2].AttributeByName['type'].Value = 'flash' then
                flash := Node_Dname.Items[i2].AttributeByName['size'].ValueAsInteger
              else if Node_Dname.Items[i2].AttributeByName['type'].Value = 'ram' then
                ram := Node_Dname.Items[i2].AttributeByName['size'].ValueAsInteger
            end;

            if name = '' then
              Continue;

            if ram <> -1 then
              So.O[name].i['ram_size'] := ram;
            if flash <> -1 then
              So.O[name].i['flash_size'] := flash;
          end;
        end;
        if SaveDialog1.Execute then
          So.SaveTo(SaveDialog1.FileName + '.json');
      end;
    except
    end;
  finally
    XMLDoc.Free;
    Node_Device.Free;
    Node_Dname.Free;
  end;
end;

end.

