#!/bin/bash 
#
# Jobscript reserved for testing the submission to remote machinery. It doesn't really
# submit anuthing, but it created a dummy output to be recollected back to the client
# which sent the request to run a job on a remote worker.
#
# Usage:
# ======
#
# ./thisScriptName.sh <jobID>
#
# where <jobID> is the ID number of the job (an integer number).
#

#get input
if [ "$#" -ne 1 ]
then
    echo " ERROR! This script must be executed with one argument: the job ID."
    exit 1
fi

#define variables
jobid="${1}"
jobname="job$jobid"
myIP=$(curl ifconfig.me/ip)
myDir="$(dirname "$0")"
wDirParent="$("$myDir/../utils/parseConfiguration.sh" -f "$myDir/../configuration" -i "$myIP" -o w | head -n 1 )"
if [ -z "$wDirParent" ] || [ ! -d "$wDirParent" ]; then
    echo "ERROR! I could not get the work directory from the configuration file"
    exit 1
fi
wdir="$wDirParent/$jobname"
jobscript="$wdir/$jobname.job"

walltime="2"

#prepare master job script
ls 
cat<<EOF>"$jobscript"
#!/bin/bash -l
# Test job script
cd "$wdir"
echo "This is the dummy output file" > dummy_output
echo jobid $jobid >> dummy_output
echo jobname $jobname >> dummy_output
echo myIP $myIP >> dummy_output
echo myDir $myDir >> dummy_output
echo wDirParent $wDirParent >> dummy_output
echo wdir $wdir >> dummy_output
echo jobscript $jobscript >> dummy_output

echo "dummy_output" > "$wdir/tc_$jobid"
exit 0
EOF

# Run the job script
chmod u+x "$jobscript"
chmod o-rwx "$jobscript"
bash "$jobscript"

exit 0
