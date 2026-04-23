# gtk_skin.tcl — GTK3 (Adwaita) and GTK4 (libadwaita) skin for Tk.
#
# This file is the canonical, language-agnostic skin. The Python and Nim
# front-ends both source it into their Tk interpreter.
#
# Usage from Tcl/Tk:
#     source gtk_skin.tcl
#     gtk_skin::apply . gtk4 0            ;# root, style, dark
#     gtk_skin::headerbar .hb -title "My App"
#     pack .hb -fill x
#     gtk_skin::switch .sw
#     pack .sw
#
# All custom widgets are plain Tk canvases with bindings; no compiled
# extension is required, so this file works in every Tk 8.6+ host.

package require Tk 8.6
package require Ttk

namespace eval gtk_skin {
    # --- Palette storage ---------------------------------------------------
    # Each palette is a dict of semantic role -> color. We store four
    # palettes and copy the selected one into ::gtk_skin::p on apply.
    variable palettes
    variable p
    variable current_style "gtk4"
    variable current_dark 0

    array set palettes {}

    # --- GTK3 Adwaita Light -----------------------------------------------
    set palettes(gtk3_light) [dict create \
        name            "Adwaita"             \
        style           gtk3                  \
        dark            0                     \
        window_bg       #f6f5f4               \
        view_bg         #ffffff               \
        headerbar_bg    #ebebeb               \
        headerbar_fg    #2e3436               \
        headerbar_border #c0bfbc              \
        fg              #2e3436               \
        muted_fg        #555a5e               \
        dim_fg          #929595               \
        border          #cdc7c2               \
        strong_border   #b6b2ae               \
        button_bg       #f6f5f4               \
        button_bg_hover #f9f9f8               \
        button_bg_active #d5d0cc              \
        button_border   #cdc7c2               \
        accent          #3584e4               \
        accent_hover    #5294e8               \
        accent_active   #1c71d8               \
        accent_fg       #ffffff               \
        selection_bg    #3584e4               \
        selection_fg    #ffffff               \
        success         #26a269               \
        warning         #cd9309               \
        error           #c01c28               \
        shadow          #d8d4d0               \
        radius          3                     \
        header_height   46                    ]

    # --- GTK3 Adwaita Dark ------------------------------------------------
    set palettes(gtk3_dark) [dict merge $palettes(gtk3_light) [dict create \
        name            "Adwaita Dark"        \
        dark            1                     \
        window_bg       #353535               \
        view_bg         #2d2d2d               \
        headerbar_bg    #1f1f1f               \
        headerbar_fg    #eeeeec               \
        headerbar_border #101010              \
        fg              #eeeeec               \
        muted_fg        #c0bfbc               \
        dim_fg          #888a85               \
        border          #1b1b1b               \
        strong_border   #0e0e0e               \
        button_bg       #4a4a4a               \
        button_bg_hover #555555               \
        button_bg_active #2a2a2a              \
        button_border   #1b1b1b               \
        shadow          #1b1b1b               ]]

    # --- GTK4 libadwaita Light --------------------------------------------
    set palettes(gtk4_light) [dict create \
        name            "libadwaita"          \
        style           gtk4                  \
        dark            0                     \
        window_bg       #fafafa               \
        view_bg         #ffffff               \
        headerbar_bg    #ebebeb               \
        headerbar_fg    #1d1d1d               \
        headerbar_border #d9d9d9              \
        fg              #1d1d1d               \
        muted_fg        #5e5c64               \
        dim_fg          #9a9996               \
        border          #d9d9d9               \
        strong_border   #c0bfbc               \
        button_bg       #e8e8e7               \
        button_bg_hover #dededd               \
        button_bg_active #cecdcc              \
        button_border   #d9d9d9               \
        accent          #3584e4               \
        accent_hover    #5294e8               \
        accent_active   #1c71d8               \
        accent_fg       #ffffff               \
        selection_bg    #3584e4               \
        selection_fg    #ffffff               \
        success         #2ec27e               \
        warning         #e5a50a               \
        error           #e01b24               \
        shadow          #e0e0e0               \
        radius          9                     \
        header_height   48                    ]

    # --- GTK4 libadwaita Dark ---------------------------------------------
    set palettes(gtk4_dark) [dict merge $palettes(gtk4_light) [dict create \
        name            "libadwaita Dark"     \
        dark            1                     \
        window_bg       #242424               \
        view_bg         #1e1e1e               \
        headerbar_bg    #303030               \
        headerbar_fg    #ffffff               \
        headerbar_border #1b1b1b              \
        fg              #ffffff               \
        muted_fg        #c0bfbc               \
        dim_fg          #77767b               \
        border          #404040               \
        strong_border   #545454               \
        button_bg       #3a3a3a               \
        button_bg_hover #454545               \
        button_bg_active #2a2a2a              \
        button_border   #1b1b1b               \
        accent          #78aeed               \
        accent_hover    #8fbdf0               \
        accent_active   #5b9ce6               \
        shadow          #1a1a1a               ]]

    # --- Helpers ----------------------------------------------------------

    proc color {key} {
        variable p
        return [dict get $p $key]
    }

    proc is_dark {} {
        variable p
        return [dict get $p dark]
    }

    proc style_name {} {
        variable p
        return [dict get $p style]
    }

    # Resolve the parent window's background by walking the path lexically
    # (so it works even when the widget we're about to create doesn't exist
    # yet). Falls back to the palette's window_bg when the parent is a ttk
    # widget (which doesn't expose -background).
    proc _parent_bg {path} {
        set idx [string last "." $path]
        if {$idx <= 0} { return [color window_bg] }
        set parent [string range $path 0 [expr {$idx-1}]]
        if {![winfo exists $parent]} { return [color window_bg] }
        if {[catch {$parent cget -background} bg]} {
            # ttk widget — look up its style's -background.
            set st ""
            catch {set st [$parent cget -style]}
            if {$st eq ""} { catch {set st [winfo class $parent]} }
            if {$st ne ""} {
                set bg [ttk::style lookup $st -background]
                if {$bg ne ""} { return $bg }
            }
            return [color window_bg]
        }
        return $bg
    }

    # Pick the nicest available GTK-ish font, falling back to Tk's default.
    proc _pick_font {} {
        set preferred {Cantarell Inter "Adwaita Sans" "SF Pro Text" \
                       "Helvetica Neue" "Segoe UI Variable" "Segoe UI" "Noto Sans"}
        set avail [font families]
        foreach fam $preferred {
            if {[lsearch -exact $avail $fam] >= 0} {
                return [list $fam 11]
            }
        }
        return [list TkDefaultFont 11]
    }

    # --- apply -------------------------------------------------------------
    proc apply {{root .} {style gtk4} {dark 0}} {
        variable palettes
        variable p
        variable current_style
        variable current_dark

        set key "${style}_[expr {$dark ? "dark" : "light"}]"
        if {![info exists palettes($key)]} {
            error "gtk_skin: unknown palette $key"
        }
        set p $palettes($key)
        set current_style $style
        set current_dark $dark

        set font_pair [_pick_font]
        set family [lindex $font_pair 0]
        set size   [lindex $font_pair 1]

        # Option database defaults — affect classic tk widgets (tk::frame,
        # tk::label, tk::canvas, text, listbox, menu).
        option add *Font            [list $family $size]
        option add *Background      [color window_bg]
        option add *Foreground      [color fg]
        option add *selectBackground [color selection_bg]
        option add *selectForeground [color selection_fg]
        option add *Entry.background       [color view_bg]
        option add *Entry.foreground       [color fg]
        option add *Entry.insertBackground [color fg]
        option add *Text.background        [color view_bg]
        option add *Text.foreground        [color fg]
        option add *Text.insertBackground  [color fg]
        option add *Listbox.background     [color view_bg]
        option add *Listbox.foreground     [color fg]
        option add *Listbox.selectBackground [color selection_bg]
        option add *Listbox.selectForeground [color selection_fg]
        option add *Menu.background        [color headerbar_bg]
        option add *Menu.foreground        [color fg]
        option add *Menu.activeBackground  [color selection_bg]
        option add *Menu.activeForeground  [color selection_fg]
        option add *Menu.borderWidth       0

        if {[winfo exists $root]} {
            $root configure -background [color window_bg]
        }

        # Combobox dropdown listbox (created on demand; option add ensures
        # the nested listbox picks up our colors).
        option add *TCombobox*Listbox.background       [color view_bg]
        option add *TCombobox*Listbox.foreground       [color fg]
        option add *TCombobox*Listbox.selectBackground [color selection_bg]
        option add *TCombobox*Listbox.selectForeground [color selection_fg]
        option add *TCombobox*Listbox.borderWidth      0

        # Use clam — the only themable engine on all platforms.
        catch {ttk::style theme use clam}

        _configure_ttk $family $size
        return [dict get $p name]
    }

    # ---------------------------------------------------------------------
    # ttk style configuration
    # ---------------------------------------------------------------------
    proc _configure_ttk {family size} {
        variable p

        set base_font    [list $family $size]
        set bold_font    [list $family $size bold]
        set title_font   [list $family [expr {$size+2}] bold]
        set header_font  [list $family [expr {$size+4}] bold]

        # Root defaults
        ttk::style configure . \
            -background       [color window_bg]   \
            -foreground       [color fg]          \
            -fieldbackground  [color view_bg]     \
            -bordercolor      [color border]      \
            -lightcolor       [color border]      \
            -darkcolor        [color border]      \
            -troughcolor      [color window_bg]   \
            -selectbackground [color selection_bg]\
            -selectforeground [color selection_fg]\
            -insertcolor      [color fg]          \
            -focuscolor       [color accent]      \
            -font             $base_font

        # Frames
        ttk::style configure TFrame         -background [color window_bg]
        ttk::style configure View.TFrame    -background [color view_bg]
        ttk::style configure Card.TFrame    -background [color view_bg] \
            -bordercolor [color border] -lightcolor [color border] \
            -darkcolor [color border] -relief solid -borderwidth 1
        ttk::style configure HeaderBar.TFrame -background [color headerbar_bg]

        # Labels
        ttk::style configure TLabel         -background [color window_bg] -foreground [color fg] -font $base_font
        ttk::style configure View.TLabel    -background [color view_bg]    -foreground [color fg]
        ttk::style configure Header.TLabel  -background [color headerbar_bg] -foreground [color headerbar_fg] -font $bold_font
        ttk::style configure Title.TLabel   -background [color window_bg]  -foreground [color fg] -font $title_font
        ttk::style configure LargeTitle.TLabel -background [color window_bg] -foreground [color fg] -font $header_font
        ttk::style configure Dim.TLabel     -background [color window_bg]  -foreground [color muted_fg]
        ttk::style configure DimView.TLabel -background [color view_bg]    -foreground [color muted_fg]
        ttk::style configure Error.TLabel   -background [color window_bg]  -foreground [color error]
        ttk::style configure Success.TLabel -background [color window_bg]  -foreground [color success]

        # Buttons
        set btn_padx [expr {[style_name] eq "gtk4" ? 14 : 12}]
        set btn_pady [expr {[style_name] eq "gtk4" ? 6  : 5}]

        ttk::style configure TButton \
            -background     [color button_bg]     \
            -foreground     [color fg]            \
            -bordercolor    [color button_border] \
            -lightcolor     [color button_bg]     \
            -darkcolor      [color button_border] \
            -focusthickness 1                     \
            -focuscolor     [color accent]        \
            -padding        [list $btn_padx $btn_pady] \
            -relief         flat                  \
            -borderwidth    1                     \
            -font           $base_font
        ttk::style map TButton \
            -background [list pressed [color button_bg_active] \
                              active  [color button_bg_hover] \
                              disabled [color button_bg]] \
            -foreground [list disabled [color dim_fg]] \
            -bordercolor [list focus [color accent] active [color strong_border]] \
            -lightcolor [list pressed [color button_bg_active] \
                               active  [color button_bg_hover]]

        ttk::style configure Suggested.TButton \
            -background  [color accent]    \
            -foreground  [color accent_fg] \
            -bordercolor [color accent]    \
            -lightcolor  [color accent]    \
            -darkcolor   [color accent]    \
            -padding     [list $btn_padx $btn_pady] \
            -relief      flat              \
            -borderwidth 1                 \
            -font        $bold_font
        ttk::style map Suggested.TButton \
            -background [list pressed [color accent_active] active [color accent_hover] \
                              disabled [color button_bg]] \
            -foreground [list disabled [color dim_fg]] \
            -bordercolor [list pressed [color accent_active] active [color accent_hover]] \
            -lightcolor  [list pressed [color accent_active] active [color accent_hover]]

        ttk::style configure Destructive.TButton \
            -background  [color error] \
            -foreground  #ffffff       \
            -bordercolor [color error] \
            -lightcolor  [color error] \
            -darkcolor   [color error] \
            -padding     [list $btn_padx $btn_pady] \
            -relief      flat \
            -borderwidth 1 \
            -font        $bold_font
        ttk::style map Destructive.TButton \
            -background  [list pressed #a51d2d active #e45a62] \
            -bordercolor [list pressed #a51d2d active #e45a62] \
            -lightcolor  [list pressed #a51d2d active #e45a62]

        ttk::style configure Flat.TButton \
            -background  [color headerbar_bg] \
            -foreground  [color headerbar_fg] \
            -bordercolor [color headerbar_bg] \
            -lightcolor  [color headerbar_bg] \
            -darkcolor   [color headerbar_bg] \
            -padding     {10 6}               \
            -relief      flat -borderwidth 1  \
            -font        $base_font
        ttk::style map Flat.TButton \
            -background  [list pressed [color button_bg_active] active [color button_bg_hover]] \
            -bordercolor [list active [color border]] \
            -lightcolor  [list active [color button_bg_hover]]

        ttk::style configure Link.TButton \
            -background  [color window_bg] \
            -foreground  [color accent]    \
            -bordercolor [color window_bg] \
            -lightcolor  [color window_bg] \
            -darkcolor   [color window_bg] \
            -relief      flat -borderwidth 0 \
            -padding     {4 2} -font $base_font
        ttk::style map Link.TButton \
            -foreground [list pressed [color accent_active] active [color accent_hover]]

        # Entries / combo / spin
        ttk::style configure TEntry \
            -fieldbackground [color view_bg] \
            -foreground      [color fg]      \
            -bordercolor     [color border]  \
            -lightcolor      [color border]  \
            -darkcolor       [color border]  \
            -insertcolor     [color fg]      \
            -padding 6 -relief flat -borderwidth 1
        ttk::style map TEntry \
            -bordercolor [list focus [color accent] invalid [color error]] \
            -lightcolor  [list focus [color accent]] \
            -darkcolor   [list focus [color accent]]

        ttk::style configure TCombobox \
            -fieldbackground [color view_bg]  \
            -background      [color button_bg] \
            -foreground      [color fg]       \
            -bordercolor     [color border]   \
            -lightcolor      [color border]   \
            -darkcolor       [color border]   \
            -arrowcolor      [color muted_fg] \
            -padding 5 -relief flat
        ttk::style map TCombobox \
            -fieldbackground [list readonly [color view_bg] disabled [color window_bg]] \
            -bordercolor     [list focus [color accent] active [color strong_border]] \
            -arrowcolor      [list active [color fg] disabled [color dim_fg]]

        ttk::style configure TSpinbox \
            -fieldbackground [color view_bg]  \
            -background      [color button_bg] \
            -foreground      [color fg]       \
            -bordercolor     [color border]   \
            -lightcolor      [color border]   \
            -darkcolor       [color border]   \
            -arrowcolor      [color muted_fg] \
            -padding 5 -relief flat
        ttk::style map TSpinbox -bordercolor [list focus [color accent]]

        # Check / radio
        ttk::style configure TCheckbutton \
            -background        [color window_bg] \
            -foreground        [color fg]        \
            -focuscolor        [color accent]    \
            -indicatorcolor    [color view_bg]   \
            -indicatorbackground [color view_bg] \
            -padding 4
        ttk::style map TCheckbutton \
            -background      [list active [color window_bg]] \
            -indicatorcolor  [list selected [color accent] pressed [color accent_active]] \
            -foreground      [list disabled [color dim_fg]]

        ttk::style configure TRadiobutton \
            -background     [color window_bg] \
            -foreground     [color fg]        \
            -focuscolor     [color accent]    \
            -indicatorcolor [color view_bg]   \
            -padding 4
        ttk::style map TRadiobutton \
            -indicatorcolor [list selected [color accent] pressed [color accent_active]] \
            -background     [list active [color window_bg]]

        # Notebook
        ttk::style configure TNotebook \
            -background [color window_bg] -bordercolor [color border] \
            -lightcolor [color border] -darkcolor [color border] \
            -tabmargins {0 0 0 0}
        ttk::style configure TNotebook.Tab \
            -background  [color window_bg] \
            -foreground  [color muted_fg]  \
            -bordercolor [color window_bg] \
            -lightcolor  [color window_bg] \
            -darkcolor   [color window_bg] \
            -padding     {14 8}            \
            -font        $base_font
        ttk::style map TNotebook.Tab \
            -background  [list selected [color window_bg] active [color button_bg_hover]] \
            -foreground  [list selected [color fg] active [color fg]] \
            -bordercolor [list selected [color accent]] \
            -lightcolor  [list selected [color accent]]

        # Treeview
        set rowheight [expr {int($size * 2.4)}]
        ttk::style configure Treeview \
            -background      [color view_bg] \
            -fieldbackground [color view_bg] \
            -foreground      [color fg]      \
            -bordercolor     [color border]  \
            -lightcolor      [color border]  \
            -darkcolor       [color border]  \
            -rowheight       $rowheight      \
            -font            $base_font
        ttk::style map Treeview \
            -background [list selected [color selection_bg]] \
            -foreground [list selected [color selection_fg]]
        ttk::style configure Treeview.Heading \
            -background  [color headerbar_bg] \
            -foreground  [color headerbar_fg] \
            -bordercolor [color border] \
            -lightcolor  [color headerbar_bg] \
            -darkcolor   [color border] \
            -relief      flat \
            -padding     {8 6} \
            -font        $bold_font
        ttk::style map Treeview.Heading \
            -background [list active [color button_bg_hover]]

        # Scrollbars
        ttk::style configure TScrollbar \
            -background  [color window_bg] \
            -troughcolor [color window_bg] \
            -bordercolor [color window_bg] \
            -arrowcolor  [color muted_fg]  \
            -gripcount   0 -relief flat -borderwidth 0
        ttk::style map TScrollbar \
            -background [list active [color strong_border] !active [color border]] \
            -arrowcolor [list disabled [color dim_fg] active [color fg]]

        # Progressbar
        set pbar_thickness [expr {[style_name] eq "gtk4" ? 8 : 10}]
        ttk::style configure TProgressbar \
            -background  [color accent]    \
            -troughcolor [color button_bg] \
            -bordercolor [color border]    \
            -lightcolor  [color accent]    \
            -darkcolor   [color accent]    \
            -thickness   $pbar_thickness

        # Scale (ttk's — we recommend using gtk_skin::scale for a nicer knob)
        ttk::style configure TScale \
            -background  [color window_bg]       \
            -troughcolor [color button_bg_active] \
            -bordercolor [color border]          \
            -lightcolor  [color accent]          \
            -darkcolor   [color accent]

        ttk::style configure TSeparator   -background [color border]
        ttk::style configure TLabelframe \
            -background  [color window_bg] \
            -bordercolor [color border]    \
            -lightcolor  [color border]    \
            -darkcolor   [color border]    \
            -relief solid -borderwidth 1
        ttk::style configure TLabelframe.Label \
            -background [color window_bg] -foreground [color fg] -font $bold_font

        ttk::style configure TPanedwindow -background [color window_bg]
    }

    # ---------------------------------------------------------------------
    # Canvas primitives
    # ---------------------------------------------------------------------

    # _rounded_rect — returns the point list for a rounded rect polygon.
    proc _rounded_rect {x1 y1 x2 y2 r} {
        if {$r > ($x2 - $x1) / 2.0} { set r [expr {($x2 - $x1) / 2.0}] }
        if {$r > ($y2 - $y1) / 2.0} { set r [expr {($y2 - $y1) / 2.0}] }
        return [list \
            [expr {$x1+$r}] $y1  [expr {$x2-$r}] $y1  [expr {$x2-$r}] $y1  \
            $x2 $y1  $x2 [expr {$y1+$r}]  $x2 [expr {$y2-$r}]  \
            $x2 [expr {$y2-$r}]  $x2 $y2  [expr {$x2-$r}] $y2 \
            [expr {$x1+$r}] $y2  [expr {$x1+$r}] $y2  $x1 $y2 \
            $x1 [expr {$y2-$r}]  $x1 [expr {$y1+$r}]  $x1 [expr {$y1+$r}] \
            $x1 $y1  [expr {$x1+$r}] $y1]
    }

    proc draw_rounded_rect {canvas x1 y1 x2 y2 r args} {
        set pts [_rounded_rect $x1 $y1 $x2 $y2 $r]
        return [$canvas create polygon {*}$pts -smooth true {*}$args]
    }

    # ---------------------------------------------------------------------
    # HeaderBar
    # ---------------------------------------------------------------------
    # gtk_skin::headerbar path -title "..." -subtitle "..."
    # Creates a frame at `path`; packs .leading on the left and .trailing on
    # the right for caller to add buttons into.
    proc headerbar {path args} {
        variable p
        array set opts {-title "" -subtitle ""}
        array set opts $args

        frame $path -background [color headerbar_bg] -highlightthickness 0 -bd 0
        frame $path.border -background [color headerbar_border] -height 1
        pack $path.border -side bottom -fill x

        frame $path.inner -background [color headerbar_bg] -height [color header_height]
        pack $path.inner -fill both -expand 1
        pack propagate $path.inner 0

        frame $path.inner.leading  -background [color headerbar_bg]
        pack $path.inner.leading  -side left  -padx {8 0} -pady 6

        frame $path.inner.trailing -background [color headerbar_bg]
        pack $path.inner.trailing -side right -padx {0 8} -pady 6

        frame $path.inner.title_frame -background [color headerbar_bg]
        pack $path.inner.title_frame -expand 1

        set fam [lindex [_pick_font] 0]
        label $path.inner.title_frame.title \
            -text $opts(-title) \
            -background [color headerbar_bg] \
            -foreground [color headerbar_fg] \
            -font [list $fam 11 bold]
        pack $path.inner.title_frame.title

        if {[style_name] eq "gtk3" && $opts(-subtitle) ne ""} {
            label $path.inner.title_frame.subtitle \
                -text $opts(-subtitle) \
                -background [color headerbar_bg] \
                -foreground [color muted_fg] \
                -font [list $fam 9]
            pack $path.inner.title_frame.subtitle
        }
        return $path
    }

    proc headerbar_leading  {path} { return $path.inner.leading }
    proc headerbar_trailing {path} { return $path.inner.trailing }

    # ---------------------------------------------------------------------
    # Switch — rounded pill toggle
    # ---------------------------------------------------------------------
    # gtk_skin::switch path ?-variable name? ?-command cmd? ?-width 44? ?-height 24?
    proc switch {path args} {
        variable p
        array set opts {-variable "" -command "" -width 44 -height 24 -bg ""}
        array set opts $args

        if {$opts(-bg) eq ""} { set opts(-bg) [_parent_bg $path] }

        canvas $path -width $opts(-width) -height $opts(-height) \
            -bg $opts(-bg) -highlightthickness 0 -bd 0

        # Store state in the widget's Tcl array.
        variable switches
        set switches($path,var)     $opts(-variable)
        set switches($path,cmd)     $opts(-command)
        set switches($path,w)       $opts(-width)
        set switches($path,h)       $opts(-height)
        set switches($path,state)   0
        if {$opts(-variable) ne ""} {
            upvar #0 $opts(-variable) var
            if {[info exists var]} { set switches($path,state) [expr {!!$var}] }
            trace add variable $opts(-variable) write \
                [list ::gtk_skin::_switch_var_changed $path]
        }

        bind $path <Button-1>  [list ::gtk_skin::_switch_toggle $path]
        bind $path <Destroy>   [list ::gtk_skin::_switch_destroy $path]

        _switch_redraw $path
        return $path
    }

    proc _switch_toggle {path} {
        variable switches
        set switches($path,state) [expr {!$switches($path,state)}]
        if {$switches($path,var) ne ""} {
            upvar #0 $switches($path,var) var
            set var $switches($path,state)
        }
        _switch_redraw $path
        if {$switches($path,cmd) ne ""} {
            uplevel #0 [list {*}$switches($path,cmd) $switches($path,state)]
        }
    }

    proc _switch_var_changed {path args} {
        variable switches
        if {![info exists switches($path,var)]} return
        upvar #0 $switches($path,var) var
        set new [expr {!!$var}]
        if {$new ne $switches($path,state)} {
            set switches($path,state) $new
            _switch_redraw $path
        }
    }

    proc _switch_destroy {path} {
        variable switches
        if {[info exists switches($path,var)] && $switches($path,var) ne ""} {
            catch {trace remove variable $switches($path,var) write \
                [list ::gtk_skin::_switch_var_changed $path]}
        }
        array unset switches "$path,*"
    }

    proc _switch_redraw {path} {
        variable p
        variable switches
        if {![winfo exists $path]} return
        $path delete all
        set w $switches($path,w)
        set h $switches($path,h)
        set r [expr {$h / 2.0 - 1}]
        set state $switches($path,state)

        if {$state} {
            set track [color accent]
        } elseif {[is_dark]} {
            set track "#5a5a5a"
        } else {
            set track [color button_bg_active]
        }
        draw_rounded_rect $path 1 1 [expr {$w-1}] [expr {$h-1}] $r \
            -fill $track -outline ""

        set margin 3
        set knob_size [expr {$h - 2*$margin}]
        if {$state} {
            set x [expr {$w - $margin - $knob_size}]
        } else {
            set x $margin
        }
        $path create oval $x $margin [expr {$x+$knob_size}] [expr {$margin+$knob_size}] \
            -fill #ffffff -outline ""
    }

    # ---------------------------------------------------------------------
    # Pill button (rounded accent/flat/destructive)
    # ---------------------------------------------------------------------
    # gtk_skin::pill_button path text ?-kind accent|flat|destructive?
    #                                  ?-command cmd? ?-padx 16? ?-pady 8?
    proc pill_button {path text args} {
        variable p
        array set opts {-kind accent -command "" -padx 16 -pady 8 -bg ""}
        array set opts $args

        set fam [lindex [_pick_font] 0]
        set f [font create -family $fam -size 11 -weight bold]
        set text_w [font measure $f $text]
        set line_h [font metrics $f -linespace]
        font delete $f
        set w [expr {$text_w + $opts(-padx)*2}]
        set h [expr {$line_h + $opts(-pady)*2}]

        if {$opts(-bg) eq ""} { set opts(-bg) [_parent_bg $path] }

        canvas $path -width $w -height $h -bg $opts(-bg) \
            -highlightthickness 0 -bd 0

        variable pills
        set pills($path,text) $text
        set pills($path,kind) $opts(-kind)
        set pills($path,cmd)  $opts(-command)
        set pills($path,w)    $w
        set pills($path,h)    $h
        set pills($path,pressed) 0
        set pills($path,hover)   0

        bind $path <Button-1>        [list ::gtk_skin::_pill_press $path]
        bind $path <ButtonRelease-1> [list ::gtk_skin::_pill_release $path %x %y]
        bind $path <Enter>           [list ::gtk_skin::_pill_enter $path]
        bind $path <Leave>           [list ::gtk_skin::_pill_leave $path]
        bind $path <Destroy>         [list array unset ::gtk_skin::pills "$path,*"]

        _pill_redraw $path
        return $path
    }

    proc _pill_press   {path}       { variable pills; set pills($path,pressed) 1; _pill_redraw $path }
    proc _pill_enter   {path}       { variable pills; set pills($path,hover) 1;   _pill_redraw $path }
    proc _pill_leave   {path}       {
        variable pills
        set pills($path,hover) 0
        set pills($path,pressed) 0
        _pill_redraw $path
    }
    proc _pill_release {path x y} {
        variable pills
        set was $pills($path,pressed)
        set pills($path,pressed) 0
        _pill_redraw $path
        if {$was && $x >= 0 && $x <= $pills($path,w) && $y >= 0 && $y <= $pills($path,h)} {
            if {$pills($path,cmd) ne ""} { uplevel #0 $pills($path,cmd) }
        }
    }

    proc _pill_colors {path} {
        variable p
        variable pills
        set kind $pills($path,kind)
        set hover $pills($path,hover)
        set pressed $pills($path,pressed)
        # Qualified ::switch — our namespace defines a `switch` proc for the
        # toggle widget, which would shadow the builtin here.
        ::switch -- $kind {
            accent {
                if {$pressed} { return [list [color accent_active] [color accent_fg]] }
                if {$hover}   { return [list [color accent_hover]  [color accent_fg]] }
                return [list [color accent] [color accent_fg]]
            }
            destructive {
                if {$pressed} { return [list #a51d2d #ffffff] }
                if {$hover}   { return [list #e45a62 #ffffff] }
                return [list [color error] #ffffff]
            }
            default {
                if {$pressed} { return [list [color button_bg_active] [color fg]] }
                if {$hover}   { return [list [color button_bg_hover]  [color fg]] }
                return [list [color button_bg] [color fg]]
            }
        }
    }

    proc _pill_redraw {path} {
        variable p
        variable pills
        if {![winfo exists $path]} return
        $path delete all
        lassign [_pill_colors $path] bg fg
        set w $pills($path,w)
        set h $pills($path,h)
        set r [expr {$h/2.0}]
        set max_r [expr {[color radius] + ([style_name] eq "gtk4" ? 6 : 2)}]
        if {$r > $max_r} { set r $max_r }
        draw_rounded_rect $path 1 1 [expr {$w-1}] [expr {$h-1}] $r -fill $bg -outline ""
        set fam [lindex [_pick_font] 0]
        $path create text [expr {$w/2.0}] [expr {$h/2.0}] \
            -text $pills($path,text) -fill $fg \
            -font [list $fam 11 bold]
    }

    # ---------------------------------------------------------------------
    # Radio — GNOME-style
    # ---------------------------------------------------------------------
    proc radio {path text args} {
        variable p
        array set opts {-variable "" -value "" -command ""}
        array set opts $args
        if {$opts(-variable) eq ""} { error "radio: -variable required" }

        set bg [_parent_bg $path]

        frame $path -background $bg -bd 0 -highlightthickness 0
        canvas $path.ind -width 18 -height 18 -bg $bg -highlightthickness 0 -bd 0
        set fam [lindex [_pick_font] 0]
        label $path.lbl -text $text -background $bg -foreground [color fg] \
            -font [list $fam 11]
        pack $path.ind -side left -padx {0 8}
        pack $path.lbl -side left

        variable radios
        set radios($path,var)     $opts(-variable)
        set radios($path,value)   $opts(-value)
        set radios($path,cmd)     $opts(-command)
        set radios($path,hover)   0

        foreach w [list $path $path.ind $path.lbl] {
            bind $w <Button-1> [list ::gtk_skin::_radio_select $path]
            bind $w <Enter>    [list ::gtk_skin::_radio_enter  $path]
            bind $w <Leave>    [list ::gtk_skin::_radio_leave  $path]
        }

        trace add variable $opts(-variable) write \
            [list ::gtk_skin::_radio_var_changed $path]
        bind $path <Destroy> [list ::gtk_skin::_radio_destroy $path]

        _radio_redraw $path
        return $path
    }

    proc _radio_select {path} {
        variable radios
        upvar #0 $radios($path,var) var
        set var $radios($path,value)
        if {$radios($path,cmd) ne ""} { uplevel #0 $radios($path,cmd) }
    }
    proc _radio_enter  {path} { variable radios; set radios($path,hover) 1; _radio_redraw $path }
    proc _radio_leave  {path} { variable radios; set radios($path,hover) 0; _radio_redraw $path }
    proc _radio_var_changed {path args} { _radio_redraw $path }
    proc _radio_destroy {path} {
        variable radios
        catch {trace remove variable $radios($path,var) write \
            [list ::gtk_skin::_radio_var_changed $path]}
        array unset radios "$path,*"
    }

    proc _radio_redraw {path} {
        variable p
        variable radios
        if {![winfo exists $path.ind]} return
        set c $path.ind
        $c delete all
        upvar #0 $radios($path,var) var
        set selected [expr {[info exists var] && $var eq $radios($path,value)}]

        if {$selected} {
            set border [color accent]
            set fill   [color accent]
        } elseif {$radios($path,hover)} {
            set border [color strong_border]
            set fill   [color view_bg]
        } else {
            set border [color border]
            set fill   [color view_bg]
        }
        $c create oval 1 1 17 17 -outline $border -width 2 -fill $fill
        if {$selected} {
            $c create oval 6 6 12 12 -fill #ffffff -outline ""
        }
    }

    # ---------------------------------------------------------------------
    # Check — GNOME-style
    # ---------------------------------------------------------------------
    proc check {path text args} {
        variable p
        array set opts {-variable "" -command ""}
        array set opts $args
        if {$opts(-variable) eq ""} { error "check: -variable required" }

        set bg [_parent_bg $path]

        frame $path -background $bg -bd 0 -highlightthickness 0
        canvas $path.ind -width 18 -height 18 -bg $bg -highlightthickness 0 -bd 0
        set fam [lindex [_pick_font] 0]
        label $path.lbl -text $text -background $bg -foreground [color fg] \
            -font [list $fam 11]
        pack $path.ind -side left -padx {0 8}
        pack $path.lbl -side left

        variable checks
        set checks($path,var)   $opts(-variable)
        set checks($path,cmd)   $opts(-command)
        set checks($path,hover) 0

        foreach w [list $path $path.ind $path.lbl] {
            bind $w <Button-1> [list ::gtk_skin::_check_toggle $path]
            bind $w <Enter>    [list ::gtk_skin::_check_enter  $path]
            bind $w <Leave>    [list ::gtk_skin::_check_leave  $path]
        }
        trace add variable $opts(-variable) write \
            [list ::gtk_skin::_check_var_changed $path]
        bind $path <Destroy> [list ::gtk_skin::_check_destroy $path]
        _check_redraw $path
        return $path
    }

    proc _check_toggle {path} {
        variable checks
        upvar #0 $checks($path,var) var
        set var [expr {![info exists var] || !$var}]
        if {$checks($path,cmd) ne ""} { uplevel #0 [list {*}$checks($path,cmd) $var] }
    }
    proc _check_enter  {path} { variable checks; set checks($path,hover) 1; _check_redraw $path }
    proc _check_leave  {path} { variable checks; set checks($path,hover) 0; _check_redraw $path }
    proc _check_var_changed {path args} { _check_redraw $path }
    proc _check_destroy {path} {
        variable checks
        catch {trace remove variable $checks($path,var) write \
            [list ::gtk_skin::_check_var_changed $path]}
        array unset checks "$path,*"
    }

    proc _check_redraw {path} {
        variable p
        variable checks
        if {![winfo exists $path.ind]} return
        set c $path.ind
        $c delete all
        upvar #0 $checks($path,var) var
        set checked [expr {[info exists var] && $var}]
        if {$checked} {
            set border [color accent];  set fill [color accent]
        } elseif {$checks($path,hover)} {
            set border [color strong_border]; set fill [color view_bg]
        } else {
            set border [color border]; set fill [color view_bg]
        }
        draw_rounded_rect $c 1 1 17 17 4 -fill $fill -outline $border -width 2
        if {$checked} {
            $c create line 5 9 8 12 13 6 -fill #ffffff -width 2 -capstyle round
        }
    }

    # ---------------------------------------------------------------------
    # Scale — GNOME-style slider
    # ---------------------------------------------------------------------
    proc scale {path args} {
        variable p
        array set opts {-from 0 -to 100 -value 0 -variable "" -length 220 -command ""}
        array set opts $args

        set bg [_parent_bg $path]

        canvas $path -width $opts(-length) -height 22 \
            -bg $bg -highlightthickness 0 -bd 0

        variable scales
        set scales($path,from)     $opts(-from)
        set scales($path,to)       $opts(-to)
        set scales($path,length)   $opts(-length)
        set scales($path,var)      $opts(-variable)
        set scales($path,cmd)      $opts(-command)
        set scales($path,dragging) 0
        set scales($path,hover)    0
        if {$opts(-variable) ne ""} {
            upvar #0 $opts(-variable) v
            if {[info exists v]} { set scales($path,value) $v } \
            else                 { set scales($path,value) $opts(-value); set v $opts(-value) }
            trace add variable $opts(-variable) write \
                [list ::gtk_skin::_scale_var_changed $path]
        } else {
            set scales($path,value) $opts(-value)
        }

        bind $path <Button-1>         [list ::gtk_skin::_scale_press $path %x]
        bind $path <B1-Motion>        [list ::gtk_skin::_scale_drag  $path %x]
        bind $path <ButtonRelease-1>  [list ::gtk_skin::_scale_release $path]
        bind $path <Enter>            [list ::gtk_skin::_scale_enter $path]
        bind $path <Leave>            [list ::gtk_skin::_scale_leave $path]
        bind $path <Configure>        [list ::gtk_skin::_scale_configure $path %w]
        bind $path <Destroy>          [list ::gtk_skin::_scale_destroy $path]

        _scale_redraw $path
        return $path
    }

    proc _scale_knob_r {}    { return 8 }
    proc _scale_val2x {path v} {
        variable scales
        set r [_scale_knob_r]
        set usable [expr {$scales($path,length) - 2*$r}]
        if {$scales($path,to) == $scales($path,from)} { return $r }
        return [expr {$r + ($v - $scales($path,from)) / \
                     double($scales($path,to) - $scales($path,from)) * $usable}]
    }
    proc _scale_x2val {path x} {
        variable scales
        set r [_scale_knob_r]
        set usable [expr {$scales($path,length) - 2*$r}]
        if {$usable <= 0} { return $scales($path,from) }
        set t [expr {($x - $r) / double($usable)}]
        if {$t < 0} { set t 0 }
        if {$t > 1} { set t 1 }
        return [expr {$scales($path,from) + $t * ($scales($path,to) - $scales($path,from))}]
    }

    proc _scale_set {path v} {
        variable scales
        if {$v < $scales($path,from)} { set v $scales($path,from) }
        if {$v > $scales($path,to)}   { set v $scales($path,to) }
        if {$v == $scales($path,value)} return
        set scales($path,value) $v
        if {$scales($path,var) ne ""} {
            upvar #0 $scales($path,var) var
            set var $v
        }
        _scale_redraw $path
        if {$scales($path,cmd) ne ""} {
            uplevel #0 [list {*}$scales($path,cmd) $v]
        }
    }

    proc _scale_press    {path x} { variable scales; set scales($path,dragging) 1; _scale_set $path [_scale_x2val $path $x] }
    proc _scale_drag     {path x} { variable scales; if {$scales($path,dragging)} { _scale_set $path [_scale_x2val $path $x] } }
    proc _scale_release  {path}   { variable scales; set scales($path,dragging) 0; _scale_redraw $path }
    proc _scale_enter    {path}   { variable scales; set scales($path,hover) 1; _scale_redraw $path }
    proc _scale_leave    {path}   { variable scales; set scales($path,hover) 0; _scale_redraw $path }
    proc _scale_configure {path w} { variable scales; set scales($path,length) $w; _scale_redraw $path }
    proc _scale_var_changed {path args} {
        variable scales
        upvar #0 $scales($path,var) var
        if {[info exists var] && $var ne $scales($path,value)} {
            set scales($path,value) $var
            _scale_redraw $path
        }
    }
    proc _scale_destroy {path} {
        variable scales
        if {[info exists scales($path,var)] && $scales($path,var) ne ""} {
            catch {trace remove variable $scales($path,var) write \
                [list ::gtk_skin::_scale_var_changed $path]}
        }
        array unset scales "$path,*"
    }

    # Mix hex_color toward white by amount.
    proc _lighten {hex amount} {
        set h [string trimleft $hex "#"]
        scan [string range $h 0 1] %x r
        scan [string range $h 2 3] %x g
        scan [string range $h 4 5] %x b
        set r [expr {int($r + (255 - $r) * $amount)}]
        set g [expr {int($g + (255 - $g) * $amount)}]
        set b [expr {int($b + (255 - $b) * $amount)}]
        return [format "#%02x%02x%02x" $r $g $b]
    }

    proc _scale_redraw {path} {
        variable p
        variable scales
        if {![winfo exists $path]} return
        $path delete all
        set r [_scale_knob_r]
        set h 22
        set mid [expr {$h/2.0}]
        set trough 5
        set x_left $r
        set x_right [expr {$scales($path,length) - $r}]
        set knob_x [_scale_val2x $path $scales($path,value)]

        draw_rounded_rect $path $x_left [expr {$mid - $trough/2.0}] \
            $x_right [expr {$mid + $trough/2.0}] [expr {$trough/2.0}] \
            -fill [color button_bg_active] -outline ""
        if {$knob_x > $x_left} {
            draw_rounded_rect $path $x_left [expr {$mid - $trough/2.0}] \
                $knob_x [expr {$mid + $trough/2.0}] [expr {$trough/2.0}] \
                -fill [color accent] -outline ""
        }
        if {$scales($path,hover) || $scales($path,dragging)} {
            set halo [_lighten [color accent] 0.82]
            $path create oval \
                [expr {$knob_x - $r - 3}] [expr {$mid - $r - 3}] \
                [expr {$knob_x + $r + 3}] [expr {$mid + $r + 3}] \
                -fill $halo -outline ""
        }
        set knob_border [expr {[is_dark] ? "#1a1a1a" : [color strong_border]}]
        $path create oval \
            [expr {$knob_x - $r}] [expr {$mid - $r}] \
            [expr {$knob_x + $r}] [expr {$mid + $r}] \
            -fill #ffffff -outline $knob_border -width 1
    }

    # ---------------------------------------------------------------------
    # Avatar — circular initials
    # ---------------------------------------------------------------------
    proc avatar {path text args} {
        variable p
        array set opts {-size 40 -color ""}
        array set opts $args
        if {$opts(-color) eq ""} { set opts(-color) [color accent] }

        set bg [_parent_bg $path]

        set s $opts(-size)
        canvas $path -width $s -height $s -bg $bg -highlightthickness 0 -bd 0
        $path create oval 1 1 [expr {$s-1}] [expr {$s-1}] -fill $opts(-color) -outline ""
        set fam [lindex [_pick_font] 0]
        set initials [string toupper [string range $text 0 1]]
        $path create text [expr {$s/2.0}] [expr {$s/2.0 + 1}] \
            -text $initials -fill [color accent_fg] \
            -font [list $fam [expr {int($s * 0.4)}] bold]
        return $path
    }

    # ---------------------------------------------------------------------
    # Separator
    # ---------------------------------------------------------------------
    proc separator {path args} {
        variable p
        array set opts {-orient horizontal}
        array set opts $args
        if {$opts(-orient) eq "horizontal"} {
            frame $path -background [color border] -height 1 -bd 0 -highlightthickness 0
        } else {
            frame $path -background [color border] -width 1 -bd 0 -highlightthickness 0
        }
        return $path
    }

    namespace export apply headerbar headerbar_leading headerbar_trailing \
        switch pill_button radio check scale avatar separator color
}
