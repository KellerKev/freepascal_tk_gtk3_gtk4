{
  TkGtkSkin — friendly wrapper around TclTkBindings plus the GTK skin.

  Typical use:
    var app := TTkApp.Create(Gtk4, False);
    app.HeaderBar('.hb', 'My App', '');
    app.Eval('pack .hb -fill x');
    app.Switch('.sw', 'darkMode');
    app.Run;

  Run raises TkError on Tcl errors; all Eval calls also raise on failure so
  the caller doesn't need to poll return codes.
}
unit TkGtkSkin;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Classes, Math, ctypes, Generics.Collections,
  TclTkBindings;

type
  TGtkStyle = (Gtk3, Gtk4);

  TkError = class(Exception);

  { Void-no-arg click handler, typed as a method so it carries a Self. }
  TProcedure = procedure of object;

  { Signature for Pascal procs invoked from Tcl. args[0] is the command
    name itself (dropped); args[1..] are the invocation arguments. Return
    an empty string for void callbacks. }
  TTkCallback = function(const args: array of string): string of object;

  { --- TTkApp ------------------------------------------------------------ }

  TTkApp = class
  private
    FInterp: PTclInterp;
    FCallbacks: specialize TDictionary<string, TTkCallback>;
    FNextId: Integer;
    procedure Bail(const prefix: string);
  public
    constructor Create(style: TGtkStyle = Gtk4; dark: Boolean = False;
                       const title: string = 'FPC Tk GTK';
                       width: Integer = 780; height: Integer = 620);
    destructor Destroy; override;

    function Eval(const script: string): string;
    procedure EvalFile(const path: string);

    { Register a Pascal method as a Tcl command. Returns the actual command
      name (auto-generated if `name` is empty). }
    function Cmd(const name: string; fn: TTkCallback): string;

    { Convenience for void-no-arg handlers (`-command` clicks). }
    function OnClick(fn: TProcedure): string;

    { (Re-)apply skin at runtime. }
    procedure ApplySkin(style: TGtkStyle; dark: Boolean);

    procedure Run;

    { -- high-level widget constructors -- }
    procedure HeaderBar(const path, title: string; const subtitle: string = '');
    procedure Switch(const path: string; const variable: string = '';
                     const command: string = '');
    procedure PillButton(const path, text: string; const kind: string = 'accent';
                         const command: string = '');
    procedure Radio(const path, text, variable, value: string;
                    const command: string = '');
    procedure Check(const path, text, variable: string;
                    const command: string = '');
    procedure Scale(const path: string; fromVal, toVal, value: Double;
                    length: Integer = 220; const variable: string = '';
                    const command: string = '');
    procedure Avatar(const path, text: string; size: Integer = 40;
                     const color: string = '');

    property Interp: PTclInterp read FInterp;
  end;

implementation

uses
  StrUtils;

{ Callback trampoline — registered as the same Tcl command for every Pascal
  callback. The per-call dispatch looks up the Pascal routine by name in
  the app's FCallbacks table. }
function TrampolineProc(clientData: Pointer; interp: PTclInterp;
                        objc: cint; objv: Pointer): cint; cdecl;
var
  app: TTkApp;
  args: array of string;
  i: Integer;
  cbName: string;
  cb: TTkCallback;
  userArgs: array of string;
  ret: string;
begin
  app := TTkApp(clientData);
  SetLength(args, objc);
  for i := 0 to objc - 1 do
    args[i] := string(Tcl_GetString(TclObjAt(objv, i)));

  cbName := args[0];
  if not app.FCallbacks.TryGetValue(cbName, cb) then
  begin
    Tcl_SetResult(interp, PChar('unknown Pascal callback: ' + cbName), nil);
    Result := TCL_ERROR;
    Exit;
  end;

  SetLength(userArgs, Length(args) - 1);
  for i := 1 to High(args) do
    userArgs[i - 1] := args[i];

  try
    ret := cb(userArgs);
    if ret <> '' then
      Tcl_SetResult(interp, PChar(ret), nil);
    Result := TCL_OK;
  except
    on E: Exception do
    begin
      Tcl_SetResult(interp, PChar('Pascal callback error: ' + E.Message), nil);
      Result := TCL_ERROR;
    end;
  end;
end;

{ --- TTkApp ------------------------------------------------------------- }

procedure TTkApp.Bail(const prefix: string);
begin
  raise TkError.Create(prefix + ': ' + string(Tcl_GetStringResult(FInterp)));
end;

function TTkApp.Eval(const script: string): string;
var
  rc: cint;
begin
  rc := Tcl_Eval(FInterp, PChar(script));
  if rc <> TCL_OK then
    Bail('Tcl error in eval');
  Result := string(Tcl_GetStringResult(FInterp));
end;

procedure TTkApp.EvalFile(const path: string);
begin
  if Tcl_EvalFile(FInterp, PChar(path)) <> TCL_OK then
    Bail('Tcl error loading ' + path);
end;

function TTkApp.Cmd(const name: string; fn: TTkCallback): string;
var
  actual: string;
begin
  actual := name;
  if actual = '' then
  begin
    Inc(FNextId);
    actual := 'pas_cb_' + IntToStr(FNextId);
  end;
  FCallbacks.AddOrSetValue(actual, fn);
  Tcl_CreateObjCommand(FInterp, PChar(actual),
                       @TrampolineProc, Self, nil);
  Result := actual;
end;

{ Helper: wrap a plain TProcedure as a TTkCallback.
  We can't use a closure directly — Pascal method pointers need an object —
  so we use a tiny adapter class. }
type
  TOnClickAdapter = class
    FProc: TProcedure;
    function Invoke(const args: array of string): string;
  end;

function TOnClickAdapter.Invoke(const args: array of string): string;
begin
  FProc;
  Result := '';
end;

function TTkApp.OnClick(fn: TProcedure): string;
var
  a: TOnClickAdapter;
begin
  a := TOnClickAdapter.Create;
  a.FProc := fn;
  // NOTE: adapter is leaked for app lifetime — fine for a demo; a real
  // library would track adapters in the app for cleanup on destruction.
  Result := Cmd('', @a.Invoke);
end;

procedure TTkApp.ApplySkin(style: TGtkStyle; dark: Boolean);
var
  styleArg, darkArg: string;
begin
  styleArg := IfThen(style = Gtk3, 'gtk3', 'gtk4');
  darkArg := IfThen(dark, '1', '0');
  Eval(Format('gtk_skin::apply . %s %s', [styleArg, darkArg]));
end;

function LocateSkinFile: string;
var
  exeDir: string;
  candidates: array of string;
  i: Integer;
begin
  exeDir := ExtractFilePath(ParamStr(0));
  SetLength(candidates, 4);
  candidates[0] := exeDir + 'resources/gtk_skin.tcl';
  candidates[1] := exeDir + '../resources/gtk_skin.tcl';
  candidates[2] := GetCurrentDir + '/resources/gtk_skin.tcl';
  candidates[3] := exeDir + 'gtk_skin.tcl';
  for i := 0 to High(candidates) do
    if FileExists(candidates[i]) then
    begin
      Result := candidates[i];
      Exit;
    end;
  raise TkError.Create('Could not find resources/gtk_skin.tcl near executable or CWD');
end;

constructor TTkApp.Create(style: TGtkStyle; dark: Boolean; const title: string;
                          width, height: Integer);
begin
  inherited Create;
  // macOS fix: FPC enables FP exception traps by default; AppKit's
  // NSWindow init paths through _NSGetCGFloatAppConfig perform FP ops that
  // would trap (EXC_BAD_INSTRUCTION) with those masks. Disable them before
  // touching Tk so Tk_Init can create the root NSWindow.
  SetExceptionMask([exInvalidOp, exDenormalized, exZeroDivide,
                    exOverflow, exUnderflow, exPrecision]);

  FCallbacks := specialize TDictionary<string, TTkCallback>.Create;
  FNextId := 0;
  // Tcl_FindExecutable tells Tcl/Tk where we are on disk so it can find
  // matching support files in ../lib/tcl8.6 and ../lib/tk8.6 relative paths.
  Tcl_FindExecutable(PChar(ParamStr(0)));
  FInterp := Tcl_CreateInterp;
  if FInterp = nil then
    raise TkError.Create('Tcl_CreateInterp returned nil');
  if Tcl_Init(FInterp) <> TCL_OK then Bail('Tcl_Init failed');
  if Tk_Init(FInterp)  <> TCL_OK then Bail('Tk_Init failed');

  EvalFile(LocateSkinFile);
  ApplySkin(style, dark);
  Eval(Format('wm title . {%s}', [title]));
  Eval(Format('wm geometry . %dx%d', [width, height]));
end;

destructor TTkApp.Destroy;
begin
  if FInterp <> nil then
  begin
    Tcl_DeleteInterp(FInterp);
    FInterp := nil;
  end;
  FCallbacks.Free;
  inherited Destroy;
end;

procedure TTkApp.Run;
begin
  Tk_MainLoop;
end;

{ --- Widget constructors ------------------------------------------------- }

procedure TTkApp.HeaderBar(const path, title: string; const subtitle: string);
begin
  Eval(Format('gtk_skin::headerbar %s -title {%s} -subtitle {%s}',
              [path, title, subtitle]));
end;

procedure TTkApp.Switch(const path: string; const variable, command: string);
var opts: string;
begin
  opts := '';
  if variable <> '' then opts := opts + ' -variable ' + variable;
  if command  <> '' then opts := opts + ' -command '  + command;
  Eval('gtk_skin::switch ' + path + opts);
end;

procedure TTkApp.PillButton(const path, text: string; const kind, command: string);
var opts: string;
begin
  opts := ' -kind ' + kind;
  if command <> '' then opts := opts + ' -command ' + command;
  Eval(Format('gtk_skin::pill_button %s {%s}%s', [path, text, opts]));
end;

procedure TTkApp.Radio(const path, text, variable, value: string; const command: string);
var opts: string;
begin
  opts := Format(' -variable %s -value {%s}', [variable, value]);
  if command <> '' then opts := opts + ' -command ' + command;
  Eval(Format('gtk_skin::radio %s {%s}%s', [path, text, opts]));
end;

procedure TTkApp.Check(const path, text, variable: string; const command: string);
var opts: string;
begin
  opts := ' -variable ' + variable;
  if command <> '' then opts := opts + ' -command ' + command;
  Eval(Format('gtk_skin::check %s {%s}%s', [path, text, opts]));
end;

procedure TTkApp.Scale(const path: string; fromVal, toVal, value: Double;
                       length: Integer; const variable, command: string);
var opts: string;
begin
  opts := Format(' -from %g -to %g -value %g -length %d',
                 [fromVal, toVal, value, length]);
  if variable <> '' then opts := opts + ' -variable ' + variable;
  if command  <> '' then opts := opts + ' -command '  + command;
  Eval('gtk_skin::scale ' + path + opts);
end;

procedure TTkApp.Avatar(const path, text: string; size: Integer; const color: string);
var opts: string;
begin
  opts := ' -size ' + IntToStr(size);
  if color <> '' then opts := opts + ' -color ' + color;
  Eval(Format('gtk_skin::avatar %s {%s}%s', [path, text, opts]));
end;

end.
