unit Pythia.GitHub.Auth;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Net.HttpClient,
  System.Net.URLClient, System.IniFiles, Vcl.Dialogs, Vcl.Forms;

type
  TGitHubAuthStatus = (asNotAuthenticated, asAuthenticating, asAuthenticated, asError);

  TGitHubAuthResult = record
    Success: Boolean;
    Token: string;
    Username: string;
    ErrorMessage: string;
  end;

  TGitHubCopilotAuth = class
  private
    class var FAuthToken: string;
    class var FUsername: string;
    class var FStatus: TGitHubAuthStatus;
  public
    // GitHub OAuth Device Flow - matches VS Code Copilot
    class function StartDeviceFlow(out UserCode: string; out VerificationUri: string): Boolean;
    class function PollForToken(const DeviceCode: string): TGitHubAuthResult;
    class function GetAuthToken: string;
    class function GetUsername: string;
    class function IsAuthenticated: Boolean;
    class function GetStatus: TGitHubAuthStatus;
    class procedure ClearAuth;
    class procedure LoadCachedToken;
    class procedure SaveToken(const AToken, AUsername: string);
  end;

const
  // GitHub Copilot OAuth client ID (public - same as VS Code)
  GITHUB_CLIENT_ID = 'Iv1.b507a08c87ecfe98';
  GITHUB_DEVICE_CODE_URL = 'https://github.com/login/device/code';
  GITHUB_TOKEN_URL = 'https://github.com/login/oauth/access_token';
  GITHUB_USER_URL = 'https://api.github.com/user';

implementation

uses
  Pythia.Config;

{ TGitHubCopilotAuth }

class function TGitHubCopilotAuth.StartDeviceFlow(out UserCode, VerificationUri: string): Boolean;
var
  HttpClient: THTTPClient;
  Response: IHTTPResponse;
  RequestBody: TStringStream;
  ResponseJSON: TJSONObject;
begin
  Result := False;
  FStatus := asAuthenticating;
  
  HttpClient := THTTPClient.Create;
  try
    // Build request body: client_id + scope
    RequestBody := TStringStream.Create('client_id=' + GITHUB_CLIENT_ID + '&scope=', TEncoding.UTF8);
    try
      HttpClient.ContentType := 'application/x-www-form-urlencoded';
      HttpClient.Accept := 'application/json';
      
      Response := HttpClient.Post(GITHUB_DEVICE_CODE_URL, RequestBody);
      
      if Response.StatusCode = 200 then
      begin
        ResponseJSON := TJSONObject.ParseJSONValue(Response.ContentAsString) as TJSONObject;
        try
          if Assigned(ResponseJSON) then
          begin
            UserCode := ResponseJSON.GetValue<string>('user_code');
            VerificationUri := ResponseJSON.GetValue<string>('verification_uri');
            // Also get device_code for polling
            Result := True;
          end;
        finally
          ResponseJSON.Free;
        end;
      end;
    finally
      RequestBody.Free;
    end;
  finally
    HttpClient.Free;
  end;
end;

class function TGitHubCopilotAuth.PollForToken(const DeviceCode: string): TGitHubAuthResult;
var
  HttpClient: THTTPClient;
  Response: IHTTPResponse;
  RequestBody: TStringStream;
  ResponseJSON: TJSONObject;
  MaxAttempts, Attempt: Integer;
begin
  Result.Success := False;
  Result.Token := '';
  Result.Username := '';
  Result.ErrorMessage := '';
  
  HttpClient := THTTPClient.Create;
  try
    MaxAttempts := 60; // Poll for up to 5 minutes (5 second intervals)
    
    for Attempt := 1 to MaxAttempts do
    begin
      RequestBody := TStringStream.Create(
        'client_id=' + GITHUB_CLIENT_ID + 
        '&device_code=' + DeviceCode +
        '&grant_type=urn:ietf:params:oauth:grant-type:device_code',
        TEncoding.UTF8
      );
      try
        HttpClient.ContentType := 'application/x-www-form-urlencoded';
        HttpClient.Accept := 'application/json';
        
        Response := HttpClient.Post(GITHUB_TOKEN_URL, RequestBody);
        
        if Response.StatusCode = 200 then
        begin
          ResponseJSON := TJSONObject.ParseJSONValue(Response.ContentAsString) as TJSONObject;
          try
            if Assigned(ResponseJSON) then
            begin
              // Check for access_token
              if ResponseJSON.TryGetValue<string>('access_token', Result.Token) then
              begin
                FAuthToken := Result.Token;
                FStatus := asAuthenticated;
                
                // Get username
                Result.Username := GetUsername;
                Result.Success := True;
                
                // Save to config
                SaveToken(Result.Token, Result.Username);
                Exit;
              end
              else if ResponseJSON.TryGetValue<string>('error', Result.ErrorMessage) then
              begin
                // authorization_pending = keep waiting
                if Result.ErrorMessage = 'authorization_pending' then
                begin
                  Sleep(5000); // Wait 5 seconds before next poll
                  Continue;
                end
                else if Result.ErrorMessage = 'slow_down' then
                begin
                  Sleep(10000); // Wait longer
                  Continue;
                end
                else
                begin
                  // access_denied, expired_token, etc.
                  FStatus := asError;
                  Exit;
                end;
              end;
            end;
          finally
            ResponseJSON.Free;
          end;
        end;
      finally
        RequestBody.Free;
      end;
    end;
    
    // Timeout
    Result.ErrorMessage := 'Authentication timed out';
    FStatus := asError;
  finally
    HttpClient.Free;
  end;
end;

class function TGitHubCopilotAuth.GetAuthToken: string;
begin
  if FAuthToken = '' then
    LoadCachedToken;
  Result := FAuthToken;
end;

class function TGitHubCopilotAuth.GetUsername: string;
var
  HttpClient: THTTPClient;
  Response: IHTTPResponse;
  ResponseJSON: TJSONObject;
begin
  Result := '';
  
  if FAuthToken = '' then
    Exit;
    
  HttpClient := THTTPClient.Create;
  try
    HttpClient.CustomHeaders['Authorization'] := 'Bearer ' + FAuthToken;
    HttpClient.Accept := 'application/json';
    
    Response := HttpClient.Get(GITHUB_USER_URL);
    
    if Response.StatusCode = 200 then
    begin
      ResponseJSON := TJSONObject.ParseJSONValue(Response.ContentAsString) as TJSONObject;
      try
        if Assigned(ResponseJSON) then
          ResponseJSON.TryGetValue<string>('login', Result);
      finally
        ResponseJSON.Free;
      end;
    end;
  finally
    HttpClient.Free;
  end;
  
  FUsername := Result;
end;

class function TGitHubCopilotAuth.IsAuthenticated: Boolean;
begin
  if FAuthToken = '' then
    LoadCachedToken;
  Result := (FAuthToken <> '') and (FStatus = asAuthenticated);
end;

class function TGitHubCopilotAuth.GetStatus: TGitHubAuthStatus;
begin
  Result := FStatus;
end;

class procedure TGitHubCopilotAuth.ClearAuth;
var
  Ini: TIniFile;
begin
  FAuthToken := '';
  FUsername := '';
  FStatus := asNotAuthenticated;
  
  Ini := TIniFile.Create(TPythiaConfig.GetConfigPath);
  try
    Ini.DeleteKey('GitHub', 'Token');
    Ini.DeleteKey('GitHub', 'Username');
  finally
    Ini.Free;
  end;
end;

class procedure TGitHubCopilotAuth.LoadCachedToken;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(TPythiaConfig.GetConfigPath);
  try
    FAuthToken := Ini.ReadString('GitHub', 'Token', '');
    FUsername := Ini.ReadString('GitHub', 'Username', '');
    
    if FAuthToken <> '' then
      FStatus := asAuthenticated
    else
      FStatus := asNotAuthenticated;
  finally
    Ini.Free;
  end;
end;

class procedure TGitHubCopilotAuth.SaveToken(const AToken, AUsername: string);
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(TPythiaConfig.GetConfigPath);
  try
    Ini.WriteString('GitHub', 'Token', AToken);
    Ini.WriteString('GitHub', 'Username', AUsername);
  finally
    Ini.Free;
  end;
  
  FAuthToken := AToken;
  FUsername := AUsername;
  FStatus := asAuthenticated;
end;

end.
