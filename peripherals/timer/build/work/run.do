onbreak {quit -code 1}; onerror {quit -code 1}; onfinish stop; run -all; if {[coverage attribute -name TESTSTATUS] >= 1} {quit -code 1} else {quit -code 0}
