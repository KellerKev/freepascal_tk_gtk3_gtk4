{
  TclTkBindings — raw FFI declarations for Tcl 8.6 and Tk 8.6.

  We bind only what the high-level API uses: interpreter lifecycle, Eval,
  result retrieval, command registration (for Pascal callbacks), and the
  Tk main loop.

  Libraries are located via the linker `-L$CONDA_PREFIX/lib` flag passed
  in build.sh; the runtime DYLD_LIBRARY_PATH (set by pixi activation)
  makes sure the dylibs are found at execution time.
}
unit TclTkBindings;

{$mode objfpc}{$H+}

interface

uses
  ctypes;

const
  {$IFDEF DARWIN}
    TCL_LIB = 'libtcl8.6.dylib';
    TK_LIB  = 'libtk8.6.dylib';
  {$ENDIF}
  {$IFDEF LINUX}
    TCL_LIB = 'libtcl8.6.so';
    TK_LIB  = 'libtk8.6.so';
  {$ENDIF}
  {$IFDEF WINDOWS}
    TCL_LIB = 'tcl86.dll';
    TK_LIB  = 'tk86.dll';
  {$ENDIF}

  TCL_OK       = 0;
  TCL_ERROR    = 1;
  TCL_RETURN   = 2;
  TCL_BREAK    = 3;
  TCL_CONTINUE = 4;

type
  { Opaque structs — we only ever hold pointers to them. }
  PTclInterp = Pointer;
  PTclObj    = Pointer;

  { objv is actually `Tcl_Obj *const *` in C, which we keep opaque as a raw
    Pointer and index via TclObjAt below. }
  TTclObjCmdProc = function(clientData: Pointer; interp: PTclInterp;
                            objc: cint; objv: Pointer): cint; cdecl;

  TTclCmdDeleteProc = procedure(clientData: Pointer); cdecl;

{ --- Interpreter lifecycle ------------------------------------------------- }

{ Must be called before Tcl_CreateInterp on macOS for Tk to find its
  support files and for NSApplication to initialize correctly. }
procedure Tcl_FindExecutable(argv0: PChar); cdecl; external TCL_LIB;

function Tcl_CreateInterp(): PTclInterp; cdecl; external TCL_LIB;
procedure Tcl_DeleteInterp(interp: PTclInterp); cdecl; external TCL_LIB;
function Tcl_Init(interp: PTclInterp): cint; cdecl; external TCL_LIB;
function Tk_Init(interp: PTclInterp): cint; cdecl; external TK_LIB;

{ --- Evaluating scripts ---------------------------------------------------- }

function Tcl_Eval(interp: PTclInterp; script: PChar): cint; cdecl;
  external TCL_LIB;
function Tcl_EvalFile(interp: PTclInterp; fileName: PChar): cint; cdecl;
  external TCL_LIB;

function Tcl_GetStringResult(interp: PTclInterp): PChar; cdecl;
  external TCL_LIB;
procedure Tcl_SetResult(interp: PTclInterp; msg: PChar; freeProc: Pointer);
  cdecl; external TCL_LIB;

function Tcl_GetString(objPtr: PTclObj): PChar; cdecl; external TCL_LIB;

{ --- Command registration -------------------------------------------------- }

function Tcl_CreateObjCommand(interp: PTclInterp; cmdName: PChar;
                              prc: Pointer; clientData: Pointer;
                              deleteProc: Pointer): Pointer; cdecl;
  external TCL_LIB;
function Tcl_DeleteCommand(interp: PTclInterp; cmdName: PChar): cint; cdecl;
  external TCL_LIB;

{ --- Main loop ------------------------------------------------------------- }

procedure Tk_MainLoop(); cdecl; external TK_LIB;
function Tcl_DoOneEvent(flags: cint): cint; cdecl; external TCL_LIB;

const
  TCL_ALL_EVENTS = -1;
  TCL_DONT_WAIT  = 2;

{ --- Helper: index into objv ---------------------------------------------- }

{ Returns the i-th Tcl_Obj pointer from a C `Tcl_Obj *const *` array. }
function TclObjAt(objv: Pointer; i: Integer): PTclObj;

{ $cdecl / ctypes bridging: cint. We alias it as Integer here since
  FPC's Integer is 32-bit on all our target platforms, which matches cint. }

implementation

function TclObjAt(objv: Pointer; i: Integer): PTclObj;
var
  arr: ^PTclObj;
begin
  arr := objv;
  Result := (arr + i)^;
end;

end.
