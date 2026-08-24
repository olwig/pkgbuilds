# pkgbuilds

Personal Arch Linux PKGBUILDs — modified, improved and new packages I use.

## Usage with paru

Add this to your `paru.conf` (usually `~/.config/paru/paru.conf` or `/etc/paru.conf`):

```ini
[olw-pkgbuilds]
Url = https://github.com/olwig/pkgbuilds
Depth = 2
```

Then run:

```bash
paru -Sya
```

Afterwards you can install packages from this repo with `paru -S <pkgname>`.

## Troubleshooting

If you run into problems with this repo, remove the paru cache and refresh again:

```bash
rm -rf ~/.cache/paru/*
paru -Sya
```


