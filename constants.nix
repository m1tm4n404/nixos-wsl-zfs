{
  # Microsoft WSL2 kernel source, pinned by commit.
  # Branch: linux-msft-wsl-6.18.y, release commit "WSL Kernel 6.18.58.1".
  msRev = "a989171929bed4ea681be8d77333845ce1c1732a";
  msVersion = "6.18.58.1";
  # CONFIG_LOCALVERSION in Microsoft's arch/x86/configs/config-wsl.
  localversion = "-microsoft-standard-WSL2";
  # Full `uname -r` of the built kernel (version + localversion).
  modDirVersion = "6.18.58.1-microsoft-standard-WSL2";
  # sha256 of https://github.com/microsoft/WSL2-Linux-Kernel/archive/${msRev}.tar.gz
  # (nix store prefetch-file --hash-type sha256 <url>)
  srcHash = "sha256-6zyNYVfeSshDs1959gQ8uCWDMlpjW9GUKK895bBkGtc=";
}
