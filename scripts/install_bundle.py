"""Replace a generated bundle with rollback; never merge old resources into a new app."""
import os
from pathlib import Path
import plistlib
import shutil
import sys
import tempfile


def install_bundle(source: Path, destination: Path) -> None:
    destination = destination.absolute()
    if destination.suffix != ".app" or destination.is_symlink():
        raise ValueError("Destination must be a non-symlink .app path")
    if destination.exists():
        with (destination / "Contents/Info.plist").open("rb") as handle:
            if plistlib.load(handle).get("CFBundleIdentifier") != "de.lorizdigital.maussprung":
                raise ValueError("Refusing to replace a different application")
    destination.parent.mkdir(parents=True, exist_ok=True)
    # Same-volume renames preserve a recoverable previous bundle until replacement succeeds.
    temporary = Path(tempfile.mkdtemp(prefix=".maussprung-install-", dir=destination.parent))
    previous = temporary / "previous.app"
    try:
        staging = Path(temporary) / "new.app"
        shutil.copytree(source, staging, copy_function=shutil.copyfile, symlinks=True)
        # copyfile intentionally omits cloud metadata; preserve executable permission bits.
        for file in source.rglob("*"):
            if file.is_file() and not file.is_symlink():
                (staging / file.relative_to(source)).chmod(file.stat().st_mode & 0o777)
        if destination.exists():
            os.rename(destination, previous)
        try:
            os.rename(staging, destination)
        except BaseException:
            if previous.exists():
                os.rename(previous, destination)
            raise
    finally:
        if previous.exists() and not destination.exists():
            print(f"Previous app preserved for recovery: {previous}", file=sys.stderr)
        else:
            shutil.rmtree(temporary)


if __name__ == "__main__":
    install_bundle(Path(sys.argv[1]), Path(sys.argv[2]))
