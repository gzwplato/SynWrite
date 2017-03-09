unit unMenuCmds;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, Menus,
  TntStdCtrls, TntForms, TntClasses,
  ecKeyMap, ExtCtrls, DKLang;

type
  TfmMenuCmds = class(TTntForm)
    List: TTntListBox;
    KeysList: TSyntKeyMapping;
    Edit: TTntEdit;
    TimerType: TTimer;
    Panel1: TPanel;
    LabelInfo: TTntLabel;
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure FormShow(Sender: TObject);
    procedure ListDblClick(Sender: TObject);
    procedure EditKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure EditChange(Sender: TObject);
    procedure TimerTypeTimer(Sender: TObject);
    procedure ListDrawItem(Control: TWinControl; Index: Integer;
      Rect: TRect; State: TOwnerDrawState);
    procedure TntFormResize(Sender: TObject);
    procedure TntFormCreate(Sender: TObject);
    procedure labHelpClick(Sender: TObject);
    procedure TntFormClose(Sender: TObject; var Action: TCloseAction);
    procedure TntFormDestroy(Sender: TObject);
    procedure ListKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
  private
    { Private declarations }
    FFuzzy: boolean;
    procedure DoFilter;
    procedure DoDialogHotkeys(AOwner: TComponent; ACommand: integer);
    function GetHotkeyStringFromCommandItem(AItem: TecCommandItem; AKeyIndex: integer): string;
  public
    { Public declarations }
    //PyList: TTntStringList;
    LexList: TTntStringList;
    FIniFN: string;
    FColorSel: TColor;
    FColorSelBk: TColor;
  end;

const
  cLexListBase = 6000; //must be bigger than cPyCommandBase=5000

implementation

uses
  TntWideStrings,
  Math,
  IniFiles,
  ecStrUtils,
  unProc,
  unProcHelp,
  ATxSProc, unHotkeys;

{$R *.dfm}

procedure TfmMenuCmds.DoDialogHotkeys(AOwner: TComponent; ACommand: integer);
var
  F: TfmHotkeys;
  Str1: string;
  KeyIndex, i: Integer;
begin
  KeyIndex:= -1;
  for i:= 0 to KeysList.Items.Count-1 do
    if KeysList.Items[i].Command=ACommand then
      begin KeyIndex:= i; break end;
  if KeyIndex<0 then exit;

  F:= TfmHotkeys.Create(AOwner);
  try
    F.labelInfo1.Caption:= '1)  '+GetHotkeyStringFromCommandItem(KeysList.Items[KeyIndex], 0);
    F.labelInfo2.Caption:= '2)  '+GetHotkeyStringFromCommandItem(KeysList.Items[KeyIndex], 1);
    if F.ShowModal=mrOk then
    begin
    end;
  finally
    FreeAndNil(F);
  end;    
end;

procedure TfmMenuCmds.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  S, SItem: Widestring;
begin
  //Esc
  if (Key=vk_escape) and (Shift=[]) then
  begin
    ModalResult:= mrCancel;
    Key:= 0;
    Exit
  end;
  //Enter
  if (Key=vk_return) and (Shift=[]) then
  begin
    if List.ItemIndex>=0 then
      ModalResult:= mrOk;
    Key:= 0;
    Exit
  end;
  //F9
  if (Key=vk_f9) and (Shift=[]) then
  begin
    if List.ItemIndex>=0 then
    begin
      DoDialogHotkeys(Self, integer(List.Items.Objects[List.ItemIndex]));
    end;
    Key:= 0;
    Exit
  end;
  //F4
  if (Key=vk_f4) and (Shift=[]) then
  begin
    FFuzzy:= not FFuzzy;
    DoFilter;
    Key:= 0;
    Exit
  end;
  //F1
  if (Key=vk_f1) and (Shift=[]) then
  begin
    labHelpClick(Self);
    Key:= 0;
    Exit
  end;
end;

procedure TfmMenuCmds.FormShow(Sender: TObject);
begin
  DoFilter;

  if FIniFN<>'' then
  with TIniFile.Create(FIniFN) do
  try
    FFuzzy:= ReadBool('Win', 'CmdListFuzzy', false);
  finally
    Free
  end;

  LabelInfo.Caption:= WideFormat(' F1: %s | F4: %s',
    [DKLangConstW('zMHintHelp'),
     DKLangConstW('zMHintFuzzy')]);
end;


function TfmMenuCmds.GetHotkeyStringFromCommandItem(
  AItem: TecCommandItem; AKeyIndex: integer): string;
begin
  Result:= '';
  if (AKeyIndex<AItem.KeyStrokes.Count) then
    Result:= AItem.KeyStrokes[AKeyIndex].AsString;
end;

procedure TfmMenuCmds.DoFilter;
  function SFiltered(const S: Widestring): boolean;
  begin
    if FFuzzy then
      Result:= SFuzzyMatch(S, Edit.Text)
    else
      Result:= SSubstringMatch(S, Edit.Text);
  end;
var
  i, j: Integer;
  ListCat: TTntStringList;
  S, SKey: Widestring;
begin
  ListCat:= TTntStringList.Create;
  try
    for i:= 0 to KeysList.Items.Count-1 do
      if ListCat.IndexOf(KeysList.Items[i].Category)<0 then
        ListCat.Add(KeysList.Items[i].Category);

    List.Items.BeginUpdate;
    try
      List.Items.Clear;
      for j:= 0 to ListCat.Count-1 do
        for i:= 0 to KeysList.Items.Count-1 do
          if ListCat[j]=KeysList.Items[i].Category then
            if KeysList.Items[i].Command>0 then
            begin
              //todo: use Gethotkey
              S:= KeysList.Items[i].Category + ': ' + KeysList.Items[i].DisplayName;
              if KeysList.Items[i].KeyStrokes.Count>0 then
              begin
                SKey:= KeysList.Items[i].KeyStrokes[0].AsString;
                if KeysList.Items[i].KeyStrokes.Count>1 then
                  SKey:= SKey+' / '+KeysList.Items[i].KeyStrokes[1].AsString;
              end
              else
                SKey:= '';
              if SFiltered(S) then
                List.Items.AddObject(S + #9 + SKey, Pointer(KeysList.Items[i].Command));
            end;

      for i:= 0 to LexList.Count-1 do
      begin
        S:= LexList[i];
        if SFiltered(S) then
          List.Items.AddObject(S, Pointer(cLexListBase+i));
      end;

      {
      for i:= 0 to PyList.Count-1 do
      begin
        S:= PyList[i];
        if SFiltered(S) then
          List.Items.AddObject(S, Pointer(cPyListBase+i));
      end;
      }
    finally
      List.Items.EndUpdate;
    end;
  finally
    FreeAndNil(ListCat);
  end;

  List.ItemIndex:= 0;
end;

procedure TfmMenuCmds.ListDblClick(Sender: TObject);
begin
  if List.ItemIndex>=0 then
    ModalResult:= mrOk;
end;

procedure TfmMenuCmds.EditKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (((Key=vk_prior) or (Key=vk_next) or (key=vk_up) or (key=vk_down)) and (Shift=[])) or
    (((key=vk_home) or (key=vk_end)) and (Shift=[ssCtrl])) then
    begin
      List.Perform(wm_keydown, key, 0);
      Key:= 0;
      Exit
    end;
end;

procedure TfmMenuCmds.EditChange(Sender: TObject);
begin
  TimerType.Enabled:= false;
  TimerType.Enabled:= true;
end;

procedure TfmMenuCmds.TimerTypeTimer(Sender: TObject);
begin
  TimerType.Enabled:= false;
  DoFilter;
end;

procedure TfmMenuCmds.ListDrawItem(Control: TWinControl; Index: Integer;
  Rect: TRect; State: TOwnerDrawState);
var
  S, S1, S2: Widestring;
  i, n: Integer;
  Arr: TSynCharArray;
begin
  with Control as TTntListbox do
  begin
    if odSelected in State then
      Canvas.Brush.Color:= FColorSelBk
    else
      Canvas.Brush.Color:= Color;
    Canvas.FillRect(Rect);
    Inc(Rect.Left, 2);

    S:= Items[Index];
    S1:= SGetItem(S, #9);
    S2:= SGetItem(S, #9);

    //shortcut
    Canvas.Font.Color:= IfThen(odSelected in State, clYellow, clNavy);
    n:= ecTextExtent(Canvas, S2).cx+4;
    ecTextOut(Canvas, rect.right-n, rect.top, S2);

    //caption
    Canvas.Font.Color:= IfThen(odSelected in State, FColorSel, Font.Color);
    ecTextOut(Canvas, rect.left, rect.top, S1);

    //filter chars
    if FFuzzy then
    begin
      Canvas.Font.Color:= IfThen(odSelected in State, clYellow, clBlue);
      SGetCharArray(S1, Edit.Text, Arr);
      for i:= Low(Arr) to High(Arr) do
        if Arr[i]>0 then
        begin
          n:= ecTextExtent(Canvas, Copy(S1, 1, Arr[i]-1)).cx;
          ecTextOut(Canvas, rect.left+n, rect.top, Copy(S1, Arr[i], 1));
        end
        else
          Break;
    end;      
  end;
end;

procedure TfmMenuCmds.TntFormResize(Sender: TObject);
begin
  List.Invalidate;
end;

procedure TfmMenuCmds.TntFormCreate(Sender: TObject);
begin
  List.ItemHeight:= ScaleFontSize(List.ItemHeight, Self);
  //PyList:= TTntStringList.Create;
  LexList:= TTntStringList.Create;
end;

procedure TfmMenuCmds.labHelpClick(Sender: TObject);
begin
  SynHelpTopic(helpCmdListDlg, Handle);
end;

procedure TfmMenuCmds.TntFormClose(Sender: TObject;
  var Action: TCloseAction);
begin
  if FIniFN<>'' then
  with TIniFile.Create(FIniFN) do
  try
    WriteBool('Win', 'CmdListFuzzy', FFuzzy);
  finally
    Free
  end;
end;

procedure TfmMenuCmds.TntFormDestroy(Sender: TObject);
begin
  //FreeAndNil(PyList);
  FreeAndNil(LexList);
end;

procedure TfmMenuCmds.ListKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key=vk_up) and (List.ItemIndex=0) then
  begin
    List.ItemIndex:= List.Items.Count-1;
    Key:= 0;
    Exit
  end;
  if (Key=vk_down) and (List.ItemIndex=List.Items.Count-1) then
  begin
    List.ItemIndex:= 0;
    Key:= 0;
    Exit
  end;
end;

end.
