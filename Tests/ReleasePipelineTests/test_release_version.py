import plistlib
from pathlib import Path
import subprocess
import tempfile
import unittest


class ReleaseVersionTests(unittest.TestCase):
    def run_check(self, current, published):
        script = Path(__file__).resolve().parents[2] / 'scripts/check-release-version.py'
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            with (folder / 'Info.plist').open('wb') as stream:
                plistlib.dump({'CFBundleVersion': current}, stream)
            items = ''.join(f'<item><sparkle:version>{version}</sparkle:version></item>' for version in published)
            (folder / 'appcast.xml').write_text('<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel>' + items + '</channel></rss>')
            return subprocess.run(['python3', str(script), str(folder / 'Info.plist'), str(folder / 'appcast.xml')], capture_output=True)

    def test_unchanged_or_older_build_cannot_replace_latest_feed(self):
        for current in ['1', '2', '2.0', '2.0.0']:
            with self.subTest(current=current):
                self.assertNotEqual(self.run_check(current, ['1', '2']).returncode, 0)

    def test_new_build_advances_all_published_items(self):
        self.assertEqual(self.run_check('3', ['1', '2.0.0']).returncode, 0)
        self.assertEqual(self.run_check('2.0.1', ['2']).returncode, 0)

    def test_unusable_feed_does_not_bypass_version_check(self):
        self.assertNotEqual(self.run_check('3', []).returncode, 0)
        self.assertNotEqual(self.run_check('3', ['bad-version']).returncode, 0)


if __name__ == '__main__':
    unittest.main()
