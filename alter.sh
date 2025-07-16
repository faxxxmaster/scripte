#!/bin/bash

#gibt dein Alter in Jahrem/monaten und Tagen aus

# Hier kannst du dein Geburtsdatum direkt festlegen
geburtsdatum="1973-07-15" # Ändere dieses Datum zu deinem tatsächlichen Geburtsdatum

# Prüfen ob das Datum im korrekten Format ist
if ! [[ $geburtsdatum =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    echo "Fehler: Ungültiges Datumsformat. Bitte verwende YYYY-MM-DD."
    exit 1
fi

# Aktuelles Datum
heute=$(date +%Y-%m-%d)

# Geburtsdatum in Einzelteile zerlegen
geburts_jahr=$(echo $geburtsdatum | cut -d'-' -f1)
geburts_monat=$(echo $geburtsdatum | cut -d'-' -f2)
geburts_tag=$(echo $geburtsdatum | cut -d'-' -f3)

# Heutiges Datum in Einzelteile zerlegen
heute_jahr=$(echo $heute | cut -d'-' -f1)
heute_monat=$(echo $heute | cut -d'-' -f2)
heute_tag=$(echo $heute | cut -d'-' -f3)

# Berechnung der Jahre
jahre=$((heute_jahr - geburts_jahr))

# Überprüfen, ob der Geburtstag in diesem Jahr schon war
if [ $heute_monat -lt $geburts_monat ] || [ $heute_monat -eq $geburts_monat -a $heute_tag -lt $geburts_tag ]; then
    jahre=$((jahre - 1))
fi

# Datum vor einem Jahr vom heutigen Datum
if [ $heute_monat -lt $geburts_monat ] || [ $heute_monat -eq $geburts_monat -a $heute_tag -lt $geburts_tag ]; then
    letzter_geburtstag=$(date -d "$((heute_jahr - 1))-$geburts_monat-$geburts_tag" +%Y-%m-%d 2>/dev/null)
    if [ $? -ne 0 ]; then
        # Fallback für BSD/macOS date
        letzter_geburtstag=$(date -j -f "%Y-%m-%d" "$((heute_jahr - 1))-$geburts_monat-$geburts_tag" +%Y-%m-%d 2>/dev/null || echo "$((heute_jahr - 1))-$geburts_monat-$geburts_tag")
    fi
else
    letzter_geburtstag=$(date -d "$heute_jahr-$geburts_monat-$geburts_tag" +%Y-%m-%d 2>/dev/null)
    if [ $? -ne 0 ]; then
        # Fallback für BSD/macOS date
        letzter_geburtstag=$(date -j -f "%Y-%m-%d" "$heute_jahr-$geburts_monat-$geburts_tag" +%Y-%m-%d 2>/dev/null || echo "$heute_jahr-$geburts_monat-$geburts_tag")
    fi
fi

# Berechnung der Monate
monate=0
temp_jahr=$(echo $letzter_geburtstag | cut -d'-' -f1)
temp_monat=$(echo $letzter_geburtstag | cut -d'-' -f2)

while true; do
    temp_monat=$((temp_monat + 1))
    if [ $temp_monat -gt 12 ]; then
        temp_monat=1
        temp_jahr=$((temp_jahr + 1))
    fi
    
    vergleich_datum="$temp_jahr-$(printf "%02d" $temp_monat)-$(printf "%02d" $geburts_tag)"
    
    # Überprüfen, ob der Tag im aktuellen Monat gültig ist
    if [ $geburts_tag -gt $(date -d "$temp_jahr-$temp_monat-01 +1 month -1 day" +%d 2>/dev/null || date -j -f "%Y-%m-%d" "$temp_jahr-$temp_monat-01" -v+1m -v-1d +%d 2>/dev/null || echo "31") ]; then
        # Letzter Tag des Monats verwenden
        vergleich_datum="$temp_jahr-$(printf "%02d" $temp_monat)-$(date -d "$temp_jahr-$temp_monat-01 +1 month -1 day" +%d 2>/dev/null || date -j -f "%Y-%m-%d" "$temp_jahr-$temp_monat-01" -v+1m -v-1d +%d 2>/dev/null || echo "31")"
    fi
    
    if [[ "$vergleich_datum" > "$heute" ]]; then
        break
    fi
    
    monate=$((monate + 1))
done

# Berechnung der Tage mit Berücksichtigung von Schaltjahren
# Datum des letzten Monats-Geburtstags finden
if [ $monate -eq 0 ]; then
    monats_geburtstag=$letzter_geburtstag
else
    temp_jahr=$(echo $letzter_geburtstag | cut -d'-' -f1)
    temp_monat=$(echo $letzter_geburtstag | cut -d'-' -f2)
    
    for ((i=1; i<=monate; i++)); do
        temp_monat=$((temp_monat + 1))
        if [ $temp_monat -gt 12 ]; then
            temp_monat=1
            temp_jahr=$((temp_jahr + 1))
        fi
    done
    
    tag_im_monat=$geburts_tag
    tage_im_monat=$(date -d "$temp_jahr-$temp_monat-01 +1 month -1 day" +%d 2>/dev/null || date -j -f "%Y-%m-%d" "$temp_jahr-$temp_monat-01" -v+1m -v-1d +%d 2>/dev/null || echo "31")
    
    if [ $tag_im_monat -gt $tage_im_monat ]; then
        tag_im_monat=$tage_im_monat
    fi
    
    monats_geburtstag="$temp_jahr-$(printf "%02d" $temp_monat)-$(printf "%02d" $tag_im_monat)"
fi

# Tage seit dem letzten Monats-Geburtstag berechnen
tage=$(( ($(date -d "$heute" +%s) - $(date -d "$monats_geburtstag" +%s)) / 86400 ))

# Kompatibilität mit BSD/macOS
if [ $? -ne 0 ]; then
    # Für BSD/macOS date berechnen
    heute_sekunden=$(date -j -f "%Y-%m-%d" "$heute" +%s 2>/dev/null)
    monats_sek=$(date -j -f "%Y-%m-%d" "$monats_geburtstag" +%s 2>/dev/null)
    
    if [ -n "$heute_sekunden" ] && [ -n "$monats_sek" ]; then
        tage=$(( (heute_sekunden - monats_sek) / 86400 ))
    else
        # Einfache Fallback-Berechnung ohne Schaltjahre
        heute_year=$(echo $heute | cut -d'-' -f1)
        heute_month=$(echo $heute | cut -d'-' -f2)
        heute_day=$(echo $heute | cut -d'-' -f3)
        
        monats_year=$(echo $monats_geburtstag | cut -d'-' -f1)
        monats_month=$(echo $monats_geburtstag | cut -d'-' -f2)
        monats_day=$(echo $monats_geburtstag | cut -d'-' -f3)
        
        # Einfache Differenz (ungenau für Datumsberechnungen)
        tage=$(( (heute_day - monats_day) + 30 * (heute_month - monats_month) + 365 * (heute_year - monats_year) ))
        tage=$(( tage % 30 ))
    fi
fi

echo "Du bist $jahre Jahre, $monate Monate und $tage Tage alt."

# Gesamtzahl der Tage seit der Geburt berechnen (mit Berücksichtigung von Schaltjahren)
gesamt_tage=$(( ($(date -d "$heute" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$heute" +%s) - $(date -d "$geburtsdatum" +%s 2>/dev/null || date -j -f "%Y-%m-%d" "$geburtsdatum" +%s)) / 86400 ))

echo "Das entspricht insgesamt $gesamt_tage Tagen seit deiner Geburt."
