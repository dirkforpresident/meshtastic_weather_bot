# Meshtastic Wetter-Bot

Ein Bash-Skript für automatisierte Wetter- und Systemmeldungen, das stündlich Wetterdaten und CPU-Temperatur für Hamburg, Deutschland (ca. 53.350000, 10.030000) über Meshtastic (Main Channel, Index 0) sendet. Es ist für einen Computer mit einem per USB angeschlossenen Meshtastic-Node ausgelegt (z. B. Raspberry Pi), ruft Wetterdaten von [Open-Meteo](https://open-meteo.com/) ab und erfasst die CPU-Temperatur via `lm-sensors`, ergänzt durch kontextbezogene, hardwareorientierte Meldungen und Emojis.

## Funktionen
- **Wetterdaten**: Abfrage von Temperatur (`temperature_2m`), Wettercode (`weathercode`) und Windgeschwindigkeit (`wind_speed_10m`) von Open-Meteo für Hamburg.
  - Wetter-Emojis: ☀️ (≥30°C oder klarer Himmel), ☁️ (bewölkt), 🌫️ (Nebel), 🌧️ (Regen), ❄️ (Schnee), ⚡️ (Gewitter), 💨 (Wind ≥40 km/h), 🤔 (unbekannt).
  - Temperaturabhängiges Emoji: 🥵 (>36°C), 🌞 (30–36°C), 🕶️ (20–30°C), 😊 (10–20°C), 🥶 (0–10°C), ❄️ (<0°C).
- **CPU-Temperatur**: Erfassung via `sensors`, mit Warnsymbol ⚠️ bei >60°C.
- **Temperaturtrend**: Anzeige von ↑ oder ↓ bei Änderungen >0.5°C, mit Meldungen wie „Heisser wird’s!“.
- **Hardware-Meldungen** (20 pro Zustand):
  - **Hitze (≥30°C)**: Lüfter/Temperaturprobleme (z. B. „Lüfter schreit um Hilfe!“).
  - **Kälte (≤5°C)**: Raspberry Pi-Wärmeerzeugung (z. B. „Pi heizt wie ’n Ofen!“).
  - **Sturm (Wind ≥40 km/h)**: Wind/Antenne (z. B. „Antenne wackelt im Wind!“).
  - **Gewitter (Wettercode: 95, 96, 99)**: Blitz/Donner (z. B. „Blitz? Antenne duckt sich!“).
- **Laune-Meldungen**: 100 % Wahrscheinlichkeit für Nacht (22:00–05:59, 😴), Wochenende (Sa/So, 🎉), Montag vormittag (00:00–11:59, ☕).
- **Format**: `[$UHRZEIT] [$LAUNE_EMOJI] [$LAUNE] $WEATHER_EMOJI Hamburg: TEMP°C $TREND $SWEAT_EMOJI [$TREND_JOKE] - $HARDWARE_JOKE/$WEATHER_JOKE [$CPU: TEMP°C ⚠️ 🔥 $CPU_JOKE]`
- **Meshtastic**: Sendet auf Main Channel (Index 0) eines per USB angeschlossenen Nodes, Protokollierung in `/tmp/wetterbot.log` und `/tmp/wetterbot_debug.log`.

## Beispielausgaben
- **Nacht, Hitze, steigend**: `[23:00] 😴 Nacht? So müde! ☀️ Hamburg: 37.0°C ↑ 🥵 Heisser wird’s! - Lüfter schreit um Hilfe! [CPU: 75.0°C ⚠️ 🔥 CPU heiss? Ich schmelz!]`
- **Montagmorgen, warm**: `[09:00] ☕ Montag? Kaffee her! ☀️ Hamburg: 25.0°C 🕶️ - Sonne lacht, nice! [CPU: 50.0°C 🔥 CPU chillt!]`
- **Tag, kalt**: `[18:00] ❄️ Hamburg: 3.0°C 🥶 - Pi heizt wie ’n Ofen! [CPU: 40.0°C 🔥 CPU chillt!]`
- **Tag, Sturm**: `[12:00] 💨 Hamburg: 25.0°C 🕶️ - Antenne wackelt im Wind! [CPU: 50.0°C 🔥 CPU chillt!]`
- **Tag, Gewitter**: `[14:00] ⚡️ Hamburg: 25.0°C 🕶️ - Blitz? Antenne duckt sich! [CPU: 50.0°C 🔥 CPU chillt!]`

## Einrichtung auf einem Linux-System
Diese Anleitung geht von einem Linux-System (z. B. Raspberry Pi mit Raspberry Pi OS, Bullseye oder Bookworm) mit angeschlossenem Meshtastic-Node aus.

### Voraussetzungen
- Computer (z. B. Raspberry Pi) mit Linux.
- Meshtastic-Node (z. B. Heltec V3) per USB angeschlossen.
- Internetverbindung für API-Aufrufe.
- Meshtastic-Netzwerk mit aktiviertem Main Channel (Index 0).

### Installationsschritte
1. **System aktualisieren und Abhängigkeiten installieren**:
   ```bash
   sudo apt update
   sudo apt install -y curl jq lm-sensors python3-pip
   pip3 install meshtastic
   ```
   - `curl`: Für Open-Meteo-API-Aufrufe.
   - `jq`: Zum Parsen von JSON-Antworten.
   - `lm-sensors`: Für CPU-Temperatur.
   - `meshtastic`: Python-CLI für Meshtastic.

2. **Meshtastic-Node konfigurieren**:
   - Verbinde den Meshtastic-Node (z. B. `/dev/ttyUSB0`).
   - Prüfe den Port:
     ```bash
     ls /dev/ttyUSB*
     ```
   - Teste die Meshtastic-CLI:
     ```bash
     meshtastic --port /dev/ttyUSB0 --info
     ```
   - Stelle sicher, dass Main Channel (Index 0) aktiviert ist:
     ```bash
     meshtastic --port /dev/ttyUSB0 --ch-enable --ch-index 0
     ```
   - Falls der Port abweicht (z. B. `/dev/ttyUSB1`), passe `MESHTASTIC_PORT` im Skript an.

3. **Skript speichern**:
   - Speichere `meshtastic_wetter_bot.sh` in `/home/$USER/meshtastic_wetter_bot.sh` (z. B. `/home/pi/` auf einem Raspberry Pi).
   - Mache es ausführbar:
     ```bash
     chmod +x /home/$USER/meshtastic_wetter_bot.sh
     ```

4. **Skript testen**:
   - Führe es manuell aus:
     ```bash
     cd /home/$USER
     ./meshtastic_wetter_bot.sh
     ```
   - Prüfe die Protokolldateien:
     ```bash
     cat /tmp/wetterbot.log
     cat /tmp/wetterbot_debug.log
     ```
   - Überprüfe, ob die Nachricht auf dem Meshtastic-Gerät ankommt.

5. **Cron-Job einrichten**:
   - Bearbeite die Crontab:
     ```bash
     crontab -e
     ```
   - Füge hinzu, um stündlich auszuführen:
     ```
     0 * * * * /home/$USER/meshtastic_wetter_bot.sh
     ```
   - Prüfe, ob `cron` läuft:
     ```bash
     systemctl status cron
     ```

### Anpassungen
- **Standort**: Ändere die Koordinaten in `WEATHER_URL` (Standard: Hamburg, 53.350000, 10.030000).
  ```bash
  WEATHER_URL="https://api.open-meteo.com/v1/forecast?latitude=DEINE_LATITUDE&longitude=DEINE_LONGITUDE¤t=temperature_2m,weathercode,wind_speed_10m"
  ```
- **Meshtastic-Port**: Passe `MESHTASTIC_PORT` an, falls nicht `/dev/ttyUSB0`.
- **Meldungen/Emojis**: Bearbeite Arrays (z. B. `HARDWARE_JOKE_ARRAY`, `WEATHER_JOKE_ARRAY`) für eigene Meldungen.

### Fehlerbehebung
- **Keine Nachrichten gesendet**:
  - Prüfe `/tmp/wetterbot.log` und `/tmp/wetterbot_debug.log` auf Fehler.
  - Überprüfe den Meshtastic-Port:
    ```bash
    meshtastic --port /dev/ttyUSB0 --sendtext "Test"
    ```
  - Stelle sicher, dass `cron` läuft:
    ```bash
    systemctl status cron
    ```
- **Wetter-API-Fehler**:
  - Teste die API:
    ```bash
    curl -s "https://api.open-meteo.com/v1/forecast?latitude=53.350000&longitude=10.030000¤t=temperature_2m,weathercode,wind_speed_10m"
    ```
  - Erwartete Ausgabe: JSON wie `{"current":{"temperature_2m":25.0,"weathercode":1,"wind_speed_10m":15}}`.
- **Emoji-Anzeigeprobleme**:
  - Stelle UTF-8 sicher:
    ```bash
    locale
    export LANG=de_DE.UTF-8
    ```

## Mitwirken
Forke das Projekt, füge eigene Meldungen hinzu oder melde Fehler/Vorschläge über Issues oder Pull Requests!

## Lizenz
MIT-Lizenz – nutze, ändere und teile frei!

## Danksagung
Entwickelt für die Meshtastic-Community. Inspiriert durch den Wunsch nach einem technischen Wetter-Bot mit Humor und Hardware-Fokus!
