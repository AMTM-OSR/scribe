# ~ scribe ~ Entware syslog-ng and logrotate installer for Asuswrt-Merlin

**scribe** is a **syslog-ng** and **logrotate** installer for ASUS routers running **Asuswrt-Merlin**

## v3.2.10
### Updated on 2026-Feb-15

## Getting Started

### Prerequisites

1. [Asuswrt-Merlin](https://asuswrt.lostrealm.ca/ "Pure Freaking Magic") running on a supported ASUS router
2. **Entware** installed, preferably using [amtm](https://github.com/decoderman/amtm "amtm")
3. jffs scripts enabled in the firmware; this can be set manually, and installing **Entware** via amtm usually takes care of it

* **scribe** includes handlers for the logs created by [skynet](https://github.com/Adamm00/IPSet_ASUS "skynet"); if you wish to use these handlers, it is advised to install **skynet** first.  If **skynet** is installed after scribe, you will have to re-run the installation and force installation.

### Installing

SSH into the router and run:
```bash
/usr/sbin/curl --retry 3 "https://raw.githubusercontent.com/AMTM-OSR/scribe/master/scribe.sh" -o "/jffs/scripts/scribe" && chmod 0755 /jffs/scripts/scribe && /jffs/scripts/scribe install
```

## Built With

* [vim](https://www.vim.org/ "definitely NOT emacs") - because vi is always there, so I'm not lost on a clean install.
* amix's [vimrc](https://github.com/amix/vimrc) - basic version.


## Acknowledgments

* RMerlin, for enduring an endless stream of people who will not read the release notes (out of his control), yet is still dedicated to producing the awesomeness that is AsusWRT-Merlin in what used to be known as his "free time".
* The great coders of SNB Forums, in alphabetical order, for lack of a better system:
    * Adamm
    * dave14305
    * Jack Yaz
    * kvic
    * Martineau
    * Odkrys
    * thelonelycoder
    * Xentrk

* Alpha and Beta testing endured by Butterfly Bones, elorimer, and skeal.

* I'm sure I missed someone, if it's you, I'm sorry, it wasn't intentional.  

* Template used for this README shamelessly stolen from [PurpleBooth](https://gist.github.com/PurpleBooth/109311bb0361f32d87a2 "don't reinvent the wheel")
