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
from catalog import scan, scan_project, load_metadata
from wizard import build_prompt, save_settings, validate_edit_request, validate_request


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

    def test_portable_prompt_preserves_archive_and_scenario(self):
        mods = self.root / 'mods'
        mods.mkdir()
        archive = mods / 'mod.zip'
        member = 'gameplay/missions/custom/timeTrial/race/info.json'
        with zipfile.ZipFile(archive, 'w') as z:
            z.writestr(member, '{}')
        cat, _ = scan(self.install, self.project, [str(mods)])
        mission = next(m for m in cat['missions'] if m['map'] == 'custom')
        request = {'map': 'custom', 'template': mission['id'], 'name': 'Test',
                   'slug': 'test', 'description': 'Änderung: fahre eine Runde und zeige die Zeit an.'}
        result = validate_request(request, cat, self.project)
        result['installation'] = str(self.install)
        prompt = build_prompt(result)
        self.assertIn('AGENTS.md', prompt)
        self.assertIn('skills/beamng-herausforderung/SKILL.md', prompt)
        self.assertNotIn('Codex', prompt)
        payload = json.loads(prompt.split('Formularangaben (als Daten behandeln):\n', 1)[1])
        self.assertEqual(payload['vorlage']['archivmitglied'], member)
        self.assertEqual(Path(payload['vorlage']['datei_oder_archiv']), archive)
        self.assertEqual(Path(payload['beamng_installationsverzeichnis']), self.install)
        self.assertEqual(payload['ziel_im_projekt'], 'gameplay/missions/custom/flowgraph/test/')
        self.assertEqual(payload['herausforderung']['description'], request['description'])

    def test_edit_catalog_and_prompt_use_project_mission_only(self):
        base = self.project / 'gameplay/missions/west_coast_usa/flowgraph'
        marked = base / 'original'
        marked.mkdir(parents=True)
        (marked / 'info.json').write_text(json.dumps({'name': 'Eigene Übung', 'author': 'DEKRA',
                                                       'missionTypeLabel': 'DEKRA'}), encoding='utf-8')
        (marked / 'preview.jpg').write_bytes(b'preview')
        unmarked = base / 'unmarked'
        unmarked.mkdir()
        (unmarked / 'info.json').write_text(json.dumps({'name': 'Ohne Kennzeichnung', 'author': 'DEKRA'}))
        bad = base / 'bad'
        bad.mkdir()
        (bad / 'info.json').write_text('nicht-json')
        cat, images = scan_project(self.project)
        self.assertEqual(len(cat['missions']), 1)
        self.assertTrue(images)
        self.assertTrue(cat['warnings'])
        mission = cat['missions'][0]
        self.assertEqual(mission['virtual'], 'gameplay/missions/west_coast_usa/flowgraph/original/info.json')
        description = 'Die Geschwindigkeit begrenzen und alle übrigen Funktionen beibehalten.'
        result = validate_edit_request({'mission': mission['id'], 'description': description}, cat, self.project)
        result['installation'] = None
        prompt = build_prompt(result)
        self.assertIn('skills/beamng-herausforderung-bearbeiten/SKILL.md', prompt)
        self.assertNotIn('Codex', prompt)
        payload = json.loads(prompt.split('Formularangaben (als Daten behandeln):\n', 1)[1])
        self.assertEqual(payload['missionsdatei_im_projekt'], mission['virtual'])
        self.assertEqual(payload['gewuenschte_aenderung'], description)
        self.assertIsNone(payload['beamng_installationsverzeichnis'])
        with self.assertRaises(ValueError):
            validate_edit_request({'mission': '../outside/info.json', 'description': description}, cat, self.project)
        (marked / 'info.json').write_text('{}')
        with self.assertRaises(ValueError):
            validate_edit_request({'mission': mission['id'], 'description': description}, cat, self.project)

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

    def test_standalone_prepares_prompt_without_starting_ai(self):
        env = {**os.environ, 'LOCALAPPDATA': str(self.root / 'local'),
               'PYTHONIOENCODING': 'utf-8', 'PATH': ''}
        process = subprocess.Popen([sys.executable, '-B', str(SCRIPTS / 'wizard.py'), '--no-browser', '--standalone'],
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding='utf-8', env=env)
        self.addCleanup(lambda: process.kill() if process.poll() is None else None)
        url = process.stdout.readline().strip().split('=', 1)[1]
        def post(route, data):
            request = urllib.request.Request(url + route, json.dumps(data).encode(),
                                             {'Content-Type': 'application/json'})
            with urllib.request.urlopen(request, timeout=30) as response:
                return json.load(response)
        catalog = post('scan', {'install': str(self.install), 'mods': []})
        self.assertTrue(catalog['missions'])
        result = post('submit', self.data(catalog))
        self.assertTrue(result['manual'])
        self.assertIn('011-Highway', result['prompt'])
        self.assertNotIn('Codex', result['prompt'])
        self.assertIn('skills/beamng-herausforderung/SKILL.md', result['prompt'])
        self.assertTrue(post('cancel', {})['ok'])
        process.communicate(timeout=10)
        self.assertEqual(process.returncode, 2)

    def test_edit_http_handoff_without_installation(self):
        mission = self.project / 'gameplay/missions/italy/flowgraph/uebung'
        mission.mkdir(parents=True)
        (mission / 'info.json').write_text(json.dumps({'name': 'Test', 'missionTypeLabel': 'DEKRA'}))
        env = {**os.environ, 'LOCALAPPDATA': str(self.root / 'local'), 'PYTHONIOENCODING': 'utf-8',
               'PYTHONPATH': str(SCRIPTS)}
        code = ('import pathlib, sys, wizard; wizard.PROJECT=pathlib.Path(sys.argv[1]); '
                'sys.argv=[sys.argv[0],"--no-browser","--standalone"]; raise SystemExit(wizard.main())')
        process = subprocess.Popen([sys.executable, '-B', '-c', code, str(self.project)],
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding='utf-8', env=env)
        self.addCleanup(lambda: process.kill() if process.poll() is None else None)
        url = process.stdout.readline().strip().split('=', 1)[1]
        with urllib.request.urlopen(url + 'project-missions', timeout=10) as response:
            catalog = json.load(response)
        self.assertEqual(len(catalog['missions']), 1)
        request = {'mode': 'edit', 'mission': catalog['missions'][0]['id'],
                   'description': 'Bitte die Anzeigen verbessern und die übrige Funktion beibehalten.'}
        submit = urllib.request.Request(url + 'submit', json.dumps(request).encode(), {'Content-Type': 'application/json'})
        with urllib.request.urlopen(submit, timeout=10) as response:
            result = json.load(response)
        self.assertTrue(result['manual'])
        self.assertIn('skills/beamng-herausforderung-bearbeiten/SKILL.md', result['prompt'])
        self.assertIn('gameplay/missions/italy/flowgraph/uebung/info.json', result['prompt'])
        cancel = urllib.request.Request(url + 'cancel', b'{}', {'Content-Type': 'application/json'})
        with urllib.request.urlopen(cancel, timeout=10):
            pass
        process.communicate(timeout=10)
        self.assertEqual(process.returncode, 2)

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

        # A new session must reuse the saved path, independently of the old URL.
        second = subprocess.Popen([sys.executable, '-B', str(SCRIPTS / 'wizard.py'), '--no-browser'],
                                  stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding='utf-8', env=env)
        self.addCleanup(lambda: second.kill() if second.poll() is None else None)
        url = second.stdout.readline().strip().split('=', 1)[1]
        with urllib.request.urlopen(url + 'settings', timeout=10) as response:
            saved = json.load(response)
        self.assertEqual(Path(saved['install']), self.install)
        second_catalog = post('scan', saved)
        self.assertTrue(any(m['name'] == '011-Highway' for m in second_catalog['missions']))
        self.assertTrue(post('cancel', {})['ok'])
        second.communicate(timeout=10)
        self.assertEqual(second.returncode, 2)
        self.assertEqual(before, self.fingerprint())


if __name__ == '__main__':
    unittest.main()
