import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location(
    "install_bundle", Path(__file__).parents[1] / "scripts/install_bundle.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


def bundle(path, identifier="de.lorizdigital.maussprung"):
    (path / "Contents/MacOS").mkdir(parents=True)
    (path / "Contents/Info.plist").write_bytes(plistlib.dumps({"CFBundleIdentifier": identifier}))
    executable = path / "Contents/MacOS/MausSprung"
    executable.write_text("test fixture, never executed")
    executable.chmod(0o755)


class PackagingTests(unittest.TestCase):
    def test_failed_install_restores_previous_bundle(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, destination = root / "source.app", root / "destination.app"
            bundle(source)
            bundle(destination)
            (destination / "previous.txt").write_text("recover me")
            rename = module.os.rename

            def fail_new_bundle(old, new):
                if Path(old).name == "new.app":
                    raise OSError("simulated install failure")
                return rename(old, new)

            with patch.object(module.os, "rename", side_effect=fail_new_bundle):
                with self.assertRaises(OSError):
                    module.install_bundle(source, destination)
            self.assertEqual((destination / "previous.txt").read_text(), "recover me")

    def test_replacement_removes_stale_files_preserves_permissions(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, destination = root / "source.app", root / "destination.app"
            bundle(source)
            bundle(destination)
            (destination / "stale.txt").write_text("old resource")
            module.install_bundle(source, destination)
            self.assertFalse((destination / "stale.txt").exists())
            self.assertEqual((destination / "Contents/MacOS/MausSprung").stat().st_mode & 0o777, 0o755)

    def test_other_app_is_not_overwritten(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source, destination = root / "source.app", root / "other.app"
            bundle(source)
            bundle(destination, "org.example.other")
            before = (destination / "Contents/Info.plist").read_bytes()
            with self.assertRaises(ValueError):
                module.install_bundle(source, destination)
            self.assertEqual((destination / "Contents/Info.plist").read_bytes(), before)

    def test_symlink_destination_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            source = root / "source.app"
            bundle(source)
            destination = root / "link.app"
            destination.symlink_to(source, target_is_directory=True)
            with self.assertRaises(ValueError):
                module.install_bundle(source, destination)
            self.assertTrue(destination.is_symlink())


if __name__ == "__main__":
    unittest.main()
