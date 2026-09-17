"""Export the current client source (including uncommitted work), not secrets/SDKs.

Run from WSL: python3 scripts/package_ios_handoff.py /path/to/new.zip
The bundle is a client-only snapshot, NOT a replacement for the monorepo.
"""
import hashlib
import json
from pathlib import Path, PurePosixPath
import subprocess
import sys
import zipfile

ROOT = Path(__file__).resolve().parents[1]
CLIENT = "mobile/korkem_flow/"
CLIENT_DIRS = {"lib", "assets", "test", "integration_test", "ios", "tool"}
CLIENT_FILES = {"pubspec.yaml", "pubspec.lock", ".metadata", ".gitignore",
                "analysis_options.yaml", "dart_test.yaml", "l10n.yaml",
                "README.md", "THIRD_PARTY_LICENSES.md"}
ROOT_FILES = {"PROJECT.md", "PLAN.md", "ROADMAP.md", "NOW.md", "CLAUDE.md"}
EXTRA = {"scripts/ios_on_mac.sh", "scripts/package_ios_handoff.py",
         "docs/operations/IOS_ON_MAC_RU.md"}


def selected(name):
    p = PurePosixPath(name)
    if p.is_absolute() or ".." in p.parts:
        return False
    if any(part in {"build", ".dart_tool", "Pods", "ephemeral", ".symlinks",
                    "xcuserdata", "DerivedData", "failures", "__pycache__"} for part in p.parts):
        return False
    if (p.name.startswith(".env") or p.suffix in {".key", ".pem", ".p8", ".p12", ".cer", ".mobileprovision"}
            or p.name in {"GoogleService-Info.plist", "Generated.xcconfig", "flutter_export_environment.sh",
                          "GeneratedPluginRegistrant.h", "GeneratedPluginRegistrant.m"}):
        return False
    if name in ROOT_FILES or name in EXTRA:
        return True
    if name.startswith(".claude/skills/"):
        return p.parts[2] in {"korkem-flutter", "korkem-docs", "korkem-architecture",
                              "verification-before-completion"} and p.name == "SKILL.md"
    if name.startswith(CLIENT):
        sub = PurePosixPath(name[len(CLIENT):])
        return (len(sub.parts) == 1 and sub.name in CLIENT_FILES) or sub.parts[0] in CLIENT_DIRS
    return False


def main():
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python3 scripts/package_ios_handoff.py /path/to/new.zip")
    destination = Path(sys.argv[1]).resolve()
    if destination.exists():
        raise SystemExit("Refusing to overwrite an existing archive")
    raw = subprocess.check_output(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"], cwd=ROOT)
    paths = sorted({n for n in raw.decode().split("\0") if n and selected(n)})
    required = {CLIENT + "pubspec.lock", CLIENT + "lib/main.dart",
                CLIENT + "ios/Runner.xcodeproj/project.pbxproj"} | EXTRA | ROOT_FILES
    if not required <= set(paths):
        raise SystemExit("Required sources missing from bundle selection")
    manifest = {}
    destination.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(destination, "x", compression=zipfile.ZIP_DEFLATED) as archive:
        for name in paths:
            p = ROOT / name
            if p.is_symlink() or not p.is_file():
                raise SystemExit("Refusing symlink or missing source: " + name)
            data = p.read_bytes()
            archive.writestr("korkem-ios-handoff/" + name, data)
            manifest[name] = hashlib.sha256(data).hexdigest()
        archive.writestr("korkem-ios-handoff/SOURCE_MANIFEST.json", json.dumps({
            "kind": "client-only working-tree snapshot; not a Git clone",
            "base_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT).decode().strip(),
            "files_sha256": manifest,
        }, indent=2))
    print(f"Created {destination} ({len(paths)} source files)")
    print("SHA256:", hashlib.sha256(destination.read_bytes()).hexdigest())


if __name__ == "__main__":
    main()
