# alwaysIntense.sh
Cron job based bash script to reclaim disk space from rtorrent. With knobs.

**The Problem:**

Rtorrent has a shutdown disk usage threshold, looks like this in your ~/.rtorrent.rc

    schedule2 = monitor_diskspace, 15, 60, ((close_low_diskspace, 5120M))
    
Once above that threshold is hit rtorrent will quit. When combined with SystemD, you can get thrashing. SystemD will recognize it isn't running, restart rtorrent, rtorrent will see the disk usage... Wash, repeat.

This can cause tracker blipping, loss of seed time, and failure with gettors like Sonarr.

--

**A Solution**

This script offers a slow methodical way to prevent disk over runs.

As a cronjob that runs say once an hour, a grind set of torrents and their payloads is generated, those that are above criteria settings. They are then removed, culled, purged,  terminated with extreme prejudice, whacked - to free-up needed disk space.

It uses five criteria:

* Disk Usage Threshold
* Torrent Ratio
* Seed Time
* Prune Count
* Label (optional)

Given the criteria, the script sorts the set by size, and prunes the largest first, up to the prune count are removed. 

Additionally the script is designed to ignore torrents that are actively connected. It also can limit by label, easing the integration to Q4D or any tool that uses labeling to indicate that the torrent is safe to remove (ie payload integrated)


*Installing*

The script uses [pyroscope](https://pyrocore.readthedocs.io/en/latest/installation.html), you will need that installed first.

    git clone https://github.com/weaselBuddha/alwaysIntense.sh.git
    chmod 755 alwaysIntense.sh/alwaysIntense.sh
    mv alwaysIntense.sh/alwaysIntense.sh ~/bin

Edit Script for criteria, changing the presets to suit your setup
    
    echo "7 * * * * ~/bin/alwaysIntense.sh >> ~/repoed.log" |crontab -

--

This script is suitable for other torrent clients, you'll need to change genList() and doCull() functions
