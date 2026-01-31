# ============================================
# Nothing sus at all
# ============================================
FROM kasmweb/core-ubuntu-noble:1.18.0@sha256:688b454c7d6d16a20afc18497cfca3e9963be2c4e8167c29b6ced2f1252b6fa6

# Use safe shell for all RUN commands
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]

LABEL maintainer="Anon Anon <nothing@toseehere.com>"
LABEL description="Nothing to see I swear :3"
LABEL version="1.1.0"

USER root

ENV HOME=/home/kasm-default-profile \
    STARTUPDIR=/dockerstartup \
    INST_SCRIPTS=/dockerstartup/install \
    DEBIAN_FRONTEND=noninteractive \
    LIBGL_ALWAYS_SOFTWARE=1

WORKDIR $HOME

RUN mkdir -p /home/kasm-default-profile && chown 1000:1000 /home/kasm-default-profile

# ============================================
# System packages, build essentials, and runtime libraries
# ============================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential gcc g++ make cmake \
    curl wget jq tree unzip zip \
    ca-certificates gnupg lsb-release apt-transport-https software-properties-common \
    libssl-dev pkg-config sqlite3 libsqlite3-dev redis-tools \
    git git-lfs \
    libgbm1 libnss3 libasound2t64 libxss1 libatk-bridge2.0-0 libgtk-3-0 \
    libxcb-cursor0 libxkbcommon-x11-0 libxcb-icccm4 libxcb-keysyms1 \
    libxcb-randr0 libxcb-render-util0 libxcb-xinerama0 libxcb-xinput0 \
    libgl1 libegl1 libopengl0 mesa-utils xdg-utils dbus-x11 \
    python3 python3-pip python3-venv python3-dev \
    openjdk-21-jdk \
    && git lfs install --system \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# Firefox (from Ubuntu repos - more secure than PPA)
# ============================================
RUN apt-get update && apt-get install -y --no-install-recommends firefox \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# Google Chrome (with sandbox preserved)
# ============================================
# NOTE: Chrome sandbox works best with user namespaces enabled on host.
# Avoid --cap-add=SYS_ADMIN as it grants excessive privileges.
# If sandbox issues occur, use --security-opt seccomp=chrome.json
RUN wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb \
    && apt-get update && apt-get install -y --no-install-recommends /tmp/chrome.deb \
    && rm /tmp/chrome.deb && rm -rf /var/lib/apt/lists/*

# ============================================
# VS Code (sandbox preserved)
# ============================================
RUN install -d -m 0755 /usr/share/keyrings \
    && curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /usr/share/keyrings/packages.microsoft.gpg \
    && chmod 0644 /usr/share/keyrings/packages.microsoft.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list \
    && apt-get update && apt-get install -y --no-install-recommends code \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# Node.js LTS (using apt repo instead of curl|bash)
# ============================================
RUN mkdir -p /usr/share/keyrings \
    && curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | gpg --dearmor -o /usr/share/keyrings/nodesource.gpg \
    && echo "deb [signed-by=/usr/share/keyrings/nodesource.gpg] https://deb.nodesource.com/node_22.x nodistro main" > /etc/apt/sources.list.d/nodesource.list \
    && apt-get update && apt-get install -y nodejs \
    && npm install -g yarn pnpm \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# Python virtual environment (pinned versions)
# ============================================
RUN python3 -m venv /opt/reviewer-venv \
    && /opt/reviewer-venv/bin/pip install --no-cache-dir \
        requests==2.32.3 flask==3.1.0 discord.py==2.5.2 httpx==0.28.1 python-dotenv==1.1.0 virtualenv==20.29.3

ENV PATH="/opt/reviewer-venv/bin:$PATH"

# ============================================
# Rust toolchain (with checksum verification)
# ============================================
ENV RUSTUP_HOME=/opt/rustup \
    CARGO_HOME=/opt/cargo
ENV PATH=/opt/cargo/bin:$PATH

ARG RUSTUP_SHA256=20a06e644b0d9bd2fbdbfd52d42540bdde820ea7df86e92e533c073da0cdd43c
RUN curl --proto '=https' --tlsv1.2 -sSf https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu/rustup-init -o /tmp/rustup-init \
    && echo "${RUSTUP_SHA256}  /tmp/rustup-init" | sha256sum -c - \
    && chmod +x /tmp/rustup-init \
    && /tmp/rustup-init -y --default-toolchain stable \
    && rm /tmp/rustup-init \
    && chown -R 1000:1000 $RUSTUP_HOME $CARGO_HOME

# ============================================
# Java environment and Gradle 8.10.2 (with checksum)
# ============================================
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
ARG GRADLE_VERSION=8.10.2
ARG GRADLE_SHA256=31c55713e40233a8303827ceb42ca48a47267a0ad4bab9177123121e71524c26

RUN wget -q https://services.gradle.org/distributions/gradle-${GRADLE_VERSION}-bin.zip -O /tmp/gradle.zip \
    && echo "${GRADLE_SHA256}  /tmp/gradle.zip" | sha256sum -c - \
    && unzip -q /tmp/gradle.zip -d /opt \
    && ln -s /opt/gradle-${GRADLE_VERSION} /opt/gradle \
    && rm /tmp/gradle.zip

ENV GRADLE_HOME=/opt/gradle
ENV PATH=$GRADLE_HOME/bin:$PATH

# ============================================
# Go 1.24.12 (with checksum from go.dev/dl)
# ============================================
ARG GO_VERSION=1.24.12
ARG GO_SHA256=bddf8e653c82429aea7aec2520774e79925d4bb929fe20e67ecc00dd5af44c50

RUN wget -q https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz -O /tmp/go.tar.gz \
    && echo "${GO_SHA256}  /tmp/go.tar.gz" | sha256sum -c - \
    && tar -C /usr/local -xzf /tmp/go.tar.gz \
    && rm /tmp/go.tar.gz \
    && mkdir -p /home/kasm-default-profile/go && chown 1000:1000 /home/kasm-default-profile/go

ENV PATH=/usr/local/go/bin:$PATH



# ============================================
# Android SDK (with checksum verification)
# ============================================
ENV ANDROID_SDK_ROOT=/opt/android-sdk \
    ANDROID_HOME=/opt/android-sdk
ENV PATH=$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH
ARG ANDROID_CMDLINE_SHA256=2d2d50857e4eb553af5a6dc3ad507a17adf43d115264b1afc116f95c92e5e258

RUN mkdir -p $ANDROID_SDK_ROOT/cmdline-tools \
    && wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O /tmp/cmdline-tools.zip \
    && echo "${ANDROID_CMDLINE_SHA256}  /tmp/cmdline-tools.zip" | sha256sum -c - \
    && unzip -q /tmp/cmdline-tools.zip -d $ANDROID_SDK_ROOT/cmdline-tools \
    && mv $ANDROID_SDK_ROOT/cmdline-tools/cmdline-tools $ANDROID_SDK_ROOT/cmdline-tools/latest \
    && rm /tmp/cmdline-tools.zip \
    && (yes || true) | sdkmanager --licenses \
    && sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0" \
    && chown -R 1000:1000 $ANDROID_SDK_ROOT

# ============================================
# Insomnia 10.3.1 (sandbox preserved)
# NOTE: Kong/Insomnia does not publish SHA256 checksums for releases.
# Consider verifying the download manually or using a mirror with checksums.
# ============================================
ARG INSOMNIA_VERSION=10.3.1
RUN wget -qL "https://github.com/Kong/insomnia/releases/download/core%40${INSOMNIA_VERSION}/Insomnia.Core-${INSOMNIA_VERSION}.deb" -O /tmp/insomnia.deb \
    && apt-get update && apt-get install -y --no-install-recommends /tmp/insomnia.deb \
    && rm /tmp/insomnia.deb && rm -rf /var/lib/apt/lists/*

# ============================================
# MongoDB Compass 1.45.0 (sandbox preserved)
# NOTE: MongoDB does not publish SHA256 checksums for Compass releases.
# ============================================
ARG COMPASS_VERSION=1.45.0
RUN wget -q "https://downloads.mongodb.com/compass/mongodb-compass_${COMPASS_VERSION}_amd64.deb" -O /tmp/compass.deb \
    && apt-get update && apt-get install -y --no-install-recommends /tmp/compass.deb \
    && rm /tmp/compass.deb && rm -rf /var/lib/apt/lists/*

# ============================================
# SQLite Browser
# ============================================
RUN apt-get update && apt-get install -y --no-install-recommends sqlitebrowser \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# REMOVED: Steam Client
# Steam requires --security-opt seccomp=unconfined which is a security risk.
# If needed, create a separate "gaming" image with explicit security warnings.
# ============================================

# ============================================
# Prism Launcher 9.2 (Minecraft)
# ============================================
RUN wget -qL https://github.com/PrismLauncher/PrismLauncher/releases/download/9.2/PrismLauncher-Linux-x86_64.AppImage -O /tmp/prism.AppImage \
    && chmod +x /tmp/prism.AppImage \
    && cd /tmp && /tmp/prism.AppImage --appimage-extract \
    && mv /tmp/squashfs-root /opt/PrismLauncher \
    && chmod +x /opt/PrismLauncher/AppRun \
    && rm /tmp/prism.AppImage \
    && cat > /usr/local/bin/prismlauncher-container << 'EOF'
#!/bin/bash
export QT_QPA_PLATFORM=xcb
export LIBGL_ALWAYS_SOFTWARE=1
export LD_LIBRARY_PATH="/opt/PrismLauncher/usr/lib:$LD_LIBRARY_PATH"
export QT_PLUGIN_PATH="/opt/PrismLauncher/usr/plugins"
cd /opt/PrismLauncher
exec /opt/PrismLauncher/usr/bin/prismlauncher "$@"
EOF
RUN chmod +x /usr/local/bin/prismlauncher-container \
    && cat > /usr/share/applications/prismlauncher.desktop << 'EOF'
[Desktop Entry]
Type=Application
Name=Prism Launcher
Comment=Minecraft Launcher
Exec=/usr/local/bin/prismlauncher-container
Icon=/opt/PrismLauncher/org.prismlauncher.PrismLauncher.svg
Categories=Game;
Terminal=false
EOF

# ============================================
# Slack 4.47.69 (sandbox preserved, GPG signed)
# NOTE: Slack uses GPG signatures instead of SHA256 checksums.
# See: https://slack.com/help/articles/115004809166
# ============================================
ARG SLACK_VERSION=4.47.69
RUN wget -q "https://downloads.slack-edge.com/desktop-releases/linux/x64/${SLACK_VERSION}/slack-desktop-${SLACK_VERSION}-amd64.deb" -O /tmp/slack.deb \
    && apt-get update && apt-get install -y --no-install-recommends /tmp/slack.deb \
    && rm /tmp/slack.deb && rm -rf /var/lib/apt/lists/*

# ============================================
# Wine (from WineHQ repository for latest stable)
# ============================================
RUN dpkg --add-architecture i386 \
    && mkdir -pm755 /etc/apt/keyrings \
    && wget -O - https://dl.winehq.org/wine-builds/winehq.key | gpg --dearmor -o /etc/apt/keyrings/winehq-archive.key - \
    && wget -NP /etc/apt/sources.list.d/ https://dl.winehq.org/wine-builds/ubuntu/dists/noble/winehq-noble.sources \
    && apt-get update \
    && apt-get install -y --install-recommends winehq-devel \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# VS Code Extensions (pinned versions recommended)
# ============================================
RUN mkdir -p /home/kasm-default-profile/.vscode/extensions \
    && mkdir -p /home/kasm-default-profile/.config/Code/User

# ============================================
# Git configuration (secure - no credential storage)
# ============================================
RUN git config --system user.name "Reviewer" \
    && git config --system user.email "reviewer@local" \
    && git config --system credential.helper cache --timeout=3600 \
    && git config --system init.defaultBranch main

# ============================================
# Firefox profile with bookmarks
# ============================================
RUN mkdir -p /home/kasm-default-profile/.mozilla/firefox/default.profile \
    && cat > /home/kasm-default-profile/.mozilla/firefox/profiles.ini << 'EOF'
[Profile0]
Name=default
IsRelative=1
Path=default.profile
Default=1

[General]
StartWithLastProfile=1
EOF

RUN cat > /home/kasm-default-profile/.mozilla/firefox/default.profile/bookmarks.html << 'EOF'
<!DOCTYPE NETSCAPE-Bookmark-file-1>
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
<TITLE>Bookmarks</TITLE>
<H1>Bookmarks Menu</H1>
<DL><p>
    <DT><H3 PERSONAL_TOOLBAR_FOLDER="true">Bookmarks Toolbar</H3>
    <DL><p>
        <DT><A HREF="https://reviews.hackclub.com">Reviews - Hack Club</A>
        <DT><A HREF="https://hackclub.com">Hack Club</A>
        <DT><A HREF="https://flavortown.hackclub.com">Flavortown - Hack Club</A>
    </DL><p>
</DL><p>
EOF

RUN cat > /home/kasm-default-profile/.mozilla/firefox/default.profile/user.js << 'EOF'
user_pref("browser.toolbars.bookmarks.visibility", "always");
user_pref("browser.bookmarks.file", "/home/kasm-user/.mozilla/firefox/default.profile/bookmarks.html");
user_pref("browser.places.importBookmarksHTML", true);
EOF

# ============================================
# Chrome policies (bookmarks + uBlock Origin Lite)
# ============================================
RUN mkdir -p /etc/opt/chrome/policies/managed \
    && cat > /etc/opt/chrome/policies/managed/policy.json << 'EOF'
{
    "BookmarkBarEnabled": true,
    "ManagedBookmarks": [
        {"toplevel_name": "Bookmarks"},
        {"name": "Reviews - Hack Club", "url": "https://reviews.hackclub.com"},
        {"name": "Hack Club", "url": "https://hackclub.com"},
        {"name": "Flavortown - Hack Club", "url": "https://flavortown.hackclub.com"}
    ],
    "ExtensionInstallForcelist": [
        "ddkjiahejlhfcafbddmgiahcphecmpfh"
    ]
}
EOF

# ============================================
# Desktop shortcuts
# ============================================
RUN mkdir -p /home/kasm-default-profile/Desktop \
    && for app in firefox google-chrome code insomnia mongodb-compass sqlitebrowser prismlauncher slack; do \
        cp /usr/share/applications/${app}.desktop /home/kasm-default-profile/Desktop/ 2>/dev/null || true; \
    done \
    && chmod +x /home/kasm-default-profile/Desktop/*.desktop 2>/dev/null || true

# ============================================
# Desktop README
# ============================================
RUN cat > /home/kasm-default-profile/Desktop/README.txt << 'EOF'
Welcome! This workspace is pre-configured for reviewing projects.


RUNNING PROJECTS BY STACK
-------------------------
Node.js:    npm install && npm start
Python:     python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt && python main.py
Rust:       cargo build && cargo run
Java:       ./gradlew build
Go:         go mod download && go run .

INSTALLED TOOLS
---------------
Browsers:      Firefox, Google Chrome
IDE:           VS Code
Languages:     Node.js 22, Python 3, Rust, Java 21, Go
Databases:     MongoDB Compass, SQLite Browser, Redis CLI
API Testing:   Insomnia
Communication: Slack
Gaming:        Prism Launcher

Happy reviewing!
EOF

# ============================================
# Fix permissions
# ============================================
RUN chown -R 1000:1000 /home/kasm-default-profile

# ============================================
# Final cleanup
# ============================================
RUN apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \
    && find /var/log -type f -delete

ENV HOME=/home/kasm-user \
    GOPATH=/home/kasm-user/go
ENV PATH=$GOPATH/bin:$PATH

WORKDIR $HOME
USER 1000
