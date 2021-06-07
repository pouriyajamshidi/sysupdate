# sysupdate

sysupdate is a Bash script that is used to not only update/upgrade your Linux (Debian based for now) server/workstation, but also take care of the residual files and configurations that are prone to stay on your system over time and need to be manually removed.

It logs the steps taken in a file located in ```/var/log/sysupdate.txt``` so you can keep track of the changes made to your system.

This script has been running on over a dozen different servers and workstations for a couple of years now and never caused any issues, however, **please be wise and cautious** when using it.

_If you don't like or not using snap, you can crop it out from this script_.

## Usage

For convenience, it is suggested to place this script in your OS's ```PATH``` as depicted below:

```bash
curl -O https://raw.githubusercontent.com/pouriyajamshidi/sysupdate/master/sysupdate.sh
chmod +x sysupdate.sh
sudo cp sysupdate.sh /usr/bin/sysupdate
```

And run it like:

```bash
sudo sysupdate
```

If you prefer to not place it in your system `PATH`:

```bash
sudo sysupdate.sh
```

You can also make a cron job to run it at the time of your liking.

## Demo

[![asciicast](https://asciinema.org/a/qnuWfHTvsXf8VDl0aHbpwC2Mq.svg)](https://asciinema.org/a/qnuWfHTvsXf8VDl0aHbpwC2Mq)

## Images

![sysupdate1](/images/sysupdate1.jpg)
![sysupdate2](/images/sysupdate2.jpg)

## Tested on

Ubuntu server/Desktop 14 to 20, Linux Mint and vanilla Debian.

## Contributing

Pull requests are welcome.

## License

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
