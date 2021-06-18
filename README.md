## Overview - chronywake
chronywake is a program that will force the [chronyd](https://chrony.tuxfamily.org/) NTP daemon to quickly synchronise to it's upstream NTP servers or peers.

When macOS sleeps, chronyd is left in a suspended state, no longer disciplining the system clock. Real time continues to march on relentlessly and is tracked by the hardware real time clock.

When the machine is woken up, through user action or perhaps network activity, macOS will fetch the current time from the real time clock, which may be very advanced from what chronyd considers to be the correct time, and set the system clock to this time. As soon as it resumes operation chronyd notices this discrepancy and begins to adjust it's version of time. It may take a very long time for this adjustment to complete and the system time may have a large offset from NTP time throughout the adjustment period.

chronywake receives a notification from macOS when the machine wakes up. It will then send a message (makestep) to chronyd telling it the threshold for offset correction and the number of NTP probes for which the correction should be in effect.

chronywake then sends a message to [chronyd](https://chrony.tuxfamily.org/documentation.html) (via [chronyc](https://chrony.tuxfamily.org/documentation.html)) asking it to send a burst of NTP probes to each peer/server.

Messages to [chronyd](https://chrony.tuxfamily.org/documentation.html) are performed via the [chronyc](https://chrony.tuxfamily.org/documentation.html) utility.

In pseudo code the following commands (default values) are performed:
<pre>
on wakeup:
	chronyc makestep 0.1 3
	chronyc burst 4/4
</pre>

### Installation

#### Install via ChronyControl
The easiest way to install chronyd, chronyc and chronywake is to download ChronyControl from <a href=https://whatroute.net/chronycontrol.html>https://whatroute.net/chronycontrol.html</a>. ChronyControl will install signed and notarised versions of the chrony software, including chronywake.

#### Install manually
If you decide to compile and install the program manually, you will also need to install a means of starting the program when your machine starts up.

chronywake must be run as the root user and the normal way to start root services on macOS are via launchctl. See below for an example property list that could be modified for your use.

#### Compilation
You can compile the source with the following command (if you have Xcode installed on your machine).

`
clang -Wall -framework Foundation -fmodules main.m -o chronywake
`

### Help message

#### Output from chronywake -h
chronywake, by default, waits for a DidWakeNotification from macOS. On awakening, the
following commands are run (as root) to synchronise the system clock:
<pre>
chronyc makestep 0.1 3
chronyc burst 4/4 [optional netmask]
</pre>

The -h option displays this help text and then exits.  
The -s option causes chronywake to execute the commands a single time and then exit.  

For further detail on the arguments, refer to the entries for 'makestep' and 'burst' in the [chronyc](https://chrony.tuxfamily.org/documentation.html) man page.  

**Usage:**
<pre>
chronywake [options]
options: [-c path-to-chronyc]
         [-g burst-good]
         [-h]
         [-l makestep-limit]
         [-m burst-max]
         [-n netmask]
         [-s]
         [-t makestep-threshold]
</pre>

### Automatic launch at boot
Launching software at boot under macOS is performed with the launchctl utility and a propertylist (plist) file.

```
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>KeepAlive</key>
	<true/>
	<key>Label</key>
	<string>net.whatroute.chronywake</string>
	<key>Program</key>
	<string>/usr/local/bin/chronywake</string>
	<key>ProgramArguments</key>
	<array>
		<string>chronywake</string>
		<string>-c</string>
		<string>/usr/local/bin/chronyc</string>
		<string>-g</string>
		<string>4</string>
		<string>-l</string>
		<string>3</string>
		<string>-m</string>
		<string>4</string>
		<string>-t</string>
		<string>0.05</string>
	</array>
</dict>
</plist>
```

A property list in <code>/Library/LaunchDaemons/net.whatroute.chronywake.plist</code> can be used to load chronywake at system boot. Register this service with the command:

`sudo launchctl load -w /Library/LaunchDaemons/net.whatroute.chronywake.plist`

See `man launchctl` for more information.
