#!/bin/bash
#
#   Copyright (C) 2021 Marco Foscato
#
#   This program is free software: you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation, either version 3 of the License, or
#   (at your option) any later version.
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program. If not, see <http://www.gnu.org/licenses/>.
#
###############################################################################
#
# This script is meant to parse the configuration file to extract 
# information related to remote computers that can be used to 
# run computational tasks.
#
#
###############################################################################

function printUsage() {
cat <<EOF

 This script is meant to parse the configuration file to extract
 information related to remote computers that can be used to
 run computational tasks.

 Usage
 =====

 ./thisScript.sh [-f <pathname>] [-k <kind>] [-i <IP>] [-o <ouputformat>]

 where
 -f <pathname> is the pathname to the configuration file  to read.

 -k <kind> use this option to filter the results of any configuration parsing 
           by the kind of work a worker is expected to provide.
 -i <IP> use this option to filter the results of any configuration parsing by 
           the IP address of the worker
 -o <outputformat> use this option to select which fields to print on STDOUT 
                   for each worker that is found in the configuration file 
                   and that matches any of the required criteria. Fields are 
                   identified by 
                     - \"i\" for IP,
                     - \"u\" for username,
                     - \"w\" for work directory,
                     - \"k\" for identity file,
                     - \"t\" for work type/kind.
                   Use a comma-separated list for specifying multiple fields.
                   By default the output format is "u,i,w,k". 

EOF
}

# These strings must NOT be changed as they are part of the conventional syntax
ipKey='remoteIP'
userKey='userOnRemote'
keyKey='identityFile'
wdirKey='wdirOnRemote'
workKindKey='workKind'

#
# Function that checks if the arguments of a command line option is present.
#
# @param $1 the argument index (0-based integer) of the argument right before
# the one we are checking the existence of.
# @param $2 a string identifying what $1 is supposed to be (used only for logging).
# @param $3 total number of arguments given to the script that calles this function.
# @param $4-$# original arguments of the script that calls this function.
# @return 1 when no argument is found for a command line option.
#

function checkArg() {
   local ii="$1"
   local option="$2"
   local tot="$3"
   local args=("${@:4}")
   ii=$((ii+1))
   if [ "$ii" -ge "$tot" ]
   then
      echo "ERROR! Missing argument for option '$option'."
      return 1
   fi
   local argument=${args[$i+1]}
   if [[ "$argument" == "-"* ]]
   then
      echo "ERROR! Missing argument for option '$option'."
      return 1
   fi
   return 0
}

#
# Function that checks whether the arguments of a command line option it valid.
# If not, it exits with an error.
#

function ensureGoodArg() {
   local option="$2"
   if ! checkArg $@
   then
     echo "ERROR! Missing argument for option '$option'."
     exit 1
   fi
}

#
# Main
#

configFile="none"
wantedKind="none"
wantedIP="none"
outputFormat="u,i,w,k"
args=("$@")
for ((i=0; i<${#args[@]}; i++))
do
    arg="${args[$i]}"
    case "$arg" in
        "-h") printUsage ; exit 1 ;;
        "--help") printUsage ; exit 1 ;;
        "-f") ensureGoodArg "$i" "$arg" "$#"; 
            configFile=${args[$i+1]};;
        "-k") ensureGoodArg "$i" "$arg" "$#";
            wantedKind=${args[$i+1]};;
        "-i") ensureGoodArg "$i" "$arg" "$#";
            wantedIP=${args[$i+1]};;
        "-o") ensureGoodArg "$i" "$arg" "$#";
            outputFormat=${args[$i+1]};;
    esac
done

if [[ "$configFile" == "none" ]]; then
    echo "ERROR! You need to specify the pathname to the configuration file."
    echo "Use opyion '-f <pathname>'."
    exit 1
fi
if [ ! -f "$configFile" ]; then
    echo "ERROR! File '$configFile' not found."
    exit 1
fi

wIDs=()
wIPs=()
wUsers=()
wKeys=()
wWDs=()
wKinds=()
keeps=()

function saveWorker() {
    wIDs+=("$1")
    wIPs+=("$2")
    wUsers+=("$3")
    wKeys+=("$4")
    wWDs+=("$5")
    wKinds+=("$6")
    keeps+=("$7")
    #echo "SAVING $1 $2 $3 $4 $5 $6 $7"
    wID="none"
    wIP="none"
    wUser="none"
    wKey="none"
    wWD="none"
    wKind="none"
    keep=0
}

wID="none"
wIP="none"
wUser="none"
wKey="none"
wWD="none"
wKind="none"
keep=0
while read -r line
do
    line=$(echo $line | awk '{gsub(/^[ \t]+/,""); print $0}')
    if [[ "$line" == "[WORKER"* ]]; then
        # store old data is any
        if [[ "$wID" != "none" ]]; then
            saveWorker "$wID" "$wIP" "$wUser" "$wKey" "$wWD" "$wKind" "$keep"
        fi
        wID=$(echo $line | awk  '{ gsub("\\[WORKER",""); gsub("\\]",""); print $0}')
    fi

    if [[ "$line" == "$ipKey"* ]]; then
        wIP=$(echo $line | awk  -F"=" '{print $2}')
        if [[ "$wantedIP" != "none" ]] && [[ "$wantedIP" != "$wIP" ]]; then
            keep=1
        fi
    fi 

    if [[ "$line" == "$userKey"* ]]; then
        wUser=$(echo $line | awk  -F"=" '{print $2}')
    fi

    if [[ "$line" == "$wdirKey"* ]]; then
        wWD=$(echo $line | awk  -F"=" '{print $2}')
    fi

    if [[ "$line" == "$keyKey"* ]]; then
        wKey=$(echo $line | awk  -F"=" '{print $2}')
    fi

    if [[ "$line" == "$workKindKey"* ]]; then
        wKind=$(echo $line | awk  -F"=" '{print $2}')
        if [[ "$wantedKind" != "none" ]]; then
            found=1
            IFS="," read -r -a listOfKinds <<< "$wKind"
            for kind in ${listOfKinds[@]}
            do
                if [[ "$wantedKind" == "$kind" ]]; then
                    found=0
                fi
            done
            if [ "$found" -eq 1 ]; then
                keep=1
            fi
        fi
    fi
done < "$configFile"
saveWorker "$wID" "$wIP" "$wUser" "$wKey" "$wWD" "$wKind" "$keep"

#
# Function that gets a specific field for a specific entry
#
function decodeField() {
  case "$1" in
      "i") echo ${wIPs[$2]};;
      "u") echo ${wUsers[$2]};;
      "w") echo ${wWDs[$2]};;
      "k") echo ${wKeys[$2]};;
      "t") echo ${wKinds[$2]};;
  esac
}

#
# Printing results to STDOUT
#
IFS="," read -r -a fieldsToPrint <<< "$outputFormat"
for i in $(seq 0 $((${#wIDs[@]}-1)))
do
    if [ "${keeps[$i]}" -eq 0 ] ; then
        line=""
        for field in ${fieldsToPrint[@]}
        do
            val=$(decodeField "$field" "$i")
            line="$line $val"
        done
        echo $line
    fi
done
exit 0
