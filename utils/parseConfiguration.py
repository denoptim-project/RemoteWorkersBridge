#!/usr/bin/python
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
# Usage:
# ======
#
# python -h/--help
#
###############################################################################

import sys
import os
import os.path as path
import configparser
import optparse
from optparse import OptionParser

# These strings must NOT be changed as they are part of the conventional syntax
ipKey='remoteIP'
userKey='userOnRemote'
keyKey='identityFile'
wdirKey='wdirOnRemote'
workKindKey='workKind'
outputDict = {
  "i": ipKey,
  "u": userKey,
  "w": wdirKey,
  "k": keyKey
}

parser = OptionParser()
parser.add_option("-f","--file",dest="configFile",help="the pathname to the configuration file  to read.")
parser.add_option("-k","--workKind",dest="wantedKind",help="use this option to filter the results of any configuration parsing by the kind of work a worker is expected to provide.")
parser.add_option("-i","--workerIP",dest="wantedIP",help="use this option to filter the results of any configuration parsing by the IP address of the worker")
parser.add_option("-o","--output",dest="output",help="use this option to select which fields to print on STDOUT for each worker that is found in the configuration file and that matches any of the required criteria. Fields are identified by \"i\" for IP, \"u\" for username, \"w\" for work directory, \"k\" for identity file. Use a comma-separated list for specifying multiple fields. [default= %default]",default="u,i,w,k")

(options, args) = parser.parse_args()

configFile = options.configFile
if not options.configFile:
    print('ERROR! You need to define what configuration file to read. Use -f/--file option.')
    quit()
if not path.exists(configFile):
    print('ERROR! File \'' + configFile + '\' not found.')
    quit()

wantedKind = 'none'
if options.wantedKind:
    wantedKind = options.wantedKind

output = options.output

wantedIP = 'none'
if options.wantedIP:
    wantedIP = options.wantedIP

config = configparser.ConfigParser()
config.read(configFile)
for section in config.sections():
    if not section.startswith('WORKER'):
        continue

    if wantedKind != 'none' and not config.has_option(section,workKindKey):
        continue
    else:
        wKinds = config[section][workKindKey].split(",")
        keepMe = True
        if wantedKind != 'none':
            keepMe = False
            for wKind in wKinds:
                if wKind == wantedKind:
                    keepMe = True

    if keepMe and wantedIP != 'none':
        keepMe = False
        if config[section][ipKey] == wantedIP:
            keepMe = True

    if not keepMe:
        continue

    fields = output.split(",")
    line = ""
    for field in fields:
        line = line + config[section][outputDict[field]] + ' '

    print(line)

