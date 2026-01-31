# ============================================
# Totally not sus at all
# ============================================
FROM kasmweb/core-ubuntu-noble:1.18.0

LABEL maintainer="Anon Anon <nothing@toseehere.com>"
LABEL description="Nothing see to here :3"
LABEL version="1.0.0"

USER root

ENV HOME=/home/kasm-default-profile \
    STARTUPDIR=/dockerstartup \
    INST_SCRIPTS=/dockerstartup/install \
    DEBIAN_FRONTEND=noninteractive \
    LIBGL_ALWAYS_SOFTWARE=1

WORKDIR $HOME

# Ensure default profile directory exists
RUN mkdir -p /home/kasm-default-profile && chown 1000:1000 /home/kasm-default-profile

# ============================================
# System packages, build essentials, and runtime libraries
# ============================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Build essentials
    build-essential gcc g++ make cmake \
    # Utilities
    curl wget jq tree unzip zip \
    ca-certificates gnupg lsb-release apt-transport-https software-properties-common \
    # Development libraries
    libssl-dev pkg-config sqlite3 libsqlite3-dev redis-tools \
    # Git
    git git-lfs \
    # Runtime libraries for Electron/Qt apps
    libgbm1 libnss3 libasound2t64 libxss1 libatk-bridge2.0-0 libgtk-3-0 \
    libxcb-cursor0 libxkbcommon-x11-0 libxcb-icccm4 libxcb-keysyms1 \
    libxcb-randr0 libxcb-render-util0 libxcb-xinerama0 libxcb-xinput0 \
    libgl1 libegl1 libopengl0 mesa-utils xdg-utils dbus-x11 \
    # Python
    python3 python3-pip python3-venv python3-dev \
    # Java
    openjdk-21-jdk \
    && git lfs install \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# Firefox
# ============================================
RUN if [ -f "$INST_SCRIPTS/firefox/install_firefox.sh" ]; then \
        bash $INST_SCRIPTS/firefox/install_firefox.sh; \
    else \
        add-apt-repository -y ppa:mozillateam/ppa \
        && echo 'Package: *\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 1001' > /etc/apt/preferences.d/mozilla-firefox \
        && apt-get update && apt-get install -y --no-install-recommends firefox \
        && rm -rf /var/lib/apt/lists/*; \
    fi

# ============================================
# Google Chrome
# ============================================
RUN if [ -f "$INST_SCRIPTS/chrome/install_chrome.sh" ]; then \
        bash $INST_SCRIPTS/chrome/install_chrome.sh; \
    else \
        wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/chrome.deb \
        && apt-get update && apt-get install -y /tmp/chrome.deb \
        && rm /tmp/chrome.deb && rm -rf /var/lib/apt/lists/*; \
    fi \
    && sed -i 's|Exec=/usr/bin/google-chrome-stable|Exec=/usr/bin/google-chrome-stable --no-sandbox|g' /usr/share/applications/google-chrome.desktop || true

# ============================================
# VS Code
# ============================================
RUN wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > /usr/share/keyrings/packages.microsoft.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list \
    && apt-get update && apt-get install -y code \
    && rm -rf /var/lib/apt/lists/* \
    && cat > /usr/local/bin/code-container << 'EOF'
#!/bin/bash
exec /usr/share/code/code --no-sandbox --disable-dev-shm-usage "$@"
EOF
RUN chmod +x /usr/local/bin/code-container \
    && sed -i 's|Exec=/usr/share/code/code|Exec=/usr/local/bin/code-container|g' /usr/share/applications/code.desktop \
    && sed -i 's|Exec=/usr/share/code/code|Exec=/usr/local/bin/code-container|g' /usr/share/applications/code-url-handler.desktop || true

# ============================================
# Node.js LTS with npm, yarn, pnpm
# ============================================
RUN curl -fsSL https://deb.nodesource.com/setup_lts.x | bash - \
    && apt-get install -y nodejs \
    && npm install -g yarn pnpm \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# Python virtual environment with common packages
# ============================================
RUN python3 -m venv /opt/reviewer-venv \
    && /opt/reviewer-venv/bin/pip install --no-cache-dir \
        requests flask discord.py httpx python-dotenv virtualenv

ENV PATH="/opt/reviewer-venv/bin:$PATH"

# ============================================
# Rust toolchain
# ============================================
ENV RUSTUP_HOME=/opt/rustup \
    CARGO_HOME=/opt/cargo
ENV PATH=/opt/cargo/bin:$PATH

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable \
    && chown -R 1000:1000 $RUSTUP_HOME $CARGO_HOME

# ============================================
# Java environment and Gradle 8.10.2
# ============================================
ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64

RUN wget -q https://services.gradle.org/distributions/gradle-8.10.2-bin.zip -O /tmp/gradle.zip \
    && unzip -q /tmp/gradle.zip -d /opt \
    && ln -s /opt/gradle-8.10.2 /opt/gradle \
    && rm /tmp/gradle.zip

ENV GRADLE_HOME=/opt/gradle
ENV PATH=$GRADLE_HOME/bin:$PATH

# ============================================
# Go 1.24.4
# ============================================
RUN wget -q https://go.dev/dl/go1.24.4.linux-amd64.tar.gz -O /tmp/go.tar.gz \
    && tar -C /usr/local -xzf /tmp/go.tar.gz \
    && rm /tmp/go.tar.gz \
    && mkdir -p /home/kasm-default-profile/go && chown 1000:1000 /home/kasm-default-profile/go

ENV PATH=/usr/local/go/bin:$PATH

# ============================================
# Docker CLI (no daemon - use host socket mount)
# ============================================
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu noble stable" > /etc/apt/sources.list.d/docker.list \
    && apt-get update && apt-get install -y --no-install-recommends docker-ce-cli docker-compose-plugin \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# Android SDK
# ============================================
ENV ANDROID_SDK_ROOT=/opt/android-sdk \
    ANDROID_HOME=/opt/android-sdk
ENV PATH=$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH

RUN mkdir -p $ANDROID_SDK_ROOT/cmdline-tools \
    && wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip -O /tmp/cmdline-tools.zip \
    && unzip -q /tmp/cmdline-tools.zip -d $ANDROID_SDK_ROOT/cmdline-tools \
    && mv $ANDROID_SDK_ROOT/cmdline-tools/cmdline-tools $ANDROID_SDK_ROOT/cmdline-tools/latest \
    && rm /tmp/cmdline-tools.zip \
    && yes | sdkmanager --licenses || true \
    && sdkmanager "platform-tools" "platforms;android-34" "build-tools;34.0.0" \
    && chown -R 1000:1000 $ANDROID_SDK_ROOT

# ============================================
# Insomnia 10.3.1
# ============================================
RUN wget -qL https://github.com/Kong/insomnia/releases/download/core%4010.3.1/Insomnia.Core-10.3.1.deb -O /tmp/insomnia.deb \
    && apt-get update && apt-get install -y /tmp/insomnia.deb \
    && rm /tmp/insomnia.deb && rm -rf /var/lib/apt/lists/* \
    && cat > /usr/local/bin/insomnia-container << 'EOF'
#!/bin/bash
exec /usr/bin/insomnia --no-sandbox --disable-dev-shm-usage --disable-gpu "$@"
EOF
RUN chmod +x /usr/local/bin/insomnia-container \
    && sed -i 's|^Exec=.*|Exec=/usr/local/bin/insomnia-container|g' /usr/share/applications/insomnia.desktop || true

# ============================================
# MongoDB Compass 1.45.0
# ============================================
RUN wget -q https://downloads.mongodb.com/compass/mongodb-compass_1.45.0_amd64.deb -O /tmp/compass.deb \
    && apt-get update && apt-get install -y /tmp/compass.deb \
    && rm /tmp/compass.deb && rm -rf /var/lib/apt/lists/* \
    && cat > /usr/local/bin/compass-container << 'EOF'
#!/bin/bash
exec /usr/bin/mongodb-compass --no-sandbox --disable-dev-shm-usage --disable-gpu "$@"
EOF
RUN chmod +x /usr/local/bin/compass-container \
    && sed -i 's|^Exec=.*|Exec=/usr/local/bin/compass-container|g' /usr/share/applications/mongodb-compass.desktop || true

# ============================================
# SQLite Browser
# ============================================
RUN apt-get update && apt-get install -y --no-install-recommends sqlitebrowser \
    && rm -rf /var/lib/apt/lists/*

# ============================================
# Steam Client
# NOTE: Requires --security-opt seccomp=unconfined --shm-size=1g
# ============================================
RUN dpkg --add-architecture i386 \
    && apt-get update && apt-get install -y \
        libc6:i386 libstdc++6:i386 libgl1:i386 libx11-6:i386 libxau6:i386 \
        libxcb1:i386 libxdmcp6:i386 libnss3:i386 libnspr4:i386 \
        libdbus-1-3:i386 libfreetype6:i386 libgpg-error0:i386 \
    && wget -q https://cdn.akamai.steamstatic.com/client/installer/steam.deb -O /tmp/steam.deb \
    && apt-get install -y /tmp/steam.deb || true \
    && rm -f /tmp/steam.deb && rm -rf /var/lib/apt/lists/*

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
# Slack 4.39.95
# ============================================
RUN wget -q https://downloads.slack-edge.com/desktop-releases/linux/x64/4.39.95/slack-desktop-4.39.95-amd64.deb -O /tmp/slack.deb \
    && apt-get update && apt-get install -y /tmp/slack.deb \
    && rm /tmp/slack.deb && rm -rf /var/lib/apt/lists/* \
    && cat > /usr/local/bin/slack-container << 'EOF'
#!/bin/bash
exec /usr/bin/slack --no-sandbox --disable-dev-shm-usage --disable-gpu "$@"
EOF
RUN chmod +x /usr/local/bin/slack-container \
    && sed -i 's|^Exec=.*|Exec=/usr/local/bin/slack-container|g' /usr/share/applications/slack.desktop || true

# ============================================
# VS Code Extensions
# ============================================
RUN mkdir -p /home/kasm-default-profile/.vscode/extensions \
    && mkdir -p /home/kasm-default-profile/.config/Code/User \
    && for ext in ms-python.python rust-lang.rust-analyzer dbaeumer.vscode-eslint \
                  esbenp.prettier-vscode redhat.java vscjava.vscode-java-pack \
                  golang.go ms-vscode.cpptools; do \
        code --no-sandbox \
            --user-data-dir=/home/kasm-default-profile/.config/Code \
            --extensions-dir=/home/kasm-default-profile/.vscode/extensions \
            --install-extension $ext --force || true; \
    done

# ============================================
# Git configuration
# ============================================
RUN git config --system user.name "Anon Anon" \
    && git config --system user.email "anon@sussy.com" \
    && git config --system credential.helper store \
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
# Desktop shortcuts
# ============================================
RUN mkdir -p /home/kasm-default-profile/Desktop \
    && for app in firefox google-chrome code insomnia mongodb-compass sqlitebrowser steam prismlauncher slack; do \
        cp /usr/share/applications/${app}.desktop /home/kasm-default-profile/Desktop/ 2>/dev/null || true; \
    done \
    && chmod +x /home/kasm-default-profile/Desktop/*.desktop 2>/dev/null || true

# ============================================
# Desktop README
# ============================================
RUN cat > /home/kasm-default-profile/Desktop/README.txt << 'EOF'
Welcome! This workspace is pre-configured for reviewing projects.

QUICK START
-----------
  git clone <project-url>
  cd <project-name>

RUNNING PROJECTS BY STACK
-------------------------
Node.js:    npm install && npm start
Python:     python3 -m venv venv && source venv/bin/activate && pip install -r requirements.txt && python main.py
Rust:       cargo build && cargo run
Java:       ./gradlew build
Go:         go mod download && go run .
Docker:     docker compose up (requires host socket mount)

INSTALLED TOOLS
---------------
Browsers:      Firefox, Google Chrome
IDE:           VS Code (with extensions)
Languages:     Node.js LTS, Python 3, Rust, Java 21, Go
Databases:     MongoDB Compass, SQLite Browser, Redis CLI
API Testing:   Insomnia
Communication: Slack
Gaming:        Steam*, Prism Launcher

* Steam requires: --security-opt seccomp=unconfined --shm-size=1g

Happy reviewing!
EOF

# ============================================
# Fix permissions (must be last before cleanup)
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
