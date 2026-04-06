source [file dirname [info script]]/setup.tcl

if {[sizeof_collection [current_lib -quiet]] == 0} {
  open_lib $DESIGN_LIBRARY
} else {
  close_blocks -purge -force [get_blocks]
}