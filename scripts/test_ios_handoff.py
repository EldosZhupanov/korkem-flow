"""Safety boundaries of the client-only handoff packager."""
import unittest
from package_ios_handoff import selected


class HandoffSelectionTests(unittest.TestCase):
    def test_new_ios_source_is_included(self):
        self.assertTrue(selected("mobile/korkem_flow/ios/Runner/Info.plist"))
        self.assertTrue(selected("mobile/korkem_flow/ios/Runner/ru.lproj/InfoPlist.strings"))

    def test_current_dart_and_lock_are_included(self):
        self.assertTrue(selected("mobile/korkem_flow/lib/features/hardware/screen.dart"))
        self.assertTrue(selected("mobile/korkem_flow/pubspec.lock"))

    def test_credentials_and_signing_material_are_excluded(self):
        for name in (".env", ".env.production", "push.p8", "signing.p12", "profile.mobileprovision",
                     "Runner/GoogleService-Info.plist"):
            with self.subTest(name=name):
                self.assertFalse(selected("mobile/korkem_flow/ios/" + name))

    def test_machine_generated_files_are_excluded(self):
        for name in ("Flutter/Generated.xcconfig", "Flutter/ephemeral/Packages/a.swift",
                     "Pods/private.txt", "Runner/GeneratedPluginRegistrant.m",
                     "Runner.xcodeproj/xcuserdata/a.xcuserstate"):
            with self.subTest(name=name):
                self.assertFalse(selected("mobile/korkem_flow/ios/" + name))

    def test_server_and_ssh_are_excluded(self):
        self.assertFalse(selected(".ssh/oracle_korkem"))
        self.assertFalse(selected("backend/site_config.json"))
        self.assertFalse(selected("infra/frappe_bench/.env"))

    def test_build_and_traversal_are_excluded(self):
        self.assertFalse(selected("mobile/korkem_flow/build/ios/app.ipa"))
        self.assertFalse(selected("mobile/korkem_flow/ios/../../secret.txt"))
        self.assertFalse(selected("/home/eldos/.ssh/korkem"))


if __name__ == "__main__":
    unittest.main()
