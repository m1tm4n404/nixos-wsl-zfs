# nixos-wsl-zfs

Microsoft WSL2 Linux **kernel with OpenZFS support** for [NixOS-WSL](https://github.com/nix-community/NixOS-WSL) (and any WSL2 distro willing to use Nix-built artifacts).

## Why

- The stock WSL2 kernel shipped by Windows (`*-microsoft-standard-WSL2`) has **no ZFS**.
- NixOS-WSL does not manage its own kernel — it boots whatever Windows provides via `%USERPROFILE%\.wslconfig`.
- Existing alternatives (e.g. [omasakun/wsl-zfs-module](https://github.com/omasakun/wsl-zfs-module)) ship prebuilt modules that must exactly match the Windows-provided kernel revision, which changes silently with Windows updates.

This flake solves it the reproducible way, with **two modes**:

### Mode A: stock kernel (default, simplest)

Keep the Windows-provided kernel. The flake builds the OpenZFS module against a vanilla [kernel.org](https://kernel.org) source release versioned to match the running WSL2 kernel (`6.18.57-microsoft-standard-WSL2` at the time of writing), using Microsoft's own WSL kernel config so the vermagic and ABI line up. Load it at boot via the NixOS module — no kernel replacement, no `.wslconfig` changes.

Trade-off: whenever Windows updates the WSL2 kernel, bump `stockVersion`/`stockModDirVersion`/`stockSrcHash` in `constants.nix` and rebuild.

### Mode B: pinned custom kernel

Builds the **Microsoft WSL2 kernel** from [microsoft/WSL2-Linux-Kernel](https://github.com/microsoft/WSL2-Linux-Kernel) (`linux-msft-wsl-6.18.y`, currently `6.18.58.1`) with Microsoft's config **verbatim**, plus the OpenZFS module against that exact kernel. You select the resulting `bzImage` via `.wslconfig`, so Windows updates can no longer break the module — kernel updates are on you.

The NixOS module **fails loudly** if the running kernel is not the one the module was built for.

## Build

```console
$ nix build .#zfs-kmod-stock  # mode A: ZFS kmod for the stock Windows kernel
$ nix build .#kernel          # mode B: bzImage in ./result/bzImage
$ nix build .#zfs-kmod        # mode B: ZFS kmod for the flake's kernel
```

## Install

### Mode A (stock kernel)

Skip the Windows-side steps entirely; only do the NixOS side below (default `wsl-zfs.kmod = "stock-kernel"`).

### Mode B (pinned kernel)

1. Copy the kernel image somewhere Windows-stable, e.g.:

```powershell
mkdir $env:USERPROFILE\.wsl-kernels
wsl -d NixOS -- cat ~/nixos-wsl-zfs/result/bzImage > $env:USERPROFILE\.wsl-kernels\bzImage-wsl-zfs
```

2. Point `.wslconfig` at it (`%USERPROFILE%\.wslconfig`):

```ini
[wsl2]
kernel=C:\\Users\\<you>\\.wsl-kernels\\bzImage-wsl-zfs
```

3. Restart WSL:

```powershell
wsl --shutdown
```

## Install (NixOS-WSL side)

Add this flake as an input to your NixOS flake:

```nix
# flake.nix
inputs.wsl-zfs.url = "github:m1tm4n404/nixos-wsl-zfs";
```

```nix
# your nixos-wsl host
inputs@{ ... }: {
  imports = [ inputs.wsl-zfs.nixosModules.wsl-zfs ];
  wsl-zfs.enable = true;
  # "stock-kernel" (default) or "custom-kernel" (mode B):
  # wsl-zfs.kmod = "custom-kernel";
  # optional: import all visible pools without mounting:
  # wsl-zfs.autoImportPools = true;
}
```

Then `sudo nixos-rebuild switch --flake .#yourhost` and verify:

```console
$ uname -r
6.18.57-microsoft-standard-WSL2   # stock (mode A) — or 6.18.58.1-... (mode B)
$ zfs version
zfs-2.4.4-1
zfs-kmod-2.4.4-1
```

## Usage example: receive a dataset from a remote ZFS host

Give WSL a disk to work with (either a VHDX or a bare physical disk):

```powershell
wsl --mount --vhd D:\pools\zfs.vhdx --bare        # virtual disk
# or, for a whole physical disk (admin):
wsl --mount \\.\PHYSICALDRIVE3 --bare
```

Then inside WSL:

```console
$ sudo zpool create tank /dev/sdX          # one-time
$ ssh remote-host 'zfs send -R pool/home@snap' | sudo zfs receive tank/home
```

## Updating the kernel

1. Pick the release commit from [`linux-msft-wsl-6.18.y`](https://github.com/microsoft/WSL2-Linux-Kernel/commits/linux-msft-wsl-6.18.y).
2. Update `constants.nix` (`msRev`, `msVersion`, `modDirVersion`) and fetch the new hash:

```console
$ nix store prefetch-file --hash-type sha256 \
    https://github.com/microsoft/WSL2-Linux-Kernel/archive/<rev>.tar.gz
```

3. Copy the matching `arch/x86/configs/config-wsl` to `kernel/config-wsl-<version>`, update the path in `flake.nix`.
4. Rebuild, reinstall `bzImage` (Windows side), `wsl --shutdown`.

## Caveats

- You pin the kernel: Windows no longer auto-updates it (that is the point, but security updates are now your job — bump the rev regularly).
- `wsl --mount --bare` requires Windows 11 and admin rights.
- Built kernel is GPL-2.0 (as upstream); the Nix expressions here are MIT.
