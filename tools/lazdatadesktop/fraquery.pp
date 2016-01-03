unit fraquery;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, SynHighlighterSQL, SynEdit, LResources, Forms,
  DB, LCLType, Controls, ComCtrls, StdCtrls, ActnList, Dialogs, ExtCtrls,
  fpDatadict, fradata, lazdatadeskstr;

type

  { TQueryFrame }

  TQueryFrame = class(TFrame)
    ACloseQuery: TAction;
    ACreateCode: TAction;
    AExport: TAction;
    ASaveSQL: TAction;
    ALoadSQL: TAction;
    ANextQuery: TAction;
    APreviousQuery: TAction;
    AExecute: TAction;
    ALQuery: TActionList;
    ILQuery: TImageList;
    MResult: TMemo;
    ODSQL: TOpenDialog;
    PCResult: TPageControl;
    FMSQL: TSynEdit;
    SDSQL: TSaveDialog;
    SQuery: TSplitter;
    SQLSyn: TSynSQLSyn;
    TBExecute: TToolButton;
    TBSep1: TToolButton;
    TBPrevious: TToolButton;
    TBClose: TToolButton;
    TBNext: TToolButton;
    TBSep2: TToolButton;
    TBLoadSQL: TToolButton;
    TBSaveSQL: TToolButton;
    TBSep3: TToolButton;
    ToolButton1: TToolButton;
    ToolButton2: TToolButton;
    TSResult: TTabSheet;
    TSData: TTabSheet;
    ToolBar1: TToolBar;
    procedure AExecuteExecute(Sender: TObject);
    procedure BExecClick(Sender: TObject);
    procedure CloseQueryClick(Sender: TObject);
    procedure HaveNextQuery(Sender: TObject);
    procedure HavePreviousQuery(Sender: TObject);
    procedure LoadQueryClick(Sender: TObject);
    procedure NextQueryClick(Sender: TObject);
    procedure OnMemoKey(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure PreviousQueryClick(Sender: TObject);
    procedure SaveQueryClick(Sender: TObject);
    procedure ExportDataClick(Sender: TObject);
    procedure CreateCodeClick(Sender: TObject);
    Procedure NotBusy(Sender: TObject);
    Procedure DataShowing(Sender: TObject);
  private
    { private declarations }
    FEngine: TFPDDEngine;
    FQueryHistory : TStrings;
    FCurrentQuery : Integer;
    FBusy : Boolean;
    FData : TDataFrame;
    procedure ClearResults;
    procedure DoExecuteQuery(Qry: String);
    procedure LocalizeFrame;
    procedure SetTableNames;
  public
  Protected
    procedure SetEngine(const AValue: TFPDDEngine);
    Function GetDataset: TDataset;
    Procedure CreateControls; virtual;
  Public
    Constructor Create(AOwner : TComponent); override;
    Destructor Destroy; override;
    procedure ExecuteQuery(Qry: String);
    procedure SaveQuery(AFileName: String);
    procedure LoadQuery(AFileName: String);
    Function AddToHistory(Qry : String) : Integer;
    Function NextQuery : Integer;
    Function PreviousQuery : Integer;
    Procedure CloseDataset;
    Procedure FreeDataset;
    Procedure ExportData;
    Procedure CreateCode;
    Procedure ActivatePanel;
    Property Dataset : TDataset Read GetDataset;
    Property Engine : TFPDDEngine Read FEngine Write SetEngine;
    Property QueryHistory : TStrings Read FQueryHistory;
    Property CurrentQuery : Integer Read FCurrentQuery;
    Property Busy : Boolean Read FBusy;
    { public declarations }
  end;

implementation

uses strutils, sqldb, fpdataexporter, fpcodegenerator;

{$r *.lfm}


constructor TQueryFrame.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FQueryHistory:=TStringList.Create;
  FCurrentQuery:=-1;
  CreateControls;
  LocalizeFrame;
end;

destructor TQueryFrame.Destroy;
begin
  FreeAndNil(FQueryHistory);
  inherited Destroy;
end;

procedure TQueryFrame.SetEngine(const AValue: TFPDDEngine);
begin
  if FEngine=AValue then exit;
  If Assigned(Dataset) then
    begin
    CloseDataset;
    FreeDataset;
    end;
  FEngine:=AValue;
  SetTableNames;
end;

procedure TQueryFrame.SetTableNames;

begin
  SQLSyn.TableNames.BeginUpdate;
  try
    SQLSyn.TableNames.Clear;
    if (FEngine=Nil) or Not (FEngine.Connected) then
       exit;
    FEngine.GetTableList(SQLSyn.TableNames);
  finally
    SQLSyn.TableNames.EndUpdate;
  end;
end;

procedure TQueryFrame.ExportDataClick(Sender: TObject);
begin
  ExportData;
end;

procedure TQueryFrame.CreateCodeClick(Sender: TObject);
begin
  CreateCode;
end;

function TQueryFrame.GetDataset: TDataset;
begin
  Result:=FData.Dataset;
end;

procedure TQueryFrame.LocalizeFrame;

begin
  // Localize
  AExecute.Caption:=SExecute;
  AExecute.Hint:=SHintExecute;
  APreviousQuery.Caption:=SPrevious;
  APreviousQuery.Hint:=SHintPrevious;
  ANextQuery.Caption:=SNext;
  ANextQuery.Hint:=SHintNext;
  ALoadSQL.Caption:=SLoad;
  ALoadSQL.Hint:=SHintLoad;
  ASaveSQL.Caption:=SSave;
  ASaveSQL.Hint:=SHintSave;
  ACloseQuery.Caption:=SClose;
  ACloseQuery.Hint:=SHintClose;
  AExport.Caption:=SExport;
  AExport.Hint:=SHintExport;
  ACreateCode.Caption:=SCreateCode;
  ACreateCode.Hint:=SHintCreateCode;
  ODSQL.Filter:=SSQLFilters;
  SDSQL.Filter:=SSQLFilters;
end;

procedure TQueryFrame.CreateControls;

begin
  FData:=TDataFrame.Create(Self);
  FData.Parent:=TSData;
  FData.Align:=alClient;
  FData.Visible:=True;
  FData.ShowExtraButtons:=False;
  MResult.Lines.Clear;
  MResult.Append(SReadyForSQL);
end;

{ ---------------------------------------------------------------------
  Callbacks
  ---------------------------------------------------------------------}

procedure TQueryFrame.OnMemoKey(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  If (Key=VK_E) and (Shift=[ssCtrl]) then
    begin
    AExecute.Execute;
    Key:=0;
    end;
end;

procedure TQueryFrame.ClearResults;

Var
  DS : TDataset;

begin
  MResult.Clear;
  DS:=Dataset;
  If Assigned(DS) then
    CloseDataset;
end;

procedure TQueryFrame.BExecClick(Sender : TObject);

begin
  ClearResults;
  ExecuteQuery(FMSQL.Lines.Text);
end;

procedure TQueryFrame.AExecuteExecute(Sender: TObject);
begin

end;

procedure TQueryFrame.CloseQueryClick(Sender : TObject);

begin
  CloseDataset;
end;

procedure TQueryFrame.NotBusy(Sender : TObject);

begin
  (Sender as TAction).Enabled:=Not FBusy;
end;

procedure TQueryFrame.DataShowing(Sender : TObject);

Var
  DS : TDataset;

begin
  DS:=Dataset;
  (Sender as TAction).Enabled:=Assigned(DS) and DS.Active;
end;

procedure TQueryFrame.HaveNextQuery(Sender : TObject);

begin
  (Sender as TAction).Enabled:=(FCurrentQuery<FQueryHistory.Count-1);
end;

procedure TQueryFrame.HavePreviousQuery(Sender : TObject);

begin
  (Sender as TAction).Enabled:=(FCurrentQuery>0);
end;

procedure TQueryFrame.NextQueryClick(Sender : TObject);

begin
  NextQuery;
end;

procedure TQueryFrame.PreviousQueryClick(Sender : TObject);

begin
  PreviousQuery;
end;

procedure TQueryFrame.LoadQueryClick(Sender : TObject);

begin
  With ODSQL do
    begin
    Options:=[ofFileMustExist];
    If Execute then
      LoadQuery(FileName);
    end;
end;

procedure TQueryFrame.SaveQueryClick(Sender : TObject);

begin
  With SDSQL.Create(Self) do
    begin
    If Execute then
      SaveQuery(FileName);
    end;
end;

{ ---------------------------------------------------------------------
  Actual commands
  ---------------------------------------------------------------------}

procedure TQueryFrame.LoadQuery(AFileName: String);

begin
  FMSQL.Lines.LoadFromFile(AFileName);
end;

function TQueryFrame.AddToHistory(Qry: String): Integer;

Var
  I : Integer;

begin
  I:=FQueryHistory.IndexOf(Qry);
  If (I=-1) then
    FCurrentQuery:=FQueryHistory.Add(Qry)
  else
    begin
    FQueryHistory.Move(I,FQueryHistory.Count-1);
    FCurrentQuery:=FQueryHistory.Count-1;
    end;
  Result:=FCurrentQuery;
end;

function TQueryFrame.NextQuery: Integer;
begin
  If FCurrentQuery<FQueryHistory.Count-1 then
    begin
    Inc(FCurrentQuery);
    FMSQL.Lines.Text:=FQueryHistory[FCurrentQuery];
    end;
  Result:=FCurrentQuery;
end;

function TQueryFrame.PreviousQuery: Integer;
begin
  If (FCurrentQuery>0) then
    begin
    Dec(FCurrentQuery);
    FMSQL.Lines.Text:=FQueryHistory[FCurrentQuery];
    end;
  Result:=FCurrentQuery;
end;


procedure TQueryFrame.SaveQuery(AFileName: String);

begin
  FMSQL.Lines.SaveToFile(AFileName);
end;

procedure TQueryFrame.DoExecuteQuery(Qry : String);

Var
  DS : TDataset;
  S,RowsAff : String;
  N : Integer;
  TS,TE : TDateTime;

begin
  RowsAff:='';
  TS:=Now;
  MResult.Append(Format(SExecutingSQLStatement,[DateTimeToStr(TS)]));
  MResult.Append(Qry);
  If Not assigned(FEngine) then
    Raise Exception.Create(SErrNoEngine);
  S:=ExtractDelimited(1,Trim(Qry),[' ',#9,#13,#10]);
  If (CompareText(S,'SELECT')<>0) then
    begin
    N:=FEngine.RunQuery(Qry);
    TE:=Now;
    If ecRowsAffected in FEngine.EngineCapabilities then
      RowsAff:=Format(SRowsAffected,[N]);
    TSData.TabVisible:=False;
    PCResult.ActivePage:=TSResult;
    end
  else
    begin
    DS:=Dataset;
    If Assigned(DS) then
      FEngine.SetQueryStatement(Qry,DS)
    else
      begin
      DS:=FEngine.CreateQuery(Qry,Self);
      FData.Dataset:=DS;
      end;
    TSData.TabVisible:=true;
    PCResult.ActivePage:=TSData;
    DS.Open;
    TE:=Now;
    RowsAff:=Format(SRecordsFetched,[DS.RecordCount]);
    end;
  MResult.Append(Format(SSQLExecutedOK,[DateTimeToStr(TE)]));
  MResult.Append(Format(SExecutionTime,[FormatDateTime('hh:nn:ss.zzz',TE-TS,[fdoInterval])]));
  if (RowsAff<>'') then
    MResult.Append(RowsAff);
  AddToHistory(Qry);
  ACloseQuery.Update;
end;

procedure TQueryFrame.ExecuteQuery(Qry : String);

Var
  Msg : String;

begin
  FBusy:=True;
  Try
    try
      DoExecuteQuery(Qry);
    except
      on Ed : ESQLDatabaseError do
        begin
        Msg:=Ed.Message;
        if Ed.ErrorCode<>0 then
          Msg:=Msg+sLineBreak+Format(SSQLErrorCode,[Ed.ErrorCode]);
        if (Ed.SQLState<>'') then
          Msg:=Msg+sLineBreak+Format(SSQLStatus,[Ed.SQLState]);
        end;
      On E : EDatabaseError do
        begin
        Msg:=E.Message;
        end;
    end;
    if (Msg<>'') then
      begin
      PCResult.ActivePage:=TSResult;
      MResult.Append(SErrorExecutingSQL);
      MResult.Append(Msg);
      end;
  Finally
    FBusy:=False;
  end;
end;

procedure TQueryFrame.CloseDataset;
begin
  FBusy:=True;
  Try
    FData.Dataset.Close;
    FData.Visible:=False;
    ACloseQuery.Update;
  Finally
    FBusy:=False;
  end;
end;

procedure TQueryFrame.FreeDataset;

Var
  D : TDataset;

begin
  D:=FData.Dataset;
  FData.Dataset:=Nil;
  D.Free;
end;



procedure TQueryFrame.ExportData;

begin
  With TFPDataExporter.Create(Dataset) do
    try
      Execute;
    finally
      Free;
    end;
end;

procedure TQueryFrame.CreateCode;
begin
  With TFPCodeGenerator.Create(Dataset) do
    try
      SQL:=FMSQL.Lines;
      DataSet:=Self.Dataset;
      Execute;
    Finally
      Free;
    end;
end;

procedure TQueryFrame.ActivatePanel;
begin
  If SQLSyn.TableNames.Count=0 then
    SetTableNames;
end;

end.
