onbreak {quit -code 1}
onerror {quit -code 1}
onfinish stop
run -all
set status [coverage attribute -name TESTSTATUS]
if {$status >= 1} {
    quit -code 1
} else {
    quit -code 0
}