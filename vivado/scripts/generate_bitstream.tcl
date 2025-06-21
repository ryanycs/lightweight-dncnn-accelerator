# This script generates the bitstream for a Vivado project.

proc numberOfCPUs {} {
    # Windows puts it in an environment variable
    global tcl_platform env
    if {$tcl_platform(platform) eq "windows"} {
        return $env(NUMBER_OF_PROCESSORS)
    }

    # Check for sysctl (OSX, BSD)
    set sysctl [auto_execok "sysctl"]
    if {[llength $sysctl]} {
        if {![catch {exec {*}$sysctl -n "hw.ncpu"} cores]} {
            return $cores
        }
    }

    # Assume Linux, which has /proc/cpuinfo, but be careful
    if {![catch {open "/proc/cpuinfo"} f]} {
        set cores [regexp -all -line {^processor\s} [read $f]]
        close $f
        if {$cores > 0} {
            return $cores
        }
    }

    # No idea what the actual number of cores is; exhausted all our options
    # Fall back to returning 1; there must be at least that because we're running on it!
    return 1
}

# Open project
open_project PE_ARRAY_36.xpr

# Set top module name
update_compile_order -fileset sources_1

# Launch synthesis
launch_runs synth_1 -jobs [numberOfCPUs]
wait_on_run synth_1

# Launch implementation
launch_runs impl_1 -to_step write_bitstream -jobs [numberOfCPUs]
wait_on_run impl_1

# Copy the generated bitstream to the output directory
set output_dir "output"
set bit_files [glob -nocomplain -type f *.runs/impl_1/*.bit]
set hwh_files [glob -nocomplain -type f *.gen/sources_1/bd/design_1/hw_handoff/*.hwh]
file mkdir $output_dir
file copy -force [lindex $bit_files 0] "$output_dir/design_1.bit"
file copy -force [lindex $hwh_files 0] "$output_dir/design_1.hwh"

puts "Bitstream generation completed successfully."