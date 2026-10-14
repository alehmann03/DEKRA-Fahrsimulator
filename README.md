# DEKRA BeamNG Scenario Project

## Ziel
Entwicklung einfacher Fahrszenarien mit BeamNG.drive und Lua.

## Entwicklungsumgebung
- Windows
- Visual Studio Code
- Git
- BeamNG.drive

## Erste Meilensteine
- [ ] Entwicklungsumgebung einrichten
- [ ] Erstes Lua-Skript laden
- [ ] Erste Situation im Spiel auslösen
- [ ] Eigenes Szenario entwickeln


Dein-Git-Repo-Ordner/
├── mod_info.json                <-- Beschreibt die GESAMTE Mod (sichtbar im Mod-Manager)
├── lua/
│   └── ge/
│       └── extensions/
│           ├── testszenario.lua <-- Dein aktuelles globales Testskript
│           └── core_system.lua  <-- Spätere globale Skripte für den Simulator
└── gameplay/
    └── missions/
        ├── erstes_test_szenario/
        │   ├── info.json        <-- Beschreibt NUR dieses eine Szenario (Name, Bild, Typ)
        │   └── mission.json     <-- Die Missionslogik/Flowgraph-Daten
        └── echtes_szenario_01/
            ├── info.json        <-- Beschreibt das echte Szenario
            └── mission.json
