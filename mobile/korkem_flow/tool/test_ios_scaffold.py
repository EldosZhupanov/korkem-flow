"""Static iOS contract checks; these do NOT replace an Xcode/device build."""
import json
from pathlib import Path
import plistlib
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
IOS = ROOT / "ios"


class IosScaffoldTests(unittest.TestCase):
    def setUp(self):
        self.info = plistlib.loads((IOS / "Runner/Info.plist").read_bytes())
        self.project = (IOS / "Runner.xcodeproj/project.pbxproj").read_text()

    def test_native_permission_purposes(self):
        for key in ("NSCameraUsageDescription", "NSPhotoLibraryUsageDescription",
                    "NSMicrophoneUsageDescription", "NSSpeechRecognitionUsageDescription"):
            with self.subTest(key=key):
                self.assertTrue(self.info.get(key))

    def test_no_blanket_network_exceptions(self):
        ats = self.info.get("NSAppTransportSecurity", {})
        self.assertFalse(ats.get("NSAllowsArbitraryLoads", False))
        self.assertFalse(ats.get("NSAllowsArbitraryLoadsInWebContent", False))
        self.assertFalse(ats.get("NSExceptionDomains"))

    def test_plugins_minimum_ios_version(self):
        versions = re.findall(r"IPHONEOS_DEPLOYMENT_TARGET = ([\d.]+);", self.project)
        self.assertEqual(len(versions), 3)
        self.assertTrue(all(float(v) >= 15 for v in versions))

    def test_keychain_entitlement_in_every_app_configuration(self):
        self.assertEqual(self.project.count('CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'), 3)
        data = plistlib.loads((IOS / "Runner/Runner.entitlements").read_bytes())
        self.assertEqual(data["keychain-access-groups"], [])
        self.assertNotIn("aps-environment", data)  # Push is not provisioned yet.

    def test_identity_is_not_flutter_example(self):
        self.assertEqual(self.info["CFBundleDisplayName"], "KORKEM Flow")
        self.assertNotIn("com.example", self.project)
        self.assertNotIn("DEVELOPMENT_TEAM =", self.project)

    def test_localized_permission_files_are_bundled(self):
        for locale in ("ru", "kk", "en"):
            path = IOS / "Runner" / f"{locale}.lproj/InfoPlist.strings"
            self.assertTrue(path.is_file())
            self.assertIn(f"{locale}.lproj/InfoPlist.strings", self.project)
            self.assertIn("NSMicrophoneUsageDescription", path.read_text())
        self.assertIn("InfoPlist.strings in Resources", self.project)

    def test_all_icon_assets_exist(self):
        icons = IOS / "Runner/Assets.xcassets/AppIcon.appiconset"
        contents = json.loads((icons / "Contents.json").read_text())
        for item in contents["images"]:
            with self.subTest(item=item):
                self.assertTrue((icons / item["filename"]).is_file())


if __name__ == "__main__":
    unittest.main()
