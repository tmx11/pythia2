unit Pythia.Context;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  ToolsAPI;

type
  TContextItemType = (
    ctCurrentFile,    // Active file in editor
    ctSelection,      // Selected text
    ctProjectFile,    // File from project (metadata only)
    ctRelatedFile     // Related file (full content)
  );

  TContextItem = record
    ItemType: TContextItemType;
    FilePath: string;
    Content: string;
    LineStart: Integer;
    LineEnd: Integer;
    TokenCount: Integer;
    
    class function Create(AType: TContextItemType; const AFilePath, AContent: string;
      ALineStart: Integer = 0; ALineEnd: Integer = 0): TContextItem; static;
  end;

  IContextProvider = interface
    ['{B8E9F7A1-2C3D-4E5F-8A9B-1C2D3E4F5A6B}']
    function GetCurrentFile: TContextItem;
    function GetSelection: TContextItem;
    function GetProjectFiles: TArray<string>;
    function GetRelatedFiles(const FileName: string): TArray<string>;
    function EstimateTokens(const Text: string): Integer;
    function IsAvailable: Boolean;
    // File editing methods
    function ReplaceFileContent(const FileName, NewContent: string): Boolean;
    function InsertTextAt(const FileName: string; Line, Column: Integer; const Text: string): Boolean;
    function ReplaceLines(const FileName: string; StartLine, EndLine: Integer; const NewText: string): Boolean;
  end;

  TBaseContextProvider = class(TInterfacedObject, IContextProvider)
  protected
    function GetCurrentFile: TContextItem; virtual; abstract;
    function GetSelection: TContextItem; virtual; abstract;
    function GetProjectFiles: TArray<string>; virtual; abstract;
    function GetRelatedFiles(const FileName: string): TArray<string>; virtual;
    function IsAvailable: Boolean; virtual; abstract;
    // File editing methods (virtual)
    function ReplaceFileContent(const FileName, NewContent: string): Boolean; virtual; abstract;
    function InsertTextAt(const FileName: string; Line, Column: Integer; const Text: string): Boolean; virtual; abstract;
    function ReplaceLines(const FileName: string; StartLine, EndLine: Integer; const NewText: string): Boolean; virtual; abstract;
  public
    function EstimateTokens(const Text: string): Integer;
    function GatherContext(AIncludeProject: Boolean = False): TArray<TContextItem>;
    function FormatContextForAI(const Context: TArray<TContextItem>): string;
    procedure PrioritizeAndTruncate(var Context: TArray<TContextItem>; MaxTokens: Integer);
  end;

  // IDE-based context provider using ToolsAPI
  TIDEContextProvider = class(TBaseContextProvider)
  protected
    function GetCurrentFile: TContextItem; override;
    function GetSelection: TContextItem; override;
    function GetProjectFiles: TArray<string>; override;
    function IsAvailable: Boolean; override;
    // File editing via IOTASourceEditor
    function ReplaceFileContent(const FileName, NewContent: string): Boolean; override;
    function InsertTextAt(const FileName: string; Line, Column: Integer; const Text: string): Boolean; override;
    function ReplaceLines(const FileName: string; StartLine, EndLine: Integer; const NewText: string): Boolean; override;
  end;

  // Standalone context provider using filesystem
  TStandaloneContextProvider = class(TBaseContextProvider)
  private
    FProjectPath: string;
    FProjectFiles: TArray<string>;
    procedure ParseProjectFile;
  protected
    function GetCurrentFile: TContextItem; override;
    function GetSelection: TContextItem; override;
    function GetProjectFiles: TArray<string>; override;
    function IsAvailable: Boolean; override;
    // File editing (stubs - not supported in standalone mode)
    function ReplaceFileContent(const FileName, NewContent: string): Boolean; override;
    function InsertTextAt(const FileName: string; Line, Column: Integer; const Text: string): Boolean; override;
    function ReplaceLines(const FileName: string; StartLine, EndLine: Integer; const NewText: string): Boolean; override;
  public
    constructor Create(const AProjectPath: string);
  end;

implementation

uses
  System.IOUtils,
  System.Math,
  Xml.XMLIntf,
  Xml.XMLDoc;

{ TContextItem }

class function TContextItem.Create(AType: TContextItemType; const AFilePath,
  AContent: string; ALineStart, ALineEnd: Integer): TContextItem;
begin
  Result.ItemType := AType;
  Result.FilePath := AFilePath;
  Result.Content := AContent;
  Result.LineStart := ALineStart;
  Result.LineEnd := ALineEnd;
  Result.TokenCount := 0; // Will be estimated later
end;

{ TBaseContextProvider }

function TBaseContextProvider.EstimateTokens(const Text: string): Integer;
begin
  // Rough estimate: 1 token ≈ 3 characters for code
  // This is conservative; actual tokenization depends on model
  Result := Max(1, Length(Text) div 3);
end;

function TBaseContextProvider.GatherContext(AIncludeProject: Boolean): TArray<TContextItem>;
var
  Items: TList<TContextItem>;
  CurrentFile, Selection: TContextItem;
  ProjectFiles: TArray<string>;
  ProjectFile: string;
begin
  Items := TList<TContextItem>.Create;
  try
    // Priority 1: Selection (if available)
    Selection := GetSelection;
    if Selection.Content <> '' then
    begin
      Selection.TokenCount := EstimateTokens(Selection.Content);
      Items.Add(Selection);
    end;

    // Priority 2: Current file
    CurrentFile := GetCurrentFile;
    if CurrentFile.Content <> '' then
    begin
      CurrentFile.TokenCount := EstimateTokens(CurrentFile.Content);
      Items.Add(CurrentFile);
    end;

    // Priority 3: Project file list (if requested)
    if AIncludeProject then
    begin
      ProjectFiles := GetProjectFiles;
      for ProjectFile in ProjectFiles do
      begin
        Items.Add(TContextItem.Create(ctProjectFile, ProjectFile, ''));
      end;
    end;

    Result := Items.ToArray;
  finally
    Items.Free;
  end;
end;

function TBaseContextProvider.FormatContextForAI(const Context: TArray<TContextItem>): string;
var
  Item: TContextItem;
  SB: TStringBuilder;
  FileExt: string;
begin
  SB := TStringBuilder.Create;
  try
    SB.AppendLine('## Workspace Context');
    SB.AppendLine;

    for Item in Context do
    begin
      case Item.ItemType of
        ctCurrentFile:
        begin
          FileExt := LowerCase(TPath.GetExtension(Item.FilePath));
          SB.AppendFormat('### Current File: %s', [TPath.GetFileName(Item.FilePath)]);
          SB.AppendLine;
          SB.AppendFormat('```%s', [Copy(FileExt, 2, MaxInt)]); // Remove leading dot
          SB.AppendLine;
          SB.Append(Item.Content);
          SB.AppendLine;
          SB.AppendLine('```');
          SB.AppendLine;
        end;

        ctSelection:
        begin
          SB.AppendFormat('### Selected Code (Lines %d-%d):', [Item.LineStart, Item.LineEnd]);
          SB.AppendLine;
          SB.AppendLine('```pascal');
          SB.Append(Item.Content);
          SB.AppendLine;
          SB.AppendLine('```');
          SB.AppendLine;
        end;

        ctProjectFile:
        begin
          if SB.ToString.IndexOf('### Project Files:') < 0 then
          begin
            SB.AppendLine('### Project Files:');
          end;
          SB.AppendFormat('- %s', [Item.FilePath]);
          SB.AppendLine;
        end;

        ctRelatedFile:
        begin
          SB.AppendFormat('### Related File: %s', [TPath.GetFileName(Item.FilePath)]);
          SB.AppendLine;
          SB.AppendLine('```pascal');
          SB.Append(Item.Content);
          SB.AppendLine;
          SB.AppendLine('```');
          SB.AppendLine;
        end;
      end;
    end;

    Result := SB.ToString;
  finally
    SB.Free;
  end;
end;

procedure TBaseContextProvider.PrioritizeAndTruncate(var Context: TArray<TContextItem>; MaxTokens: Integer);
var
  TotalTokens: Integer;
  Item: TContextItem;
  I: Integer;
begin
  // Calculate total tokens
  TotalTokens := 0;
  for Item in Context do
    Inc(TotalTokens, Item.TokenCount);

  // If under budget, no truncation needed
  if TotalTokens <= MaxTokens then
    Exit;

  // Remove project files first (lowest priority)
  I := High(Context);
  while (I >= 0) and (TotalTokens > MaxTokens) do
  begin
    if Context[I].ItemType = ctProjectFile then
    begin
      Dec(TotalTokens, Context[I].TokenCount);
      Delete(Context, I, 1);
    end;
    Dec(I);
  end;

  // Remove related files if still over budget
  I := High(Context);
  while (I >= 0) and (TotalTokens > MaxTokens) do
  begin
    if Context[I].ItemType = ctRelatedFile then
    begin
      Dec(TotalTokens, Context[I].TokenCount);
      Delete(Context, I, 1);
    end;
    Dec(I);
  end;

  // If still over budget, truncate current file content
  if TotalTokens > MaxTokens then
  begin
    for I := Low(Context) to High(Context) do
    begin
      if Context[I].ItemType = ctCurrentFile then
      begin
        // Keep only first 1000 lines
        Context[I].Content := Copy(Context[I].Content, 1, 
          Min(Length(Context[I].Content), 50000)); // ~50KB
        Context[I].TokenCount := EstimateTokens(Context[I].Content);
        Break;
      end;
    end;
  end;
end;

function TBaseContextProvider.GetRelatedFiles(const FileName: string): TArray<string>;
var
  BaseName, ImplFile: string;
begin
  // Find interface/implementation pairs
  SetLength(Result, 0);
  
  BaseName := TPath.GetFileNameWithoutExtension(FileName);
  
  // If this is a .pas file, no interface file
  // If this is a .dfm, look for .pas
  if SameText(TPath.GetExtension(FileName), '.dfm') then
  begin
    ImplFile := TPath.ChangeExtension(FileName, '.pas');
    if TFile.Exists(ImplFile) then
    begin
      SetLength(Result, 1);
      Result[0] := ImplFile;
    end;
  end;
end;

{ TIDEContextProvider }

function TIDEContextProvider.GetCurrentFile: TContextItem;
var
  ModuleServices: IOTAModuleServices;
  Module: IOTAModule;
  Editor: IOTASourceEditor;
  Reader: IOTAEditReader;
  Content: UTF8String;
  CharPos, ReadSize: Integer;
const
  BufferSize = 1024;
begin
  Result := TContextItem.Create(ctCurrentFile, '', '');
  
  if not Supports(BorlandIDEServices, IOTAModuleServices, ModuleServices) then
    Exit;

  Module := ModuleServices.CurrentModule;
  if not Assigned(Module) then
    Exit;

  if Module.GetModuleFileCount = 0 then
    Exit;

  Editor := Module.GetModuleFileEditor(0) as IOTASourceEditor;
  if not Assigned(Editor) then
    Exit;

  Result.FilePath := Editor.FileName;
  
  Reader := Editor.CreateReader;
  try
    SetLength(Content, BufferSize);
    CharPos := 0;
    repeat
      ReadSize := Reader.GetText(CharPos, PAnsiChar(Content) + CharPos, BufferSize);
      Inc(CharPos, ReadSize);
      if ReadSize = BufferSize then
        SetLength(Content, Length(Content) + BufferSize);
    until ReadSize < BufferSize;
    
    SetLength(Content, CharPos);
    Result.Content := string(Content);
  except
    Result.Content := '';
  end;
end;

function TIDEContextProvider.GetSelection: TContextItem;
var
  ModuleServices: IOTAModuleServices;
  Module: IOTAModule;
  Editor: IOTASourceEditor;
  EditView: IOTAEditView;
  Block: IOTAEditBlock;
  Reader: IOTAEditReader;
  StartPos, EndPos: TOTACharPos;
  SelectedText: UTF8String;
  CharPos, ReadSize: Integer;
const
  BufferSize = 1024;
begin
  Result := TContextItem.Create(ctSelection, '', '');
  
  if not Supports(BorlandIDEServices, IOTAModuleServices, ModuleServices) then
    Exit;

  Module := ModuleServices.CurrentModule;
  if not Assigned(Module) then
    Exit;

  if Module.GetModuleFileCount = 0 then
    Exit;

  Editor := Module.GetModuleFileEditor(0) as IOTASourceEditor;
  if not Assigned(Editor) or (Editor.GetEditViewCount = 0) then
    Exit;

  EditView := Editor.GetEditView(0);
  Block := EditView.Block;
  
  if not Block.IsValid then
    Exit;

  Result.FilePath := Editor.FileName;
  Result.LineStart := Block.StartingRow;
  Result.LineEnd := Block.EndingRow;
  
  StartPos.Line := Block.StartingRow;
  StartPos.CharIndex := Block.StartingColumn;
  EndPos.Line := Block.EndingRow;
  EndPos.CharIndex := Block.EndingColumn;
  
  // Read selected text
  Reader := Editor.CreateReader;
  try
    SetLength(SelectedText, EndPos.CharIndex - StartPos.CharIndex);
    CharPos := StartPos.CharIndex;
    ReadSize := Reader.GetText(CharPos, PAnsiChar(SelectedText), 
                                EndPos.CharIndex - StartPos.CharIndex);
    SetLength(SelectedText, ReadSize);
    Result.Content := string(SelectedText);
  except
    Result.Content := '';
  end;
end;

function TIDEContextProvider.GetProjectFiles: TArray<string>;
var
  ProjectGroup: IOTAProjectGroup;
  Project: IOTAProject;
  ModuleInfo: IOTAModuleInfo;
  I, J: Integer;
  Files: TList<string>;
begin
  Files := TList<string>.Create;
  try
    if Supports(BorlandIDEServices, IOTAModuleServices) then
    begin
      ProjectGroup := (BorlandIDEServices as IOTAModuleServices).MainProjectGroup;
      if Assigned(ProjectGroup) then
      begin
        for I := 0 to ProjectGroup.ProjectCount - 1 do
        begin
          Project := ProjectGroup.Projects[I];
          for J := 0 to Project.GetModuleCount - 1 do
          begin
            ModuleInfo := Project.GetModule(J);
            Files.Add(ModuleInfo.FileName);
          end;
        end;
      end;
    end;
    
    Result := Files.ToArray;
  finally
    Files.Free;
  end;
end;

function TIDEContextProvider.IsAvailable: Boolean;
begin
  Result := Assigned(BorlandIDEServices);
end;

function TIDEContextProvider.ReplaceFileContent(const FileName, NewContent: string): Boolean;
var
  ModuleServices: IOTAModuleServices;
  Module: IOTAModule;
  Editor: IOTASourceEditor;
  Writer: IOTAEditWriter;
  I: Integer;
  UTF8Content: UTF8String;
begin
  Result := False;
  
  if not Supports(BorlandIDEServices, IOTAModuleServices, ModuleServices) then
    Exit;

  // Find the open module for this file
  Module := nil;
  for I := 0 to ModuleServices.ModuleCount - 1 do
  begin
    if SameText(ModuleServices.Modules[I].FileName, FileName) then
    begin
      Module := ModuleServices.Modules[I];
      Break;
    end;
  end;

  if not Assigned(Module) then
    Exit; // File not open

  if Module.GetModuleFileCount = 0 then
    Exit;

  Editor := Module.GetModuleFileEditor(0) as IOTASourceEditor;
  if not Assigned(Editor) then
    Exit;

  Writer := Editor.CreateUndoableWriter;
  try
    UTF8Content := UTF8String(NewContent);
    Writer.DeleteTo(MaxInt); // Delete all content
    Writer.Insert(PAnsiChar(UTF8Content)); // Insert new content
    Result := True;
  except
    Result := False;
  end;
end;

function TIDEContextProvider.InsertTextAt(const FileName: string; Line, Column: Integer; const Text: string): Boolean;
var
  ModuleServices: IOTAModuleServices;
  Module: IOTAModule;
  Editor: IOTASourceEditor;
  Writer: IOTAEditWriter;
  EditView: IOTAEditView;
  CharPos: TOTACharPos;
  I: Integer;
  UTF8Text: UTF8String;
begin
  Result := False;
  
  if not Supports(BorlandIDEServices, IOTAModuleServices, ModuleServices) then
    Exit;

  // Find the open module for this file
  Module := nil;
  for I := 0 to ModuleServices.ModuleCount - 1 do
  begin
    if SameText(ModuleServices.Modules[I].FileName, FileName) then
    begin
      Module := ModuleServices.Modules[I];
      Break;
    end;
  end;

  if not Assigned(Module) then
    Exit; // File not open

  if Module.GetModuleFileCount = 0 then
    Exit;

  Editor := Module.GetModuleFileEditor(0) as IOTASourceEditor;
  if not Assigned(Editor) then
    Exit;

  EditView := Editor.GetEditView(0);
  if not Assigned(EditView) then
    Exit;

  // Convert line/column to character position
  CharPos.Line := Line;
  CharPos.CharIndex := Column;

  Writer := Editor.CreateUndoableWriter;
  try
    Writer.CopyTo(EditView.CharPosToPos(CharPos)); // Move to position
    UTF8Text := UTF8String(Text);
    Writer.Insert(PAnsiChar(UTF8Text));
    Result := True;
  except
    Result := False;
  end;
end;

function TIDEContextProvider.ReplaceLines(const FileName: string; StartLine, EndLine: Integer; const NewText: string): Boolean;
var
  ModuleServices: IOTAModuleServices;
  Module: IOTAModule;
  Editor: IOTASourceEditor;
  Writer: IOTAEditWriter;
  EditView: IOTAEditView;
  StartPos, EndPos: TOTACharPos;
  StartCharPos, EndCharPos: Integer;
  I: Integer;
  UTF8Text: UTF8String;
begin
  Result := False;
  
  if not Supports(BorlandIDEServices, IOTAModuleServices, ModuleServices) then
    Exit;

  // Find the open module for this file
  Module := nil;
  for I := 0 to ModuleServices.ModuleCount - 1 do
  begin
    if SameText(ModuleServices.Modules[I].FileName, FileName) then
    begin
      Module := ModuleServices.Modules[I];
      Break;
    end;
  end;

  if not Assigned(Module) then
    Exit; // File not open

  if Module.GetModuleFileCount = 0 then
    Exit;

  Editor := Module.GetModuleFileEditor(0) as IOTASourceEditor;
  if not Assigned(Editor) then
    Exit;

  EditView := Editor.GetEditView(0);
  if not Assigned(EditView) then
    Exit;

  // Convert line ranges to character positions
  StartPos.Line := StartLine;
  StartPos.CharIndex := 0; // Start of line
  EndPos.Line := EndLine + 1; // Go to next line
  EndPos.CharIndex := 0;

  StartCharPos := EditView.CharPosToPos(StartPos);
  EndCharPos := EditView.CharPosToPos(EndPos);

  Writer := Editor.CreateUndoableWriter;
  try
    Writer.CopyTo(StartCharPos); // Move to start position
    Writer.DeleteTo(EndCharPos); // Delete lines
    UTF8Text := UTF8String(NewText);
    Writer.Insert(PAnsiChar(UTF8Text)); // Insert new text
    Result := True;
  except
    Result := False;
  end;
end;

{ TStandaloneContextProvider }

constructor TStandaloneContextProvider.Create(const AProjectPath: string);
begin
  inherited Create;
  FProjectPath := AProjectPath;
  if FProjectPath <> '' then
    ParseProjectFile;
end;

procedure TStandaloneContextProvider.ParseProjectFile;
var
  XMLDoc: IXMLDocument;
  RootNode, ItemGroupNode, Node: IXMLNode;
  I, J: Integer;
  FileName: string;
  Files: TList<string>;
begin
  Files := TList<string>.Create;
  try
    if not TFile.Exists(FProjectPath) then
      Exit;

    XMLDoc := TXMLDocument.Create(nil);
    try
      XMLDoc.LoadFromFile(FProjectPath);
      RootNode := XMLDoc.DocumentElement;
      
      // Parse .dproj XML for source files
      for I := 0 to RootNode.ChildNodes.Count - 1 do
      begin
        ItemGroupNode := RootNode.ChildNodes[I];
        if SameText(ItemGroupNode.NodeName, 'ItemGroup') then
        begin
          for J := 0 to ItemGroupNode.ChildNodes.Count - 1 do
          begin
            Node := ItemGroupNode.ChildNodes[J];
            if SameText(Node.NodeName, 'DCCReference') then
            begin
              FileName := Node.Attributes['Include'];
              if FileName <> '' then
              begin
                // Make path absolute relative to project directory
                FileName := TPath.Combine(TPath.GetDirectoryName(FProjectPath), FileName);
                Files.Add(FileName);
              end;
            end;
          end;
        end;
      end;
    except
      // Ignore XML parsing errors
    end;
    
    FProjectFiles := Files.ToArray;
  finally
    Files.Free;
  end;
end;

function TStandaloneContextProvider.GetCurrentFile: TContextItem;
var
  MostRecent: string;
  MostRecentTime: TDateTime;
  F: string;
  FileTime: TDateTime;
begin
  Result := TContextItem.Create(ctCurrentFile, '', '');
  
  // Find most recently modified .pas file
  MostRecentTime := 0;
  for F in FProjectFiles do
  begin
    if SameText(TPath.GetExtension(F), '.pas') and TFile.Exists(F) then
    begin
      FileTime := TFile.GetLastWriteTime(F);
      if FileTime > MostRecentTime then
      begin
        MostRecentTime := FileTime;
        MostRecent := F;
      end;
    end;
  end;
  
  if MostRecent <> '' then
  begin
    Result.FilePath := MostRecent;
    Result.Content := TFile.ReadAllText(MostRecent, TEncoding.UTF8);
  end;
end;

function TStandaloneContextProvider.GetSelection: TContextItem;
begin
  // No selection available in standalone mode
  Result := TContextItem.Create(ctSelection, '', '');
end;

function TStandaloneContextProvider.GetProjectFiles: TArray<string>;
begin
  Result := FProjectFiles;
end;

function TStandaloneContextProvider.IsAvailable: Boolean;
begin
  Result := FProjectPath <> '';
end;

function TStandaloneContextProvider.ReplaceFileContent(const FileName, NewContent: string): Boolean;
begin
  // File editing not supported in standalone mode
  Result := False;
end;

function TStandaloneContextProvider.InsertTextAt(const FileName: string; Line, Column: Integer; const Text: string): Boolean;
begin
  // File editing not supported in standalone mode
  Result := False;
end;

function TStandaloneContextProvider.ReplaceLines(const FileName: string; StartLine, EndLine: Integer; const NewText: string): Boolean;
begin
  // File editing not supported in standalone mode
  Result := False;
end;

end.
