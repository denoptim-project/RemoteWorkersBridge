#!/bin/bash
#
# Runs a test of the submit tool using localhost as remote worker.
#

if [ -f ../../configuration ]
then
    echo "ERROR! This test will write its own configuration file but ../../configuration exists already. Rename or remove ../../configuration before trying again."
    exit -1
fi

# Make ssh key
sshkey="$(pwd)/rsa_id_to_localhost"
rm -rf "$sshkey" "$sshkey.pub"
echo "You can enter an empty passphrase: this key is only used on localhost and removed afterwards."
ssh-keygen -t rsa -b 4096 -f "$sshkey"

# Make the configuration file
TMP="$HOME" #Must be on a pathname that include the name of the user!
if [ ! -d "$TMP" ]; then
    echo "ERROR! could not find user-specific space under \$HOME. Aborting test."
    exit -1
fi
mkdir "$TMP/fake_remote"
if [ 0 -ne "$?" ]; then
    echo "ERROR! Failed to make work space at '$TMP/fake_remote'"
    exit -1
fi
echo "[WORKER1]" > ../../configuration
echo "remoteIP=localhost" >> ../../configuration
echo "wdirOnRemote=$TMP/fake_remote" >> ../../configuration
echo "userOnRemote=$USER" >> ../../configuration
echo "identityFile=$sshkey" >> ../../configuration
echo "workKind=xtb,dft" >> ../../configuration

# Authorize the key but only via the command filter
mv ~/.ssh/authorized_keys ~/.ssh/authorized_keys_bkp
echo "command=\"$(cd ../.. ; pwd)/commandFilter.sh\" $(cat "$sshkey".pub)" >> ~/.ssh/authorized_keys

# Test the remote bridge to localhost
python ../submit.py -i "fileIn.sdf fileIn.jd" -d 1 -x 10 -t s -K t 

if [ -f "dummy_output" ]; then
    echo "Test PASSED!"
fi

# Cleanup and restore original settings
rm -f dummy_output
rm -rf "$sshkey" "$sshkey.pub"
rm -f ../../configuration
rm -rf "$TMP/fake_remote"
mv ~/.ssh/authorized_keys_bkp ~/.ssh/authorized_keys

exit 0
