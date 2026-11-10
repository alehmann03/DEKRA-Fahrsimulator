"""Loopback-only wizard. Result on stdout; no AI service or game writes."""
import argparse
import json
import os
from pathlib import Path
import re
import secrets
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlsplit
import webbrowser

from catalog import installation, read_ref, scan

PROJECT = Path(__file__).resolve().parents[3]
ASSET = Path(__file__).resolve().parents[1] / 'assets' / 'index.html'


def config_path():
    base = Path(os.environ.get('LOCALAPPDATA') or os.environ.get('XDG_CONFIG_HOME') or Path.home() / '.config')
    return base / 'DEKRA-BeamNG-Wizard' / 'settings.json'


def save_settings(path, data):
    install = installation(data['install'])
    # Refuse paths redirected into the protected tree, including symlink parents.
    destination = path.resolve()
    if destination == install or install in destination.parents:
        raise ValueError('Einstellungen dürfen nicht in der Installation gespeichert werden.')
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix('.tmp')
    if temporary.is_symlink():
        raise ValueError('Unsicherer temporärer Einstellungspfad.')
    temporary.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding='utf-8')
    temporary.replace(path)


def validate_request(data, catalog, project):
    template = next((m for m in catalog['missions'] if m['id'] == data.get('template')), None)
    if not template or template['map'] != data.get('map'):
        raise ValueError('Bitte eine gültige Vorlage für die gewählte Karte auswählen.')
    slug = data.get('slug', '')
    if not isinstance(slug, str) or not re.fullmatch(r'[a-z0-9]+(?:_[a-z0-9]+)*', slug) or len(slug) > 80:
        raise ValueError('Ordnername: maximal 80 Zeichen, Kleinbuchstaben, Ziffern und Unterstriche.')
    map_id = template['map']
    if not re.fullmatch(r'[A-Za-z0-9_-]+', map_id):
        raise ValueError('Kartenkennung benötigt eine manuelle Prüfung.')
    target = Path(project) / 'gameplay' / 'missions' / map_id / 'flowgraph' / slug
    if target.exists():
        raise ValueError('Diese Herausforderung existiert bereits. Bitte einen neuen Ordnernamen wählen.')
    if Path(project).resolve() not in target.resolve().parents:
        raise ValueError('Ziel liegt außerhalb des Projekts.')
    fields = {}
    for name in ('name', 'description', 'vehicle', 'trigger', 'success', 'reset', 'feedback'):
        value = data.get(name, '')
        if not isinstance(value, str) or len(value) > 20000:
            raise ValueError('Ungültiges Eingabefeld.')
        fields[name] = value.strip()
    if not fields['name'] or len(fields['description']) < 30:
        raise ValueError('Bitte Namen und eine Beschreibung mit mindestens 30 Zeichen angeben.')
    return {'schema': 1, 'map': map_id, 'slug': slug, 'target': str(target), 'template': template,
            'scenario': fields, 'catalog_warnings': catalog['warnings']}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--no-browser', action='store_true')
    args = parser.parse_args()
    settings_file = config_path()
    try:
        settings = json.loads(settings_file.read_text(encoding='utf-8'))
        if not isinstance(settings, dict):
            settings = {}
    except (OSError, ValueError):
        settings = {}
    state = {'settings': settings, 'catalog': None, 'images': {}, 'result': None}
    token = secrets.token_urlsafe(32)
    lock = threading.Lock()

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def send(self, status, body, mime='application/json'):
            raw = body if isinstance(body, bytes) else json.dumps(body, ensure_ascii=False).encode('utf-8')
            self.send_response(status)
            self.send_header('Content-Type', mime + ('; charset=utf-8' if mime.startswith(('text/', 'application/json')) else ''))
            self.send_header('Content-Length', str(len(raw)))
            self.send_header('Cache-Control', 'no-store')
            self.send_header('X-Content-Type-Options', 'nosniff')
            self.send_header('Referrer-Policy', 'no-referrer')
            self.send_header('Content-Security-Policy', "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self'; connect-src 'self'; frame-ancestors 'none'")
            self.end_headers()
            self.wfile.write(raw)

        def route(self):
            expected = f'127.0.0.1:{self.server.server_port}'
            if self.headers.get('Host') != expected or self.headers.get('Origin', f'http://{expected}') != f'http://{expected}':
                raise ValueError('Unzulässiger Ursprung.')
            path = urlsplit(self.path).path
            prefix = '/' + token + '/'
            if not path.startswith(prefix):
                raise ValueError('Ungültige Sitzung.')
            return path[len(prefix):]

        def do_GET(self):
            try:
                route = self.route()
                if route == '':
                    self.send(200, ASSET.read_bytes(), 'text/html')
                elif route == 'settings':
                    self.send(200, state['settings'])
                elif route.startswith('image/'):
                    ref = state['images'].get(route[6:])
                    if not ref:
                        raise ValueError('Bild nicht verfügbar.')
                    self.send(200, read_ref(ref), ref['mime'])
                else:
                    self.send(404, {'error': 'Nicht gefunden.'})
            except Exception as error:
                self.send(400, {'error': str(error)})

        def do_POST(self):
            try:
                route = self.route()
                if self.headers.get('Content-Type') != 'application/json':
                    raise ValueError('JSON erforderlich.')
                size = int(self.headers.get('Content-Length', '0'))
                if not 0 < size <= 200000:
                    raise ValueError('Ungültige Eingabegröße.')
                data = json.loads(self.rfile.read(size))
                if not isinstance(data, dict):
                    raise ValueError('JSON-Objekt erforderlich.')
                with lock:
                    if route == 'scan':
                        root = installation(data['install'])
                        mods = data.get('mods', [])
                        if not isinstance(mods, list) or not all(isinstance(x, str) for x in mods):
                            raise ValueError('Ungültige Mod-Verzeichnisse.')
                        catalog, images = scan(root, PROJECT, mods)
                        config = {'install': str(root), 'mods': mods}
                        config_warning = None
                        try:
                            save_settings(settings_file, config)
                        except (OSError, ValueError) as error:
                            config_warning = f'Pfad nur für diese Sitzung: Einstellungen nicht gespeichert: {error}'
                        if config_warning:
                            catalog['warnings'].append(config_warning)
                        state.update(settings=config, catalog=catalog, images=images)
                        self.send(200, catalog)
                    elif route == 'submit':
                        if state['result'] is not None or state['catalog'] is None:
                            raise ValueError('Sitzung nicht bereit.')
                        result = validate_request(data, state['catalog'], PROJECT)
                        result['installation'] = state['settings']['install']
                        state['result'] = result
                        self.send(200, {'ok': True})
                        threading.Thread(target=self.server.shutdown, daemon=True).start()
                    elif route == 'cancel':
                        self.send(200, {'ok': True})
                        threading.Thread(target=self.server.shutdown, daemon=True).start()
                    else:
                        self.send(404, {'error': 'Nicht gefunden.'})
            except Exception as error:
                self.send(400, {'error': str(error)})

    with ThreadingHTTPServer(('127.0.0.1', 0), Handler) as server:
        url = f'http://127.0.0.1:{server.server_port}/{token}/'
        print('EINGABEFENSTER=' + url, flush=True)
        if not args.no_browser:
            webbrowser.open(url)
        try:
            server.serve_forever(poll_interval=0.2)
        except KeyboardInterrupt:
            pass
    if state['result']:
        print('BEAMNG_REQUEST=' + json.dumps(state['result'], ensure_ascii=True), flush=True)
        return 0
    print('Eingabe abgebrochen.', flush=True)
    return 2


if __name__ == '__main__':
    raise SystemExit(main())
