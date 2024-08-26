# idle-delay
 Auto adjust screen blank idle-delay based on phone connection

#### Why?

I needed a nice way to set idle-delay based on wether I'm at my PC or not,
to not accidentally leave the PC unlocked. So when disconnecting the phone,
idle-delay is set to 10 minutes, and when connected it's set to 120 minutes.

Default idle-delay is set to 60 minutes (if no phone is defined)

## Install

With wget:
```bash
wget -qO- https://github.com/tmiland/idle-delay/raw/main/idle-delay.sh | bash -s -- -i
```
With curl:
```bash
curl -fsSLk https://github.com/tmiland/idle-delay/raw/main/idle-delay.sh | bash -s -- -i
```

## Requirements

- Only tested on debian 12 desktop
- Gnome Desktop
- curl or wget
- screen
- systemd
- libnotify-bin

#### Disclaimer 

*** ***Use at own risk*** ***

### License

[![MIT License Image](https://upload.wikimedia.org/wikipedia/commons/thumb/0/0c/MIT_logo.svg/220px-MIT_logo.svg.png)](https://github.com/tmiland/idle-delay/blob/master/LICENSE)

[MIT License](https://github.com/tmiland/idle-delay/blob/master/LICENSE)