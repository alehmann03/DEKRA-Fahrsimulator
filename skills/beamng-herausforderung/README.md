# Neue BeamNG-Herausforderung

## Start für neue Personen

Voraussetzungen: lokales Repository, BeamNG.drive, Python **3.10 oder neuer**,
ein Browser und ein KI-Agent mit Zugriff auf lokale Programme und Dateien.
Keine Python-Zusatzpakete, Cloud-Dienste oder API-Schlüssel erforderlich.

Schreibe im KI-Chat:

> Lies `skills/beamng-herausforderung/SKILL.md` und entwickle mit diesem Skill eine neue Herausforderung.

Die AGENTS.md verweist ebenfalls darauf. Bei Plattformen mit Skill-Verwaltung
kann der Ordner nach deren Vorgaben registriert werden; die automatische
Entdeckung im Verzeichnis `skills/` wird nicht für jede Plattform garantiert.
Die mitgelieferte `agents/openai.yaml` beschreibt den Skill für kompatible UIs.

Der Agent startet aus dem Repository:

```powershell
python -B skills/beamng-herausforderung/scripts/wizard.py
```

Im externen Browserfenster:

1. Beim ersten Mal Installationspfad eintragen (Ordner mit `content` und `gameplay`).
2. Optional zusätzliche Mod-Verzeichnisse angeben, zum Beispiel den `mods`-Ordner
   des aktiven BeamNG-Benutzerordners. Diese werden ebenfalls gespeichert.
3. Karte und kategorisierte Vorlage auswählen.
4. Namen, Ablauf und gewünschte Änderungen beschreiben.
5. Übersicht prüfen und **Entwicklung starten** wählen.

Die KI übernimmt die Angaben aus dem laufenden Prozess, formuliert ihren
Umsetzungsauftrag und entwickelt im Feature-Branch. Die Eingabemaske ruft
selbst kein KI-Modell auf. Bei manueller Ausführung fehlt dieser wartende Agent;
das JSON-Ergebnis muss dann einem Agenten übergeben werden.

**Abbrechen** beendet die Sitzung ohne Entwicklungsauftrag. Nur das Fenster zu
schließen beendet den wartenden Prozess nicht: URL erneut öffnen und abbrechen
oder den Agenten bitten, den Prozess zu stoppen. `Strg+C` bricht ebenfalls ab.
Falls kein Browser startet, öffne die ausgegebene lokale URL. Mit `--no-browser`
kann der automatische Browserstart unterdrückt werden.

## Einstellungen und Daten

Auf Windows liegen die Einstellungen unter
`%LOCALAPPDATA%/DEKRA-BeamNG-Wizard/settings.json`, sonst unter
`$XDG_CONFIG_HOME/DEKRA-BeamNG-Wizard/settings.json` beziehungsweise
`~/.config/DEKRA-BeamNG-Wizard/settings.json`.
Sie sind rechner-/benutzerbezogen und werden nicht mit Git übertragen. Ein
gültiger gespeicherter Pfad wird automatisch wiederverwendet. „Pfade ändern“
erlaubt Änderungen. Ein ungültiger Pfad führt zurück zur Pfadeingabe. Falls
Schreibrechte auf den Einstellungsordner fehlen, bleibt der Ablauf nutzbar;
die Oberfläche meldet dann, dass Einstellungen nur für diese Sitzung gelten.

Der lokale Server bindet ausschließlich an `127.0.0.1` mit zufälligem Port
und zufälliger Sitzungs-URL. Er prüft Host/Origin, nimmt nur JSON-Anfragen an
und liefert nur katalogisierte Bilder aus. Die Auswahl bleibt bis zur
Übergabe im Speicher; keine Beschreibungen oder Spielbilder werden ins Repo
geschrieben. Die Installation wird nicht entpackt oder verändert.

## Datenquellen und Grenzen

- Lose Dateien und ZIP-Archive der Installation, des Projekts und optionaler
  Mod-Verzeichnisse werden gelesen. Archivmitglieder werden direkt gelesen,
  nicht extrahiert. Symlinks und Verzeichnis-Junctions werden nicht verfolgt.
- Karten: `levels/<Karte>/info.json`; Karten mit Missionen werden auch ohne
  passende Level-Metadaten gelistet.
- Vorlagen: `gameplay/missions/<Karte>/<Kategorie>/<Name>/info.json`.
- Kategorien stammen aus dem Missionspfad; Fundorte sind in der Übersicht
  sichtbar. Gleichnamige Vorlagen unterschiedlicher Quellen bleiben getrennt.
- Vorschaubilder werden aus Metadaten oder üblichen preview-/thumbnail-Dateien
  gesucht. Ohne passendes Bild erscheint ein Platzhalter.
- Übersetzungsschlüssel werden derzeit nicht aufgelöst. Als stabiler Name
  wird der Missionsordner gezeigt; nicht aufgelöste Beschreibungen werden in
  der Kartenauswahl nicht als Klartext erfunden.
- Es wird kein vollständiges BeamNG-Dateisystem mit Mod-Prioritäten simuliert.
  Nicht angegebene Mods, andere Archivformate, abweichende Pfade und nicht
  lesbare Daten können fehlen. Warnungen erscheinen im Fenster.
- Laufzeit-Sichtbarkeit und Funktion im Spiel müssen getrennt geprüft werden.
- Metadaten und Bilder sind auf 16 MiB pro Datei begrenzt.

Zum Übergeben des Projekts Skill-Dateien mit versionieren, keine lokalen
Einstellungen oder Spielinhalte. Auf einem anderen Rechner Python installieren,
Repository öffnen und den Skill wie oben aufrufen. Eventuelle Berechtigungen
der KI-Plattform müssen lokalen Prozessstart und Einstellungsablage erlauben.

## Prüfung

```powershell
python -B -m unittest discover -s skills/beamng-herausforderung/tests -v
```

Die Tests verwenden ausschließlich synthetische Spielordner in temporären
Verzeichnissen, prüfen die Katalogisierung und Übergabe sowie unveränderte
Quelldateien. Sie verändern keine echte BeamNG-Installation.
