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

## Packages

- grok-build-bin
  https://aur.archlinux.org/packages/grok-build-bin
- grok-build
  
- grok-build-git
  https://aur.archlinux.org/packages/grok-build-git

## License

- Root (workflows, scripts, actions, etc.) → **MIT**  
  See the `LICENSE` file in the root.

- Each package folder → **0BSD** (as prescribed by Arch Linux for PKGBUILDs)  
  Every package folder contains its own `LICENSE` file.
