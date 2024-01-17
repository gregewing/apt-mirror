# apt-mirror

<b>Reason for Being</b><br>
<br>I created this image because I was frustrated with the apt-mirror images I found in docker hub,  they were all based on old baseimages.  
So I created a new one and have set it to build automatically whenever there is a new <code>ubuntu:latest</code> basemiage published, so it should always be up to date.

<b>High Level Information</b><br>
<br>This is built using ubuntu:latest, at the time of writing this is the Focal Fosa build (20.04).  There have been rumours of problems with <code>apt-mirror</code> running on Ubuntu 20.04, but i've not had any issues with it during my testing.  

The software installed in this image:
<li>apt-mirror  -  to mirror apt based resposiroties (e.g. Ubuntu / Debian / Kali)</li>
<li>wget  -  Does the actual downloads, is a dependency of apt-mirror</li>
<li>nginx  -  Provides a lightweight web server to serve up the mirrored repo on your network.</li>
<li>cron  -  Provides a mechanism to re-run the mirror script on a daily basis, only after the initial download has completed. Not to be confused with cron on teh docker host, which is required for bandwidth management, see below.</li>
<li>iproute2  -  Provides a more accurate mechanism for capping bandwidth consumption than is available in wget. (wget is used by apt-mirror to download content, but it has only rudimentary bandwidth capping features. See below.</li>

<br><b>A note on Bandwidth Management:</b><br>

I was also frustrated with the bandwidth limiting capability of apt-mirror as it seems pretty inaccurate.  The mechanism in the <code>apt-mirror</code> app is to pass the responsability on to <code>wget</code> by passing it a command line parameter to limit the bandwidth consumed, but in the wget man page the maintainers admit that the mechanism is not very good.  Therefore I've added in <code>tc</code> command from <code>iproute2</code> to limit the bandwidth to a rock-solid ceiling that you can control.  The drawback from this approach so far is that I need to run a cron job on the docker host to read a file created by the running container which helps identify which veth adapter in dockers network stack to apply the bandwidth limit to. But it works like a charm, so long as you can configure cron on the docker host.  I found that if I tried to use <code>tc</code> from inside the container then there was no effect, even if running it before the aptmirror software starts as was suggested in a post I saw somewhere.  Running it the way I have it set up allows me to alter the bandwidth consumption of the running apt-mirror without restarting it, which I prefer.  There is however a dependency on iproute2 being installed on the docker host, and that it is availalbe for you to run (perhaps via sudoers?).

<b>Deploying:</b><br>

I recommend creating a volume first, so that the scripts can go in the right places inside the container.  This step is not necessary, but this will make sure that your bandwidth control script (<code>limit_bw</code>) is easy to get to whenever you re-create or upgrade the container:

<code>
docker volume create apt-mirror-config
</code><br>

Once this volume exists, we can use it when we create the container:

/var/spool/apt-mirror

<code>
docker run -d -it \<br>
--name=apt-mirror \<br>
-e TZ=Europe/London \<br>
-v apt-mirror-config:/var/spool/apt-mirror \<br>
--restart unless-stopped \<br>
 -p 9090:80 \<br>
gregewing/apt-mirror<br>
</code><br>

<br><b>Configuring:</b><br>

The list of repos that get mirrored is held in <code>/etc/apt/mirror.list</code>. This should provide perisitence across re-creations of the container, and it does easily allow altering the list of mirrored repos without having the container running, simply by editing the config file in the volume directly on the host, even while the container is stopped.

Restart the container after making changes to <code>/etc/apt/mirror.list</code>

<b>Managing Bandwidth:</b><br>

To apply meaningful bandwidth controls I have created a few scripts.  The anatomy is as follows:<br>
<li>get_adapter.id  -  this runs right at the beginning of the entrypoint.sh scipt and it writes the network adapter ID that is seen inside the running container to this file : <code>/var/spool/apt-mirror/adapter.id</code></li>
<li>limit_bw  -  this sits inside the container, just so that it does not have to be created manually outside the container, but it does not get run by the container itself.  This script file sits in the volume that is mounted from the docker host, where it can be executed by a cron job configured on the host.</li>
<br>
The magic happens when you add a cron job on the docker host to run <code>limit_bw</code> at regular intervals.  I set it up as follows to run every 60 seconds, so only have a maximum of that long to wait before any changes to the allocated bandwidth are implemented.  
<br><br>
To change the allocated bandwidth, just alter the parameters in the <code>limit_bw</code> script, any changes will be applied next time the cron job executed.  You can reach the <code>limit_bw</code> script for editing either my exec-ing into the container or my simply editing it in the mounted volume directly from the docker host.  There are only two parameters to edit:
<li>ratelimit=1mbit</li>
<li>burstlimit=1mbit</li>
<br>
See the 'tc' man page for which suffixes you can use if you want to limit to kbps or Mbps etc.  https://man7.org/linux/man-pages/man8/tc.8.html
<br>
Heres an extract of the relevant part of the 'tc' man page to save you the bother of finding it :
<br>
<code>
RATES  Bandwidths or rates.  These parameters accept a floating
              point number, possibly followed by either a unit (both SI
              and IEC units supported), or a float followed by a '%'
              character to specify the rate as a percentage of the
              device's speed (e.g. 5%, 99.5%). Warning: specifying the
              rate as a percentage means a fraction of the current
              speed; if the speed changes, the value will not be
              recalculated.

              bit or a bare number
                     Bits per second

              kbit   Kilobits per second

              mbit   Megabits per second

              gbit   Gigabits per second

              tbit   Terabits per second

              bps    Bytes per second

              kbps   Kilobytes per second

              mbps   Megabytes per second

              gbps   Gigabytes per second

              tbps   Terabytes per second

              To specify in IEC units, replace the SI prefix (k-, m-,
              g-, t-) with IEC prefix (ki-, mi-, gi- and ti-)
              respectively.

              TC store rates as a 32-bit unsigned integer in bps
              internally, so we can specify a max rate of 4294967295
              bps.
</code>
<br>
It's not all that pretty, but it works and i think its a simple and elegant solution.  Here is the cron job line i have in my crontab:<br>

<code>* * * * * sudo /var/lib/docker/volumes/apt-mirror/_data/limit_bw</code>

<br> Enjoy   :-)
