# Projektverzeichnisse

- `C:\Users\alber\AppData\Local\BeamNG\BeamNG.drive\current\mods\unpacked\DEKRA-Fahrsimulator` ist der Projektordner im Mod-Verzeichnis von BeamNG.drive. Hier finden alle Programmieraufgaben statt.
- `C:\Users\alber\OneDrive\Dokumente\02_Arbeit\DEKRA\Fahrsimulator` dient zur Ablage von Präsentationen, Word-Dokumenten und anderen Dateien, die nicht zum Coding gehören.
- `C:\Users\alber\Dokumente lokal\Projektplanung` dient ausschließlich der Organisation.

Diese Zuordnung gilt für das gesamte Projekt. Beachte bei konkreten Aufgaben abweichende ausdrückliche Anweisungen des Nutzers.

# BeamNG.drive als Referenz

- Das gesamte Installationsverzeichnis `C:\Program Files (x86)\Steam\steamapps\common\BeamNG.drive` darf als Referenz für die Entwicklung gelesen werden. Nutze bei Bedarf vorhandene Inhalte, Dateien und Beispiele, um Herausforderungen bestmöglich umzusetzen; ein vorheriges Kopieren nach `_references` ist dafür nicht erforderlich.
- Originale Herausforderungen befinden sich dort unter `gameplay/missions/<Karte>/<Kategorie>/<Name_der_Herausforderung>/`. Wenn eine Vorlage mit Karte und Namen genannt wird, suche sie für die entsprechende Karte über die Kategorien hinweg, beispielsweise `011-Highway` für West Coast USA unter `gameplay/missions/west_coast_usa/<Kategorie>/011-Highway/`. Berücksichtige bei der lesenden Suche auch Inhalte in Archiven des Installationsverzeichnisses.
- Oberste Priorität: Das Installationsverzeichnis und alle darin enthaltenen Dateien und Ordner dürfen unter keinen Umständen verändert werden. Dort ausschließlich lesend zugreifen: nichts erstellen, bearbeiten, löschen, verschieben oder überschreiben und keine Werkzeuge oder Befehle ausführen, die dort Änderungen verursachen könnten. Dies gilt auch für indirekte Änderungen und temporäre Dateien.
- Die Entwicklung und alle Änderungen am Code und an den zugehörigen Projektdateien erfolgen ausschließlich im Projektordner `C:\Users\alber\AppData\Local\BeamNG\BeamNG.drive\current\mods\unpacked\DEKRA-Fahrsimulator`. Inhalte aus dem Installationsverzeichnis dürfen bei Bedarf lesend als Vorlage genutzt oder in den Projektordner kopiert und ausschließlich dort bearbeitet werden.

# Herausforderungen

- Herausforderungen liegen unter `gameplay/missions/<Karte>/flowgraph/<Name_der_Herausforderung>/` im Projektordner, zum Beispiel unter `gameplay/missions/west_coast_usa/flowgraph/`.
- Neue Herausforderungen entsprechend der zugehörigen Karte und Kategorie anlegen und konfigurieren, sodass sie in der jeweiligen Karte und in der Seitenansicht der Spielkarte unter der passenden Kategorie erscheinen.

# Git-Arbeitsweise

- Features, Tests und Szenarien werden auf eigenen Branches entwickelt und dort committet. Direkte Commits auf `main` nur auf ausdrückliche Anweisung.
- Commits erfolgen auf Aufforderung des Nutzers.
- Fertige Branches auf Anweisung des Nutzers in `main` mit einem eigenen Merge-Commit zusammenführen (`git merge --no-ff`), auch wenn ein Fast-Forward möglich wäre. So bleibt die Verzweigung in der Historie sichtbar.
- Pushes erfolgen nur auf ausdrückliche Anweisung des Nutzers.

# Projekt-Skill

- Für die geführte Entwicklung einer neuen Herausforderung nutze `skills/beamng-herausforderung/SKILL.md`. Der Skill startet eine lokale Browser-Eingabemaske für Karte, Vorlage und Szenariobeschreibung.
- Bei KI-Plattformen ohne automatische Skill-Erkennung die genannte Datei ausdrücklich lesen. Einrichtung und technische Voraussetzungen stehen in `skills/beamng-herausforderung/README.md`.
