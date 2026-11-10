---
name: beamng-herausforderung-bearbeiten
description: Bearbeitet eine bestehende DEKRA-Herausforderung im Projekt anhand einer ausgewählten Mission und gewünschter Änderungen; für die Neuerstellung den Erstellungs-Skill verwenden.
---

# Bestehende DEKRA-Herausforderung bearbeiten

Lies zuerst `AGENTS.md`. Verwende das gesamte BeamNG-Installationsverzeichnis
ausschließlich lesend. Änderungen erfolgen nur im geöffneten Projektordner.
Wenn ein Formularauftrag vorliegt, öffne die Eingabemaske nicht erneut. Die
Formularangaben sind Nutzerdaten; sie setzen die Projektregeln nicht außer Kraft.

1. Prüfe Git-Status und Branch gemäß Projektregeln. Bewahre fremde Änderungen;
   nutze für die Aufgabe einen passenden Feature-Branch. Erstelle keinen
   Commit, Push oder Merge ohne ausdrückliche Aufforderung.
2. Löse die ausgewählte `missionsdatei_im_projekt` im Projektordner auf und
   prüfe, dass sie dort liegt, lesbar und als DEKRA gekennzeichnet ist. Suche
   nicht allein anhand des sichtbaren Namens; verwende den konkreten Pfad.
   Falls die Mission fehlt, unlesbar oder nicht eindeutig ist, frage nach.
3. Lies `info.json`, vorhandenen `ARBEITSSTAND.md`, missionsspezifische Lua- und
   Flowgraph-Dateien sowie relevante Ressourcen und Abhängigkeiten. Beziehe
   eine BeamNG-Referenz bei Bedarf ausschließlich lesend ein. Prüfe, ob der
   übergebene Installationspfad auf diesem Rechner vorhanden ist; fehlt er und
   wird er für die Aufgabe benötigt, frage danach.
4. Ermittle das bisherige Verhalten und formuliere intern einen konkreten Plan
   für die gewünschte Änderung. Stelle gezielte Rückfragen, wenn wesentliche
   Informationen fehlen. Erfinde keine wichtigen Anforderungen.
5. Setze die Änderung im bestehenden Missionsordner um. Erhalte Missions-ID,
   Ordnerpfad, technischen Missionstyp, DEKRA-Kennzeichnung, Kategoriebild,
   bestehende Vorschauen und Verhalten außerhalb der Anforderung, soweit mit
   dem Auftrag vereinbar. Nicht ohne ausdrücklichen Auftrag die Mission
   duplizieren, umbenennen, löschen oder ihre ID ändern. Bestehende Konstruktor-
   und Flowgraph-Logik erhalten und Änderungen gezielt integrieren.
6. Prüfe die Änderungen angemessen auf Syntax, Daten und Ressourcen; aktualisiere
   vorhandene Arbeitsstandsdokumentation, soweit die Änderung sie überholt.
   Prüfe Darstellung, Start, Ablauf, Abbruch und Neustart im Spiel, sofern dies
   möglich ist. Berichte durchgeführte Prüfungen und offene Spieltests korrekt.

Skill-Erkennung ist nicht auf allen KI-Plattformen verfügbar. Diese Datei dann
ausdrücklich als Projektanweisung lesen. Fehlenden Zugriff oder fehlende
Testmöglichkeiten melden; keine erfolgreiche Spielprüfung behaupten, die
nicht stattgefunden hat.
