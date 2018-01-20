# Debian SID SWGMasters Developer VM (PRIVATE REPO ONLY)

## Download
(not currently available)

### Special Notes for Image v6
If you're using version 6 of the development image, you'll need to do a few things prior to being able to start the server (but AFTER all other steps):
- Add the compiled binary locations to the PATH variable

```export PATH=$PATH:/home/swg/swg-main/build/bin```

- You'll also need to possibly edit the build_linux.sh script (located in the swg-main folder) and set the MODE equal to "Debug" instead of "Release".  If you run into issues 
starting the server for the first time, set to Debug, recompile the server, rebuild the templates (the compile script step below), truncate your OBJECT_TEMPLATES table and
re-import your database.

## System Requirements

* Virtualbox 5.0.x
* 4GB RAM minimum (The VM supports 64GB RAM)
* 30GB Harddisk Space

Recommended: 
* SSH-Client (Putty in Windows) 
* SCP-Client (WinSCP)
* more RAM if you want to run more then 1-2 Zones
* SSD as VM Storage

## What's Included In The VM 

* Debian SID/Testing 32Bit
* OracleDB 11g Release 2
* Oracle Enterprise Manager https://<vmip>:1158/em/console (User: SYSTEM Pass: swg)
* Clientfiles needed to start the server /home/swg/clientdata/
* Appearance Files needed to start the server /home/swg/appearance/
* Copy of https://bitbucket.org/swgmasters/swg-src/ /home/swg/swg-src/
* All predependecies installed to compile your own server
* Samba preinstalled pointed to /home/swg/ (You can use editors/IDEs or/and your git in Windows)
* Dummy-X-Server to run X-Applications through VNC (Isnt started by default, google vnc4server)

Default Password: swg

## What Do You Need To Do To Get A Server Running?

Import the Appliance to Virtualbox.
* CPU Setting PAE
* Network Setting: Bridge Network

Change the /etc/hosts file to the right ipaddress. 

		nano /etc/hosts

Change the 192.168.2.113 to the IP of the Virtual Machine

		<yourip>		swg

Restart the server: 

		shutdown -r now

Download Putty and point it to the IP of your VM
Login as user swg with password swg
		
Delete the public repo (You can skip this, if you want to build both binarysets on the same system)

		rm /home/swg/swg-src -rf
		
Create an ssh-key to use with the private gitlab as user swg

		ssh-keygen -t rsa
		
Copy the public key to your gitlab account settings. (Profile Settings -> SSH-Keys)

		cat /home/swg/.ssh/id_rsa.pub

After this you can download the private main repo: 

		cd /home/swg
		git clone git@git.stellabellum.net:staff/swg-main.git

When you are done with the git clone part, go into the swg-main folder

		cd /home/swg/swg-main
		touch .setup

Start the Download of other Repos by using the build_linux.sh git pull/push option.

		./build_linux.sh
		!! Ignore the install dependencies PART !!

## Building Phases
Follow the instructions. The binary building phase will take roughly 1h/1Core.
The Script Building Phase will throw errors if you skip the configphase, do configs first, then scriptbuilding.

### Config Phase
use local

Database DSN: 
//127.0.0.1/swg

Database User:
swg

Database Password: 
swg

### Script Building
Scriptbuilding will take about 6hours the first time. You can later just recompile single scripts or tab files, look at the
utils/build_ and the build_linux.sh files to see the syntax of the mocha, javac and compilertools. 

### Database 
The Clustername has to be the same you used in the configphase. The same for the nodeip. The other settings are self-explaining.

## Clientdata and Appearance Files
The Clientdata Repo is copied from our Git here, its in /home/swg/clientdata. http://git.stellabellum.net/staff/clientdata

The .git Folder is removed to save space!

You need to modify: 
* exe/shared/servercommon.cfg

        [SharedFile]
        searchPath2=../../data/sku.0/sys.shared/compiled/game
        searchPath2=../../data/sku.0/sys.server/compiled/game
        searchPath1=../../data/sku.0/sys.shared/built/game
        searchPath1=../../data/sku.0/sys.server/built/game
        searchPath0=../../data/sku.0/sys.client/compiled/clientdata
        
* mkdir /home/swg/swg-main/data/sku.0/sys.client/compiled
* ln -s /home/swg/clientdata /home/swg/swg-main/data/sku.0/sys.client/compiled/clientdata

## First Start
		./startServer.sh

Point your login.cfg to the IP of the Virtualmachine.
