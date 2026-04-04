##########################################################################################
# read_croc.tcl - Dynamic .flist parser for Fusion Compiler
##########################################################################################
puts "RM-info: Parsing croc.flist..."

set flist_file "./croc.flist"
set CROC_FILES ""
set CROC_DEFINES ""
set CROC_INCDIRS ""

# Read the file list
set fp [open $flist_file r]
while {[gets $fp line] >= 0} {
    set line [string trim $line]
    
    # Ignore comments and empty lines
    if {[string match "#*" $line] || $line == ""} { continue }

    # Extract include directories
    if {[string match "+incdir+*" $line]} {
        set inc [string map {"+incdir+" ""} $line]
        lappend CROC_INCDIRS "./$inc"
        
    # Extract defines/macros
    } elseif {[string match "+define+*" $line]} {
        set def [string map {"+define+" ""} $line]
        lappend CROC_DEFINES $def
        
    # Standard SystemVerilog file path
    } else {
        lappend CROC_FILES "./$line"
    }
}
close $fp

# 1. Add include directories to the tool's search path so `include works
set search_path [concat $search_path $CROC_INCDIRS]

# 2. Analyze the SystemVerilog files with the parsed defines
puts "RM-info: Analyzing RTL with defines: $CROC_DEFINES"
analyze -format sverilog -define $CROC_DEFINES $CROC_FILES

# 3. Elaborate the top module
puts "RM-info: Elaborating $DESIGN_NAME..."
elaborate $DESIGN_NAME