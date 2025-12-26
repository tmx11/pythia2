object ChatWindow: TChatWindow
  Left = 0
  Top = 0
  Caption = 'Pythia - AI Chat Assistant'
  ClientHeight = 661
  ClientWidth = 584
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -12
  Font.Name = 'Segoe UI'
  Font.Style = []
  Position = poScreenCenter
  OnCloseQuery = FormCloseQuery
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  TextHeight = 15
  object SplitterInput: TSplitter
    Left = 0
    Top = 451
    Width = 584
    Height = 4
    Cursor = crVSplit
    Align = alBottom
    ExplicitTop = 444
    ExplicitWidth = 600
  end
  object SplitterContext: TSplitter
    Left = 0
    Top = 98
    Width = 584
    Height = 4
    Cursor = crVSplit
    Align = alTop
    ExplicitTop = 91
  end
  object PanelTop: TPanel
    Left = 0
    Top = 0
    Width = 584
    Height = 75
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object LabelModel: TLabel
      Left = 16
      Top = 13
      Width = 36
      Height = 15
      Caption = 'Model:'
    end
    object LabelMode: TLabel
      Left = 16
      Top = 44
      Width = 35
      Height = 15
      Caption = 'Mode:'
    end
    object ComboModel: TComboBox
      Left = 64
      Top = 10
      Width = 217
      Height = 23
      Style = csDropDownList
      TabOrder = 0
      Text = 'ComboModel'
    end
    object ComboMode: TComboBox
      Left = 64
      Top = 41
      Width = 100
      Height = 23
      Style = csDropDownList
      TabOrder = 1
      Text = 'ComboMode'
      OnChange = ComboModeChange
    end
    object ButtonSettings: TButton
      Left = 296
      Top = 10
      Width = 85
      Height = 25
      Caption = 'Settings...'
      TabOrder = 2
      OnClick = ButtonSettingsClick
    end
    object ButtonTestConnection: TButton
      Left = 391
      Top = 10
      Width = 110
      Height = 25
      Caption = 'Test Connection'
      TabOrder = 3
      OnClick = ButtonTestConnectionClick
    end
    object ButtonClear: TButton
      Left = 511
      Top = 10
      Width = 60
      Height = 25
      Caption = 'Clear'
      TabOrder = 4
      OnClick = ButtonClearClick
    end
  end
  object PanelBottom: TPanel
    Left = 0
    Top = 455
    Width = 584
    Height = 185
    Align = alBottom
    BevelOuter = bvNone
    TabOrder = 1
    object PanelContext: TPanel
      Left = 0
      Top = 0
      Width = 584
      Height = 41
      Align = alTop
      BevelOuter = bvNone
      TabOrder = 0
      object LabelCurrentFile: TLabel
        Left = 16
        Top = 13
        Width = 63
        Height = 15
        Caption = 'Current File:'
      end
      object LabelContext: TEdit
        Left = 320
        Top = 10
        Width = 132
        Height = 23
        ReadOnly = True
        TabOrder = 1
        Text = 'Context: No file active'
      end
      object EditCurrentFile: TEdit
        Left = 88
        Top = 10
        Width = 217
        Height = 23
        TabOrder = 0
        Text = ''
        OnChange = EditCurrentFileChange
      end
      object CheckAutoContext: TCheckBox
        Left = 320
        Top = 11
        Width = 129
        Height = 17
        Caption = 'Auto-Context'
        Checked = True
        State = cbChecked
        TabOrder = 2
        Visible = False
        OnClick = CheckAutoContextClick
      end
      object ButtonRefreshContext: TButton
        Left = 462
        Top = 8
        Width = 110
        Height = 25
        Caption = 'Refresh Context'
        TabOrder = 3
        OnClick = ButtonRefreshContextClick
      end
    end
    object MemoContextInfo: TMemo
      Left = 0
      Top = 41
      Width = 584
      Height = 80
      Align = alTop
      Color = cl3DLight
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -11
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      ReadOnly = True
      ScrollBars = ssVertical
      TabOrder = 1
    end
    object MemoInput: TMemo
      Left = 0
      Top = 91
      Width = 584
      Height = 46
      Align = alClient
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      ScrollBars = ssVertical
      TabOrder = 2
      OnKeyDown = MemoInputKeyDown
    end
    object ButtonSend: TButton
      Left = 488
      Top = 143
      Width = 89
      Height = 34
      Align = alCustom
      Anchors = [akRight, akBottom]
      Caption = 'Send'
      Default = True
      TabOrder = 3
      OnClick = ButtonSendClick
    end
  end
  object PanelChat: TPanel
    Left = 0
    Top = 57
    Width = 584
    Height = 394
    Align = alClient
    BevelOuter = bvNone
    TabOrder = 2
    object MemoChat: TRichEdit
      Left = 0
      Top = 0
      Width = 584
      Height = 394
      Align = alClient
      Font.Charset = DEFAULT_CHARSET
      Font.Color = clWindowText
      Font.Height = -13
      Font.Name = 'Segoe UI'
      Font.Style = []
      ParentFont = False
      ReadOnly = True
      ScrollBars = ssVertical
      TabOrder = 0
    end
  end
  object StatusBar: TStatusBar
    Left = 0
    Top = 640
    Width = 584
    Height = 21
    Panels = <>
    SimplePanel = True
    SimpleText = 'Ready'
  end
end
