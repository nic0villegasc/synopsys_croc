set log_file "../logs/floorplan.log" ;
set fp [open $log_file r]

# Clear existing highlights
gui_remove_all_annotations

set count 0

while {[gets $fp line] >= 0} {
    # Look for the bbox pattern in the PGR-599 warnings
    if {[regexp {bbox \(([\d\.]+)\s+([\d\.]+)\)\(([\d\.]+)\s+([\d\.]+)\)} $line match llx lly urx ury]} {
        
        # Format the coordinates as required by gui_add_annotation: {{llx lly} {urx ury}}
        set points [list [list $llx $lly] [list $urx $ury]]
        
        # Add a yellow rectangle annotation to the GUI
        gui_add_annotation -type rect -color yellow $points
        
        incr count
    }
}

close $fp
puts "Finished highlighting all error locations."