#!/bin/bash
#
if [ $# -ne 2 ]; then
cat -<<EOT
Usage: $0 [BW Mbps] [RTT ms]
Example:
    $0 1.5 51
EOT
exit 1
fi
#
BANDWIDTH=$1                              #Mbps
RTT=$( echo "scale=5;  $2 / 1000." |bc )  #ms
#LOSS=$( echo "scale=5;  $3 / 100." |bc )  #percent
#LOSS=$( echo "scale=5;  0.1 / 100." |bc )  # 0.1 percent
LOSS=0.015
#
simplemath () {
    echo "" | awk 'END { exit ( !( '"$1"')); }'
}
buffcalc () {
    # $1 = Buffer size
    echo "scale=5; $1 * 8 / $RTT /1000/1000" |bc
}
mtucalc () {
    # $1 = MTU, $2 = Header size
    echo "scale=5; 0.7 * ( $1 - $2 ) * 8 / ( $RTT * sqrt($LOSS) ) /1000/1000" |bc -l
}
bits2bytes () {
    echo "scale=5; $1 / 8" |bc
}

test1=$( echo "scale=5; 0.98 * $BANDWIDTH" |bc )
MAX1=$test1; MAX2=$test1; MAX3=$test1

test2a=$( buffcalc 17520 )
simplemath "$MAX1 > $test2a" && MAX1=$test2a
test2b=$( buffcalc 262144 )
test2c=$( buffcalc 4194304 )
simplemath "$MAX2 > $test2c" && MAX2=$test2c
test2d=$( echo "scale=5; $BANDWIDTH * 1000 * 1000 / 8 * $RTT" |bc)
test2e=$( buffcalc 65535 )

test3a=$( mtucalc 1500 52 )
simplemath "$MAX1 > $test3a" && MAX1=$test3a
test3b=$( mtucalc 9000 52 )
simplemath "$MAX2 > $test3b" && MAX2=$test3b
test3c=$( echo "scale=5; ( $BANDWIDTH / 0.7 / 8 * $RTT * sqrt($LOSS) * 1000 * 1000 ) + 52" |bc -l)

test4a=$( mtucalc 1500 40 )
simplemath "$MAX3 > $test4a" && MAX3=$test4a
test4b=$( mtucalc 9000 40 )
simplemath "$MAX3 > $test4b" && MAX3=$test4b
test4c=$( echo "scale=5; ( $BANDWIDTH / 0.7 / 8 * $RTT * sqrt($LOSS) * 1000 * 1000 ) + 40" |bc -l)
simplemath "$MAX3 > $test4c" && MAX3=$test4c
test4d=$( buffcalc 65535 )
simplemath "$MAX3 > $test4d" && MAX3=$test4d

MAX1B=$( bits2bytes $MAX1 ); MAX2B=$( bits2bytes $MAX2 ); MAX3B=$( bits2bytes $MAX3 )

cat -<<EOT
Dependant upon physical line:
1) $test1 Mbps

Dependant upon buffer size and RTT:
2a) 17kB buffer: $test2a Mbps
2b) 262kB buffer: $test2b Mbps
2c) 4M buffer: $test2c Mbps
2d) Min buffer req to fill BW: $test2d b
2e) 64kB buffer: $test2e Mbps

Dependant upon MTU, RTT, and LOSS: (window scaling enabled)
3a) default MTU: $test3a Mbps
3b) 9k MTU: $test3b Mbps
3c) Min MTU req to fill BW: $test3c b

Dependant upon MTU, RTT, and LOSS: (window scaling disabled)
4a) default MTU: $test4a Mbps
4b) 9k MTU: $test4b Mbps
4c) Min MTU req to fill BW: $test4c b
4d) Max buffer (64k): $test4d Mbps

Max throughput = $MAX1 Mbps (default) or $MAX2 Mbps (fully tuned) or $MAX3 Mbps (without scaling)
Max throughput = $MAX1B MB/s (default) or $MAX2B MB/s (fully tuned) or $MAX3B MB/s (without scaling)

EOT

#EOF
