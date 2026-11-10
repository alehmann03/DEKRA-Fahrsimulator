# Kreuzung – Geschwindigkeitsvergleich: Prototyp

Vorlage 008-Street; Kreuzung bei (-260.426, 665.635, 75.012). In den kopierten Prefabs wurden 13 Barrieren innerhalb von 40 m entfernt; in diesem Bereich verbleiben dort keine positionierten Objekte. Levelobjekte sind dadurch nicht geprüft oder verändert.

Der Vorwärtskurs führt zwischen den Pathnodes 6 und 7 grob nach Westen. Der Querverkehr wird südlich bei (-260.5, 620, 75.2) erstellt und entlang einer nach Norden führenden ScriptAI-Trajektorie mit Sollgeschwindigkeit 40 km/h gesteuert. Der Start erfolgt abhängig von der geschätzten Ankunftszeit des Spielers bei konstanter Geschwindigkeit; bei x=-225 erfolgt die Warnung. Dies sind unkalibrierte Ausgangswerte. ScriptAI ist eine physikalische Regelung und garantiert weder konstante Istgeschwindigkeit noch einen bestimmten Kollisionszeitpunkt. Straßenlage, Ausrichtung, Höhe und der tatsächlich vom Spieler befahrene Kreuzungsbereich sind im Spiel zu prüfen.

Das in der Installation gefundene Fahrzeug ist `vivace` mit Konfiguration `tograc_110_M`. Die Mission nutzt derzeit das gewählte Spielerfahrzeug; die Konfiguration wird nicht automatisch erzwungen. Für vergleichbare Tests muss es vor beiden Fahrten manuell gewählt werden.

Missions-Log meldet Positionen und Geschwindigkeiten beim Start des Querverkehrs und bei Warnung sowie die Geschwindigkeiten bei erkanntem Fahrzeugkontakt. Bei erkanntem Kontakt wird ScriptAI beendet und die Parkbremse aktiviert; die Crashphysik bleibt aktiv. Automatische Messung von Bremsbeginn, Aufprall und Restgeschwindigkeit ist noch nicht implementiert.

**Nicht abgenommen:** BeamNG lief bei der Erstellung nicht. Die Mission, der Spawn und ScriptAI sind ungetestet. Insbesondere die gewünschten Ergebnisse bei 50 und 80 km/h sind nicht bestätigt. Nach einem Spieltest müssen Positionen, Anlauf, Auslösepunkt und Zeitverhalten anhand mehrfacher Versuche gemeinsam kalibriert werden. Der Prototyp ist bis dahin nicht als zuverlässige Vorführung anzusehen.

Die geschätzte Querverkehr-Anfahrt einschließlich Anlauf beträgt zunächst 5,8 Sekunden (Start um 0,5 Sekunden später als zuvor). Sie muss für 40 km/h und das Vorführfahrzeug im Spiel kalibriert werden. Auch die Kollisionserkennung über die BeamNG-Kontaktdaten und der Stopp der KI müssen praktisch geprüft werden.
