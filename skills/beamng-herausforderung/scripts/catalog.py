"""Read-only BeamNG virtual-file catalog. Never extracts or writes game data."""
import json
import os
from pathlib import Path, PurePosixPath
import re
import zipfile

LIMIT = 16 * 1024 * 1024


def load_metadata(raw):
    # BeamNG accepts comments and trailing commas. Preserve quoted strings.
    text = raw.decode('utf-8-sig')
    text = re.sub(r'"(?:\\.|[^"\\])*"|//[^\n]*|/\*[\s\S]*?\*/',
                  lambda m: m[0] if m[0].startswith('"') else ' ', text)
    text = re.sub(r'"(?:\\.|[^"\\])*"|,\s*(?=[}\]])',
                  lambda m: m[0] if m[0].startswith('"') else '', text)
    return json.loads(text)


def read_ref(ref):
    if ref.get('member'):
        with zipfile.ZipFile(ref['path'], 'r') as archive:
            if archive.getinfo(ref['member']).file_size > LIMIT:
                raise ValueError('Datei überschreitet 16 MiB.')
            return archive.read(ref['member'])
    path = Path(ref['path'])
    if path.stat().st_size > LIMIT:
        raise ValueError('Datei überschreitet 16 MiB.')
    return path.read_bytes()


def installation(path):
    root = Path(path).expanduser().resolve()
    if not root.is_dir() or not (root / 'content').is_dir() or not (root / 'gameplay').is_dir():
        raise ValueError('Bitte den BeamNG-Installationsordner mit content und gameplay auswählen.')
    return root


def scan(install, project, mods=()):
    install = installation(install)
    project = Path(project).resolve()
    if project == install or install in project.parents:
        raise ValueError('Das Projekt darf nicht in der Spielinstallation liegen.')
    files, warnings = [], []
    roots = [(install, 'Original'), (project, 'Projekt')]
    for raw in mods:
        root = Path(raw).expanduser().resolve()
        if root == install or install in root.parents or root in install.parents:
            raise ValueError('Mod-Quelle darf die Installation nicht überlappen.')
        if not root.is_dir():
            warnings.append(f'Mod-Verzeichnis nicht verfügbar: {root}')
        else:
            roots.append((root, 'Mod'))
    # Index only relevant virtual paths. No following directory junctions/symlinks.
    for root, origin in roots:
        def failed(error):
            warnings.append(str(error))
        for base, dirs, names in os.walk(root, followlinks=False, onerror=failed):
            dirs[:] = [d for d in dirs if d not in {'.git', '_references', 'skills', '__pycache__'}
                       and not Path(base, d).is_symlink()
                       and not (hasattr(Path(base, d), 'is_junction') and Path(base, d).is_junction())]
            for name in names:
                path = Path(base, name)
                if path.is_symlink():
                    continue
                if name.lower().endswith('.zip'):
                    try:
                        with zipfile.ZipFile(path, 'r') as archive:
                            for member in archive.namelist():
                                add_file(files, member, {'path': str(path), 'member': member}, origin, str(path))
                    except (OSError, zipfile.BadZipFile) as error:
                        warnings.append(f'Archiv nicht lesbar: {path}: {error}')
                else:
                    relative = path.relative_to(root).as_posix()
                    # Mods can live below unpacked/<name>/.
                    parts = relative.split('/')
                    candidates = [relative]
                    if origin == 'Mod':
                        candidates += ['/'.join(parts[i:]) for i, p in enumerate(parts) if p in ('levels', 'gameplay')]
                    for candidate in dict.fromkeys(candidates):
                        if add_file(files, candidate, {'path': str(path)}, origin, str(root)):
                            break
    lookup = {(f['source'], f['virtual']): f['ref'] for f in files}
    maps, missions, images = {}, [], {}
    for f in files:
        virtual = f['virtual']
        match_map = re.fullmatch(r'levels/([^/]+)/info.json', virtual, re.I)
        match_mission = re.fullmatch(r'gameplay/missions/([^/]+)/([^/]+)/([^/]+)/info.json', virtual, re.I)
        if not (match_map or match_mission):
            continue
        try:
            data = load_metadata(read_ref(f['ref']))
            if not isinstance(data, dict):
                raise ValueError('Metadaten müssen ein Objekt sein.')
        except (ValueError, OSError, KeyError, RuntimeError, zipfile.BadZipFile) as error:
            warnings.append(f'Metadaten nicht lesbar: {virtual}: {error}')
            continue
        map_id = (match_map or match_mission)[1]
        entry = maps.setdefault(map_id, {'id': map_id, 'title': map_id.replace('_', ' ').title(), 'sources': [], 'image': None})
        label = f"{f['origin']}: {f['source']}"
        if label not in entry['sources']:
            entry['sources'].append(label)
        directory = str(PurePosixPath(virtual).parent)
        candidates = []
        for key in ('previews', 'preview', 'thumbnail'):
            value = data.get(key, [])
            if isinstance(value, str):
                value = [value]
            if isinstance(value, list):
                candidates.extend(x for x in value if isinstance(x, str))
        candidates += ['preview.jpg', 'preview.png', 'thumbnail.jpg', 'thumbnail.png']
        image_id = None
        for candidate in candidates:
            rel = candidate.lstrip('/') if candidate.startswith('/') else directory + '/' + candidate
            ref = lookup.get((f['source'], rel))
            if ref and rel.lower().endswith(('.jpg', '.jpeg', '.png', '.webp')):
                image_id = str(len(images))
                images[image_id] = {**ref, 'mime': 'image/png' if rel.lower().endswith('.png') else 'image/webp' if rel.lower().endswith('.webp') else 'image/jpeg'}
                break
        if match_map:
            title = data.get('title', '')
            if isinstance(title, str) and title and not title.startswith('levels.'):
                entry['title'] = title
            entry['image'] = entry['image'] or image_id
        else:
            missions.append({'id': str(len(missions)), 'map': map_id, 'category': match_mission[2],
                             'name': match_mission[3], 'title': data.get('name', match_mission[3]),
                             'description': data.get('description', ''), 'origin': f['origin'],
                             'source': f['source'], 'virtual': virtual, 'ref': f['ref'], 'image': image_id})
    warnings.append('Erfasst sind lesbare info.json-Dateien und ZIP-Archive der angegebenen Quellen. Nicht angegebene Mod-Ordner, andere Archivformate und Sonderformate können fehlen. Die Sichtbarkeit im Spiel ist nicht geprüft.')
    return {'maps': sorted(maps.values(), key=lambda x: x['title']), 'missions': missions, 'warnings': warnings}, images


def add_file(files, virtual, ref, origin, source):
    virtual = virtual.replace('\\', '/').lstrip('/')
    if '..' in PurePosixPath(virtual).parts:
        return False
    if virtual.startswith(('levels/', 'gameplay/missions/')) and not virtual.endswith('/'):
        files.append({'virtual': virtual, 'ref': ref, 'origin': origin, 'source': source})
        return True
    return False
