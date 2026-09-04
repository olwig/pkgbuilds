# pkgbuilds

Personal Arch Linux PKGBUILDs — modified, improved and new packages I use.

## Usage with paru

Add one of these to your `paru.conf` (usually `~/.config/paru/paru.conf` or `/etc/paru.conf`):

All packages:

```ini
[olwig/pkgbuilds]
Url = https://github.com/olwig/pkgbuilds
Depth = 3
```

Just `grok-build`:

```ini
[olwig/pkgbuilds-grok-build]
Url = https://github.com/olwig/pkgbuilds
Path = packages/grok-build
```

Then run:

```bash
paru -Sya
```

Afterwards you can install packages from this repo with `paru -S <pkgname>`.

## Packages

Package directories live under `packages/`.

- grok-build-bin: [AUR](https://aur.archlinux.org/packages/grok-build-bin)
- grok-build
- grok-build-git: [AUR](https://aur.archlinux.org/packages/grok-build-git)

> ⚠️ **<u>grok-build</u>**
> These packages install Grok on the host. If you are also paranoid about
> running Grok on your host, use the externally sandboxed Docker/Podman
> image instead: [olwig/grok-build-boxed](https://github.com/olwig/grok-build-boxed).
>
> Sandboxing should not sit inside grok-build. grok-build is what you want
> contained; relying on its own built-in sandbox to isolate itself fights
> that goal. An outer shell is better — one that is not maintained by the
> very thing it is meant to protect against.

## License

- Root (workflows, scripts, actions, etc.) → **MIT**  
  See the `LICENSE` file in the root.

- Each package folder → **0BSD** (as prescribed by Arch Linux for PKGBUILDs)  
  Every package folder contains its own `LICENSE` file.
