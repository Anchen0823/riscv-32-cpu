set proj_dir [get_property DIRECTORY [current_project]]
set root_dir [file normalize [file join $proj_dir ..]]
set srcset [get_filesets sources_1]

foreach src [list fpga_top.v CLK_DIV.v] {
    set src_path [file normalize [file join $root_dir $src]]
    if {[llength [get_files -quiet $src_path]] == 0} {
        add_files -fileset $srcset -norecurse $src_path
    }
}

foreach src [list fpga_top.v CLK_DIV.v dm.v seg7x16.v SCPU.v ctrl.v alu.v RF.v] {
    set src_path [file normalize [file join $root_dir $src]]
    set files [get_files -quiet $src_path]
    if {[llength $files] != 0} {
        set_property used_in_synthesis true $files
        set_property used_in_implementation true $files
    }
}

set_property top IP2SOC_Top $srcset
update_compile_order -fileset sources_1

if {[llength [get_filesets -quiet sim_1]] != 0} {
    set_property top IP2SOC_Top [get_filesets sim_1]
    update_compile_order -fileset sim_1
}

puts "Top module is now: [get_property top $srcset]"
