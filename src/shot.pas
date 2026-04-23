{ Launch the demo in a given palette, raise the window, screenshot its
  rect, quit. Used to generate documentation screenshots. }
program shot;

{$mode objfpc}{$H+}

uses
  SysUtils, Process, StrUtils, ctypes,
  TkGtkSkin, TclTkBindings;

var
  i: Integer;
  arg, key, val: string;
  style: TGtkStyle;
  dark: Boolean;
  outPath: string;
  eqPos: Integer;
  app: TTkApp;
  rx, ry, rw, rh: Integer;
  rect, stdout_str: string;
  proc: TProcess;
begin
  style := Gtk4;
  dark := False;
  outPath := '/tmp/fpc_demo.png';

  for i := 1 to ParamCount do
  begin
    arg := ParamStr(i);
    if not StartsStr('--', arg) then continue;
    eqPos := Pos('=', arg);
    if eqPos > 0 then
    begin
      key := Copy(arg, 3, eqPos - 3);
      val := Copy(arg, eqPos + 1, MaxInt);
    end
    else
    begin
      key := Copy(arg, 3, MaxInt);
      val := '';
    end;
    case key of
      'style':
        if val = 'gtk3' then style := Gtk3 else style := Gtk4;
      'dark':  dark := True;
      'out':   outPath := val;
    end;
  end;

  app := TTkApp.Create(style, dark, 'GTK Skin (FPC)', 780, 620);
  try
    // Minimal sample UI — a header bar + a few widgets, enough to show the
    // skin works from FPC.
    app.HeaderBar('.hb', 'Hello from FPC', 'Tk + GTK skin');
    app.Eval(
      'ttk::button .hb.inner.trailing.menu -text "⋮" -style Flat.TButton -width 3'#10 +
      'pack .hb.inner.trailing.menu -side right -padx 4'#10 +
      'pack .hb -fill x'#10 +
      'ttk::frame .body -padding 24'#10 +
      'pack .body -fill both -expand 1'#10 +
      'ttk::label .body.t -text "It works." -style LargeTitle.TLabel'#10 +
      'pack .body.t -pady {12 4}'#10 +
      'ttk::label .body.b -justify center -text "This window is rendered by Free Pascal code\ncalling into Tcl/Tk, themed by the shared gtk_skin.tcl."'#10 +
      'pack .body.b -pady {0 20}'#10 +
      'ttk::frame .body.row'#10 +
      'pack .body.row -pady 10'#10 +
      'ttk::button .body.row.ok -text "Got it" -style Suggested.TButton'#10 +
      'ttk::button .body.row.more -text "Tell me more" -style Link.TButton'#10 +
      'pack .body.row.ok .body.row.more -side left -padx 6'#10 +
      'set ::notifications 1');
    app.Check('.body.c1', 'Enable notifications', 'notifications');
    app.Eval('pack .body.c1 -pady 6');
    app.Scale('.body.s1', 0, 100, 60, 320, 'volume');
    app.Eval('pack .body.s1 -pady 10');

    app.Eval('wm attributes . -topmost 1');
    app.Eval('update idletasks');
    app.Eval('update');

    rx := StrToInt(app.Eval('winfo rootx .'));
    ry := StrToInt(app.Eval('winfo rooty .'));
    rw := StrToInt(app.Eval('winfo width .'));
    rh := StrToInt(app.Eval('winfo height .'));
    rect := Format('%d,%d,%d,%d', [rx-24, ry-24, rw+48, rh+48]);

    proc := TProcess.Create(nil);
    try
      proc.Executable := 'screencapture';
      proc.Parameters.Add('-x');
      proc.Parameters.Add('-R');
      proc.Parameters.Add(rect);
      proc.Parameters.Add(outPath);
      proc.Options := [poWaitOnExit];
      proc.Execute;
    finally
      proc.Free;
    end;
    WriteLn('saved ', outPath);
  finally
    app.Free;
  end;
end.
