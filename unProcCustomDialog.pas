(*
This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

Copyright (c) Alexey Torgashin
*)
unit unProcCustomDialog;

interface

uses
  Windows, Classes, SysUtils, Graphics, Controls, StdCtrls, ExtCtrls, Forms,
  CheckLst, Spin, ComCtrls, Dialogs,
  TntControls, TntExtCtrls, TntComCtrls, TntStdCtrls, TntCheckLst, TntForms,
  ATLinkLabel,
  ATPanelColor;

procedure DoDialogCustom(
 const ATitle: string;
 ASizeX, ASizeY: integer;
 AText: string;
 AFocusedIndex: integer;
 out AButtonIndex: integer;
 out AStateText: string);

function IsDialogCustomShown: boolean;


implementation

const
  cButtonResultStart=100;
  cTagActive=1;

var
  FDialogShown: boolean = false;

type
  TCustomEditHack = class(TCustomEdit);
  TControlHack = class(TControl);

function SGetItem(var S: string; const sep: Char = ','): string;
var
  i: integer;
begin
  i:= Pos(sep, s);
  if i=0 then i:= MaxInt;
  Result:= Copy(s, 1, i-1);
  Delete(s, 1, i);
end;
  
type
  { TDummyClass }
  TDummyClass = class
  public
    Form: TTntForm;
    procedure DoOnShow(Sender: TObject);
    procedure DoKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure DoOnChange(Sender: TObject);
    procedure DoOnSelChange(Sender: TObject; User: boolean);
    procedure DoOnListviewChange(Sender: TObject; Item: TListItem; Change: TItemChange);
    procedure DoOnListviewSelect(Sender: TObject; Item: TListItem; Selected: Boolean);
  end;

function StrToBool(const S: string): boolean;
begin
  Result:= S<>'0';
end;

function IsControlAutosizeY(C: TControl): boolean;
begin
  Result:=
    (C is TTntLabel) or
    (C is TLinkLabel) or
    (C is TTntButton) or
    //(C is TToggleBox) or
    (C is TTntEdit) or
    (C is TTntCombobox) or
    (C is TTntCheckBox) or
    (C is TTntRadioButton) or
    (C is TSpinEdit);
end;

procedure DoFixButtonHeight(Ctl: TControl);
begin
  Ctl.Height:= 23; //smaller
end;

function DoGetListviewState(C: TTntListView): string; forward;
function DoGetControlState(C: TControl): string;
var
  i: integer;
begin
  Result:= '';

  if C is TTntEdit then
  begin
    Result:= UTF8Encode((C as TTntEdit).Text);
  end;

  if C is TTntCheckBox then
    Result:= IntToStr(Ord((C as TTntCheckBox).Checked));

  //if C is TToggleBox then
  //  Result:= IntToStr(Ord((C as TToggleBox).Checked));

  if C is TTntRadioButton then
    Result:= IntToStr(Ord((C as TTntRadioButton).Checked));

  if C is TTntListbox then
    Result:= IntToStr((C as TTntListbox).ItemIndex);

  if C is TTntCombobox then
  begin
    if (C as TTntCombobox).Style=csDropDownList then
      Result:= IntToStr((C as TTntCombobox).ItemIndex)
    else
      Result:= UTF8Encode((C as TTntCombobox).Text);
  end;

  if C is TTntMemo then
  begin
    Result:= UTF8Encode((C as TTntMemo).Lines.Text);
    Result:= StringReplace(Result, #9, #2, [rfReplaceAll]);
    Result:= StringReplace(Result, #13#10, #9, [rfReplaceAll]);
    Result:= StringReplace(Result, #13, #9, [rfReplaceAll]);
    Result:= StringReplace(Result, #10, #9, [rfReplaceAll]);
  end;

  if C is TRadioGroup then
    Result:= IntToStr((C as TRadioGroup).ItemIndex);

  //if C is TCheckGroup then
  //  for i:= 0 to (C as TCheckGroup).Items.Count-1 do
  //    Result:= Result+IntToStr(Ord((C as TCheckGroup).Checked[i]))+',';

  if C is TCheckListBox then
  begin
    Result:= IntToStr((C as TCheckListBox).ItemIndex)+';';
    for i:= 0 to (C as TCheckListBox).Items.Count-1 do
      Result:= Result+IntToStr(Ord((C as TCheckListBox).Checked[i]))+',';
  end;

  if C is TSpinEdit then
    Result:= IntToStr((C as TSpinEdit).Value);

  if C is TTntListView then
    Result:= DoGetListviewState(C as TTntListView);

  if C is TTntTabControl then
    Result:= IntToStr((C as TTntTabControl).TabIndex);
end;


function DoGetFormControlByIndex(AForm: TTntForm; AIndex: Integer): TControl;
var
  Ctl: TControl;
  i: integer;
begin
  Result:= nil;
  for i:= 0 to AForm.ControlCount-1 do
  begin
    Ctl:= AForm.Controls[i];
    if Ctl.Tag=AIndex then
    begin
      Result:= Ctl;
      Exit
    end;
  end;  
end;

function DoGetFormResult(AForm: TTntForm): string;
var
  Str: string;
  Ctl: TControl;
  i: integer;
begin
  Result:= '';
  //weird loop. reason: VCL gives bad order of controls.
  for i:= 0 to AForm.ControlCount-1 do
  begin
    Ctl:= DoGetFormControlByIndex(AForm, i);
    Str:= DoGetControlState(Ctl);
    Result:= Result+Str+#10;
  end;
end;


procedure DoSetMemoState(C: TTntMemo; AValue: string);
var
  SItem: string;
begin
  C.Lines.Clear;
  repeat
    SItem:= SGetItem(AValue, #9);
    if SItem='' then break;
    C.Lines.Add(UTF8Decode(SItem));
  until false;
end;

(*
procedure DoSetCheckgroupState(C: TCheckGroup; AValue: string);
var
  SItem: string;
  N: integer;
begin
  N:= 0;
  repeat
    if N>=C.Items.Count then exit;
    SItem:= SGetItem(AValue);
    if SItem='' then break;
    C.Checked[N]:= StrToBool(SItem);
    Inc(N);
  until false;
end;
*)

procedure DoSetChecklistboxState(C: TCheckListBox; AValue: string);
var
  SItem: string;
  N: integer;
begin
  C.ItemIndex:= StrToIntDef(SGetItem(AValue, ';'), 0);

  N:= 0;
  repeat
    if N>=C.Items.Count then exit;
    SItem:= SGetItem(AValue);
    if SItem='' then break;
    C.Checked[N]:= StrToBool(SItem);
    Inc(N);
  until false;
end;


procedure DoSetListviewItem(C: TTntListView; SListItem: string);
var
  SItem: string;
  Col: TTntListColumn;
  i: integer;
begin
  if C.Columns.Count=0 then
  begin
    repeat
      SItem:= SGetItem(SListItem, #13);
      if SItem='' then break;
      Col:= C.Columns.Add;
      Col.Caption:= UTF8Decode(SGetItem(SItem, '='));
      if SItem<>'' then
      begin
        if SItem[1]='L' then begin Delete(SItem, 1, 1); Col.Alignment:= taLeftJustify; end;
        if SItem[1]='R' then begin Delete(SItem, 1, 1); Col.Alignment:= taRightJustify; end;
        if SItem[1]='C' then begin Delete(SItem, 1, 1); Col.Alignment:= taCenter; end;
        Col.Width:= StrToIntDef(SItem, 80);
      end;
    until false;
  end
  else
  begin
    SItem:= SGetItem(SListItem, #13);
    C.Items.Add.Caption:= UTF8Decode(SItem);
    for i:= 1 to C.Columns.Count do
    begin
      SItem:= SGetItem(SListItem, #13);
      C.Items[C.Items.Count-1].SubItems.Add(UTF8Decode(SItem));
    end;
  end;
end;


procedure DoSetListviewState(C: TTntListView; SValue: string);
var
  N: integer;
  SItem: string;
begin
  //index
  SItem:= SGetItem(SValue, ';');
  N:= StrToIntDef(SItem, 0);
  if (N>=0) and (N<C.Items.Count) then
  begin
    C.ItemFocused:= C.Items[N];
    C.Selected:= C.ItemFocused;
  end;

  //check0,check1,..
  if C.Checkboxes then
  begin
    N:= 0;
    repeat
      if N>=C.Items.Count then break;
      SItem:= SGetItem(SValue);
      if SItem='' then break;
      C.Items[N].Checked:= StrToBool(SItem);
      Inc(N);
    until false;
  end;
end;


function DoGetListviewState(C: TTntListView): string;
// index;check0,check1,
var
  i: integer;
begin
  if Assigned(C.ItemFocused) then
    Result:= IntToStr(C.ItemFocused.Index);

  if C.Checkboxes then
  begin
    Result:= Result+';';
    for i:= 0 to C.Items.Count-1 do
      Result:= Result+IntToStr(Ord(C.Items[i].Checked))+',';
  end;
end;


procedure DoControlSetProps(C: TControl; S: string);
begin
  if C is TTntButton then
  begin
    (C as TTntButton).Default:= StrToBool(SGetItem(S));
    exit;
  end;

  if C is TSpinEdit then
  begin
    (C as TSpinEdit).MinValue:= StrToIntDef(SGetItem(S), 0);
    (C as TSpinEdit).MaxValue:= StrToIntDef(SGetItem(S), 100);
    (C as TSpinEdit).Increment:= StrToIntDef(SGetItem(S), 1);
    exit;
  end;

  if C is TLinkLabel then
  begin
    (C as TLinkLabel).Link:= S;
    exit;
  end;

  if C is TTntLabel then
  begin
    if StrToBool(SGetItem(S)) then
    begin
      (C as TTntLabel).AutoSize:= false;
      (C as TTntLabel).Alignment:= taRightJustify;
    end;
    exit
  end;

  if C is TTntLabel then
  begin
    if StrToBool(SGetItem(S)) then
    begin
      (C as TTntLabel).AutoSize:= false;
      (C as TTntLabel).Alignment:= taRightJustify;
    end;
    exit;
  end;

  if (C is TTntEdit) or (C is TTntMemo) then
  begin
    //RO
    if StrToBool(SGetItem(S)) then
    begin
      if (C is TTntEdit) then (C as TTntEdit).ReadOnly:= true;
      if (C is TTntMemo) then (C as TTntMemo).ReadOnly:= true;
      TCustomEditHack(C).ParentColor:= true;
    end;
    //Monospaced
    if StrToBool(SGetItem(S)) then
    begin
      if C is TTntEdit then
      begin
        (C as TTntEdit).Font.Name:= 'Courier New';
        (C as TTntEdit).Font.Size:= 9;
      end;
      if C is TTntMemo then
      begin
        (C as TTntMemo).Font.Name:= 'Courier New';
        (C as TTntMemo).Font.Size:= 9;
      end;
    end;
    //Border
    if StrToBool(SGetItem(S)) then
      TCustomEditHack(C).BorderStyle:= bsSingle
    else
      TCustomEditHack(C).BorderStyle:= bsNone;

    exit;
  end;

  if (C is TTntListView) then
  begin
    (C as TTntListView).GridLines:= StrToBool(SGetItem(S));
    Exit;
  end;

  if (C is TTntTabControl) then
  begin
    if S='1' then
      (C as TTntTabControl).TabPosition:= tpBottom;
    exit;
  end;

  if (C is TImage) then
  begin
    (C as TImage).Center:= StrToBool(SGetItem(S));
    (C as TImage).Stretch:= StrToBool(SGetItem(S));
    exit
  end;

  if (C is TATPanelColor) then
  begin
    (C as TATPanelColor).BorderWidth:= StrToIntDef(SGetItem(S), 0);
    (C as TATPanelColor).Color:= StrToIntDef(SGetItem(S), clBtnFace);
    (C as TATPanelColor).Font.Color:= StrToIntDef(SGetItem(S), clBlack);
    (C as TATPanelColor).BorderColor:= StrToIntDef(SGetItem(S), clBlack);
    exit
  end;
end;


function DoAddControl(AForm: TTntForm; ATextItems: string; ADummy: TDummyClass;
  AIndex: integer): TControl;
var
  SNameValue, SName, SValue, SListItem: string;
  NX1, NX2, NY1, NY2: integer;
  Ctl, CtlPrev: TControl;
begin
  Result:= nil;
  Ctl:= nil;
  SNameValue:= '';
  SName:= '';
  SValue:= '';
  SListItem:= '';

  repeat
    SNameValue:= SGetItem(ATextItems, Chr(1));
    if SNameValue='' then break;
    SName:= SGetItem(SNameValue, '=');
    SValue:= SNameValue;
    if SName='' then Continue;

    //-------type
    if SName='type' then
    begin
      if SValue='check' then
      begin
        Ctl:= TTntCheckBox.Create(AForm);
        (Ctl as TTntCheckBox).OnClick:= ADummy.DoOnChange;
      end;
      if SValue='radio' then
      begin
        Ctl:= TTntRadioButton.Create(AForm);
        (Ctl as TTntRadioButton).OnClick:= ADummy.DoOnChange;
      end;
      if SValue='edit' then
      begin
        Ctl:= TTntEdit.Create(AForm);
      end;
      if SValue='listbox' then
      begin
        Ctl:= TTntListbox.Create(AForm);
        (Ctl as TTntListbox).OnClick:= ADummy.DoOnChange;
      end;
      if SValue='spinedit' then
      begin
        Ctl:= TSpinEdit.Create(AForm);
      end;
      if SValue='memo' then
        begin
          Ctl:= TTntMemo.Create(AForm);
          (Ctl as TTntMemo).WordWrap:= false;
          (Ctl as TTntMemo).ScrollBars:= ssBoth;
        end;
      if SValue='label' then
        begin
          Ctl:= TTntLabel.Create(AForm);
          (Ctl as TTntLabel).AutoSize:= false;
        end;
      if SValue='combo' then
        begin
          Ctl:= TTntCombobox.Create(AForm);
          (Ctl as TTntCombobox).DropDownCount:= 20;
        end;
      if SValue='combo_ro' then
        begin
          Ctl:= TTntCombobox.Create(AForm);
          (Ctl as TTntCombobox).DropDownCount:= 20;
          (Ctl as TTntCombobox).Style:= csDropDownList;
          (Ctl as TTntCombobox).OnChange:= ADummy.DoOnChange;
        end;
      if SValue='button' then
        begin
          Ctl:= TTntButton.Create(AForm);
          (Ctl as TTntButton).ModalResult:= cButtonResultStart+ AForm.ControlCount;
          DoFixButtonHeight(Ctl);
        end;
      if SValue='checkbutton' then
        begin
          Ctl:= TTntCheckBox.Create(AForm); //not TToggleBox in D7
          (Ctl as TTntCheckBox).OnClick:= ADummy.DoOnChange;
          DoFixButtonHeight(Ctl);
        end;
      if SValue='radiogroup' then
      begin
        Ctl:= TTntRadioGroup.Create(AForm);
      end;
      //if SValue='checkgroup' then
      //begin
      //  Ctl:= TCheckGroup.Create(AForm);
      //end;
      if SValue='checklistbox' then
      begin
        Ctl:= TTntCheckListBox.Create(AForm);
        (Ctl as TTntCheckListBox).OnClickCheck:= ADummy.DoOnChange;
        (Ctl as TTntCheckListBox).OnClickCheck:= ADummy.DoOnChange;
      end;

      //disabled: label paints bad onto groupbox, Linux
      //if SValue='group' then
      //  Ctl:= TGroupBox.Create(AForm);

      if (SValue='listview') or
         (SValue='checklistview') then
      begin
        Ctl:= TTntListView.Create(AForm);
        (Ctl as TTntListView).ReadOnly:= true;
        (Ctl as TTntListView).ColumnClick:= false;
        (Ctl as TTntListView).ViewStyle:= vsReport;
        (Ctl as TTntListView).RowSelect:= true;
        (Ctl as TTntListView).HideSelection:= false;
        (Ctl as TTntListView).Checkboxes:= (SValue='checklistview');
        (Ctl as TTntListView).OnChange:= ADummy.DoOnListviewChange;
        (Ctl as TTntListView).OnSelectItem:= ADummy.DoOnListviewSelect;
      end;

      if SValue='linklabel' then
      begin
        Ctl:= TLinkLabel.Create(AForm);
      end;

      if SValue='tabs' then
      begin
        Ctl:= TTntTabControl.Create(AForm);
        (Ctl as TTntTabControl).OnChange:= ADummy.DoOnChange;
      end;

      if SValue='colorpanel' then
      begin
        Ctl:= TATPanelColor.Create(AForm);
        (Ctl as TATPanelColor).OnClick:= ADummy.DoOnChange;
      end;

      if SValue='image' then
      begin
        Ctl:= TImage.Create(AForm);
        (Ctl as TImage).Proportional:= true;
      end;

      //set parent
      if Assigned(Ctl) then
      begin
        Ctl.Parent:= AForm;
        Ctl.Tag:= AIndex; //to get in ok order
        Result:= Ctl;
      end;
      Continue;
    end;

    //first name must be "type"
    if not Assigned(Ctl) then exit;

    //adjust previous label's FocusControl
    if AIndex>0 then
      if Ctl is TWinControl then
      begin
        CtlPrev:= DoGetFormControlByIndex(AForm, AIndex-1);
        if Assigned(CtlPrev) then
          if CtlPrev is TTntLabel then
            (CtlPrev as TTntLabel).FocusControl:= Ctl as TWinControl;
      end;

    //-------
    if SName='en' then
    begin
      Ctl.Enabled:= StrToBool(SValue);
      Continue;
    end;

    //-------
    if SName='vis' then
    begin
      Ctl.Visible:= StrToBool(SValue);
      Continue;
    end;

    //-------
    if SName='x' then
    begin
      Ctl.Left:= StrToIntDef(SValue, Ctl.Left);
      Continue;
    end;
    if SName='y' then
    begin
      Ctl.Top:= StrToIntDef(SValue, Ctl.Top);
      Continue;
    end;
    if SName='w' then
    begin
      Ctl.Width:= StrToIntDef(SValue, Ctl.Width);
      Continue;
    end;
    if SName='h' then
    begin
      Ctl.Height:= StrToIntDef(SValue, Ctl.Height);
      Continue;
    end;

    //-------
    if SName='cap' then
    begin
      if (Ctl is TLinkLabel) then (Ctl as TLinkLabel).Caption:= UTF8Decode(SValue);
      if (Ctl is TTntLabel) then (Ctl as TTntLabel).Caption:= UTF8Decode(SValue);
      if (Ctl is TTntButton) then (Ctl as TTntButton).Caption:= UTF8Decode(SValue);
      if (Ctl is TTntCheckBox) then (Ctl as TTntCheckBox).Caption:= UTF8Decode(SValue);
      if (Ctl is TTntRadioButton) then (Ctl as TTntRadioButton).Caption:= UTF8Decode(SValue);
      if (Ctl is TTntEdit) then (Ctl as TTntEdit).Text:= UTF8Decode(SValue);
      if (Ctl is TATPanelColor) then (Ctl as TATPanelColor).Caption:= UTF8Decode(SValue);
      Continue;
    end;

    //-------
    if SName='hint' then
    begin
      Ctl.Hint:= SValue;
      Continue;
    end;

    //-------
    if SName='act' then
    begin
      if SValue='1' then
        Ctl.HelpContext:= cTagActive;
      Continue;
    end;

    //-------
    if SName='pos' then
    begin
      NX1:= StrToIntDef(SGetItem(SValue, ','), -1);
      NY1:= StrToIntDef(SGetItem(SValue, ','), -1);
      NX2:= StrToIntDef(SGetItem(SValue, ','), -1);
      NY2:= StrToIntDef(SGetItem(SValue, ','), -1);
      if NX1<0 then Continue;
      if NX2<0 then Continue;
      if NY1<0 then Continue;
      if NY2<0 then Continue;
      Ctl.Left:= NX1;
      Ctl.Width:= NX2-NX1;
      Ctl.Top:= NY1;
      if not IsControlAutosizeY(Ctl) then
        Ctl.Height:= NY2-NY1;
      Continue;
    end;

    //-------
    if SName='color' then
    begin
      with TControlHack(Ctl) do
        Color:= StrToIntDef(SValue, Color);
      Continue;
    end;

    if SName='font_name' then
    begin
      TControlHack(Ctl).Font.Name:= SValue;
      Continue;
    end;
    if SName='font_size' then
    begin
      TControlHack(Ctl).Font.Size:= StrToIntDef(SValue, 9);
      Continue;
    end;
    if SName='font_color' then
    begin
      TControlHack(Ctl).Font.Color:= StrToIntDef(SValue, clBlack);
      Continue;
    end;

    //-------
    if SName='props' then
    begin
      DoControlSetProps(Ctl, SValue);
      Continue;
    end;

    //-------
    if SName='items' then
    begin
      if Ctl is TImage then
      begin
        try
          (Ctl as TImage).Picture.LoadFromFile(SValue);
          (Ctl as TImage).Transparent:= true;
        except
        end;
        Continue;
      end;

      repeat
        SListItem:= SGetItem(SValue, #9);
        if SListItem='' then break;
        if Ctl is TTntListbox then (Ctl as TTntListbox).Items.Add(UTF8Decode(SListItem));
        if Ctl is TTntCombobox then (Ctl as TTntCombobox).Items.Add(UTF8Decode(SListItem));
        //if Ctl is TCheckGroup then (Ctl as TCheckGroup).Items.Add(SListItem);
        if Ctl is TTntRadioGroup then (Ctl as TTntRadioGroup).Items.Add(UTF8Decode(SListItem));
        if Ctl is TTntCheckListBox then (Ctl as TTntCheckListBox).Items.Add(UTF8Decode(SListItem));
        if Ctl is TTntListView then DoSetListviewItem(Ctl as TTntListView, SListItem);
        if Ctl is TTntTabControl then (Ctl as TTntTabControl).Tabs.Add(UTF8Decode(SListItem));
      until false;
      Continue;
    end;

    //-------
    if SName='val' then
    begin
      if Ctl is TTntCheckBox then (Ctl as TTntCheckBox).Checked:= StrToBool(SValue);
      //if Ctl is TToggleBox then (Ctl as TToggleBox).Checked:= StrToBool(SValue);
      if Ctl is TTntRadioButton then (Ctl as TTntRadioButton).Checked:= StrToBool(SValue);
      if Ctl is TTntEdit then
      begin
        (Ctl as TTntEdit).Text:= UTF8Decode(SValue);
      end;
      if Ctl is TTntCombobox then
      begin
        if (Ctl as TTntCombobox).Style=csDropDownList then
          (Ctl as TTntCombobox).ItemIndex:= StrToIntDef(SValue, 0)
        else
          (Ctl as TTntCombobox).Text:= UTF8Decode(SValue);
      end;
      if Ctl is TTntListbox then (Ctl as TTntListbox).ItemIndex:= StrToIntDef(SValue, 0);
      if Ctl is TTntRadioGroup then (Ctl as TTntRadioGroup).ItemIndex:= StrToIntDef(SValue, 0);
      //if Ctl is TCheckGroup then DoSetCheckgroupState(Ctl as TCheckGroup, SValue);
      if Ctl is TTntCheckListBox then DoSetChecklistboxState(Ctl as TTntCheckListBox, SValue);
      if Ctl is TTntMemo then DoSetMemoState(Ctl as TTntMemo, SValue);
      if Ctl is TSpinEdit then (Ctl as TSpinEdit).Value:= StrToIntDef(SValue, 0);
      if Ctl is TTntListView then DoSetListviewState(Ctl as TTntListView, SValue);
      if Ctl is TTntTabControl then (Ctl as TTntTabControl).TabIndex:= StrToIntDef(SValue, 0);

      Continue;
    end;

    //-------more?
  until false;
end;


procedure DoDialogCustom(const ATitle: string; ASizeX, ASizeY: integer;
  AText: string; AFocusedIndex: integer; out AButtonIndex: integer; out AStateText: string);
var
  F: TTntForm;
  Res, i: integer;
  SItem: string;
  Dummy: TDummyClass;
  Ctl: TControl;
begin
  AButtonIndex:= -1;
  AStateText:= '';

  F:= TTntForm.Create(nil);
  Dummy:= TDummyClass.Create;
  FDialogShown:= true;
  try
    F.BorderStyle:= bsDialog;
    F.Position:= poScreenCenter;
    F.ClientWidth:= ASizeX;
    F.ClientHeight:= ASizeY;
    F.Caption:= UTF8Decode(ATitle);
    F.ShowHint:= true;

    for i:= 0 to 100000 do
    begin
      SItem:= SGetItem(AText, #10);
      if SItem='' then break;
      Ctl:= DoAddControl(F, SItem, Dummy, i);

      if i=AFocusedIndex then
        if Ctl.Enabled then
          F.ActiveControl:= Ctl as TWinControl;
    end;

    Dummy.Form:= F;
    F.KeyPreview:= true;
    F.OnKeyDown:= Dummy.DoKeyDown;
    F.OnShow:= Dummy.DoOnShow;

    Res:= F.ShowModal;
    if Res>=cButtonResultStart then
    begin
      AButtonIndex:= Res-cButtonResultStart;
      AStateText:= DoGetFormResult(F);
    end;
  finally
    FreeAndNil(F);
    FreeAndNil(Dummy);
    FDialogShown:= false;
  end;
end;

function IsDialogCustomShown: boolean;
begin
  Result:= FDialogShown;
end;

{ TDummyClass }

procedure TDummyClass.DoOnShow(Sender: TObject);
var
  i: integer;
begin
  for i:= 0 to Form.ControlCount-1 do
    if Form.Controls[i] is TTntListView then
      with (Form.Controls[i] as TTntListView) do
        if ItemFocused<>nil then
          ItemFocused.MakeVisible(false);
end;

procedure TDummyClass.DoKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
begin
  if (Key=VK_ESCAPE) then
  begin
    if Assigned(Form) then
      Form.ModalResult:= mrCancel;
    Key:= 0;
    exit;
  end;
end;

procedure TDummyClass.DoOnChange(Sender: TObject);
begin
  if (Sender as TControl).HelpContext=cTagActive then
  begin
    Form.ModalResult:= cButtonResultStart+(Sender as TControl).Tag; 
    exit
  end;
end;

procedure TDummyClass.DoOnSelChange(Sender: TObject; User: boolean);
begin
  DoOnChange(Sender);
end;

procedure TDummyClass.DoOnListviewChange(Sender: TObject; Item: TListItem;
  Change: TItemChange);
begin
  DoOnChange(Sender);
end;

procedure TDummyClass.DoOnListviewSelect(Sender: TObject; Item: TListItem;
  Selected: Boolean);
begin
  DoOnChange(Sender);
end;


end.

