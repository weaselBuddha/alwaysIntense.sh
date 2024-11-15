#!/bin/bash

# CRITERIA

# % Disk Space Available
threshold=80
# Ratio
ratioCutoff="+2.0"
# Number to Remove
numPrune=7
# Time Spent Seeding
seedTime=+30h
# Only Certain Labels ("*" for all)
forLabel="*"


# Update Times for Unset Torrents
function updateTimes()
{
    echo -n "Updating Times."
    # Set missing "loaded" times to that of the .torrent file or data path
    rtcontrol loaded=0 metafile='!' -q -sname -o '{{py:from pyrobase.osutil import shell_escape as quote}}
        test ! -f {{d.metafile | quote}} || rtxmlrpc -q d.custom.set {{d.hash}} tm_loaded \$(stat -c "%Y" {{d.metafile | quote}})
        rtxmlrpc -q d.save_full_session {{d.hash}}' | bash +e

    echo -n "."
    rtcontrol loaded=0 is_ghost=no path='!' -q -sname -o '{{py:from pyrobase.osutil import shell_escape as quote}}
        test ! -e {{d.realpath | quote}} || rtxmlrpc -q d.custom.set {{d.hash}} tm_loaded \$(stat -c "%Y" {{d.realpath | quote}})
        rtxmlrpc -q d.save_full_session {{d.hash}}' | bash +e

    echo -n "."
    # Set missing "completed" times to that of the data file or directory
    rtcontrol completed=0 done=100 path='!' is_ghost=no -q -sname -o '{{py:from pyrobase.osutil import shell_escape as quote}}
        test ! -e {{d.realpath | quote}} || rtxmlrpc -q d.custom.set {{d.hash}} tm_completed \$(stat -c "%Y" {{d.realpath | quote}})
        rtxmlrpc -q d.save_full_session {{d.hash}}' | bash +e
    echo ". Done"
}

# Generate list of torrent hashes given criteria, all reverse sorted by size
function listGen()
{
        echo $(rtcontrol -q is_complete=y ratio=$ratioCutoff custom_1=$forLabel xfer=0 completed=$seedTime -o size,hash |sort -nr|cut -f2)
}


function doCull()
{
    count=0
    for id in $*
    do
        if [ $((count+=1)) -le $numPrune ]
        then
            path="$(rtcontrol -q hash=$id -o path)"

            echo $'\t'$(rtcontrol -q hash=$id -o name,ratio) @ $(du -h "$path"|cut -f1) removed
            rtcontrol -q hash=$id --cull --yes >/dev/null

            # Verify payload is gone.
            sleep 3
            if [ -e "$path" ]
            then
               rm -r "$path"
            fi
        else
           break
        fi
    done
}


function Main()
{

    # Update Torrent Date/Time fields
    updateTimes

    percentUsed=$(df --output=pcent ~| sed '1d;s/^ //;s/%//')

    # Are we using more disk than we want?
    if [ $percentUsed -ge $threshold ]
    then
        local bytesFreeBefore=$(( $(df --output=avail ~ |tail -1) * 1024 ))
        local bytesFreeAfter
        local numHashes

        # Get a List to Step Thru
        hashlist=$(listGen)

        numHashes=$(echo ${hashlist} |wc -w)

        # We have payloads that meet the criteria?
        if [ $numHashes -gt 0 ]
        then
            echo $'\n'Before: $(df -h ~ |tail -1)$'\n'

            echo $numHashes Items Selected.

            # Remove Torrents
            doCull ${hashlist}

            echo $'\n'After: $(df -h ~ |tail -1)

            # How Much Did We Whack?
            bytesFreeAfter=$(( $(df --output=avail ~ |tail -1) * 1024 ))
            echo Freed: $(echo "scale=2; ( ${bytesFreeAfter} - ${bytesFreeBefore} ) / 1024^3"|bc)GB

       else
            echo "No Targets meet criteria"
       fi
    else

       echo $percentUsed"% is below threshold of "$threshold"%"
    fi
}

Main
