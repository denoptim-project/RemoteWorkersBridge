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
#
###############################################################################
#
# COMMAND FILTER:
# This script is meant to be executed via SSH. It evaluates the command
# carried by SSH and authorizes or not the execution of such command.
#
# These are the commands that will result in an actual action:
# - 'mkdir' within the user's file system
# - 'scp'
# - submission of jobs identified by one of these string syntaxes:
#     'mx<integer_number>' for AutoCompChem jobs managing multiple xTB jobs
#     'md<integer_number>' for AutoCompChem jobs managing multiple Gaussian jobs
# - test command with syntax 't<integer_number>'
#
# USAGE:
# This script should not be executed directly by the user!
# Instead, it should be executed only upon incoming ssh connections from
# an authorized client.
#
# See documentation in the README.md file.
#
 
writeLog=true
myDir="$(dirname "$0")"
log="$myDir/remotecommands.log"
jobscriptdft="$myDir/runners/runDFTJobId.sh"
jobscriptxtb="$myDir/runners/runXTBJobId.sh"
jobscriptmultixtb="$myDir/runners/runMultiXTBJobId.sh"
jobscriptmultidft="$myDir/runners/runMultiDFTJobId.sh"
ts=$(date)

# Exclude multiple commands
if [[ $SSH_ORIGINAL_COMMAND == *";"* ]] || \
   [[ $SSH_ORIGINAL_COMMAND == *"|"* ]] || \
   [[ $SSH_ORIGINAL_COMMAND == *"&"* ]] ; then
  if [ "$writeLog" = true ] ; then
    echo "$ts forbidden multicommand line: $SSH_ORIGINAL_COMMAND" >> $log
  fi
  exit 129
fi

# Analyze the single command, and decide if it is allowed or not
command=$(echo $SSH_ORIGINAL_COMMAND | cut -d' ' -f 1)
arg=$(echo $SSH_ORIGINAL_COMMAND | cut -d' ' -f 2)

# Intercept attempts to call this script from ssh command
if [[ "$SSH_ORIGINAL_COMMAND" =~ "^$0 .*" ]] ; then
  echo "$ts authorized ssh-triggering of commanf filter: $SSH_ORIGINAL_COMMAND" >> $log
  command="$arg"
fi

if [[ $command == "scp" ]] ; then
  if [[ $arg == "-t" ]] || [[ $arg == "-f" ]] ; then
    if [ "$writeLog" = true ] ; then
      echo "$ts authorized scp command: $SSH_ORIGINAL_COMMAND" >> $log
    fi
    $SSH_ORIGINAL_COMMAND
  else
    if [ "$writeLog" = true ] ; then
      echo "$ts forbidden scp command: $SSH_ORIGINAL_COMMAND" >> $log
    fi
    exit 130
  fi
elif [[ $command == "mkdir" ]] ; then
  if [ "$writeLog" = true ] ; then
    echo $USER >> $log
  fi
  if [[ $arg == *$USER* ]] && [[ $arg != *" "* ]] && [[ $arg != *"."* ]] ; then
    if [ "$writeLog" = true ] ; then
      echo "$ts authorized mkdir command: $SSH_ORIGINAL_COMMAND" >> $log
    fi
    $SSH_ORIGINAL_COMMAND
  else
    if [ "$writeLog" = true ] ; then
      echo "$ts forbidden mkdir command: $SSH_ORIGINAL_COMMAND" >> $log
    fi
    exit 131
  fi
elif [[ $command =~ ^mx[0-9]+$ ]] ; then
  command=${command:2}
  if [ "$writeLog" = true ] ; then
    echo "$ts authorized multi-xtb run with ID $SSH_ORIGINAL_COMMAND" >> $log
    echo "Running '$jobscriptmultixtb $command' from $(pwd)" >> $log
  fi
  $jobscriptmultixtb $command
elif [[ $command =~ ^md[0-9]+$ ]] ; then
  command=${command:2}
  if [ "$writeLog" = true ] ; then
    echo "$ts authorized multi-DFT run with ID $SSH_ORIGINAL_COMMAND" >> $log
    echo "Running '$jobscriptmultidft $command' from $(pwd)" >> $log
  fi
  $jobscriptmultidft $command
elif [[ $command =~ ^t[0-9]+$ ]] ; then
  command=${command:1}
  echo "$ts authorized test connection: ID $SSH_ORIGINAL_COMMAND" >> $log
  echo "Running '$myDir/runners/runTest.sh $command' from "$(pwd) >> $log 
  "$myDir/runners/runTest.sh" $command  
elif [[ $command =~ ^tx[0-9]+$ ]] ; then
  command=${command:2}
  echo "$ts authorized test connection: ID $SSH_ORIGINAL_COMMAND" >> $log
  echo "Running '$myDir/runners/runTestXTB.sh $command' from "$(pwd) >> $log
  "$myDir/runners/runTestXTB.sh" $command
elif [[ $command =~ ^td[0-9]+$ ]] ; then
  command=${command:2}
  echo "$ts authorized test connection: ID $SSH_ORIGINAL_COMMAND" >> $log
  echo "Running '$myDir/runners/runTestDFT.sh $command' from "$(pwd) >> $log
  "$myDir/runners/runTestDFT.sh" $command
else
  if [ "$writeLog" = true ] ; then
    echo "$ts forbidden command: $SSH_ORIGINAL_COMMAND" >> $log
  fi
  exit 132
fi
exit 0
