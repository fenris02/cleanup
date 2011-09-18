#!/bin/bash

set -e

smartctl=/usr/sbin/smartctl
badblocks=/sbin/badblocks

usage() {
    echo "Usage: $( basename $0 ) device" >&2
}

[ $# -ne 1 ] && { usage ; exit 1 ; };

device="$1"

[ -b "$device" ] || { \
    echo "$device is not a valid block device" >&2 ; usage ; exit 1 ; };

for program in "$smartctl" "$badblocks" ; do
    [ -x "$program" ] || { echo "$program not found" >&2 ; exit 1 ; };
done

if [ "$( basename "$device" | sed 's/^\(..\).*$/\1/' )" = "sd" ]; then
    smartctl="$smartctl -d ata"
fi

echo "Enabling SMART..."
$smartctl -q silent -s on -S on $device || { \
    $smartctl -s on -S on $device || : ; echo "Continuing..." >&2 ; };

echo "Running checks on existing SMART data..."
$smartctl -q silent -H $device || { \
    $smartctl -H $device || : ; echo "FAIL" >&2 ; exit 1 ; };
$smartctl -q silent -l error $device || { \
    $smartctl -l error $device || : ; echo "FAIL" >&2 ; exit 1 ; };
$smartctl -q silent -l selftest $device || { \
    $smartctl -l selftest $device || : ; echo "FAIL" >&2 ; exit 1 ; };

echo "Checking polling times..."
TMP=$( mktemp /tmp/drivetest.XXXXXXXXXX ) || { \
    echo "mktemp failed" >&2 ; exit 1 ; };

$smartctl -c $device | perl \
    -e 'while (<>) { if (/^(Short|Extended|Conveyance) self-test routine/) {' \
    -e '$type=uc($1); $_=<>; $time=(/\(\s*(\d+)\)/)[0];' \
    -e 'print $type."_SLEEP=$time\n" } }' > $TMP

. $TMP

rm -f $TMP

if [ -n "$CONVEYANCE_SLEEP" ]; then
    echo "Performing conveyance test..." \
        " (This should take $CONVEYANCE_SLEEP minutes.)"
    $smartctl -q silent -t conveyance $device
    sleep ${CONVEYANCE_SLEEP}m
    $smartctl -q silent -H -l error -l selftest $device || { \
        $smartctl -H -l error -l selftest $device || : ; echo "FAIL" >&2 ; exit 1 ; };
elif [ -n "$SHORT_SLEEP" ]; then
    echo "Performing short test..." \
        " (This should take $SHORT_SLEEP minutes.)"
    $smartctl -q silent -t short $device
    sleep ${SHORT_SLEEP}m
    $smartctl -q silent -H -l error -l selftest $device || { \
        $smartctl -H -l error -l selftest $device || : ; echo "FAIL" >&2 ; exit 1 ; };
else
    echo "Skipping conveyance/short test..."
fi

echo "Performing non-destructive write test..."
$badblocks -s -n $device || { echo "FAIL" >&2 ; exit 1 ; };

if [ -n "$EXTENDED_SLEEP" ]; then
    echo "Performing extended test..." \
        " (This should take $EXTENDED_SLEEP minutes.)"
    $smartctl -q silent -t long $device
    sleep ${EXTENDED_SLEEP}m
    $smartctl -q silent -H -l error -l selftest $device || { \
        $smartctl -H -l error -l selftest $device || : ; echo "FAIL" >&2 ; exit 1 ; };
else
    echo "Skipping extended test..."
fi

echo OK
