#!/bin/bash

# Bash-Skript für automatisierte Wetter- und Systemmeldungen über Meshtastic
# Sendet stündlich Wetterdaten (Temperatur, Wettercode, Windgeschwindigkeit) für Hamburg (53.350000, 10.030000) über einen per USB angeschlossenen Meshtastic-Node (Main Channel, Index 0)
# Nutzt Open-Meteo für Wetterdaten und lm-sensors für CPU-Temperatur
# Protokollierung in /tmp/wetterbot.log und /tmp/wetterbot_debug.log
# Format: [$UHRZEIT] [$LAUNE_EMOJI] [$LAUNE] $WEATHER_EMOJI Hamburg: TEMP°C $TREND $SWEAT_EMOJI [$TREND_JOKE] - $HARDWARE_JOKE/$WEATHER_JOKE [$CPU: TEMP°C ⚠️ 🔥 $CPU_JOKE]

# Exit bei Fehlern
set -e

# Konfiguration
LOG_FILE="/tmp/wetterbot.log"
LAST_TEMP_FILE="/tmp/last_temp.txt"
DEBUG_FILE="/tmp/wetterbot_debug.log"
DEBUG=1 # Debugging aktiviert
MESHTASTIC_PORT="/dev/ttyUSB0"

# Pfad für meshtastic CLI
export PATH="$PATH:$HOME/.local/bin"

# --- 1. Uhrzeit und Wochenende ---
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
HOUR=$(date "+%H")
DAY=$(date "+%u")
UHRZEIT=$(date "+%H:%M")

# Nacht (22:00-05:59)?
if [ "$HOUR" -ge 22 ] || [ "$HOUR" -lt 6 ]; then
    TIME="Nacht"
else
    TIME="Tag"
fi

# Wochenende (Sa/So) oder Montag vormittag (Mo, 00:00-11:59)?
if [ "$DAY" -ge 6 ]; then
    WEEKEND="WE"
    LAUNE_STATE="Wochenende"
elif [ "$DAY" -eq 1 ] && [ "$HOUR" -lt 12 ]; then
    WEEKEND="WT"
    LAUNE_STATE="MontagVormittag"
else
    WEEKEND="WT"
    LAUNE_STATE="KeinLaune"
fi

# --- 2. CPU-Temperatur ---
if command -v sensors >/dev/null 2>&1; then
    CPU_TEMP=$(sensors | grep 'Package id 0:' | awk '{print $4}' | tr -d '+°C')
    if [ -z "$CPU_TEMP" ]; then
        CPU_TEMP="N/A"
        CPU_JOKE_ARRAY=("Sensor kaputt!" "Sensor weg!" "CPU? Keine Ahnung!" "Sensor schläft!" "Temperatur 404!" "Sensor? Wo bist du?" "CPU-Daten? Nope!" "Sensor tot? Argh!" "Sensor? Echt jetzt?" "Daten weg? Mist!" "CPU? Nix los!" "Sensor? Oh, Mann!" "Temperatur? Nada!" "Sensor? Nervig!" "CPU? Kein Plan!" "Daten? Fehlanzeige!" "Sensor? Puh!" "CPU? Verloren!" "Sensor? Argh!" "Temperatur? Hilfe!")
    elif [ $(echo "$CPU_TEMP > 60" | bc) -eq 1 ]; then
        CPU_JOKE_ARRAY=("CPU brennt! Lüfter her!" "Heisse CPU, auweia!" "CPU glüht, Hilfe!" "Lüfter, voll Gas!" "CPU wie ’ne Sauna!" "CPU heiss? Ich schmelz!" "Lüfter? Wo bist du?" "CPU kocht, aua!" "Heiss? Echt jetzt?" "CPU? Zu heiss!" "Lüfter an, schnell!" "CPU brennt? Argh!" "Sauna im Gehäuse!" "Heiss? Oh, Mann!" "CPU glüht? Puh!" "Lüfter? Echt jetzt?" "CPU? Ich schwitz!" "Heiss? So nervig!" "CPU kocht? Mist!" "Lüfter her, bitte!")
    else
        CPU_JOKE_ARRAY=("CPU cool!" "CPU chillt!" "Alles klar bei CPU!" "CPU läuft entspannt!" "CPU im grünen Bereich!" "CPU? Alles easy!" "CPU kalt, nice!" "CPU? Kein Stress!" "CPU? Alles gut!" "Kühl? Na, super!" "CPU? Relax!" "Alles klar? Yep!" "CPU? Chillen!" "Kalt? Perfekt!" "CPU? No Problem!" "Cool? Oh, yeah!" "CPU? Entspannt!" "Kühl? Echt nice!" "CPU? Alles klar!" "CPU? Null Stress!")
    fi
    CPU_JOKE=${CPU_JOKE_ARRAY[$((RANDOM % ${#CPU_JOKE_ARRAY[@]}))]}
else
    CPU_TEMP="N/A"
    CPU_JOKE_ARRAY=("Sensor kaputt!" "Sensor weg!" "CPU? Keine Ahnung!" "Sensor schläft!" "Temperatur 404!" "Sensor? Wo bist du?" "CPU-Daten? Nope!" "Sensor tot? Argh!" "Sensor? Echt jetzt?" "Daten weg? Mist!" "CPU? Nix los!" "Sensor? Oh, Mann!" "Temperatur? Nada!" "Sensor? Nervig!" "CPU? Kein Plan!" "Daten? Fehlanzeige!" "Sensor? Puh!" "CPU? Verloren!" "Sensor? Argh!" "Temperatur? Hilfe!")
    CPU_JOKE=${CPU_JOKE_ARRAY[$((RANDOM % ${#CPU_JOKE_ARRAY[@]}))]}
fi

# CPU-Warnungssymbol
if [ "$CPU_TEMP" != "N/A" ] && [ $(echo "$CPU_TEMP > 60" | bc) -eq 1 ]; then
    CPU_TEMP_STR="CPU: $CPU_TEMP°C ⚠️"
else
    CPU_TEMP_STR="CPU: $CPU_TEMP°C"
fi

# --- 3. Wetter von Open-Meteo (Hamburg: 53.350000, 10.030000) ---
WEATHER_URL="https://api.open-meteo.com/v1/forecast?latitude=53.350000&longitude=10.030000¤t=temperature_2m,weathercode,wind_speed_10m"
WEATHER=$(curl -s --connect-timeout 3 --retry 2 "$WEATHER_URL" 2>>"$DEBUG_FILE" || echo "ERROR")
if [ "$DEBUG" -eq 1 ]; then
    echo "[$TIMESTAMP] API Response: $WEATHER" >> "$DEBUG_FILE"
fi
if [ "$WEATHER" = "ERROR" ] || [ -z "$WEATHER" ] || ! echo "$WEATHER" | jq . >/dev/null 2>&1; then
    CURRENT_TEMP="N/A"
    WEATHER_CODE="99"
    WIND_SPEED="0"
    WEATHER_EMOJI="🌐"
    SWEAT_EMOJI=""
    WEATHER_JOKE_ARRAY=("Kein Netz! Mist!" "Wetter offline!" "Internet weg!" "Daten im Wind!" "Netz? Fehlanzeige!" "Kein Signal? Argh!" "WLAN tot? Echt?" "Netz weg, ich heul!" "Internet? Nope!" "Signal? Fehlanzeige!" "Netz tot? Boah!" "WLAN? Oh, Mann!" "Kein Netz? Puh!" "Daten weg? Mist!" "Internet? Argh!" "Signal? Nada!" "Netz? Echt jetzt?" "WLAN? Kaputt!" "Kein Netz? Nervig!" "Internet? Hilfe!")
    WEATHER_JOKE=${WEATHER_JOKE_ARRAY[$((RANDOM % ${#WEATHER_JOKE_ARRAY[@]}))]}
    HARDWARE_JOKE=""
    TEMP_BASE="Hamburg: $CURRENT_TEMP°C"
else
    CURRENT_TEMP=$(echo "$WEATHER" | jq '.current.temperature_2m' 2>/dev/null || echo "N/A")
    WEATHER_CODE=$(echo "$WEATHER" | jq '.current.weathercode' 2>/dev/null || echo "99")
    WIND_SPEED=$(echo "$WEATHER" | jq '.current.wind_speed_10m' 2>/dev/null || echo "0")
    if [ "$DEBUG" -eq 1 ]; then
        echo "[$TIMESTAMP] Wettercode: $WEATHER_CODE, Windgeschwindigkeit: $WIND_SPEED km/h" >> "$DEBUG_FILE"
    fi
    TEMP_BASE="Hamburg: $CURRENT_TEMP°C"
    if [ "$CURRENT_TEMP" != "N/A" ]; then
        if [ $(echo "$CURRENT_TEMP > 36" | bc) -eq 1 ]; then
            SWEAT_EMOJI="🥵"
            HARDWARE_JOKE_ARRAY=("Lüfter schreit um Hilfe!" "CPU will ’nen Eiswürfel!" "Board kocht, aua!" "Chip brutzelt, Hilfe!" "Lüfter? Vollgas!" "CPU? Sauna-Modus!" "RAM glüht, Puh!" "Board? Heiss wie Lava!" "Chip? Schmelz-Alarm!" "CPU kocht Bits!" "Lüfter? Echt jetzt?" "Board? Zu heiss!" "CPU? Ich brenn!" "RAM? Sommerhitze!" "Chip? Feueralarm!" "Lüfter, rette mich!" "CPU? Im Ofen!" "Board schmilzt fast!" "RAM? Zu heiss!" "Chip? Hitzewelle!")
            HARDWARE_JOKE=${HARDWARE_JOKE_ARRAY[$((RANDOM % ${#HARDWARE_JOKE_ARRAY[@]}))]}
        elif [ $(echo "$CURRENT_TEMP >= 30" | bc) -eq 1 ]; then
            SWEAT_EMOJI="🌞"
            HARDWARE_JOKE_ARRAY=("Lüfter heult laut!" "CPU schwitzt Bits!" "Board? Heiss, Mann!" "Chip? Zu warm!" "Lüfter? Turbo an!" "CPU? Hitzestress!" "RAM? Warmgelaufen!" "Board? Sommerfeeling!" "Chip? Braucht Eis!" "CPU? Puh, heiss!" "Lüfter? Voll dran!" "Board? Hitzealarm!" "RAM? Glüht leise!" "CPU? Schwitzt!" "Chip? Hitzewarnung!" "Lüfter? Schnell!" "Board? Zu warm!" "RAM? Heiss, Hilfe!" "CPU? Sommer!" "Chip? Lüfter her!")
            HARDWARE_JOKE=${HARDWARE_JOKE_ARRAY[$((RANDOM % ${#HARDWARE_JOKE_ARRAY[@]}))]}
        elif [ $(echo "$CURRENT_TEMP <= 5" | bc) -eq 1 ]; then
            SWEAT_EMOJI="🥶"
            HARDWARE_JOKE_ARRAY=("Pi heizt wie ’n Ofen!" "CPU wärmt die Platine!" "Board? Kuschelig!" "Chip? Heizt gut!" "Pi? Winterwärmer!" "CPU? Heizmodus!" "RAM? Wärmt mich!" "Board? Kuschlig kalt!" "Chip? Pi-Heizung!" "CPU? Wärmt auf!" "Pi? Heizt Hamburg!" "Board? Winterwarm!" "RAM? Heizt leise!" "CPU? Kälte? Nein!" "Chip? Wärme an!" "Pi? Heizstrahler!" "Board? Kuschlig!" "RAM? Winterheizung!" "CPU? Heizt gut!" "Chip? Pi wärmt!")
            HARDWARE_JOKE=${HARDWARE_JOKE_ARRAY[$((RANDOM % ${#HARDWARE_JOKE_ARRAY[@]}))]}
        else
            SWEAT_EMOJI=""
            if [ $(echo "$CURRENT_TEMP >= 20" | bc) -eq 1 ]; then
                SWEAT_EMOJI="🕶️"
            elif [ $(echo "$CURRENT_TEMP >= 10" | bc) -eq 1 ]; then
                SWEAT_EMOJI="😊"
            elif [ $(echo "$CURRENT_TEMP >= 0" | bc) -eq 1 ]; then
                SWEAT_EMOJI="🥶"
            else
                SWEAT_EMOJI="❄️"
            fi
            HARDWARE_JOKE=""
        fi
    else
        SWEAT_EMOJI=""
        HARDWARE_JOKE=""
    fi
    if [ "$WIND_SPEED" != "0" ] && [ $(echo "$WIND_SPEED >= 40" | bc) -eq 1 ]; then
        WEATHER_EMOJI="💨"
        HARDWARE_JOKE_ARRAY=("Antenne wackelt im Wind!" "Wind? Antenne hält’s aus!" "Antenne? Sturm-Tanz!" "CPU? Windresistenz!" "Board? Wackelt im Sturm!" "Chip? Wind-Alarm!" "Antenne? Festhalten!" "RAM? Windböen!" "CPU? Sturm-Panik!" "Board? Windangst!" "Antenne? Wildes Spiel!" "Chip? Sturmmodus!" "RAM? Wackelt mit!" "CPU? Wind, Hilfe!" "Board? Sturm-Party!" "Antenne? Wind-Twist!" "Chip? Wind-Chaos!" "RAM? Sturm-Schock!" "CPU? Windfrei!" "Antenne? Sturm-Spin!")
        HARDWARE_JOKE=${HARDWARE_JOKE_ARRAY[$((RANDOM % ${#HARDWARE_JOKE_ARRAY[@]}))]}
    elif [ "$WEATHER_CODE" -eq 95 ] || [ "$WEATHER_CODE" -eq 96 ] || [ "$WEATHER_CODE" -eq 99 ]; then
        WEATHER_EMOJI="⚡️"
        HARDWARE_JOKE_ARRAY=("Blitz? Antenne duckt sich!" "Antenne? Gewitter-Panik!" "CPU? Blitzschock!" "Board? Donner, Hilfe!" "Chip? Gewitter-Alarm!" "Antenne? Blitz-Tanz!" "RAM? Donner-Schreck!" "CPU? Versteck dich!" "Board? Blitzangst!" "Chip? Blitz-Chaos!" "Antenne? Gewitter-Wackeln!" "CPU? Blitz, aua!" "RAM? Gewitter-Vibes!" "Board? Donner-Panik!" "Chip? Blitz-Alarm!" "Antenne? Donner-Twist!" "CPU? Gewitter-Funkeln!" "RAM? Blitz-Schock!" "Board? Gewitter-Party!" "Antenne? Blitz-Spin!")
        HARDWARE_JOKE=${HARDWARE_JOKE_ARRAY[$((RANDOM % ${#HARDWARE_JOKE_ARRAY[@]}))]}
    elif [ -z "$HARDWARE_JOKE" ]; then
        if [ "$CURRENT_TEMP" != "N/A" ] && [ $(echo "$CURRENT_TEMP > 30" | bc) -eq 1 ] && [ "$WEATHER_CODE" -le 1 ]; then
            WEATHER_EMOJI="☀️"
            WEATHER_JOKE_ARRAY=("Sonne! Sommerfeeling!" "Blauer Himmel, yeah!" "Sonnenbrille raus!" "Sonne lacht, nice!" "Hamburg glitzert!" "Puh, Sonne? Zu hell!" "Endlich mal Sonne!" "Sonne? Na gut, ok!" "Sonne brennt, aua!" "Zu viel Sonne, echt?" "Sonne? Ich blend!" "Klarer Himmel? Puh!" "Sonne, mach Pause!" "Strahlen? Oh, Mann!" "Sonne? Zu heiss!" "Himmel klar? Argh!" "Sonne, chill mal!" "Zu hell da draussen!" "Sonne? Echt jetzt?" "Blauer Himmel? Boah!")
        else
            case $WEATHER_CODE in
                0) WEATHER_EMOJI="☀️"
                   WEATHER_JOKE_ARRAY=("Sonne! Sommerfeeling!" "Blauer Himmel, yeah!" "Sonnenbrille raus!" "Sonne lacht, nice!" "Hamburg glitzert!" "Puh, Sonne? Zu hell!" "Endlich mal Sonne!" "Sonne? Na gut, ok!" "Sonne brennt, aua!" "Zu viel Sonne, echt?" "Sonne? Ich blend!" "Klarer Himmel? Puh!" "Sonne, mach Pause!" "Strahlen? Oh, Mann!" "Sonne? Zu heiss!" "Himmel klar? Argh!" "Sonne, chill mal!" "Zu hell da draussen!" "Sonne? Echt jetzt?" "Blauer Himmel? Boah!");;
                1|2|3) WEATHER_EMOJI="☁️"
                        WEATHER_JOKE_ARRAY=("Wolken? Grau hier!" "Himmel halb voll!" "Mal Sonne, mal nicht!" "Wolkenparade!" "Grau, aber gemütlich!" "Schon wieder Wolken?" "Wolken, echt jetzt?" "Himmel, entscheide dich!" "Grau? Langweilig!" "Wolken? Nervig!" "Mal klar, mal grau?" "Wolken? Oh, nein!" "Himmel, was los?" "Grau? Echt jetzt?" "Wolken, geht weg!" "Mal Sonne? Bitte!" "Himmel, mach klar!" "Wolken? So öde!" "Grau? Ich heul!" "Wolken? Argh!");;
                45|48) WEATHER_EMOJI="🌫️"
                       WEATHER_JOKE_ARRAY=("Nebel? Wo bin ich?" "Alles verschwommen!" "Nebel-Superman!" "Sichtweite null!" "Nebel wie im Film!" "Nebel? Ich seh nix!" "Nebel, echt nervig!" "Wo ist der Himmel?" "Nebel? Echt jetzt?" "Sicht weg? Argh!" "Nebel, verschwinde!" "Alles grau? Boah!" "Nebel? Oh, Mann!" "Wo geht’s lang?" "Nebel? So ätzend!" "Sicht null? Puh!" "Nebel, echt lästig!" "Himmel weg? Mist!" "Nebel? Ich geb auf!" "Wo bin ich? Hilfe!");;
                61|63|65) WEATHER_EMOJI="🌧️"
                          WEATHER_JOKE_ARRAY=("Regen? Schirm her!" "Nass da draussen!" "Platsch, nass!" "Regen tanzt!" "Gummistiefel an!" "Schon wieder Regen?" "Regen? Echt jetzt?" "Nass? Oh, Mann!" "Wasser? Ich rust!" "Regen, hör auf!" "Nass? So ätzend!" "Schirm? Wo ist er?" "Regen? Argh!" "Platsch? Echt jetzt?" "Nasses Hamburg?" "Regen? Ich heul!" "Wasser überall!" "Schirm her, schnell!" "Regen? So nervig!" "Nass? Puh, Mist!");;
                71|73|75) WEATHER_EMOJI="❄️"
                          WEATHER_JOKE_ARRAY=("Brr, CPU wärmt mich!" "Schnee! Kalt hier!" "Winter is coming!" "Schneeflocken-Party!" "Frostig, brr!" "Schnee? Mir ist kalt!" "Schnee, echt jetzt?" "Kälte? I bibber!" "Schnee? Oh, nein!" "Frost? Echt lästig!" "Schnee? Argh!" "Kalt? Ich frier!" "Winter? So kalt!" "Schnee? Puh, kalt!" "Frost? Nervig!" "Schnee, geh weg!" "Kälte? Hilfe!" "Schnee? Zu viel!" "Winter? Boah!" "Brr, zu kalt!");;
                *) WEATHER_EMOJI="🤔"
                   WEATHER_JOKE_ARRAY=("Wetter? Rätsel!" "Wetter? Rätsel!" "Wetter? Rätsel!" "Wetter? Rätsel!" "Wetter? Rätsel!" "Wetter? Rätsel!" "Wetter? Rätsel!" "Wetter? Rätsel!" "Wetter? Rätsel!" "Wetter? Rätsel!" "Wetter? Rätsel!" "Wetter? Rätsel!" "Wetter? Rätsel!" "Wetter? Rätsel!" "Wetter? Rätsel!" "Wetter? Rätsel!" "Wetter? Rätsel!" "Wetter? Rätsel!" "Wetter? Rätsel!" "Wetter? Rätsel!");;
            esac
            WEATHER_JOKE=${WEATHER_JOKE_ARRAY[$((RANDOM % ${#WEATHER_JOKE_ARRAY[@]}))]}
        fi
    else
        WEATHER_JOKE=$HARDWARE_JOKE
    fi
fi

# --- 4. Temperaturtrend ---
if [ "$CURRENT_TEMP" != "N/A" ] && [ -f "$LAST_TEMP_FILE" ]; then
    LAST_TEMP=$(cat "$LAST_TEMP_FILE")
    TEMP_DIFF=$(echo "$CURRENT_TEMP - $LAST_TEMP" | bc)
    if [ $(echo "$TEMP_DIFF > 0.5" | bc) -eq 1 ]; then
        TREND="↑"
        TREND_JOKE_ARRAY=("Heisser wird’s!" "Wärme rauf!" "Sommer kommt!" "Temperatur hoch!" "Aufheizen, los!" "Wird heisser? Puh!" "Wärme? Oh, Mann!" "Sommer-Alarm!" "Heiss? Echt jetzt?" "Temperatur rauf?" "Wärme? Argh!" "Sommer? Boah!" "Heisser? Nervig!" "Aufheizen? Mist!" "Wärme? Zu viel!" "Sommer? Hilfe!" "Heiss? So ätzend!" "Temperatur? Puh!" "Wärme rauf? Argh!" "Heisser? Oh, nein!")
        TREND_JOKE=${TREND_JOKE_ARRAY[$((RANDOM % ${#TREND_JOKE_ARRAY[@]}))]}
    elif [ $(echo "$TEMP_DIFF < -0.5" | bc) -eq 1 ]; then
        TREND="↓"
        TREND_JOKE_ARRAY=("Kühler wird’s!" "Abkühlung, nice!" "Kälte naht!" "Temperatur runter!" "Frost-Alarm!" "Kälter? Brr!" "Abkühlen? Gut!" "Kälte? Oh, nein!" "Kühler? Echt jetzt?" "Frost? Nervig!" "Kälte? Puh!" "Abkühlen? Yeah!" "Kälter? Argh!" "Frost? Oh, Mann!" "Kühle? Boah!" "Kälte? Hilfe!" "Temperatur runter?" "Kälter? So kalt!" "Abkühlen? Nice!" "Frost? Echt jetzt?")
        TREND_JOKE=${TREND_JOKE_ARRAY[$((RANDOM % ${#TREND_JOKE_ARRAY[@]}))]}
    else
        TREND=""
        TREND_JOKE=""
    fi
else
    TREND=""
    TREND_JOKE=""
fi
[ "$CURRENT_TEMP" != "N/A" ] && echo "$CURRENT_TEMP" > "$LAST_TEMP_FILE"

# --- 5. Zufällige witzige Laune (100 % für Nacht, Wochenende, Montag vormittag) ---
if [ "$LAUNE_STATE" = "Nacht" ]; then
    LAUNE_ARRAY=("Nachtschicht! Argh!" "Sterne gucken? Puh!" "Licht aus, bitte!" "Schlummerzeit? Echt?" "Mond an, los!" "Nacht? So müde!" "Sterne? Na gut!" "Schlafen? Nein!" "Dunkel? Oh, Mann!" "Nacht? Echt jetzt?" "Mond? Zu hell!" "Dunkel? Nervig!" "Sterne? Boah!" "Nacht? Ich heul!" "Schlaf? So ätzend!" "Mond? Na, toll!" "Dunkel? Hilfe!" "Nacht? Zzz..." "Sterne? Chill mal!" "Licht aus? Los!")
    LAUNE_EMOJI="😴"
elif [ "$LAUNE_STATE" = "Wochenende" ]; then
    LAUNE_ARRAY=("Chill-Modus! Yeah!" "Partyzeit! Los!" "Sofa ruft! Nice!" "Wochenende? Cool!" "Entspann dich!" "Faul sein? Nice!" "Frei? Endlich!" "Ruhe, bitte!" "Sofa? Oh, yeah!" "Chill? Na, super!" "Party? Argh!" "Frei? Echt jetzt?" "Ruhe? Ja, bitte!" "Sofa? Nervig!" "Wochenende? Puh!" "Chill? Boah!" "Frei? So nice!" "Entspann? Los!" "Sofa? Echt jetzt?" "Party? Oh, Mann!")
    LAUNE_EMOJI="🎉"
elif [ "$LAUNE_STATE" = "MontagVormittag" ]; then
    LAUNE_ARRAY=("Montag? Kaffee her!" "Wochenstart? Argh!" "Müde? Echt jetzt?" "Kaffee? Schnell!" "Montag? Oh, nein!" "Müdigkeit? Hilfe!" "Wochenanfang? Puh!" "Kaffee? Brauch ich!" "Montag? So ätzend!" "Müde? Boah!" "Start? Nervig!" "Kaffee? Jetzt!" "Montag? Ich heul!" "Wochenstart? Mist!" "Müde? Zu früh!" "Kaffee? Oh, Mann!" "Montag? Langweilig!" "Wochenanfang? Boah!" "Müde? Na, toll!" "Start? Echt jetzt?")
    LAUNE_EMOJI="☕"
else
    LAUNE=""
    LAUNE_EMOJI=""
fi
if [ -n "$LAUNE" ]; then
    LAUNE=${LAUNE_ARRAY[$((RANDOM % ${#LAUNE_ARRAY[@]}))]}
fi

# --- 6. Nachricht zusammenstellen ---
if [ -n "$HARDWARE_JOKE" ]; then
    WEATHER_JOKE=$HARDWARE_JOKE
fi
MESSAGE="[$UHRZEIT] $LAUNE_EMOJI $LAUNE $WEATHER_EMOJI $TEMP_BASE $TREND $SWEAT_EMOJI $TREND_JOKE - $WEATHER_JOKE [$CPU_TEMP_STR 🔥 $CPU_JOKE]"

# Zeichenanzahl prüfen (<200 für Meshtastic)
MESSAGE_LENGTH=${#MESSAGE}
if [ $MESSAGE_LENGTH -gt 200 ]; then
    MESSAGE="[$UHRZEIT] $WEATHER_EMOJI $TEMP_BASE, $CPU_TEMP_STR - $WEATHER_JOKE"
fi

# --- 7. Meshtastic senden (Main Channel, Index 0) ---
if ! meshtastic --port "$MESHTASTIC_PORT" --sendtext "$MESSAGE" 2>>"$DEBUG_FILE"; then
    echo "[$TIMESTAMP] Fehler beim Senden (Port: $MESHTASTIC_PORT, Länge: ${#MESSAGE})" >> "$LOG_FILE"
fi

# --- 8. Logging ---
echo "[$TIMESTAMP] $MESSAGE" >> "$LOG_FILE"

# Ende
exit 0
