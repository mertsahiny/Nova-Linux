# NOVA Linux pipeline patch

This patch replaces the build entry point and GitHub Actions workflow.

## Apply

From the root of `Nova Linux` in PowerShell:

```powershell
Expand-Archive -Force .\NOVA-pipeline-patch.zip .\NOVA-pipeline-patch
Copy-Item .\NOVA-pipeline-patch\build\build-all.sh .\build\build-all.sh -Force
Copy-Item .\NOVA-pipeline-patch\.github\workflows\build.yml .\.github\workflows\build.yml -Force
Copy-Item .\NOVA-pipeline-patch\packages\firmware.txt .\packages\firmware.txt -Force
Remove-Item .\NOVA-pipeline-patch -Recurse -Force
```

The build is run on GitHub Actions, not locally on Windows. Do not run the shell script in PowerShell.

## Important

- This builder creates a Debian 13 live filesystem at `/live/filesystem.squashfs`.
- It uses `grub-mkrescue` with BIOS and UEFI GRUB modules and never runs `grub-install` on the CI runner's disk.
- It installs Debian's maintained `calamares-settings-debian` package and adds a NOVA installer launcher. This deliberately avoids custom fake Calamares modules.
- Gaming stack is installed in the image with i386 multiarch enabled.
- The ISO has structural validation and a SHA256 checksum. A successful CI build is not a substitute for testing on a spare USB or in a VM.
