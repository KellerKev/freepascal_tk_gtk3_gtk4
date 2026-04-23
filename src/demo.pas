{
  FPC + Tk + GTK skin demo. Mirrors the Python and Nim demos.

  Run with:
    pixi run demo              # GTK4 light (default)
    pixi run demo3             # GTK3 Adwaita
    pixi run demo4             # GTK4 libadwaita
    pixi run demo-dark         # GTK4 dark
}
program demo;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, StrUtils,
  TkGtkSkin;

type
  TOptions = record
    Style: TGtkStyle;
    Dark: Boolean;
  end;

  { Thin wrapper to hold the App so we can write buildDemo-style callbacks
    without cluttering the top-level program. }
  TDemo = class
    App: TTkApp;
    Opts: TOptions;
    constructor Create(const AOpts: TOptions);
    procedure Build;
    procedure BuildHeader;
    procedure BuildNotebook;
    procedure BuildGeneralTab;
    procedure BuildControlsTab;
    procedure BuildAboutTab;
    procedure BuildFooter;
    { Footer callbacks: rebuild with a new palette. }
    procedure ToggleDark;
    procedure SelectGtk3;
    procedure SelectGtk4;
    procedure Rebuild;
  end;

{ --- Argument parsing --------------------------------------------------- }

function ParseArgs: TOptions;
var
  i: Integer;
  arg, key, val: string;
  eqPos: Integer;
begin
  Result.Style := Gtk4;
  Result.Dark  := False;
  for i := 1 to ParamCount do
  begin
    arg := ParamStr(i);
    if StartsStr('--', arg) then
    begin
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
          if val = 'gtk3' then Result.Style := Gtk3 else Result.Style := Gtk4;
        'dark':  Result.Dark := True;
        'light': Result.Dark := False;
        'help':
          begin
            WriteLn('usage: demo [--style=gtk3|gtk4] [--dark]');
            Halt(0);
          end;
      end;
    end;
  end;
end;

{ --- TDemo -------------------------------------------------------------- }

constructor TDemo.Create(const AOpts: TOptions);
begin
  inherited Create;
  Opts := AOpts;
  App := TTkApp.Create(Opts.Style, Opts.Dark, 'GTK Skin (FPC)', 780, 620);
end;

procedure TDemo.ToggleDark;
begin
  Opts.Dark := not Opts.Dark;
  Rebuild;
end;

procedure TDemo.SelectGtk3;
begin
  Opts.Style := Gtk3;
  Rebuild;
end;

procedure TDemo.SelectGtk4;
begin
  Opts.Style := Gtk4;
  Rebuild;
end;

procedure TDemo.Rebuild;
begin
  App.Eval('foreach w [winfo children .] { destroy $w }');
  App.ApplySkin(Opts.Style, Opts.Dark);
  Build;
end;

procedure TDemo.Build;
var paletteName: string;
begin
  paletteName := App.Eval('gtk_skin::color name');
  App.Eval(Format('wm title . {GTK Skin (FPC) — %s}', [paletteName]));
  BuildHeader;
  BuildNotebook;
  BuildFooter;
end;

procedure TDemo.BuildHeader;
begin
  App.HeaderBar('.hb', 'Preferences', 'Demo of the FPC Tk GTK skin');
  App.Eval(
    'ttk::button .hb.inner.leading.menu -text "☰" -style Flat.TButton -width 3'#10 +
    'pack .hb.inner.leading.menu -side left'#10 +
    'ttk::button .hb.inner.trailing.search -text "⌕" -style Flat.TButton -width 3'#10 +
    'ttk::button .hb.inner.trailing.more   -text "⋮" -style Flat.TButton -width 3'#10 +
    'pack .hb.inner.trailing.search .hb.inner.trailing.more -side left -padx 2'#10 +
    'pack .hb -fill x');
end;

procedure TDemo.BuildNotebook;
begin
  App.Eval('ttk::notebook .nb; pack .nb -fill both -expand 1 -padx 16 -pady 16');
  BuildGeneralTab;
  BuildControlsTab;
  BuildAboutTab;
end;

procedure TDemo.BuildGeneralTab;
begin
  App.Eval(
    'ttk::frame .nb.general -padding {4 12}'#10 +
    '.nb add .nb.general -text General'#10 +
    'ttk::label .nb.general.h1 -text Appearance -style Title.TLabel'#10 +
    'pack .nb.general.h1 -anchor w -pady {0 8}'#10 +
    'ttk::frame .nb.general.card -style Card.TFrame'#10 +
    'pack .nb.general.card -fill x -pady {0 20}'#10 +
    'set ::darkMode 0'#10 +
    'set ::reduceMotion 0'#10 +
    // first row
    'ttk::frame .nb.general.card.r1 -style View.TFrame'#10 +
    'pack .nb.general.card.r1 -fill x'#10 +
    'ttk::frame .nb.general.card.r1.lbls -style View.TFrame'#10 +
    'pack .nb.general.card.r1.lbls -side left -padx 14 -pady 10 -fill x -expand 1'#10 +
    'ttk::label .nb.general.card.r1.lbls.t -text "Dark mode" -style View.TLabel -font {TkDefaultFont 11 bold}'#10 +
    'ttk::label .nb.general.card.r1.lbls.s -text "Use a dark color palette throughout the app" -style DimView.TLabel'#10 +
    'pack .nb.general.card.r1.lbls.t -anchor w'#10 +
    'pack .nb.general.card.r1.lbls.s -anchor w');
  App.Switch('.nb.general.card.r1.sw', 'darkMode');
  App.Eval('pack .nb.general.card.r1.sw -side right -padx 14 -pady 10');

  App.Eval(
    'frame .nb.general.card.sep1 -background [gtk_skin::color border] -height 1'#10 +
    'pack .nb.general.card.sep1 -fill x'#10 +
    'ttk::frame .nb.general.card.r2 -style View.TFrame'#10 +
    'pack .nb.general.card.r2 -fill x'#10 +
    'ttk::frame .nb.general.card.r2.lbls -style View.TFrame'#10 +
    'pack .nb.general.card.r2.lbls -side left -padx 14 -pady 10 -fill x -expand 1'#10 +
    'ttk::label .nb.general.card.r2.lbls.t -text "Reduce animations" -style View.TLabel -font {TkDefaultFont 11 bold}'#10 +
    'ttk::label .nb.general.card.r2.lbls.s -text "Turn off non-essential motion" -style DimView.TLabel'#10 +
    'pack .nb.general.card.r2.lbls.t -anchor w'#10 +
    'pack .nb.general.card.r2.lbls.s -anchor w');
  App.Switch('.nb.general.card.r2.sw', 'reduceMotion');
  App.Eval('pack .nb.general.card.r2.sw -side right -padx 14 -pady 10');

  // account card
  App.Eval(
    'ttk::label .nb.general.h2 -text Account -style Title.TLabel'#10 +
    'pack .nb.general.h2 -anchor w -pady {0 8}'#10 +
    'ttk::frame .nb.general.acc -style Card.TFrame'#10 +
    'pack .nb.general.acc -fill x'#10 +
    'ttk::frame .nb.general.acc.me -style View.TFrame'#10 +
    'pack .nb.general.acc.me -fill x');
  App.Avatar('.nb.general.acc.me.av', 'KK', 44);
  App.Eval(
    'pack .nb.general.acc.me.av -side left -padx {14 12} -pady 12'#10 +
    'ttk::button .nb.general.acc.me.out -text "Sign out" -style Flat.TButton'#10 +
    'pack .nb.general.acc.me.out -side right -padx {8 14} -pady 12'#10 +
    'ttk::frame .nb.general.acc.me.meta -style View.TFrame'#10 +
    'pack .nb.general.acc.me.meta -side left -fill x -expand 1 -pady 12'#10 +
    'ttk::label .nb.general.acc.me.meta.n -text "Kevin Keller" -style View.TLabel -font {TkDefaultFont 12 bold}'#10 +
    'ttk::label .nb.general.acc.me.meta.e -text "kevin@fineupp.com" -style DimView.TLabel'#10 +
    'pack .nb.general.acc.me.meta.n -anchor w'#10 +
    'pack .nb.general.acc.me.meta.e -anchor w');
end;

procedure TDemo.BuildControlsTab;
begin
  App.Eval(
    'ttk::frame .nb.ctl -padding 16'#10 +
    '.nb add .nb.ctl -text Controls'#10 +
    'ttk::label .nb.ctl.h1 -text Buttons -style Title.TLabel'#10 +
    'grid .nb.ctl.h1 -row 0 -column 0 -sticky w -pady {0 8} -columnspan 3'#10 +
    'ttk::frame .nb.ctl.bts'#10 +
    'grid .nb.ctl.bts -row 1 -column 0 -sticky w -columnspan 3 -pady {0 20}'#10 +
    'ttk::button .nb.ctl.bts.a -text Default'#10 +
    'ttk::button .nb.ctl.bts.b -text Save   -style Suggested.TButton'#10 +
    'ttk::button .nb.ctl.bts.c -text Delete -style Destructive.TButton'#10 +
    'ttk::button .nb.ctl.bts.d -text "Learn more" -style Link.TButton'#10 +
    'pack .nb.ctl.bts.a .nb.ctl.bts.b .nb.ctl.bts.c .nb.ctl.bts.d -side left -padx 4');
  App.PillButton('.nb.ctl.bts.e', 'Pill', 'accent');
  App.PillButton('.nb.ctl.bts.f', 'Neutral', 'flat');
  App.Eval(
    'pack .nb.ctl.bts.e .nb.ctl.bts.f -side left -padx 4'#10 +
    'ttk::label .nb.ctl.h2 -text "Text input" -style Title.TLabel'#10 +
    'grid .nb.ctl.h2 -row 2 -column 0 -sticky w -pady {0 8} -columnspan 3'#10 +
    'ttk::label .nb.ctl.nl -text Name'#10 +
    'grid .nb.ctl.nl -row 3 -column 0 -sticky w -padx {0 8}'#10 +
    'ttk::entry .nb.ctl.ne -width 28'#10 +
    '.nb.ctl.ne insert 0 Kevin'#10 +
    'grid .nb.ctl.ne -row 3 -column 1 -sticky w -pady 3'#10 +
    'ttk::label .nb.ctl.ll -text Language'#10 +
    'grid .nb.ctl.ll -row 5 -column 0 -sticky w -padx {0 8}'#10 +
    'ttk::combobox .nb.ctl.le -values {English French German 日本語} -state readonly -width 26'#10 +
    '.nb.ctl.le current 0'#10 +
    'grid .nb.ctl.le -row 5 -column 1 -sticky w -pady 3'#10 +
    'ttk::separator .nb.ctl.sep -orient horizontal'#10 +
    'grid .nb.ctl.sep -row 6 -column 0 -columnspan 3 -sticky ew -pady 16'#10 +
    'ttk::label .nb.ctl.h3 -text Toggles -style Title.TLabel'#10 +
    'grid .nb.ctl.h3 -row 7 -column 0 -sticky w -pady {0 8} -columnspan 3'#10 +
    'set ::notif 1'#10 +
    'set ::updates 0'#10 +
    'set ::mode balanced'#10 +
    'set ::volume 60');
  App.Check('.nb.ctl.c1', 'Enable notifications', 'notif');
  App.Check('.nb.ctl.c2', 'Auto-update apps',     'updates');
  App.Eval(
    'grid .nb.ctl.c1 -row 8 -column 0 -sticky w'#10 +
    'grid .nb.ctl.c2 -row 8 -column 1 -sticky w');
  App.Radio('.nb.ctl.r1', 'Performance', 'mode', 'perf');
  App.Radio('.nb.ctl.r2', 'Balanced',    'mode', 'balanced');
  App.Radio('.nb.ctl.r3', 'Power saver', 'mode', 'power');
  App.Eval(
    'grid .nb.ctl.r1 -row 9 -column 0 -sticky w -pady 4'#10 +
    'grid .nb.ctl.r2 -row 9 -column 1 -sticky w -pady 4'#10 +
    'grid .nb.ctl.r3 -row 9 -column 2 -sticky w -pady 4'#10 +
    'ttk::label .nb.ctl.vl -text Volume'#10 +
    'grid .nb.ctl.vl -row 10 -column 0 -sticky w -pady {12 0}');
  App.Scale('.nb.ctl.vs', 0, 100, 60, 240, 'volume');
  App.Eval(
    'grid .nb.ctl.vs -row 10 -column 1 -sticky w -columnspan 2 -pady {12 0}'#10 +
    'ttk::label .nb.ctl.sp -text "Sync progress"'#10 +
    'grid .nb.ctl.sp -row 11 -column 0 -sticky w -pady {8 0}'#10 +
    'ttk::progressbar .nb.ctl.sb -mode determinate -value 60 -length 240'#10 +
    'grid .nb.ctl.sb -row 11 -column 1 -sticky w -columnspan 2 -pady {8 0}');
end;

procedure TDemo.BuildAboutTab;
begin
  App.Eval(
    'ttk::frame .nb.about -padding 32'#10 +
    '.nb add .nb.about -text About');
  App.Avatar('.nb.about.av', 'GS', 72);
  App.Eval(
    'pack .nb.about.av -pady {12 12}'#10 +
    'ttk::label .nb.about.t -text "GTK Skin for FPC + Tk" -style LargeTitle.TLabel'#10 +
    'pack .nb.about.t'#10 +
    'ttk::label .nb.about.v -text "Version 0.1.0" -style Dim.TLabel'#10 +
    'pack .nb.about.v -pady {0 16}'#10 +
    'ttk::label .nb.about.body -justify center -text "Free Pascal bindings for Tcl/Tk plus the shared gtk_skin.tcl.\nThe same .tcl file is used by the Python and Nim sister projects."'#10 +
    'pack .nb.about.body -pady {0 20}'#10 +
    'ttk::frame .nb.about.row'#10 +
    'pack .nb.about.row'#10 +
    'ttk::button .nb.about.row.w -text Website        -style Link.TButton'#10 +
    'ttk::button .nb.about.row.r -text "Report issue" -style Link.TButton'#10 +
    'pack .nb.about.row.w .nb.about.row.r -side left -padx 6');
end;

procedure TDemo.BuildFooter;
var
  toggleCmd, gtk3Cmd, gtk4Cmd, darkLabel, paletteName: string;
begin
  paletteName := App.Eval('gtk_skin::color name');
  toggleCmd := App.OnClick(@Self.ToggleDark);
  gtk3Cmd   := App.OnClick(@Self.SelectGtk3);
  gtk4Cmd   := App.OnClick(@Self.SelectGtk4);
  darkLabel := IfThen(Opts.Dark, 'Light', 'Dark');

  App.Eval(Format(
    'ttk::frame .foot'#10 +
    'ttk::label .foot.name -text {Theme: %s} -style Dim.TLabel'#10 +
    'pack .foot.name -side left'#10 +
    'ttk::button .foot.gtk3  -text GTK3 -command %s'#10 +
    'ttk::button .foot.gtk4  -text GTK4 -command %s'#10 +
    'ttk::button .foot.theme -text %s -style Suggested.TButton -command %s'#10 +
    'pack .foot.gtk3  -side right -padx 4'#10 +
    'pack .foot.gtk4  -side right -padx 4'#10 +
    'pack .foot.theme -side right -padx 4'#10 +
    'pack .foot -fill x -side bottom -padx 16 -pady {0 16}',
    [paletteName, gtk3Cmd, gtk4Cmd, darkLabel, toggleCmd]));
end;

var
  opts: TOptions;
  app: TDemo;
begin
  opts := ParseArgs;
  app := TDemo.Create(opts);
  try
    app.Build;
    // Raise and focus the window so it's visible on top when launched from
    // a terminal — command-line binaries on macOS don't get keyboard focus
    // by default.
    app.App.Eval('wm attributes . -topmost 1; update idletasks; raise .; ' +
                 'after 200 {wm attributes . -topmost 0}');
    app.App.Run;
  finally
    app.App.Free;
    app.Free;
  end;
end.
