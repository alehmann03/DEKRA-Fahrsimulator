# Highway – Bremsdefekt

Demonstrationsszenario auf der Strecke 011-Highway. Nach mehr als fünf ununterbrochenen Simulationssekunden über 130 km/h wird am linken Vorderrad eine zusätzliche Mindestbremskraft aktiviert. Die Auslösebedingung ist künstlich gewählt und stellt keinen typischen Ablauf eines realen Bremsdefekts dar.

Die Stärke steht in `customNodes/HighwayBrakeRaceNode.lua` bei `BRAKE_STRENGTH`: 0,8 entspricht 80 % des konfigurierten Bremsmoments des Rades als Mindestwert. Die tatsächliche Wirkung und ein vollständiges Blockieren sind von Fahrzeug, Fahrbahn, Reglern und Temperaturmodell abhängig. Dieser Wert muss für das Vorführfahrzeug praktisch abgestimmt werden.

Die Radposition wird fahrzeugbezogen ermittelt. Die ursprünglich verwendeten Bremsfunktionen werden gesichert und bei Rennende, Abbruch, Fahrzeugwechsel oder Neustart wiederherzustellen versucht. Während des Rennens werden die Funktionen regelmäßig überprüft; bei unvereinbarem Fahrzeug, Fahrzeugverlust oder unerwarteter Änderung wird die Mission abgebrochen. Bei Fahrzeugverlust oder Neuladen kann eine Rückmeldung beziehungsweise Wiederherstellung nicht garantiert werden. Der Einfluss anderer Fahrzeugcontroller wird durch die Funktionsprüfung nicht vollständig abgedeckt.

**Teststatus:** Kein Spieltest durchgeführt. Zu prüfen sind Sichtbarkeit und Start der Mission, Checkpoints und Ziel, 130 km/h und fünf Sekunden einschließlich Unterbrechung, tatsächliches linkes Vorderrad, Bremswirkung und Kontrollierbarkeit mit und ohne Gegenlenken, unterschiedliche Fahrzeuge und Regler sowie Recovery, Fahrzeugwechsel, Missionsabbruch, Neustart und Wiederherstellung der normalen Bremse.
