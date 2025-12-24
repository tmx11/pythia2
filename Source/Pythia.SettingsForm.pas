unit Pythia.SettingsForm;

interface

uses
  Winapi.Windows, Winapi.Messages, Winapi.ShellAPI,
  System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls;

type
  TSettingsForm = class(TForm)
    PageControl: TPageControl;
    TabAPI: TTabSheet;
    LabelOpenAI: TLabel;
    LabelAnthropic: TLabel;
    EditOpenAIKey: TEdit;
    EditAnthropicKey: TEdit;
    ButtonOK: TButton;
    ButtonCancel: TButton;
    LabelInfo: TLabel;
    PanelButtons: TPanel;
    LabelConfigPath: TLabel;
    procedure FormCreate(Sender: TObject);
    procedure ButtonOKClick(Sender: TObject);
    procedure ButtonCancelClick(Sender: TObject);
    procedure LabelConfigPathClick(Sender: TObject);
  private
    procedure LoadSettings;
    procedure SaveSettings;
  public
    class function Execute: Boolean;
  end;

implementation

uses
  Pythia.Config;

{$R *.dfm}

class function TSettingsForm.Execute: Boolean;
var
  Form: TSettingsForm;
begin
  Form := TSettingsForm.Create(nil);
  try
    Result := Form.ShowModal = mrOk;
  finally
    Form.Free;
  end;
end;

procedure TSettingsForm.FormCreate(Sender: TObject);
var
  ConfigPath: string;
begin
  Caption := 'Pythia Settings';
  ClientWidth := 720;
  ClientHeight := 520;
  Position := poOwnerFormCenter;
  BorderStyle := bsSizeable;  // Allow resizing
  
  // Setup clickable config path label
  ConfigPath := TPythiaConfig.GetConfigPath;
  LabelConfigPath.Caption := 'Config file: ' + ConfigPath;
  LabelConfigPath.Cursor := crHandPoint;
  LabelConfigPath.Font.Color := clBlue;
  LabelConfigPath.Font.Style := [fsUnderline];
  LabelConfigPath.Hint := 'Click to open config file';
  LabelConfigPath.ShowHint := True;
  
  LoadSettings;
end;

procedure TSettingsForm.LoadSettings;
begin
  EditOpenAIKey.Text := TPythiaConfig.GetOpenAIKey;
  EditAnthropicKey.Text := TPythiaConfig.GetAnthropicKey;
  
  // Show keys as plain text
  EditOpenAIKey.PasswordChar := #0;
  EditAnthropicKey.PasswordChar := #0;
end;

procedure TSettingsForm.SaveSettings;
begin
  TPythiaConfig.SetOpenAIKey(EditOpenAIKey.Text);
  TPythiaConfig.SetAnthropicKey(EditAnthropicKey.Text);
end;

procedure TSettingsForm.ButtonOKClick(Sender: TObject);
begin
  SaveSettings;
  ModalResult := mrOk;
end;

procedure TSettingsForm.ButtonCancelClick(Sender: TObject);
begin
  ModalResult := mrCancel;
end;

procedure TSettingsForm.LabelConfigPathClick(Sender: TObject);
var
  ConfigPath: string;
begin
  ConfigPath := TPythiaConfig.GetConfigPath;
  if FileExists(ConfigPath) then
    ShellExecute(0, 'open', PChar(ConfigPath), nil, nil, SW_SHOW)
  else
    ShowMessage('Config file not found: ' + ConfigPath);
end;

end.
