#!/bin/bash 
#
# Jobscript reserved for remote execution of AutoCompChem jobs consisting of 
# one or more low-cpu-cost subjobs (e.g., xTB). 
# The script must 
# be submitted with one and only one argument, which is the ID number of the job
# and must be an integer.
#
# We expect some SDF input file named *_XTB.sdf and from any of such files we take
# the string used to name this job. The string is the furst part of those filenames
# cosidering '_' as separator.
# For example: for filename BLABLA_XTB.sdf the job name will be 'BLABLA'
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
myIP=$(curl -s -4 ifconfig.me/ip)
myDir="$(dirname "$0")"
wDirParent="$("$myDir/../utils/parseConfiguration.sh" -f "$myDir/../configuration" -i "$myIP" -k xtb -o w)"
if [ -z "$wDirParent" ] || [ ! -d "$wDirParent" ]; then
    echo "WARNING: Configuration for '$myIP' not found. Trying with 'localhost'"
    wDirParent="$("$myDir/../utils/parseConfiguration.sh" -f "$myDir/../configuration" -i "localhost" -o w | head -n 1 )"
    if [ -z "$wDirParent" ] || [ ! -d "$wDirParent" ]; then
      echo "ERROR! I could not get the work directory from the configuration file"
      exit 1
    fi
fi
wdir="$wDirParent/$jobname"
jobscript="$wdir/$jobname.job"
jobSubmissionCommand="submit_job_acc"
#parameters for actual runs
nodes="1"
cores="32"
walltime="12"

#prepare master job script
cat<<EOF>"$jobscript"
#!/bin/bash -l
# Job script for "$jobname"

# Define variables
wdir="$wdir"
jobid="$jobid"
jobname="$jobname"
logFile="$jobname.log"
tclFile="tc_$jobid"

# Move to job's home directory
cd "\$wdir"

# Log info
echo "Submitting job \$jobname" > "\$logFile"
echo "User: \$USER" >> "\$logFile"
machine=\`hostname\`
echo "Machine: \$machine" >> "\$logFile"
datetime=\$(date)
echo "Date: \$datetime" >> "\$logFile"

# Get reference name
sdfFile="\$(ls *_XTB.sdf | tail -n 1)"
molName="\$(echo \$sdfFile  | awk -F '_' '{print \$1}')"
echo "Working with molecule \$molNum" >> "\$logFile"
echo "Task is completed once '\${tclFile}' is created. " >> "\$logFile"

jdFile="\$(ls *.jd.json)"
inpFiles=\$(ls *XTB.xyz *XTB.sdf | grep -v / | paste -sd ',')

#
# Submit Task
#

echo "$jobSubmissionCommand" -f "\$inpSDFs,\$inpXYZs" -j "\$jdFile" --tcl "\$tclFile" --tclREGEX ".*last-xTB.sdf" -c "$cores" -t "$walltime" --jobname "\${molName}_XTB" --accargs "--StringFromCLI \$molName" --notify NONE >> "\$logFile" 2>&1
"$jobSubmissionCommand" -f "\$inpSDFs,\$inpXYZs" -j "\$jdFile" --tcl "\$tclFile" --tclREGEX ".*last-xTB.sdf" -c "$cores" -t "$walltime" --jobname "\${molName}_XTB" --accargs "--StringFromCLI \$molName" --notify NONE  >> "\$logFile" 2>&1

exit 0
EOF

# Submit master script
chmod u+x "$jobscript"
chmod o-rwx "$jobscript"
bash "$jobscript"

exit 0
