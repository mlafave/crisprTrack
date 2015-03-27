#!/usr/bin/env bash

source ~/.bashrc
source ../sh/functions

# Intended to delete the input file. The reason this has its own script is so
# -hold_jid can be used to make it work at the correct point in the parent
# driver.

# Check if the kill_flag exists. If it does, exit.

test_flag kill_flag


# Read in input

FILE=$1


# Delete the file

echo "Deleting ${FILE...}"
rm ${FILE}
echo "Done."

exit 0
