# apt-mirror

<b>Reason for Being</b><br>
I created this image because I was frustrated with the apt-mirror images I found in docker hub,  they were all based on old baseimages.  
So I created a new one and will relatively frequently keep it up to date.

<b>High Level Information</b><br>
This is built using ubuntu:latest, at the time of writing this is the Focal Fosa build (20.04).  there have been rumours of problems with <code>apt-mirror</code> running on Ubuntu 20.04, but i've not had any issues with it during my testing.  

The software installed in this image:
<li>apt-mirror  -  to mirror apt based resposiroties (e.g. Ubuntu / Debian / Kali)</li>
<li>wget  -  Does the actual downloads, is a dependency of apt-mirror</li>
<li>nginx  -  Provides a lightweight web server to serve up the mirrored repo on your network.</li>
<li>cron  -  Provides a mechanism to re-run the mirror script on a daily basis, only after the initial download has completed.</li>
<li>iproute2  -  Provides a more accurate mechanism for capping bandwidth consumption than is available in wget. ( used currently to get the netwoek adapter name to pass to the docker host, but I plan to keep bandwidth management within the container, if I'm able to do so.</li>

<br><b>A note on Bandwidth Management:</b><br>

I was also frustrated with the bandwidth limiting capability of apt-mirror as it seems pretty inaccurate.  The mechanism in the <code>apt-mirror</code> app is to pass the responsability on to <code>wget</code> by passing it a command line parameter to limit the bandwidth consumed, but in the wget man page the maintainers admit that the mechanism is not very good.  therefore I've started using the <code>tc</code> command from <code>iproute2</code> to limit the bandwidth to a rock-solid ceiling.  The drawback from this approach so far is that I need to run a cron job on the docker host to read a file created by the running container which helps identify which veth adapter in dockets network stack to apply the bandwidth limit to.  I found that if I applied the bandwidth limit in the container then there was no effect, though i've read elsewhere that setting the bandwidth limit before starting the apt-mirror app will help.  In the meantime, running it the way I have it set up allows me to alter the bandwidth consumption of the running apt-mirror without restarting it, which I prefer.

<b>Deploying:</b><br>

I recommend creating a volume first, so that the scripts can go in the right places inside the container.  This step is not necessary, but this will make sure that your bandwidth control is easy to get to whenever you re-create or upgrade the container:

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

The list of repos that get mirrored is held in <code>/etc/apt/mirror.list</code>. This shoud provide perisitence across recreations of teh container, but does not easily allow altering the list of mirrored repos without having teh container running (which is a handy feature I'll add when i have time) 

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
See the 'tc' man page for which suffixes you can use if you want to limit to kbps or Mbps etc.

<br>
It's not all that pretty, but it works and i think its a simple and elegant solution.  Here is the cron job line i have in my crontab:<br>

<code>* * * * * sudo /var/lib/docker/volumes/apt-mirror/_data/limit_bw</code>

<br>
Enjoy.
