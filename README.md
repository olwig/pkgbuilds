# pkgbuilds

Personal Arch Linux PKGBUILDs — modified, improved and new packages I use.

## License

PKGBUILDs them selves are OBSD as archlinux referse to. bu the action code in root like worksflow is MIT

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

## License

- Root (workflows, scripts, actions, etc.) → **MIT**  
  See the `LICENSE` file in the root.

- Each package folder → **0BSD** (as prescribed by Arch Linux for PKGBUILDs)  
  Every package folder contains its own `LICENSE` file.
