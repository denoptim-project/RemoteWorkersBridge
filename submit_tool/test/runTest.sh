#!/bin/bash
#
# Runs a test of the submit tool using the current configuration.
# If no configuration file is found, it stops.
#

testDir="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
cd "$testDir"

if [ -f ../../configuration ]
then
    python ../submit.py -i "fileIn.sdf fileIn.jd" -d 1 -x 10 -t s -K t 
else
    echo "ERROR! To run the test you need to configure the tool. Add ../../configuration file and fill it with your personal settings."
    exit -1
fi

if [ -f "dummy_output" ]; then
    echo "Test PASSED!"
fi
rm dummy_output
