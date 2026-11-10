import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import urllib.request
import zipfile
import os

SCRIPTS = Path(__file__).resolve().parents[1] / 'scripts'
sys.path.insert(0, str(SCRIPTS))
from catalog import scan, load_metadata
from wizard import save_settings, validate_request


class WizardTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='.wizard-test-', dir=SCRIPTS.parents[2])
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.install = self.root / 'game'
        (self.install / 'content').mkdir(parents=True)
        (self.install / 'gameplay').mkdir()
        self.project = self.root / 'project'
        self.project.mkdir()
        with zipfile.ZipFile(self.install / 'content' / 'level.zip', 'w') as z:
            z.writestr('levels/west_coast_usa/info.json', json.dumps({'title': 'West Coast USA'}))
            z.writestr('levels/west_coast_usa/preview.jpg', b'example')
        mission = self.install / 'gameplay/missions/west_coast_usa/timeTrial/011-Highway'
        mission.mkdir(parents=True)
        (mission / 'info.json').write_text('{}')

    def fingerprint(self):
        return {str(p.relative_to(self.install)): hashlib.sha256(p.read_bytes()).hexdigest()
                for p in self.install.rglob('*') if p.is_file()}

    def test_beamng_json_comments_and_trailing_commas(self):
        self.assertEqual(load_metadata(b'{"url":"http://example/",/* comment */ "items":[1,2,],}'),
                         {'url': 'http://example/', 'items': [1, 2]})

    def data(self, cat):
        return {'map': 'west_coast_usa', 'template': cat['missions'][0]['id'],
                'name': 'Neue Mission', 'slug': 'neue_mission',
                'description': 'Nach fünf Sekunden über 130 km/h platzt ein Reifen.'}

    def test_catalog_and_unchanged_install(self):
        before = self.fingerprint()
        cat, images = scan(self.install, self.project)
        self.assertEqual(cat['maps'][0]['title'], 'West Coast USA')
        self.assertEqual(cat['missions'][0]['name'], '011-Highway')
        self.assertEqual(cat['missions'][0]['category'], 'timeTrial')
        self.assertTrue(images)
        self.assertEqual(before, self.fingerprint())

    def test_archived_mod_and_invalid_metadata(self):
        mods = self.root / 'mods'
        mods.mkdir()
        with zipfile.ZipFile(mods / 'mod.zip', 'w') as z:
            z.writestr('gameplay/missions/custom/flowgraph/example/info.json', '{}')
            z.writestr('levels/custom/info.json', 'invalid')
        cat, _ = scan(self.install, self.project, [str(mods)])
        self.assertTrue(any(m['origin'] == 'Mod' and m['map'] == 'custom' for m in cat['missions']))
        self.assertTrue(any('Metadaten nicht lesbar' in w for w in cat['warnings']))

    def test_settings_and_protected_destination(self):
        before = self.fingerprint()
        data = {'install': str(self.install), 'mods': []}
        with self.assertRaises(ValueError):
            save_settings(self.install / 'settings.json', data)
        path = self.root / 'local' / 'settings.json'
        save_settings(path, data)
        self.assertEqual(json.loads(path.read_text()), data)
        self.assertEqual(before, self.fingerprint())

    def test_validation_and_collision(self):
        cat, _ = scan(self.install, self.project)
        data = self.data(cat)
        result = validate_request(data, cat, self.project)
        self.assertEqual(result['template']['name'], '011-Highway')
        Path(result['target']).mkdir(parents=True)
        with self.assertRaises(ValueError):
            validate_request(data, cat, self.project)
        for change in ({'slug': '../../escape'}, {'map': 'other'}, {'template': 'missing'}, {'description': ''}):
            with self.assertRaises(ValueError):
                validate_request({**data, **change}, cat, self.project)

    def test_http_handoff_and_origin_rejection(self):
        before = self.fingerprint()
        env = {**os.environ, 'LOCALAPPDATA': str(self.root / 'local'), 'PYTHONIOENCODING': 'utf-8'}
        process = subprocess.Popen([sys.executable, '-B', str(SCRIPTS / 'wizard.py'), '--no-browser'],
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding='utf-8', env=env)
        self.addCleanup(lambda: process.kill() if process.poll() is None else None)
        url = process.stdout.readline().strip().split('=', 1)[1]
        def post(route, data, origin=None):
            headers = {'Content-Type': 'application/json'}
            if origin:
                headers['Origin'] = origin
            request = urllib.request.Request(url + route, json.dumps(data).encode(), headers)
            with urllib.request.urlopen(request, timeout=30) as response:
                return json.load(response)
        with self.assertRaises(urllib.error.HTTPError):
            post('scan', {'install': str(self.install)}, 'http://untrusted.example')
        cat = post('scan', {'install': str(self.install), 'mods': []})
        self.assertTrue(post('submit', self.data(cat))['ok'])
        output, errors = process.communicate(timeout=10)
        self.assertEqual(process.returncode, 0, errors)
        result = json.loads(output.split('BEAMNG_REQUEST=', 1)[1])
        self.assertEqual(result['scenario']['name'], 'Neue Mission')
        self.assertEqual(before, self.fingerprint())


if __name__ == '__main__':
    unittest.main()
