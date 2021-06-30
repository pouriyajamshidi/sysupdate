# sysupdate

sysupdate is a Bash script that is used to not only update/upgrade your [Linux servers, workstations and IoT devices](#supported-operating-systems), but also take care of the residual files and configuration files that are prone to stay on your system over time and need to be manually removed.  
As of this writing updating `Snap` and `Flatpak` packages under `Debian` and its derivatives is supported with the plan to extend this functionality to other distros.

It logs the steps taken in a file located in ```/var/log/sysupdate.txt``` so you can keep track of the changes made to your system.

This script has been running on over a dozen different servers and workstations for a couple of years now and never caused any issues, however, **please be wise and cautious** when using it.

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
sudo ./sysupdate.sh
```

You can also make a `cron` job to run it at the time of your liking.

## Demo

[![asciicast](https://asciinema.org/a/423233.svg)](https://asciinema.org/a/423233)

## Images

![sysupdate1](/images/sysupdate1.png)
![sysupdate2](/images/sysupdate2.png)

## Supported Operating Systems

* Debian and its derivatives:
  * Ubuntu
  * Mint
  * ZorinOS
  * Pop!_OS
  * etc...
* Fedora
* RedHat
* CentOS
* Arch
* Oracle
* Raspberry Pi

## Tested on

Ubuntu, Mint and vanilla Debian.  
**If you see your distro in the [supported list](#supported-operating-systems) but the script fails to work, please file a bug report.**

## Contributing

Pull requests are welcome.

## License

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
