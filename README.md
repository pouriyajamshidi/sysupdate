# sysupdate

sysupdate is a Bash script that updates your [Linux servers, workstations and IoT devices](#supported-operating-systems) and then cleans up what the update leaves behind: unused packages, orphans, residual configuration files, superseded snap revisions, unused Flatpak runtimes and an ever-growing systemd journal.

It picks the right package manager for the running system, skips anything that is not installed and keeps going when a single step fails, so it is safe to run unattended from `cron` or a systemd timer. Every step is logged to `/var/log/sysupdate.txt` and the exit code is non-zero if any step failed.

This script has been running on over a dozen different servers and workstations for a couple of years now and never caused any issues, however, **please be wise and cautious** when using it.

## Quick install

```bash
sudo curl -fsSL https://raw.githubusercontent.com/pouriyajamshidi/sysupdate/master/sysupdate.sh -o /usr/local/bin/sysupdate
sudo chmod +x /usr/local/bin/sysupdate
```

## Usage

```bash
sudo sysupdate
```

Or without installing it:

```bash
sudo ./sysupdate.sh
```

You can also make a `cron` job to run it at the time of your liking:

```cron
0 4 * * 6 /usr/local/bin/sysupdate --user yourname
```

`cron` runs as root with no `$SUDO_USER`, so name the user explicitly there if you want your toolchains updated too.

## Configuration

```text
  -u, --user USER  also update USER's own toolchains (default: $SUDO_USER)
  -n, --no-user    system packages only
  -h, --help       show this help
```

The rest is controlled through environment variables:

| Variable | Default | Purpose |
| --- | --- | --- |
| `SYSUPDATE_LOG` | `/var/log/sysupdate.txt` | Where the run is logged |
| `SYSUPDATE_USER` | `$SUDO_USER` | Same as `--user` |
| `SYSUPDATE_JOURNAL_KEEP` | `14d` | How much systemd journal to keep |

`--user` covers the toolchains that live in a home directory rather than in the system package manager. Each one is only touched if that user actually has it: `rustup`, `choosenim` (stable, devel and itself), `nimble`, `v` and `pipx`. Running `sudo sysupdate` already picks up `$SUDO_USER`, so the flag is mostly for `cron`. Use `--no-user` to stay out of home directories entirely:

```bash
sudo sysupdate --no-user
```

## What it does

| System | Update | Clean up |
| --- | --- | --- |
| Debian and derivatives | `apt-get update`, `full-upgrade` | `autoremove --purge`, `autoclean`, purge of residual (`rc`) packages |
| Fedora, RHEL, CentOS, Oracle | `dnf`/`yum upgrade --refresh` | `autoremove`, `clean all` |
| Arch | `pacman -Syu` | orphan removal, `paccache -rk1` |
| Any | `snap refresh`, `flatpak update` | disabled snap revisions, unused Flatpak runtimes, journal trim |

If a reboot is required afterwards, it says so.

## What a run looks like

```text
======================================================================
sysupdate - 2026-09-12 04:00:01
======================================================================

==> Refreshing package lists
Hit:1 http://archive.ubuntu.com/ubuntu noble InRelease
...

==> Upgrading packages
7 upgraded, 0 newly installed, 0 to remove and 0 not upgraded.
...

==> Purging leftover config of 3 package(s)
...

==> Removing snap core22 revision 1033
core22 revision 1033 removed

==> Trimming the journal to 14d
Vacuuming done, freed 1.1G of archived journals

==> yourname: rustup update
info: cleaning up downloads & tmp directories

[!] A reboot is required

==> Finished in 96s
======================================================================
```

## Supported Operating Systems/Distros

* Debian and its derivatives:
  * Ubuntu
  * Mint
  * ZorinOS
  * Pop!_OS
  * Raspberry Pi OS
  * etc...
* Fedora
* RedHat
* CentOS
* Oracle
* Arch

## Tested on

Ubuntu, Mint and vanilla Debian.  
**If you see your distro in the [supported list](#supported-operating-systems) but the script fails to work, please file a bug report.**

## Contributing

Pull requests are welcome.

## License

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
