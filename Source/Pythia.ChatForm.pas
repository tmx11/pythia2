unit Pythia.ChatForm;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Variants, System.Classes,
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs,
  Vcl.StdCtrls, Vcl.ExtCtrls, Vcl.ComCtrls,
  Pythia.Context;

type
  TChatMessage = record
    Role: string;     // 'user' or 'assistant'
    Content: string;
    Timestamp: TDateTime;
  end;

  TChatWindow = class(TForm)
    PanelTop: TPanel;
    PanelBottom: TPanel;
    PanelChat: TPanel;
    MemoChat: TRichEdit;
    MemoInput: TMemo;
    ButtonSend: TButton;
    ButtonClear: TButton;
    ComboModel: TComboBox;
    LabelModel: TLabel;
    ButtonSettings: TButton;
    ButtonTestConnection: TButton;
    StatusBar: TStatusBar;
    SplitterInput: TSplitter;
    SplitterContext: TSplitter;
    PanelContext: TPanel;
    CheckAutoContext: TCheckBox;
    LabelContext: TEdit;
    ButtonRefreshContext: TButton;
    MemoContextInfo: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure ButtonSendClick(Sender: TObject);
    procedure ButtonClearClick(Sender: TObject);
    procedure ButtonSettingsClick(Sender: TObject);
    procedure MemoInputKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure ButtonTestConnectionClick(Sender: TObject);
    procedure CheckAutoContextClick(Sender: TObject);
    procedure ButtonRefreshContextClick(Sender: TObject);
  private
    FMessages: TArray<TChatMessage>;
    FIsProcessing: Boolean;
    FTotalTokensUsed: Integer;
    FRequestCount: Integer;
    FContextProvider: IContextProvider;
    FLastContext: TArray<TContextItem>;
    FAutoContext: Boolean;
    procedure AddMessage(const ARole, AContent: string);
    procedure DisplayMessage(const AMessage: TChatMessage);
    procedure SendMessageToAI;
    procedure UpdateUI;
    procedure UpdateStatusBar;
    procedure TestConnection;
    procedure InitializeContextProvider;
    procedure UpdateContextDisplay;
    function GatherContext: TArray<TContextItem>;
    procedure DisplayContextReferences(const Context: TArray<TContextItem>);
  public
    { Public declarations }
  end;

var
  ChatWindow: TChatWindow;

implementation

uses
  System.DateUtils,
  Pythia.AI.Client,
  Pythia.Config,
  Pythia.GitHub.Auth,
  Pythia.SettingsForm;

{$R *.dfm}

procedure TChatWindow.FormCreate(Sender: TObject);
begin
  Caption := 'Pythia - AI Chat Assistant';
  Width := 600;
  Height := 700;
  Position := poScreenCenter;
  
  FIsProcessing := False;
  FTotalTokensUsed := 0;
  FRequestCount := 0;
  FAutoContext := True;
  SetLength(FMessages, 0);
  SetLength(FLastContext, 0);
  
  // Configure chat display
  MemoChat.ReadOnly := True;
  MemoChat.Color := clWhite;
  MemoChat.Font.Name := 'Segoe UI';
  MemoChat.Font.Size := 10;
  MemoChat.ScrollBars := ssVertical;
  MemoChat.WordWrap := True;
  
  // Configure input
  MemoInput.Font.Name := 'Segoe UI';
  MemoInput.Font.Size := 10;
  MemoInput.ScrollBars := ssVertical;
  MemoInput.WordWrap := True;
  MemoInput.Height := 80;
  
  // Configure context display
  MemoContextInfo.ReadOnly := True;
  MemoContextInfo.Color := cl3DLight;
  MemoContextInfo.Font.Name := 'Segoe UI';
  MemoContextInfo.Font.Size := 8;
  MemoContextInfo.ScrollBars := ssVertical;
  MemoContextInfo.WordWrap := True;
  
  CheckAutoContext.Checked := FAutoContext;
  
  // Setup model selection
  ComboModel.Items.Clear;
  ComboModel.Items.Add('GitHub Copilot: GPT-4');
  ComboModel.Items.Add('GitHub Copilot: GPT-3.5 Turbo');
  ComboModel.Items.Add('GPT-4');
  ComboModel.Items.Add('GPT-3.5 Turbo');
  ComboModel.Items.Add('Claude 3.5 Sonnet');
  ComboModel.Items.Add('Claude 3 Opus');
  ComboModel.ItemIndex := 0;
  
  // Initialize context provider
  InitializeContextProvider;
  UpdateContextDisplay;
  
  StatusBar.SimpleText := 'Ready';
  
  // Welcome message
  AddMessage('assistant', 'Hello! I''m Pythia, your AI coding assistant for Delphi. How can I help you today?');
end;

procedure TChatWindow.FormDestroy(Sender: TObject);
begin
  SetLength(FMessages, 0);
end;

procedure TChatWindow.AddMessage(const ARole, AContent: string);
var
  Msg: TChatMessage;
begin
  Msg.Role := ARole;
  Msg.Content := AContent;
  Msg.Timestamp := Now;
  
  SetLength(FMessages, Length(FMessages) + 1);
  FMessages[High(FMessages)] := Msg;
  
  DisplayMessage(Msg);
end;

procedure TChatWindow.DisplayMessage(const AMessage: TChatMessage);
var
  TimeStr: string;
  Prefix: string;
begin
  TimeStr := FormatDateTime('hh:nn', AMessage.Timestamp);
  
  if AMessage.Role = 'user' then
  begin
    Prefix := 'You';
  end
  else
  begin
    Prefix := 'Pythia';
  end;
  
  MemoChat.SelStart := Length(MemoChat.Text);
  
  // Add timestamp and role
  MemoChat.SelAttributes.Style := [fsBold];
  MemoChat.SelAttributes.Color := clNavy;
  MemoChat.Lines.Add(Format('[%s] %s:', [TimeStr, Prefix]));
  
  // Add message content
  MemoChat.SelAttributes.Style := [];
  MemoChat.SelAttributes.Color := clBlack;
  MemoChat.Lines.Add(AMessage.Content);
  MemoChat.Lines.Add('');
  
  // Scroll to bottom
  SendMessage(MemoChat.Handle, WM_VSCROLL, SB_BOTTOM, 0);
end;

procedure TChatWindow.ButtonSendClick(Sender: TObject);
begin
  SendMessageToAI;
end;

procedure TChatWindow.SendMessageToAI;
var
  UserInput: string;
  Response: string;
  Context: TArray<TContextItem>;
  ContextStr: string;
begin
  if FIsProcessing then
  begin
    ShowMessage('Please wait for the current request to complete.');
    Exit;
  end;
  
  UserInput := Trim(MemoInput.Text);
  if UserInput = '' then
    Exit;
  
  // Add user message
  AddMessage('user', UserInput);
  MemoInput.Clear;
  
  FIsProcessing := True;
  UpdateUI;
  
  try
    StatusBar.SimpleText := 'Gathering context...';
    Application.ProcessMessages;
    
    // Gather workspace context
    Context := GatherContext;
    
    StatusBar.SimpleText := 'Processing request...';
    Application.ProcessMessages;
    
    // Format context for AI
    if Length(Context) > 0 then
    begin
      ContextStr := (FContextProvider as TBaseContextProvider).FormatContextForAI(Context);
      
      // Prepend context to messages (as a temporary system-level context)
      // Note: Will modify AI.Client to accept context parameter properly
      Response := TPythiaAIClient.SendMessageWithContext(FMessages, ComboModel.Text, ContextStr);
    end
    else
    begin
      Response := TPythiaAIClient.SendMessage(FMessages, ComboModel.Text);
    end;
    
    // Add AI response
    if Response <> '' then
    begin
      AddMessage('assistant', Response);
      
      // Display what context was used
      if Length(Context) > 0 then
        DisplayContextReferences(Context);
      
      Inc(FRequestCount);
      // Estimate tokens (rough: 1 token ≈ 4 chars)
      Inc(FTotalTokensUsed, (Length(UserInput) + Length(Response)) div 4);
    end
    else
      AddMessage('assistant', 'Sorry, I encountered an error processing your request.');
      
  finally
    FIsProcessing := False;
    UpdateStatusBar;
    UpdateUI;
  end;
end;

procedure TChatWindow.ButtonClearClick(Sender: TObject);
begin
  if MessageDlg('Clear chat history?', mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    SetLength(FMessages, 0);
    MemoChat.Clear;
    StatusBar.SimpleText := 'Chat cleared';
  end;
end;

procedure TChatWindow.ButtonSettingsClick(Sender: TObject);
begin
  TSettingsForm.Execute;
end;

procedure TChatWindow.MemoInputKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  // Enter without Shift = Send message
  if (Key = VK_RETURN) and (Shift = []) then
  begin
    Key := 0; // Suppress the Enter key
    SendMessageToAI;
  end;
  // Shift+Enter = New line (default behavior, don't intercept)
end;

procedure TChatWindow.UpdateUI;
begin
  ButtonSend.Enabled := not FIsProcessing and (Trim(MemoInput.Text) <> '');
  MemoInput.Enabled := not FIsProcessing;
  ComboModel.Enabled := not FIsProcessing;
end;

procedure TChatWindow.UpdateStatusBar;
var
  APIKey: string;
  Provider: string;
  IsAuthenticated: Boolean;
begin
  // Determine provider from model selection
  if Pos('COPILOT', UpperCase(ComboModel.Text)) > 0 then
  begin
    Provider := 'GitHub Copilot';
    IsAuthenticated := TGitHubCopilotAuth.IsAuthenticated;
  end
  else if Pos('Claude', ComboModel.Text) > 0 then
  begin
    Provider := 'Anthropic';
    APIKey := TPythiaConfig.GetAnthropicKey;
    IsAuthenticated := APIKey <> '';
  end
  else
  begin
    Provider := 'OpenAI';
    APIKey := TPythiaConfig.GetOpenAIKey;
    IsAuthenticated := APIKey <> '';
  end;
  
  if IsAuthenticated then
    StatusBar.SimpleText := Format('Connected to %s | Model: %s | Requests: %d | Est. Tokens: %d',
      [Provider, ComboModel.Text, FRequestCount, FTotalTokensUsed])
  else
    StatusBar.SimpleText := 'No authentication - Click Settings to configure';
end;

procedure TChatWindow.TestConnection;
var
  APIKey: string;
  Provider: string;
  Endpoint: string;
  TestMessages: TArray<TChatMessage>;
  Response: string;
  Msg: string;
  IsAuthenticated: Boolean;
begin
  // Check if we have authentication for the selected model
  if Pos('COPILOT', UpperCase(ComboModel.Text)) > 0 then
  begin
    IsAuthenticated := TGitHubCopilotAuth.IsAuthenticated;
    Provider := 'GitHub Copilot';
    Endpoint := 'https://api.githubcopilot.com/chat/completions';
    APIKey := 'GitHub OAuth'; // Display text only
  end
  else if Pos('Claude', ComboModel.Text) > 0 then
  begin
    APIKey := TPythiaConfig.GetAnthropicKey;
    Provider := 'Anthropic';
    Endpoint := 'https://api.anthropic.com/v1/messages';
    IsAuthenticated := APIKey <> '';
  end
  else
  begin
    APIKey := TPythiaConfig.GetOpenAIKey;
    Provider := 'OpenAI';
    Endpoint := 'https://api.openai.com/v1/chat/completions';
    IsAuthenticated := APIKey <> '';
  end;
  
  if not IsAuthenticated then
  begin
    StatusBar.SimpleText := 'Not authenticated - Configure in Settings';
    if Pos('COPILOT', UpperCase(ComboModel.Text)) > 0 then
    begin
      Msg := Format('CONNECTION TEST%s%s' +
        '----------------------%s' +
        'Provider: %s%s' +
        'Endpoint: %s%s' +
        'Model: %s%s' +
        'Status: Not signed in with GitHub%s%s' +
        'Please click Settings button to sign in with GitHub.',
        [#13#10, #13#10, #13#10, Provider, #13#10, Endpoint, #13#10, ComboModel.Text, #13#10, #13#10]);
    end
    else
    begin
      Msg := Format('CONNECTION TEST%s%s' +
        '----------------------%s' +
        'Provider: %s%s' +
        'Endpoint: %s%s' +
        'Model: %s%s' +
        'API Key: NOT CONFIGURED%s' +
        'Status: Authentication Required%s%s' +
        'Please click Settings button to configure your API key.',
        [#13#10, #13#10, #13#10, Provider, #13#10, Endpoint, #13#10, ComboModel.Text, #13#10, #13#10, #13#10, #13#10]);
    end;
    AddMessage('assistant', Msg);
    Exit;
  end;
  
  // Show connection details
  if Pos('COPILOT', UpperCase(ComboModel.Text)) > 0 then
  begin
    Msg := Format('CONNECTION TEST%s%s' +
      '━━━━━━━━━━━━━━━━━━━━━━%s' +
      'Provider: %s%s' +
      'Endpoint: %s%s' +
      'Model: %s%s' +
      'Authentication: GitHub OAuth%s' +
      'Testing connection...',
      [#13#10, #13#10, #13#10, Provider, #13#10, Endpoint, #13#10, ComboModel.Text, #13#10, #13#10]);
  end
  else
  begin
    Msg := Format('CONNECTION TEST%s%s' +
      '━━━━━━━━━━━━━━━━━━━━━━%s' +
      'Provider: %s%s' +
      'Endpoint: %s%s' +
      'Model: %s%s' +
      'API Key: %s...%s (length: %d)%s' +
      'Testing authentication...',
      [#13#10, #13#10, #13#10, Provider, #13#10, Endpoint, #13#10, ComboModel.Text, #13#10, 
       Copy(APIKey, 1, 20), Copy(APIKey, Length(APIKey) - 4, 5), Length(APIKey), #13#10]);
  end;
  AddMessage('assistant', Msg);
  
  // Make actual test API call
  SetLength(TestMessages, 1);
  TestMessages[0].Role := 'user';
  TestMessages[0].Content := 'Say "Connection successful" if you receive this.';
  TestMessages[0].Timestamp := Now;
  
  try
    StatusBar.SimpleText := 'Testing connection...';
    Application.ProcessMessages;
    
    Response := TPythiaAIClient.SendMessage(TestMessages, ComboModel.Text);
    
    if Response <> '' then
    begin
      AddMessage('assistant', Format('Authentication Successful%s%sAPI Response: %s', 
        [#13#10, #13#10, Response]));
      UpdateStatusBar;
    end;
  except
    on E: Exception do
    begin
      AddMessage('assistant', Format('✗ Authentication Failed%s%sError: %s', 
        [#13#10, #13#10, E.Message]));
      StatusBar.SimpleText := '✗ Connection failed - Check error above';
    end;
  end;
end;

procedure TChatWindow.ButtonTestConnectionClick(Sender: TObject);
begin
  TestConnection;
end;

procedure TChatWindow.InitializeContextProvider;
begin
  // Try IDE provider first, fall back to standalone
  FContextProvider := TIDEContextProvider.Create;
  if not FContextProvider.IsAvailable then
  begin
    // For standalone app, could pass project path from command line or settings
    FContextProvider := TStandaloneContextProvider.Create('');
  end;
end;

procedure TChatWindow.UpdateContextDisplay;
var
  Context: TArray<TContextItem>;
  TotalTokens: Integer;
  FileCount: Integer;
  Item: TContextItem;
  StatusText: string;
begin
  if not Assigned(FContextProvider) then
  begin
    LabelContext.Text := 'Context: Provider not initialized';
    Exit;
  end;
    
  try
    Context := (FContextProvider as TBaseContextProvider).GatherContext(False); // Don't include full project list for display
    
    TotalTokens := 0;
    FileCount := 0;
    for Item in Context do
    begin
      Inc(TotalTokens, Item.TokenCount);
      if (Item.ItemType = ctCurrentFile) or (Item.ItemType = ctSelection) then
        Inc(FileCount);
    end;
    
    if FileCount > 0 then
      StatusText := Format('Context: %d file(s), ~%d tokens', [FileCount, TotalTokens])
    else
      StatusText := 'Context: No file active';
      
    LabelContext.Text := StatusText;
    
    // Update detailed context info
    MemoContextInfo.Lines.Clear;
    
    // Always show provider type first
    if FContextProvider is TIDEContextProvider then
      MemoContextInfo.Lines.Add('Provider: IDE Context (ToolsAPI)')
    else if FContextProvider is TStandaloneContextProvider then
      MemoContextInfo.Lines.Add('Provider: Standalone (No IDE detected)')
    else
      MemoContextInfo.Lines.Add('Provider: ' + TObject(FContextProvider).ClassName);
    MemoContextInfo.Lines.Add('');
    
    if Length(Context) > 0 then
    begin
      MemoContextInfo.Lines.Add('Available Context:');
      for Item in Context do
      begin
        case Item.ItemType of
          ctCurrentFile:
            MemoContextInfo.Lines.Add(Format('  File: %s (%d tokens)', 
              [ExtractFileName(Item.FilePath), Item.TokenCount]));
          ctSelection:
            MemoContextInfo.Lines.Add(Format('  Selection: Lines %d-%d (%d tokens)', 
              [Item.LineStart, Item.LineEnd, Item.TokenCount]));
        end;
      end;
    end
    else
    begin
      MemoContextInfo.Lines.Add('No context available');
      MemoContextInfo.Lines.Add('');
      MemoContextInfo.Lines.Add('IsAvailable: ' + BoolToStr(FContextProvider.IsAvailable, True));
    end;
  except
    on E: Exception do
    begin
      LabelContext.Text := 'Context: Error - ' + E.Message;
      MemoContextInfo.Lines.Clear;
      MemoContextInfo.Lines.Add('Error gathering context:');
      MemoContextInfo.Lines.Add(E.ClassName + ': ' + E.Message);
    end;
  end;
end;

function TChatWindow.GatherContext: TArray<TContextItem>;
begin
  if not FAutoContext or not Assigned(FContextProvider) then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  
  Result := (FContextProvider as TBaseContextProvider).GatherContext(False);
  FLastContext := Result;
  
  // Apply token limits
  (FContextProvider as TBaseContextProvider).PrioritizeAndTruncate(Result, 6000); // Leave room for conversation
end;

procedure TChatWindow.DisplayContextReferences(const Context: TArray<TContextItem>);
var
  Item: TContextItem;
  RefText: string;
begin
  if Length(Context) = 0 then
    Exit;
    
  RefText := #13#10 + 'Used context:';
  for Item in Context do
  begin
    case Item.ItemType of
      ctCurrentFile:
        RefText := RefText + #13#10 + Format('  File: %s', [ExtractFileName(Item.FilePath)]);
      ctSelection:
        RefText := RefText + #13#10 + Format('  Selection: %s (lines %d-%d)', 
          [ExtractFileName(Item.FilePath), Item.LineStart, Item.LineEnd]);
      ctProjectFile:
        RefText := RefText + #13#10 + Format('  Project: %s', [ExtractFileName(Item.FilePath)]);
    end;
  end;
  
  // Add to chat display
  MemoChat.SelAttributes.Style := [fsItalic];
  MemoChat.SelAttributes.Color := clGray;
  MemoChat.Lines.Add(RefText);
  MemoChat.SelAttributes.Style := [];
  MemoChat.SelAttributes.Color := clBlack;
  MemoChat.Lines.Add('');
end;

procedure TChatWindow.CheckAutoContextClick(Sender: TObject);
begin
  FAutoContext := CheckAutoContext.Checked;
  UpdateContextDisplay;
end;

procedure TChatWindow.ButtonRefreshContextClick(Sender: TObject);
begin
  UpdateContextDisplay;
end;

end.
