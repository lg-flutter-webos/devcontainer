# Flutter for webOS — Dev Container

Building a webOS app requires the **webOS NDK, which is Linux-only**. This Dev Container packages the NDK and the `flutter-webos` toolchain so you can build webOS Flutter apps from **any host — macOS, Windows, or Linux** — without setting up a Linux machine yourself.

VS Code runs on your machine; all building, packaging, and debugging happen inside the container. See the [official Dev Container guide](https://code.visualstudio.com/docs/devcontainers/containers) for background.

## What's inside

- **`flutter-webos`** — the webOS Flutter CLI (build, run, package), preinstalled and on `PATH`.
- **webOS NDK** — the Linux-only cross-compile toolchain, with one NDK version baked in (see *webOS NDK*).
- **`ares` CLI** — webOS packaging/deploy tooling for producing and installing `.ipk` files.
- Engine artifacts pre-cached and custom devices enabled, so the container is ready to build on first start.

## Requirements

- **Visual Studio Code** + the [**Dev Containers** extension](https://code.visualstudio.com/docs/devcontainers/tutorial)
- **Docker**
  - Windows: Docker Desktop with the **WSL2 backend** (required — see the Windows note below)
  - macOS / Linux: install from the [official Docker site](https://www.docker.com/), then verify with `docker --version`
- A few GB of free disk for the image (base + NDK + engine artifacts), and enough memory allocated to Docker to build.

> **Apple Silicon (M-series) note:** the webOS NDK is an x86_64 toolchain, so the image runs as `linux/amd64`. On Apple Silicon it works under emulation, which is noticeably slower than native. This is expected.

> **Windows note — keep the project on the Linux (WSL2) filesystem.** The container bind-mounts your source from the host, and the shader compiler (`impellerc`) sets POSIX file permissions on its build output. A Windows drive (`C:\…`, i.e. `/mnt/c/…`) is NTFS and rejects that, so the build fails with `Failed to set access on file … Operation not permitted`. Clone and open the project **inside a WSL2 distribution's Linux home** (an `ext4` filesystem) — not under `C:\`. macOS and Linux are unaffected and need no special handling. See [Windows: clone into WSL2](#windows-clone-into-wsl2).

## Quick start

1. **Clone the repository.** On **Windows**, do this inside a WSL2 distribution and keep it on the Linux filesystem — see [Windows: clone into WSL2](#windows-clone-into-wsl2). On macOS and Linux, clone anywhere.

   ```shell
   git clone https://github.com/lg-flutter-webos/devcontainer.git
   ```

2. **Accept the webOS NDK license.** Open [`.devcontainer/.env`](.devcontainer/.env) and set:

   ```shell
   WEBOS_NDK_ACCEPT_EULA=1
   ```

   This is required *before* the first build — the NDK is licensed under the LG SDK License Agreement and the build will not accept it on your behalf (see *webOS NDK → webOS NDK License*).

3. **Reopen in Container.** Open the `devcontainer` folder in VS Code and, when prompted, click **"Reopen in Container"**. If the prompt doesn't appear, run `Dev Containers: Reopen in Container` from the Command Palette (`Ctrl+Shift+P`).

   VS Code builds the image automatically from `.devcontainer/docker-compose.yml` (which references `.devcontainer/Dockerfile`) — no manual `docker compose build` is required.

   > Optional — pre-build from the command line:
   > ```shell
   > cd devcontainer/.devcontainer
   > docker compose build
   > ```

4. **Verify the environment.** A terminal inside the container should find the toolchain:

   ```shell
   flutter-webos doctor -v
   ```

   (This also runs automatically once when the container is created.)

## Windows: clone into WSL2

On Windows the project **must live on the Linux (`ext4`) filesystem inside WSL2**, not on a Windows drive. The container bind-mounts your source, and `impellerc` sets POSIX permissions (`0644`) on the compiled shaders in `build/`. NTFS — which backs `C:\…` (mounted as `/mnt/c/…` in WSL) — does not support that operation, so a build from a Windows path fails with:

```
Failed to set access on file '.../build/webos/flutter_assets/shaders/stretch_effect.frag': Operation not permitted
```

macOS and Linux are not affected.

1. **Install WSL2 and a distribution** (once), from an elevated PowerShell:

   ```powershell
   wsl --install
   ```

2. **Enable Docker Desktop's WSL integration** for that distribution: Docker Desktop → *Settings → Resources → WSL Integration* → toggle your distro on.

3. **Clone into the Linux home, not `/mnt/c`.** Open the distribution (e.g. *Ubuntu*) and run:

   ```shell
   cd ~                 # a real ext4 path like /home/<you>, NOT /mnt/c/...
   git clone https://github.com/lg-flutter-webos/devcontainer.git
   code ./devcontainer  # opens VS Code connected to WSL
   ```

   > Confirm the location with `pwd` — it should print `/home/...`. If it prints `/mnt/c/...` you are on the Windows drive and the build will fail.

4. **Reopen in Container** as in [Quick start](#quick-start) step 3. VS Code's bottom-left indicator should read *WSL: \<distro\>* before you reopen, and *Dev Container* afterward.

## webOS NDK

Building a webOS app needs the **webOS NDK** — the Linux-only cross-compile toolchain. The image bakes in one NDK version, set by `WEBOS_NDK_VERSION` in [`.devcontainer/.env`](.devcontainer/.env):

| Setting | Value |
|---|---|
| `WEBOS_NDK_VERSION` | 11.2.0 |

The active toolchain lives in a **named Docker volume** (`/opt/webos-ndk`) that persists across rebuilds. To switch versions, install and select one at runtime with `webos-ndk` (see *Adding or switching NDK versions* below) — no rebuild needed.

> **Editing `WEBOS_NDK_VERSION` and rebuilding does not switch an existing setup.** Docker populates the volume from the image only when the volume is first created (empty); once it exists it keeps its contents, so the newly baked version is ignored. To change the baked default, remove the `webos-ndk` volume (`docker volume rm <project>_webos-ndk`) and rebuild so it is repopulated — or simply switch at runtime with `webos-ndk use`.

### webOS NDK License

The webOS NDK is licensed under the **LG SDK License Agreement**, which the installer displays before installing. You must accept it to build the image or install an NDK. Acceptance is never recorded on your behalf:

- **Building the image** (non-interactive): set `WEBOS_NDK_ACCEPT_EULA=1` in [`.devcontainer/.env`](.devcontainer/.env). Without it, the build stops with instructions instead of accepting for you.
- **Installing an NDK from a terminal inside the container**: the installer prints the agreement and prompts you to accept it. (You can skip the prompt with `WEBOS_NDK_ACCEPT_EULA=1 webos-ndk install …`.)

### Adding or switching NDK versions

NDKs install side by side and persist across rebuilds (the NDK root is a named volume), so you can install another version without changing the baked default:

```shell
webos-ndk install 11.3.0   # fetch + install by version
webos-ndk use 11.3.0       # switch the active toolchain
```

`flutter-webos build webos` always uses the active toolchain.

```shell
webos-ndk list             # list installed NDKs (active marked with *)
webos-ndk current          # show the active version
webos-ndk use 11.2.0       # switch back
```

If a version isn't published at the default location yet, install it from an explicit installer URL:

```shell
webos-ndk install 11.3.0 --url <installer-url>
```

| Command | Action |
|---|---|
| `webos-ndk install <version>` | fetch + install an NDK by version |
| `webos-ndk install <version> --url <installer-url>` | install from an explicit installer URL |
| `webos-ndk use <version>` | switch the active toolchain |
| `webos-ndk list` / `webos-ndk current` | inspect installed / active NDKs |

## Ports & GUI

VS Code forwards the GUI ports explicitly:

| Port | Purpose | Forwarding |
|---|---|---|
| 6080 | noVNC — view in-container GUI apps in your browser | declared (`forwardPorts`) |
| 5900 | VNC (raw protocol, for a native VNC client) | declared (`forwardPorts`) |

This lets you run a Linux GUI application **inside** the container and see it from any host: launch it against `DISPLAY=:1`, then open the forwarded port 6080 in your browser. The container runs only a minimal window manager (Openbox) on a virtual display — not a full desktop environment. The VNC server is bound to localhost and exposed only through VS Code's authenticated port forwarding.

> The GUI stack is only for running other Linux GUI apps in the container. DevTools does **not** need it — it runs in your own host browser, and its Dart VM Service port is auto-forwarded by Dev Containers when the app starts.

## Next steps

For building, running, packaging, and connecting a webOS device, see [Getting Started with Flutter for webOS](https://github.com/lg-flutter-webos/flutter-webos/blob/main/doc/getting-started.md).

## Troubleshooting

- **Build stops asking you to accept the NDK license** — set `WEBOS_NDK_ACCEPT_EULA=1` in [`.devcontainer/.env`](.devcontainer/.env) (see *webOS NDK License*).
- **`flutter-webos` not found / `doctor` reports missing toolchain** — rebuild the container (`Dev Containers: Rebuild Container`) and re-run `flutter-webos doctor -v`.
- **Engine artifact or NDK download fails** — the build fetches artifacts over the network; check connectivity (and any proxy) from inside the container.
- **Slow builds on Apple Silicon** — expected; the image runs under x86_64 emulation (see *Requirements*).
- **`Failed to set access on file … Operation not permitted` (Windows)** — the project is on a Windows/NTFS path (`C:\…` / `/mnt/c/…`). Move it onto the WSL2 Linux filesystem and reopen from there — see [Windows: clone into WSL2](#windows-clone-into-wsl2).
