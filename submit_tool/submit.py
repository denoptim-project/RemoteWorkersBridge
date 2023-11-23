#!/usr/bin/python
#
#   Copyright (C) 2014 Marco Foscato
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
#   This script allows you to do execute this workflow:
#
#   1) prepare a working space on a remote HPC machine (make a directory)
#   2) move files on the remote HPC machine,
#   3) request the submission of a job ID on the HPC
#   4) collect any output from the remote machine
#
#   For security reasons, the connection to the remote is controlled by a 
#   command filter that has to be configured accordingly. In practice, the local
#   client and the remote must be configured so that the local sends 
#   instructions (as strings) via a very constrained ssh connection, and the 
#   remote interprets those strings as commands. The only exception is the
#   'mkdir' command executed via ssh from the local client.
# 
#   To this end the following requirements must be met:
#   a) a specific ssh key must be generated. For security reasons, this must 
#      be a key specifically and exclusively meant to run the wanted task. 
#      Obviously, the whole process works also
#      with general purpose ssh keys, which may not be in agreement with
#      security policies on the remote site.
#   b) when authorizing the key on the remote machine (adding the key to 
#      .ssh/authorized_keys) the command option must be used to force and 
#      restrict the execution of a single command, which is the execution of a
#      script that filters the commands.
#      An example of such script is reported in point c) and a concrete example
#      is available in the present repository.
#   c) the remote machine must have a protected script to authorize only
#      selected remote commands. An example is given here:
#      
#      #!/bin/sh
#      log=<path_to_log.file>
#      ts=$(date)
#      
#      # Exclude multiple commands
#      if [[ $SSH_ORIGINAL_COMMAND == *";"* ]] || \
#         [[ $SSH_ORIGINAL_COMMAND == *"|"* ]] || \
#         [[ $SSH_ORIGINAL_COMMAND == *"&"* ]] ; then
#        echo "$ts forbidden multicommand line: $SSH_ORIGINAL_COMMAND" >> $log
#        exit -1
#      fi
#      
#      # Analyze the single command
#      command=$(echo $SSH_ORIGINAL_COMMAND | cut -d' ' -f 1)
#      arg=$(echo $SSH_ORIGINAL_COMMAND | cut -d' ' -f 2)
#      if [[ $command == "scp" ]] ; then
#        if [[ $arg == "-t" ]] || [[ $arg == "-f" ]] ; then
#          echo "$ts authorized scp command: $SSH_ORIGINAL_COMMAND" >> $log
#          $SSH_ORIGINAL_COMMAND
#        else
#          echo "$ts forbidden scp command: $SSH_ORIGINAL_COMMAND" >> $log
#        fi
#      elif [[ $command == "mkdir" ]] ; then
#        echo $USER >> $log
#        if [[ $arg == *$USER* ]] && [[ $arg != *" "* ]] && [[ $arg != *"."* ]] ; then
#          echo "$ts authorized mkdir command: $SSH_ORIGINAL_COMMAND" >> $log
#          $SSH_ORIGINAL_COMMAND
#        else
#          echo "$ts forbidden mkdir command: $SSH_ORIGINAL_COMMAND" >> $log
#        fi
#      elif [[ $command =~ ^[0-9]+$ ]] ; then
#        echo "$ts authorized run with ID $SSH_ORIGINAL_COMMAND" >> $log
#        # Run the jobscript with this ID
#        <jobscript_see_point_d)> $command
#      else
#          echo "$ts forbidden command: $SSH_ORIGINAL_COMMAND" >> $log
#      fi
#
#   d) The remote machine must have a jobscript that performs all wanted tasks
#      using a single argument that is the job ID. The jobscript must create a
#      text file named tc_<jobID> which contains the list of output files to
#      copy back home. The sole existence of the tc_<jobID> file is used to 
#      indicate completion of the task on the remote computer.
#   
#
#
#   Usage:
#   python thisScriptName.py [OPTIONS]
#
#   For help, use -h or --help:
#   python thisScriptName.py -h
#   
#   Default values can be controlled by the ../configuration file. Such defaults
#   are overwritten by command line arguments/options.
#
###############################################################################


import os
import os.path as path
import sys
import time
import subprocess
from optparse import OptionParser
import configparser

defUser = 'nobody'
defRemoteIP = '000.000.00.000'
defWDir = '$HOME'
defKey = 'noKey'

# Read configuration file
configFile = os.path.join(os.path.dirname(os.path.realpath(__file__)), '..', 'configuration')
config = configparser.ConfigParser()
if path.exists(configFile):
    config.read(configFile)
    defUser = config['WORKER1']['userOnRemote']
    defRemoteIP = config['WORKER1']['remoteIP']
    defWDir = config['WORKER1']['wdirOnRemote']
    defKey = config['WORKER1']['identityFile']
else:
    print('WARNING: No configuration file found at '+configFile)
    print('You\'ll have to provide many command line arguments.')

# Parse command line arguments
parser = OptionParser()
parser.add_option("-u", "--user", dest="user",
                  help="username of your account on "
                  + "the HPC [default: %default]. Please set SSH Keys to avoid"
                  + " manual typing of passwords", default=defUser)
parser.add_option("-m", "--machine", dest="machine",
                  help="hostname or IP of HPC. "
                  + "The IP is preferred if multiple login nodes are "
                  + "available.", default=defRemoteIP)
parser.add_option("-k", "--key", dest="keyfile",
                  help="private SSH key file "
                  + "(i.e., identity file).")
parser.add_option("-i", "--input", dest="infiles",
                  help="input file/s for task"
                  + " script. Use double quotes to "
                  + "list more than one file, i.e., -i \"file1 file2\". Note "
                  + "that the name of the submitted job will not be related to "
                  + "the name of the input in any way.")
parser.add_option("-K", "--jobKind", dest="jobKind",
                  help="the kind of jobs: a string"
                  + " used to redirect the execution of a specific kind "
                  + "of job submission script on the remote machine. "
                  + "The meaning of the string is defined by the"
                  + " command filter on the remote machine.")
parser.add_option("-p", "--hpcpath", dest="hpcpath",
                  help="path to parent "
                  + "directory of working copy on HPC [default: %default]",
                  default=defWDir)
parser.add_option("-d", "--delay", dest="delay",
                  help="integer number of time"
                  + " units between successive evaluation of the status of the"
                  + " running task [default: %default]", default=5)
parser.add_option("-t", "--timeunit", dest="units",
                  help="time units for delay "
                  + "(\'s\' for seconds ,\'m\' for minutes, and \'h\' for "
                  + "hours) [default: %default]", default='s')
parser.add_option("-x", "--max", dest="maxwait",
                  help="maximum number of attempt "
                  + "to evaluate the status of the running task. If the task is"
                  + " not completed after maxwait*d(sec), the tasks will be "
                  + "abandoned and its outcome ignored [default: %default].",
                  default=5)
(options, args) = parser.parse_args()

keyfile = defKey
if options.keyfile:
    keyfile = options.keyfile
else:
    if not path.exists(defKey):
        parser.error('No private private key. Try --help for instructions or add ssh private key (\'identityFile\') to ../configuration file')

if not options.infiles:
    parser.error('No input; try --help for instructions')

# Assign to local variables
user = options.user
host = options.machine
infiles = options.infiles
infiles = infiles.split()
inname = "job"
hpcpath = options.hpcpath
d = int(options.delay)
u = options.units
maxi = int(options.maxwait)
jobKind = "d"
if options.jobKind:
    jobKind = options.jobKind

ds = 0
if u == 's':
    ds = d
elif u == 'm':
    ds = int(d)*60
elif u == 'h':
    ds = int(d)*60*60
else:
    print ('ERROR! Unrecognized time unit ',u)
    print ('Permitted values are s, m, and h')
    sys.exit(1)

print ('==> Sending to HPC <==')
print ('user           ', user)
print ('machine        ', host)
print ('input files    ', infiles)
print ('path on remote ', hpcpath)
print ('job kind       ', jobKind)


# Get timestamp
ts = str(int(time.time() * 1000))
print ('Current timestamp (ms): ', ts)

# Make working space
wdir = hpcpath + '/' + inname + ts
ssh1 = subprocess.Popen(['ssh', '-i', keyfile, '%s@%s' % (user, host), 'mkdir ' + wdir],
        shell=False,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE)
res = ssh1.wait()
if res != 0:
    print ('ERROR! Unable to make working space ',wdir)
    output = ssh1.stdout.readlines()
    if output != []:
        print (output)
    error = ssh1.stderr.readlines()
    if error != []:
        print (error)
    sys.exit(1)


# Move files to working space
print ('Moving files to remote...')
for f in infiles:
    scp1 = subprocess.Popen(['scp', '-i', keyfile, f, '%s@%s:%s' % (user, host, wdir)],
            shell=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE)
    res = scp1.wait()
    if res != 0:
        print ('ERROR! Unable to copy input to %s@%s:%s' % (user,host,wdir))
        output = scp1.stdout.readlines()
        if output != []:
            print (output)
        error = scp1.stderr.readlines()
        if error != []:
            print (error)
        sys.exit(1)


# Run task...
print ('Submitting task...')
ssh2 = subprocess.Popen(['ssh', '-i', keyfile, '%s@%s' % (user,host), '%s%s' % (jobKind,ts)],
                shell=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE)
res = ssh2.wait()
if res != 0:
    print ('ERROR! Unable to execute ','%s%s' % (jobKind,ts))
    output = ssh2.stdout.readlines()
    if output != []:
        print (output)
    error = ssh2.stderr.readlines()
    if error != []:
        print (error)
    sys.exit(1)


# ...and wait for completion
tcfile = wdir + '/tc_' + ts
loctcfile='tc_'+ts
taskdone = 1
print ('Waiting for task completed flag ', tcfile)
for i in range(maxi):
    time.sleep(ds)
    scp2 = subprocess.Popen(['scp', '-i', keyfile, '%s@%s:%s' % (user,host,tcfile), loctcfile],
                shell=False,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE)
    res = scp2.wait()
    if res == 0:
        print ('Task completed (check n.',i,')')
        taskdone = 0
        break
    else:
        if i == maxi - 1:
            print ('ERROR: Abandoning an INCOPLETE task (check n.',i,')')
            sys.exit(1)
        else:
            print ('Check completion (n.',i,'): false. Keep waiting...')


# Collect results
print ('Collecting results...')
if taskdone == 0:
    with open(loctcfile) as fout:
        for f in fout:
            print ('Trying to recover ',f.rstrip())
            scp3 = subprocess.Popen(['scp', '-T' ,'-i', keyfile, '%s@%s:%s/%s' % (user,host,wdir,f), '.'],
                   shell=False,
                   stdout=subprocess.PIPE,
                   stderr=subprocess.PIPE)
            res = scp3.wait()
            if res != 0:
                print ('ERROR! Unable to collect output file ',f,' as ', '%s@%s:%s/%s' % (user,host,wdir,f))
                output = scp3.stdout.readlines()
                error = scp3.stderr.readlines()
                if output != []:
                    print (output)
                if error != []:
                    print (error)
                sys.exit(1)


# Cleanup tmp files
os.remove(loctcfile)

# Goodbye
print ('All done :) ')
sys.exit(0)
