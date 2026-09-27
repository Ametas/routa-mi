#!/usr/bin/env bash
# RoutaMi: idempotent toolchain setup for Claude Code cloud sessions
# (and any Linux x86_64 box). Installs JDK 21, Flutter, Go, Android SDK
# and NDK at the versions CI uses. Safe to run repeatedly: every step
# checks what is already installed.
#
# Usage:  bash scripts/cloud-setup.sh
# After:  source "$ROUTAMI_TOOLS/env.sh"  (also hooked into ~/.bashrc)
#
# Rust is NOT required: SlClash removed plugins/rust_api (FlClash's cargokit
# plugin) in 0850b43d.
set -euo pipefail

# Keep these in sync with .github/workflows/*.yml.
FLUTTER_VERSION="3.41.9"
GO_VERSION="1.24.13"
JDK_MAJOR="21"
ANDROID_CMDLINE_TOOLS_BUILD="16111833"
ANDROID_PLATFORM="android-36"
ANDROID_BUILD_TOOLS="36.0.0"
ANDROID_NDK_VERSION="28.2.13676358" # NDK r28c

ROUTAMI_TOOLS="${ROUTAMI_TOOLS:-/opt/routami-tools}"
ANDROID_SDK_ROOT="$ROUTAMI_TOOLS/android-sdk"
FLUTTER_ROOT="$ROUTAMI_TOOLS/flutter"
GOROOT_DIR="$ROUTAMI_TOOLS/go"

log() { printf '\033[1;34m[cloud-setup]\033[0m %s\n' "$*"; }

SUDO=""
if [ "$(id -u)" -ne 0 ] && command -v sudo >/dev/null 2>&1; then
  SUDO="sudo"
fi

$SUDO mkdir -p "$ROUTAMI_TOOLS"
$SUDO chown "$(id -u):$(id -g)" "$ROUTAMI_TOOLS"

# --- base packages --------------------------------------------------------
need_pkgs=()
for bin in curl unzip xz git; do
  command -v "$bin" >/dev/null 2>&1 || need_pkgs+=("$bin")
done
if [ "${#need_pkgs[@]}" -gt 0 ] && command -v apt-get >/dev/null 2>&1; then
  log "Installing base packages: ${need_pkgs[*]}"
  pkgs=()
  for p in "${need_pkgs[@]}"; do
    case "$p" in xz) pkgs+=(xz-utils) ;; *) pkgs+=("$p") ;; esac
  done
  $SUDO apt-get update -qq
  $SUDO apt-get install -y -qq "${pkgs[@]}"
fi

# --- JDK -------------------------------------------------------------------
java_major() {
  "$1" -version 2>&1 | grep -Eo 'version "[0-9]+' | grep -Eo '[0-9]+$' || true
}
JAVA_HOME_DIR=""
for candidate in "${JAVA_HOME:-}" /usr/lib/jvm/java-${JDK_MAJOR}-openjdk-amd64 \
  /usr/lib/jvm/temurin-${JDK_MAJOR}-jdk-amd64 "$ROUTAMI_TOOLS/jdk"; do
  if [ -n "$candidate" ] && [ -x "$candidate/bin/java" ] && \
     [ "$(java_major "$candidate/bin/java")" = "$JDK_MAJOR" ]; then
    JAVA_HOME_DIR="$candidate"
    break
  fi
done
if [ -z "$JAVA_HOME_DIR" ]; then
  log "Installing Temurin JDK $JDK_MAJOR"
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/jdk.tar.gz" \
    "https://api.adoptium.net/v3/binary/latest/${JDK_MAJOR}/ga/linux/x64/jdk/hotspot/normal/eclipse"
  rm -rf "$ROUTAMI_TOOLS/jdk" && mkdir -p "$ROUTAMI_TOOLS/jdk"
  tar -xzf "$tmp/jdk.tar.gz" -C "$ROUTAMI_TOOLS/jdk" --strip-components=1
  rm -rf "$tmp"
  JAVA_HOME_DIR="$ROUTAMI_TOOLS/jdk"
fi
log "JDK: $JAVA_HOME_DIR"
export JAVA_HOME="$JAVA_HOME_DIR"

# --- Go --------------------------------------------------------------------
if [ "$("$GOROOT_DIR/bin/go" env GOVERSION 2>/dev/null || true)" != "go$GO_VERSION" ]; then
  log "Installing Go $GO_VERSION"
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/go.tar.gz" "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
  rm -rf "$GOROOT_DIR"
  tar -xzf "$tmp/go.tar.gz" -C "$ROUTAMI_TOOLS"
  rm -rf "$tmp"
fi
log "Go: $("$GOROOT_DIR/bin/go" env GOVERSION)"

# --- Flutter ---------------------------------------------------------------
current_flutter=""
if [ -f "$FLUTTER_ROOT/version" ]; then
  current_flutter="$(cat "$FLUTTER_ROOT/version")"
elif [ -f "$FLUTTER_ROOT/bin/cache/flutter.version.json" ]; then
  current_flutter="$(grep -Eo '"frameworkVersion": *"[^"]+"' \
    "$FLUTTER_ROOT/bin/cache/flutter.version.json" | grep -Eo '[0-9][^"]*' || true)"
fi
if [ "$current_flutter" != "$FLUTTER_VERSION" ]; then
  log "Installing Flutter $FLUTTER_VERSION"
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/flutter.tar.xz" \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
  rm -rf "$FLUTTER_ROOT"
  tar -xJf "$tmp/flutter.tar.xz" -C "$ROUTAMI_TOOLS"
  rm -rf "$tmp"
fi
git config --global --get-all safe.directory 2>/dev/null | grep -qxF "$FLUTTER_ROOT" || \
  git config --global --add safe.directory "$FLUTTER_ROOT"

# --- Android SDK + NDK -----------------------------------------------------
SDKMANAGER="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager"
if [ ! -x "$SDKMANAGER" ]; then
  log "Installing Android cmdline-tools $ANDROID_CMDLINE_TOOLS_BUILD"
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/cmdline-tools.zip" \
    "https://dl.google.com/android/repository/commandlinetools-linux-${ANDROID_CMDLINE_TOOLS_BUILD}_latest.zip"
  mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools"
  unzip -q "$tmp/cmdline-tools.zip" -d "$tmp"
  rm -rf "$ANDROID_SDK_ROOT/cmdline-tools/latest"
  mv "$tmp/cmdline-tools" "$ANDROID_SDK_ROOT/cmdline-tools/latest"
  rm -rf "$tmp"
fi

sdk_packages=(
  "platform-tools"
  "platforms;$ANDROID_PLATFORM"
  "build-tools;$ANDROID_BUILD_TOOLS"
  "ndk;$ANDROID_NDK_VERSION"
)
missing=()
for pkg in "${sdk_packages[@]}"; do
  [ -d "$ANDROID_SDK_ROOT/${pkg//;//}" ] || missing+=("$pkg")
done
if [ "${#missing[@]}" -gt 0 ]; then
  log "Installing Android SDK packages: ${missing[*]}"
  yes | "$SDKMANAGER" --sdk_root="$ANDROID_SDK_ROOT" --licenses >/dev/null || true
  "$SDKMANAGER" --sdk_root="$ANDROID_SDK_ROOT" "${missing[@]}" >/dev/null
fi

# --- Gradle ----------------------------------------------------------------
# The sandbox egress proxy gets HTTP 429 from Maven Central on bursts of
# parallel downloads; more retries with backoff make cold builds pass.
GRADLE_PROPS="$HOME/.gradle/gradle.properties"
mkdir -p "$(dirname "$GRADLE_PROPS")"
touch "$GRADLE_PROPS"
for prop in \
  "systemProp.org.gradle.internal.repository.max.retries=12" \
  "systemProp.org.gradle.internal.repository.initial.backoff=3000" \
  "org.gradle.parallel=false"; do
  grep -qxF "$prop" "$GRADLE_PROPS" || echo "$prop" >> "$GRADLE_PROPS"
done

# Maven Central also rate-limits the shared egress IP outright, so route it
# through Google's Maven Central mirror (sandbox only; the project's Gradle
# files and CI are untouched). Opt out with ROUTAMI_MAVEN_MIRROR=0.
INIT_SCRIPT="$HOME/.gradle/init.d/routami-maven-mirror.gradle"
if [ "${ROUTAMI_MAVEN_MIRROR:-1}" = "1" ]; then
  mkdir -p "$(dirname "$INIT_SCRIPT")"
  cat > "$INIT_SCRIPT" <<'GRADLE'
// Generated by scripts/cloud-setup.sh (sandbox only; never used by CI).
// Puts Google's Maven Central mirror first so builds survive HTTP 429 from
// repo.maven.apache.org on shared egress IPs.
def routamiMirror = 'https://maven-central.storage-download.googleapis.com/maven2/'
def routamiPrepend = { repos ->
    def repo = repos.maven { url = routamiMirror; name = 'routamiMavenCentralMirror' }
    repos.remove(repo)
    repos.addFirst(repo)
}
beforeSettings { settings ->
    // Declaring any plugin repository drops the implicit Plugin Portal, so
    // keep it explicitly after the mirror.
    settings.pluginManagement.repositories.gradlePluginPortal()
    routamiPrepend(settings.pluginManagement.repositories)
}
settingsEvaluated { settings ->
    routamiPrepend(settings.dependencyResolutionManagement.repositories)
    settings.gradle.ext.routamiProjectRepos =
        settings.dependencyResolutionManagement.repositoriesMode.get() ==
            org.gradle.api.initialization.resolve.RepositoriesMode.PREFER_PROJECT
}
gradle.beforeProject { project ->
    routamiPrepend(project.buildscript.repositories)
    if (project.gradle.ext.routamiProjectRepos) {
        routamiPrepend(project.repositories)
    }
}
GRADLE
else
  rm -f "$INIT_SCRIPT"
fi

# --- environment -----------------------------------------------------------
ENV_FILE="$ROUTAMI_TOOLS/env.sh"
cat > "$ENV_FILE" <<EOF
# Generated by scripts/cloud-setup.sh
export ROUTAMI_TOOLS="$ROUTAMI_TOOLS"
export JAVA_HOME="$JAVA_HOME_DIR"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT"
export ANDROID_NDK="$ANDROID_SDK_ROOT/ndk/$ANDROID_NDK_VERSION"
export FLUTTER_ROOT="$FLUTTER_ROOT"
export GOROOT="$GOROOT_DIR"
export GOTOOLCHAIN=local
export PATH="$FLUTTER_ROOT/bin:$GOROOT_DIR/bin:\$HOME/go/bin:$ANDROID_SDK_ROOT/platform-tools:$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$JAVA_HOME_DIR/bin:\$PATH"
EOF
hook="[ -f \"$ENV_FILE\" ] && . \"$ENV_FILE\""
for rc in "$HOME/.bashrc" "$HOME/.profile"; do
  touch "$rc"
  grep -qxF "$hook" "$rc" || printf '\n%s\n' "$hook" >> "$rc"
done
# shellcheck disable=SC1090
. "$ENV_FILE"

flutter config --no-analytics >/dev/null 2>&1 || true
dart --disable-analytics >/dev/null 2>&1 || true
flutter config --android-sdk "$ANDROID_SDK_ROOT" >/dev/null
flutter precache --android >/dev/null

log "Flutter: $(flutter --version --machine 2>/dev/null | grep -Eo '"frameworkVersion": *"[^"]+"' | grep -Eo '[0-9][^"]*')"
log "Android SDK: $ANDROID_SDK_ROOT (NDK $ANDROID_NDK_VERSION)"
log "Done. Run: source $ENV_FILE"
