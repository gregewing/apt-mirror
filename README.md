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
<li>iproute2  -  Provides a more accurate mechanism for capping bandwidth consumption than is available in wget. ( used currently to get teh netwoek adapter name to pass to the docker host, but I plan to keep bandwidth management within the container, if I'm able to do so.</li>


<b>A note on Bandwidth Management:</b><br>

I was also frustrated with the bandwidth limiting capability of apt-mirror as it seems pretty inaccurate.  The mechanism in the <code>apt-mirror</code> app is to pass the responsability on to <code>wget</code> by passing it a command line parameter to limit the bandwidth consumed, but in the wget man page the maintainers admit that the mechanism is not very good.  therefore I've started using the <code>tc</code> command from <code>iproute2</code> to limit the bandwidth to a rock-solid ceiling.  The drawback from this approach so far is that I need to run a cron job on the docker host to read a file created by the running container which helps identify which veth adapter in dockets network stack to apply the bandwidth limit to.  I found that if I applied the bandwidth limit in the container then there was no effect, though i've read elsewhere that setting the bandwidth limit before starting the apt-mirror app will help.  In the meantime, running it the way I have it set up allows me to alter the bandwidth consumption of the running apt-mirror without restarting it, which I prefer.


Configuration details will be added once I've finished tinkering.

<b>Deploying:</b><br>

I recommend creating a volume first, so that the scripts can go in the right places inside the container.  This step is not necessary, but this will make sure that your bandwidth control is easy to get to whenever you re-create or upgrade the container:

<code>
docker volume create apt-mirror-config
</code>

Once this volume exists, we can use it when we create the container:

:/var/spool/apt-mirror

<code>
docker run -d -it \<br>
--name=apt-mirror \<br>
-e TZ=Europe/London \<br>
-v apt-mirror-config:/var/spool/apt-mirror \<br>
--restart unless-stopped \<br>
 -p 9090:80 \<br>
gregewing/apt-mirror<br>
</code>

<b>Configuring:</b><br>

In its current configuration, the list of repos that get mirrored is held in the default location for apt-mirror.  when i get a little time, I'll link this to a configuration file in the volume we created above, so that there is persistence, and also a way to easily re-configure the mirrored repositories even if the container is not running.  So for now, please modify <code> /etc/apt/mirror.list</code> to suit your individual needs.  The file that comes with the container has several examples, all of which are enabled by default, so before you download a half a terrabyte of data you don't need, make sure you update this file

Restart the container after making changes to <code>/etc/apt/mirror.list<code>

<b>Managing Bandwidth:</b><br>

I have to go out now, but in simple terms, this is creating a cron job on the host to run every minute and run one of the scripts that is placed in the volume we created earlier when we first run the container.  I'll explain a bit more about how the bandwidth utilisation is managed next time I update this page.



