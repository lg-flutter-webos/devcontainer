FROM ubuntu:22.04

ENV DEBIAN_FRONTEND="noninteractive" \
    SDK_URL="https://github.com/lg-flutter-webos/flutter-webos.git"

RUN apt update && apt install -y \
    at-spi2-core \
    clang \
    cmake \
    curl \
    file \
    git \
    git-lfs \
    iputils-ping \
    libglu1-mesa \
    libgtk-3-0 \
    libgtk-3-dev \
    liblzma-dev \
    libstdc++-10-dev \
    make \
    nano \
    net-tools \
    ninja-build \
    openbox \
    pkg-config \
    python3 \
    python3-pip \
    python-is-python3 \
    software-properties-common \
    sudo \
    unzip \
    vim \
    websockify \
    wget \
    x11-utils \
    x11vnc \
    xterm \
    xvfb \
    xz-utils \
    && apt autoremove -y && apt autoclean -y && rm -rf /var/lib/apt/lists/*

# Setup noVNC
RUN mkdir -p /opt/novnc \
    && git clone https://github.com/novnc/noVNC.git -b v1.6.0 --depth 1 /opt/novnc \
    && git clone https://github.com/novnc/websockify.git -b v0.13.0 --depth 1 /opt/novnc/utils/websockify \
    && printf "const url = new URL(window.location.href);\nif (!url.searchParams.has('resize')) {\n  url.searchParams.set('resize', 'scale');\n  window.location.href = url.toString();\n}\n" > /opt/novnc/redirect.js \
    && printf '<script src="redirect.js"></script>\n' >> /opt/novnc/vnc.html

# Node.js for ares CLI. webOS TV recommends Node 14.15.1 - 16.20.2:
# https://webostv.developer.lge.com/develop/tools/cli-installation
# The runtime is the lone root-owned piece — harmless, since it is only executed.
RUN apt-get update && apt-get install -y ca-certificates curl gnupg \
    && curl -fsSL https://deb.nodesource.com/setup_16.x | bash - \
    && apt-get install -y nodejs \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# webOS NDK toolchain(s). NDKs are managed by version via the webos-ndk helper and
# installed side by side under /opt/webos-ndk so additional versions can be added at
# runtime (no rebuild) and persist when that path is a named volume (see
# docker-compose.yml). The active toolchain is selected through the stable
# /opt/webos-ndk/active symlink, so WEBOS_FLUTTER_NDK_ENV stays constant.
# WEBOS_NDK_VERSION picks the version baked at build time. NDK_BASE_URL is
# parameterized so it can be repointed for external distribution. The install
# itself runs as the unprivileged user further down.
ARG WEBOS_NDK_VERSION
# Building the image installs the webOS NDK, which is licensed under LG's SDK
# License Agreement. Acceptance is never silent: the build only proceeds when the
# user opts in with WEBOS_NDK_ACCEPT_EULA=1 (passed through from docker-compose).
# Left unset, the NDK install aborts with instructions instead of accepting on
# the user's behalf. This must not be baked into the image as a persistent ENV.
ARG WEBOS_NDK_ACCEPT_EULA
ENV NDK_BASE_URL="https://github.com/lg-flutter-webos/ndk/releases/download" \
    WEBOS_NDK_ROOT="/opt/webos-ndk" \
    WEBOS_FLUTTER_NDK_ENV="/opt/webos-ndk/active/env-setup"
COPY webos-ndk /usr/local/bin/webos-ndk
RUN chmod +x /usr/local/bin/webos-ndk

# Create a non-root user and grant passwordless sudo.
# UID/GID are build args so the container user can match the host owner of the
# bind-mounted workspace (devcontainer also applies updateRemoteUserUID at runtime).
ARG USER_UID=1000
ARG USER_GID=1000
RUN groupadd --gid ${USER_GID} vscode 2>/dev/null || true; \
    useradd -ms /bin/bash -G sudo --uid ${USER_UID} --gid ${USER_GID} vscode && \
    echo "vscode ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Pre-create the NDK root owned by the user so everything written into it below
# is created vscode-owned — no recursive chown needed (the NDK tree has tens of
# thousands of files; a `chown -R` there would copy-up the whole tree into a new
# layer, costing minutes of build time and doubling its image size). The NDK root
# is a named volume at runtime; populating it vscode-owned at build lets the
# runtime user install additional NDKs on demand.
RUN mkdir -p /opt/webos-ndk \
    && chown vscode:vscode /opt/webos-ndk

# Everything below is webOS build tooling (SDK, ares CLI, NDK, engine artifacts).
# None of it needs root, so run it as the unprivileged user — files land
# vscode-owned by construction.
USER vscode
WORKDIR /home/vscode

# ares CLI installs globally into a user-owned npm prefix (no root); flutter-webos
# lives under the user's home. Both bin dirs go on PATH. The SDK is deliberately
# kept inside $HOME (not /opt): devcontainer's updateRemoteUserUID remaps the
# runtime user to the host UID and chowns the home tree to match, so the SDK — a
# git checkout that Flutter writes to (bin/cache/lockfile) — stays owned by and
# writable for whatever UID the user is remapped to. Placing it outside $HOME
# would miss that remap and break with "dubious ownership" / permission errors.
ENV NPM_CONFIG_PREFIX="/home/vscode/.npm-global"
ENV PATH="/home/vscode/.npm-global/bin:/home/vscode/flutter-webos/bin:${PATH}"

# Setup flutter-webos SDK into the user's home (see PATH note above).
RUN git clone ${SDK_URL} /home/vscode/flutter-webos \
    && test -f /home/vscode/flutter-webos/bin/flutter-webos \
    && chmod +x /home/vscode/flutter-webos/bin/flutter-webos \
    && command -v flutter-webos >/dev/null

# webOS CLI (ares) for packaging and deploying .ipk, installed in user space.
RUN npm install -g @webos-tools/cli \
    && ares -V

# Install the baked NDK version as the user (writes into the pre-owned
# /opt/webos-ndk). WEBOS_NDK_ACCEPT_EULA records explicit license acceptance.
RUN WEBOS_NDK_ACCEPT_EULA="${WEBOS_NDK_ACCEPT_EULA}" webos-ndk install "${WEBOS_NDK_VERSION}" \
    && webos-ndk use "${WEBOS_NDK_VERSION}" \
    && test -f "${WEBOS_FLUTTER_NDK_ENV}"

# Pre-download engine artifacts and enable custom devices so the container is
# ready on first start. A precache failure fails the image build here.
RUN flutter-webos precache -f \
    && flutter-webos config --enable-custom-devices
# `doctor` is informational only: it returns non-zero whenever optional
# toolchains (Android/Chrome) are absent, which is expected for a webOS image.
RUN flutter-webos doctor -v || true

# Root only for final system-file setup. Kept last so changes here don't
# invalidate the cache of the heavy user-space layers above.
USER root
COPY start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/start.sh
# noVNC landing page symlink, created as root: the runtime user (vscode) cannot
# write to /opt/novnc, so this must not be done at container start.
RUN ln -sf vnc.html /opt/novnc/index.html

# Final switch to the user for the entrypoint
USER vscode
WORKDIR /home/vscode

# start.sh launches the GUI stack in the background and then keeps the
# container alive (or execs the compose-provided command), so a GUI crash
# doesn't take the container down with it.
ENV DISPLAY=":1"
EXPOSE 5900 6080
ENTRYPOINT ["/usr/local/bin/start.sh"]
