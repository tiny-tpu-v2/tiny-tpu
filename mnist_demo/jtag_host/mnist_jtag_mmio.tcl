# ABOUTME: Provides System Console Tcl commands for JTAG MMIO control of the DE1-SoC MNIST interface.
# ABOUTME: Supports health checks, register reads/writes, image writes, and one-shot inference triggers.
set CTRL_ADDR 0x00000000
set STATUS_ADDR 0x00000004
set RESULT_ADDR 0x00000008
set VERSION_ADDR 0x0000000C
set IMAGE_BASE_ADDR 0x00000100
set IMAGE_PIXELS 784

proc parse_int {value} {
    return [expr {$value + 0}]
}

proc connect_master {{retries 20} {delay_ms 200}} {
    for {set attempt 0} {$attempt < $retries} {incr attempt} {
        set paths [get_service_paths master]
        if {[llength $paths] > 0} {
            return [lindex $paths 0]
        }
        after $delay_ms
    }
    return ""
}

proc read32 {master_path addr} {
    set value [lindex [master_read_32 $master_path $addr 1] 0]
    return [expr {$value & 0xFFFFFFFF}]
}

proc write32 {master_path addr value} {
    master_write_32 $master_path $addr [expr {$value & 0xFFFFFFFF}]
}

proc status_read {master_path status_addr} {
    return [read32 $master_path $status_addr]
}

proc write_bits_file {master_path path image_base_addr image_pixels verify} {
    set fh [open $path r]
    set bit_list {}
    set index 0
    while {[gets $fh line] >= 0} {
        set trimmed [string trim $line]
        if {$trimmed eq ""} {
            continue
        }
        if {$trimmed ne "0" && $trimmed ne "1"} {
            close $fh
            error "invalid bit value '$trimmed' at index $index in $path"
        }
        if {$index >= $image_pixels} {
            close $fh
            error "too many bits in $path: expected $image_pixels"
        }

        set addr [expr {$image_base_addr + ($index * 4)}]
        write32 $master_path $addr [expr {$trimmed + 0}]
        lappend bit_list [expr {$trimmed + 0}]
        incr index
    }
    close $fh

    if {$index != $image_pixels} {
        error "bit count mismatch in $path: expected $image_pixels got $index"
    }

    if {$verify} {
        for {set i 0} {$i < $image_pixels} {incr i} {
            set addr [expr {$image_base_addr + ($i * 4)}]
            set expected [lindex $bit_list $i]
            set got [expr {[read32 $master_path $addr] & 1}]
            if {$got != $expected} {
                error [format "readback mismatch at pixel %d expected=%d got=%d" $i $expected $got]
            }
        }
    }

    puts [format "WRITE_BITS_OK count=%d verify=%d" $index $verify]
}

proc predict_bits_file {master_path path timeout_ms verify} {
    global CTRL_ADDR
    global STATUS_ADDR
    global RESULT_ADDR
    global IMAGE_BASE_ADDR
    global IMAGE_PIXELS

    write_bits_file $master_path $path $IMAGE_BASE_ADDR $IMAGE_PIXELS $verify

    write32 $master_path $CTRL_ADDR 0x00000001

    set done 0
    set polls 0
    set status 0
    for {set i 0} {$i < $timeout_ms} {incr i} {
        set status [status_read $master_path $STATUS_ADDR]
        incr polls
        if {$status & 0x2} {
            set done 1
            break
        }
        after 1
    }

    if {!$done} {
        error [format "timeout waiting for done (status=0x%08X polls=%d)" $status $polls]
    }

    set result [read32 $master_path $RESULT_ADDR]
    set digit [expr {$result & 0xF}]
    puts [format "PREDICTION %d" $digit]
    puts [format "STATUS 0x%08X" $status]
    puts [format "RESULT 0x%08X" $result]
}

proc run_single_command {master_path command argv_values} {
    global CTRL_ADDR
    global STATUS_ADDR
    global RESULT_ADDR
    global VERSION_ADDR
    global IMAGE_BASE_ADDR
    global IMAGE_PIXELS

    if {$command eq "health"} {
        set version [read32 $master_path $VERSION_ADDR]
        set status [read32 $master_path $STATUS_ADDR]
        puts [format "MASTER %s" $master_path]
        puts [format "VERSION 0x%08X" $version]
        puts [format "STATUS 0x%08X" $status]
    } elseif {$command eq "read32"} {
        if {[llength $argv_values] != 2} {
            error "usage: read32 <addr>"
        }
        set addr [parse_int [lindex $argv_values 1]]
        set value [read32 $master_path $addr]
        puts [format "READ32 0x%08X 0x%08X" $addr $value]
    } elseif {$command eq "write32"} {
        if {[llength $argv_values] != 3} {
            error "usage: write32 <addr> <value>"
        }
        set addr [parse_int [lindex $argv_values 1]]
        set value [parse_int [lindex $argv_values 2]]
        write32 $master_path $addr $value
        puts [format "WRITE32 0x%08X 0x%08X" $addr [expr {$value & 0xFFFFFFFF}]]
    } elseif {$command eq "status"} {
        set status [read32 $master_path $STATUS_ADDR]
        puts [format "STATUS 0x%08X" $status]
    } elseif {$command eq "result"} {
        set result [read32 $master_path $RESULT_ADDR]
        puts [format "RESULT 0x%08X" $result]
    } elseif {$command eq "clear"} {
        write32 $master_path $CTRL_ADDR 0x00000002
        puts "CLEAR_OK"
    } elseif {$command eq "start"} {
        write32 $master_path $CTRL_ADDR 0x00000001
        puts "START_OK"
    } elseif {$command eq "write_bits"} {
        if {[llength $argv_values] < 2 || [llength $argv_values] > 3} {
            error "usage: write_bits <bits_file> [verify]"
        }
        set path [lindex $argv_values 1]
        set verify 0
        if {[llength $argv_values] == 3} {
            set verify [expr {[lindex $argv_values 2] + 0}]
        }
        write_bits_file $master_path $path $IMAGE_BASE_ADDR $IMAGE_PIXELS $verify
    } elseif {$command eq "predict_bits"} {
        if {[llength $argv_values] < 2 || [llength $argv_values] > 4} {
            error "usage: predict_bits <bits_file> [timeout_ms] [verify]"
        }
        set path [lindex $argv_values 1]
        set timeout_ms 5000
        set verify 1
        if {[llength $argv_values] >= 3} {
            set timeout_ms [expr {[lindex $argv_values 2] + 0}]
        }
        if {[llength $argv_values] == 4} {
            set verify [expr {[lindex $argv_values 3] + 0}]
        }
        predict_bits_file $master_path $path $timeout_ms $verify
    } else {
        error "unknown command: $command"
    }
}

proc run_server_loop {master_path} {
    global VERSION_ADDR
    global STATUS_ADDR

    puts "SERVER_READY"
    flush stdout

    while {1} {
        set read_len [gets stdin line]
        if {$read_len < 0} {
            if {[eof stdin]} {
                break
            }
            after 10
            continue
        }

        set trimmed [string trim $line]
        if {$trimmed eq ""} {
            continue
        }

        set fields [split $trimmed "\t"]
        set op [string toupper [lindex $fields 0]]

        puts "BEGIN $op"
        if {$op eq "PING"} {
            puts "PONG"
            puts "OK"
            puts "END $op"
            flush stdout
            continue
        }
        if {$op eq "QUIT"} {
            puts "OK"
            puts "END $op"
            flush stdout
            break
        }

        if {[catch {
            if {$op eq "HEALTH"} {
                set version [read32 $master_path $VERSION_ADDR]
                set status [read32 $master_path $STATUS_ADDR]
                puts [format "VERSION 0x%08X" $version]
                puts [format "STATUS 0x%08X" $status]
            } elseif {$op eq "WRITE_BITS"} {
                if {[llength $fields] < 2 || [llength $fields] > 3} {
                    error "usage: WRITE_BITS<TAB><bits_file><TAB>[verify]"
                }
                set verify 0
                if {[llength $fields] == 3} {
                    set verify [expr {[lindex $fields 2] + 0}]
                }
                write_bits_file $master_path [lindex $fields 1] $::IMAGE_BASE_ADDR $::IMAGE_PIXELS $verify
            } elseif {$op eq "PREDICT_BITS"} {
                if {[llength $fields] < 2 || [llength $fields] > 4} {
                    error "usage: PREDICT_BITS<TAB><bits_file><TAB>[timeout_ms]<TAB>[verify]"
                }
                set path [lindex $fields 1]
                set timeout_ms 5000
                set verify 1
                if {[llength $fields] >= 3} {
                    set timeout_ms [expr {[lindex $fields 2] + 0}]
                }
                if {[llength $fields] == 4} {
                    set verify [expr {[lindex $fields 3] + 0}]
                }
                predict_bits_file $master_path $path $timeout_ms $verify
            } else {
                error "unknown server op: $op"
            }
            puts "OK"
        } error_msg]} {
            puts [format "ERROR %s" $error_msg]
        }
        puts "END $op"
        flush stdout
    }
}

if {[llength $argv] < 1} {
    error "usage: mnist_jtag_mmio.tcl <command> [args]"
}

set command [string tolower [lindex $argv 0]]
set master_path [connect_master]
if {$master_path eq ""} {
    error "no master service found"
}
open_service master $master_path

if {$command eq "server"} {
    run_server_loop $master_path
} else {
    run_single_command $master_path $command $argv
}

close_service master $master_path
