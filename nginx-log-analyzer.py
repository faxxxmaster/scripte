#!/usr/bin/env python3
"""
nginx Access Log Analyzer - Multi-Log & Time-Filter Version
Analysiert mehrere nginx access.log Dateien mit Zeitfilter-Optionen

LOG-DATEIEN:
============
/var/log/nginx/start_access.log
/var/log/nginx/wiki_access.log
/var/log/nginx/pad_access.log
/var/log/nginx/immich_access.log
/var/log/nginx/bilder_access.log

ZEITFILTER: heute | diese_woche | dieser_monat | gesamter_zeitraum

Beispiele :

# Einzelne Log-Datei, heute
python3 nginx_access_log_analyzer.py start --zeit heute

# Mehrere Logs, diese Woche
python3 nginx_access_log_analyzer.py start wiki pad --zeit diese_woche

# Alle Logs, dieser Monat mit CSV-Export
python3 nginx_access_log_analyzer.py alle --zeit dieser_monat --csv

# Spezifische Logs, gesamter Zeitraum
python3 nginx_access_log_analyzer.py immich bilder --zeit gesamter_zeitraum

# Hilfe anzeigen
python3 nginx_access_log_analyzer.py --help

gerne auch mit : watch -n 1

"""

import re
import sys
import argparse
from collections import Counter, defaultdict
from datetime import datetime, timedelta, date
import ipaddress
import os

# KONFIGURATION - LOG-DATEIEN
LOG_FILES = {
    'start': '/var/log/nginx/start_access.log',
    'wiki': '/var/log/nginx/wiki_access.log',
    'pad': '/var/log/nginx/pad_access.log',
    'immich': '/var/log/nginx/immich_access.log',
    'bilder': '/var/log/nginx/bilder_access.log'
}

class NginxLogAnalyzer:
    def __init__(self, log_files, time_filter='gesamter_zeitraum'):
        self.log_files = log_files if isinstance(log_files, list) else [log_files]
        self.time_filter = time_filter
        self.entries = []
        self.stats = {
            'total_requests': 0,
            'unique_ips': set(),
            'status_codes': Counter(),
            'methods': Counter(),
            'top_pages': Counter(),
            'top_ips': Counter(),
            'user_agents': Counter(),
            'hourly_traffic': defaultdict(int),
            'daily_traffic': defaultdict(int),
            'bytes_transferred': 0,
            'bot_requests': Counter(),
            'error_requests': [],
            'suspicious_ips': Counter(),
            'log_file_stats': defaultdict(lambda: {'requests': 0, 'unique_ips': set()})
        }

        # Zeitfilter berechnen
        self.time_range = self._calculate_time_range()

        # Regex für nginx combined log format
        self.log_pattern = re.compile(
            r'(?P<ip>\S+) - - \[(?P<time>[^\]]+)\] "(?P<method>\S+) (?P<path>\S+) (?P<protocol>\S+)" '
            r'(?P<status>\d+) (?P<size>\d+|-) "(?P<referrer>[^"]*)" "(?P<user_agent>[^"]*)"'
        )

        # Bot User-Agent Patterns
        self.bot_patterns = [
            r'bot', r'crawler', r'spider', r'scraper', r'wget', r'curl',
            r'python', r'java', r'php', r'ruby', r'go-http-client'
        ]

    def _calculate_time_range(self):
        """Berechnet den Zeitbereich basierend auf dem Filter"""
        now = datetime.now()
        today = now.date()

        if self.time_filter == 'heute':
            start_time = datetime.combine(today, datetime.min.time())
            end_time = now
        elif self.time_filter == 'diese_woche':
            # Montag als Wochenbeginn
            days_since_monday = today.weekday()
            monday = today - timedelta(days=days_since_monday)
            start_time = datetime.combine(monday, datetime.min.time())
            end_time = now
        elif self.time_filter == 'dieser_monat':
            start_time = datetime(now.year, now.month, 1)
            end_time = now
        else:  # gesamter_zeitraum
            start_time = None
            end_time = None

        return (start_time, end_time)

    def _is_in_time_range(self, entry_time):
        """Prüft ob ein Log-Eintrag im gewählten Zeitbereich liegt"""
        if self.time_range[0] is None:  # gesamter_zeitraum
            return True

        try:
            # Format: 10/Oct/2000:13:55:36 +0000
            dt = datetime.strptime(entry_time.split()[0], '%d/%b/%Y:%H:%M:%S')
            return self.time_range[0] <= dt <= self.time_range[1]
        except ValueError:
            return False

    def parse_log_files(self):
        """Parse alle angegebenen Log-Dateien"""
        print(f"\n🔍 NGINX LOG ANALYZER - Zeitfilter: {self.time_filter.upper()}")
        print("="*80)

        total_processed = 0

        for log_file in self.log_files:
            if not os.path.exists(log_file):
                print(f"❌ Datei nicht gefunden: {log_file}")
                continue

            print(f"\n📁 Analysiere: {log_file}")
            file_entries = 0

            try:
                with open(log_file, 'r', encoding='utf-8', errors='ignore') as f:
                    for line_num, line in enumerate(f, 1):
                        match = self.log_pattern.match(line.strip())
                        if match:
                            entry = match.groupdict()
                            entry['source_file'] = os.path.basename(log_file)

                            # Zeitfilter anwenden
                            if self._is_in_time_range(entry['time']):
                                self.entries.append(entry)
                                self._update_stats(entry)
                                file_entries += 1

                total_processed += file_entries
                print(f"   ✓ {file_entries:,} Einträge (im Zeitraum) verarbeitet")

            except Exception as e:
                print(f"   ❌ Fehler beim Lesen: {e}")
                continue

        print(f"\n✅ Gesamt verarbeitet: {total_processed:,} Log-Einträge")
        return total_processed > 0

    def _update_stats(self, entry):
        """Aktualisiert die Statistiken für einen Log-Eintrag"""
        self.stats['total_requests'] += 1
        source_file = entry['source_file']

        # Per-File Statistiken
        self.stats['log_file_stats'][source_file]['requests'] += 1
        self.stats['log_file_stats'][source_file]['unique_ips'].add(entry['ip'])

        # IP-Adressen
        ip = entry['ip']
        self.stats['unique_ips'].add(ip)
        self.stats['top_ips'][ip] += 1

        # Status Codes
        status = int(entry['status'])
        self.stats['status_codes'][status] += 1

        # HTTP Methods
        self.stats['methods'][entry['method']] += 1

        # Seiten/Pfade
        path = entry['path']
        self.stats['top_pages'][path] += 1

        # User Agents
        user_agent = entry['user_agent']
        self.stats['user_agents'][user_agent] += 1

        # Bytes transferred
        size = entry['size']
        if size != '-':
            self.stats['bytes_transferred'] += int(size)

        # Zeit-basierte Statistiken
        try:
            time_str = entry['time']
            dt = datetime.strptime(time_str.split()[0], '%d/%b/%Y:%H:%M:%S')

            hour = dt.hour
            date_str = dt.date().strftime('%Y-%m-%d')

            self.stats['hourly_traffic'][hour] += 1
            self.stats['daily_traffic'][date_str] += 1

        except ValueError:
            pass

        # Bot Detection
        if self._is_bot(user_agent):
            self.stats['bot_requests'][ip] += 1

        # Error Requests (4xx, 5xx)
        if status >= 400:
            self.stats['error_requests'].append({
                'ip': ip,
                'status': status,
                'path': path,
                'time': entry['time'],
                'user_agent': user_agent,
                'source': source_file
            })

        # Suspicious Activity Detection
        if self._is_suspicious(entry):
            self.stats['suspicious_ips'][ip] += 1

    def _is_bot(self, user_agent):
        """Prüft ob User-Agent ein Bot ist"""
        user_agent_lower = user_agent.lower()
        return any(re.search(pattern, user_agent_lower) for pattern in self.bot_patterns)

    def _is_suspicious(self, entry):
        """Erkennt verdächtige Aktivitäten"""
        suspicious_patterns = [
            r'\.php$', r'\.asp$', r'\.jsp$',  # Script-Dateien
            r'wp-admin', r'wp-login',          # WordPress Angriffe
            r'admin', r'login', r'config',     # Admin-Bereiche
            r'\.env', r'\.git',               # Sensible Dateien
            r'eval\(', r'base64_decode',      # Code-Injection
        ]

        path = entry['path']
        return any(re.search(pattern, path) for pattern in suspicious_patterns)

    def format_bytes(self, bytes_count):
        """Formatiert Bytes in lesbare Einheiten"""
        for unit in ['B', 'KB', 'MB', 'GB', 'TB']:
            if bytes_count < 1024.0:
                return f"{bytes_count:.2f} {unit}"
            bytes_count /= 1024.0
        return f"{bytes_count:.2f} PB"

    def get_time_filter_description(self):
        """Gibt Beschreibung des Zeitfilters zurück"""
        if self.time_filter == 'heute':
            return f"Heute ({date.today().strftime('%d.%m.%Y')})"
        elif self.time_filter == 'diese_woche':
            today = date.today()
            monday = today - timedelta(days=today.weekday())
            return f"Diese Woche (ab {monday.strftime('%d.%m.%Y')})"
        elif self.time_filter == 'dieser_monat':
            today = date.today()
            return f"Dieser Monat ({today.strftime('%B %Y')})"
        else:
            return "Gesamter Zeitraum"

    def print_report(self):
        """Gibt einen detaillierten Bericht aus"""
        print("\n" + "="*80)
        print(f"NGINX MULTI-LOG ANALYSE - {self.get_time_filter_description().upper()}")
        print("="*80)

        # Log-Dateien Übersicht
        if len(self.log_files) > 1:
            print(f"\n📁 ANALYSIERTE LOG-DATEIEN:")
            for source_file, stats in self.stats['log_file_stats'].items():
                unique_ips = len(stats['unique_ips'])
                print(f"   {source_file:<25} {stats['requests']:>8,} requests, {unique_ips:>6,} unique IPs")

        # Grundlegende Statistiken
        print(f"\n📊 GRUNDSTATISTIKEN ({self.get_time_filter_description()}):")
        print(f"   Gesamte Requests: {self.stats['total_requests']:,}")
        print(f"   Eindeutige IPs: {len(self.stats['unique_ips']):,}")
        print(f"   Datenübertragung: {self.format_bytes(self.stats['bytes_transferred'])}")
        print(f"   Bot-Requests: {sum(self.stats['bot_requests'].values()):,}")
        print(f"   Fehler-Requests: {len(self.stats['error_requests']):,}")

        # Nur relevante Abschnitte anzeigen wenn Daten vorhanden
        if not self.stats['total_requests']:
            print(f"\n❌ Keine Daten für Zeitraum '{self.time_filter}' gefunden!")
            return

        # Top IPs
        print(f"\n🌐 TOP 10 IP-ADRESSEN:")
        for ip, count in self.stats['top_ips'].most_common(10):
            percentage = (count / self.stats['total_requests']) * 100
            print(f"   {ip:<15} {count:>8,} requests ({percentage:>5.1f}%)")

        # Status Codes
        print(f"\n📈 HTTP STATUS CODES:")
        for status, count in sorted(self.stats['status_codes'].items()):
            percentage = (count / self.stats['total_requests']) * 100
            status_text = self._get_status_text(status)
            print(f"   {status} {status_text:<20} {count:>8,} ({percentage:>5.1f}%)")

        # HTTP Methods
        print(f"\n🔧 HTTP METHODS:")
        for method, count in self.stats['methods'].most_common():
            percentage = (count / self.stats['total_requests']) * 100
            print(f"   {method:<8} {count:>8,} ({percentage:>5.1f}%)")

        # Top Pages
        print(f"\n📄 TOP 10 AUFGERUFENE SEITEN:")
        for path, count in self.stats['top_pages'].most_common(10):
            percentage = (count / self.stats['total_requests']) * 100
            path_display = path[:50] + "..." if len(path) > 50 else path
            print(f"   {count:>6,} ({percentage:>5.1f}%) {path_display}")

        # Hourly Traffic (nur wenn relevant)
        if self.time_filter in ['heute', 'diese_woche']:
            print(f"\n⏰ TRAFFIC NACH STUNDEN:")
            for hour in range(24):
                count = self.stats['hourly_traffic'][hour]
                if count > 0:
                    percentage = (count / self.stats['total_requests']) * 100
                    bar = "█" * min(int(percentage), 50)
                    print(f"   {hour:>2}:00 {count:>6,} {bar} ({percentage:>5.1f}%)")

        # Daily Traffic
        if self.stats['daily_traffic']:
            days_to_show = 7 if self.time_filter != 'heute' else 1
            print(f"\n📅 TRAFFIC NACH TAGEN (letzte {days_to_show}):")
            for date_str, count in sorted(self.stats['daily_traffic'].items())[-days_to_show:]:
                percentage = (count / self.stats['total_requests']) * 100
                print(f"   {date_str} {count:>8,} ({percentage:>5.1f}%)")

        # Top User Agents
        print(f"\n🤖 TOP 5 USER AGENTS:")
        for ua, count in self.stats['user_agents'].most_common(5):
            percentage = (count / self.stats['total_requests']) * 100
            ua_display = ua[:70] + "..." if len(ua) > 70 else ua
            print(f"   {count:>6,} ({percentage:>5.1f}%) {ua_display}")

        # Bot Traffic
        if self.stats['bot_requests']:
            print(f"\n🕷️  TOP BOT IPs:")
            for ip, count in self.stats['bot_requests'].most_common(5):
                print(f"   {ip:<15} {count:>6,} bot requests")

        # Suspicious Activity
        if self.stats['suspicious_ips']:
            print(f"\n⚠️  VERDÄCHTIGE IPs:")
            for ip, count in self.stats['suspicious_ips'].most_common(10):
                print(f"   {ip:<15} {count:>6,} verdächtige requests")

        # Recent Errors
        if self.stats['error_requests']:
            print(f"\n❌ LETZTE 5 FEHLER-REQUESTS:")
            for error in self.stats['error_requests'][-5:]:
                print(f"   {error['status']} {error['ip']} {error['path'][:40]} [{error['source']}]")

    def _get_status_text(self, status):
        """Gibt Beschreibung für HTTP Status Code zurück"""
        status_texts = {
            200: "OK",
            301: "Moved Permanently",
            302: "Found",
            304: "Not Modified",
            400: "Bad Request",
            401: "Unauthorized",
            403: "Forbidden",
            404: "Not Found",
            500: "Internal Server Error",
            502: "Bad Gateway",
            503: "Service Unavailable"
        }
        return status_texts.get(status, "Unknown")

    def export_csv(self, filename=None):
        """Exportiert Statistiken als CSV"""
        import csv

        if filename is None:
            timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
            filename = f"nginx_analysis_{self.time_filter}_{timestamp}.csv"

        with open(filename, 'w', newline='', encoding='utf-8') as csvfile:
            writer = csv.writer(csvfile)
            writer.writerow(['Zeitfilter', self.get_time_filter_description()])
            writer.writerow(['Analysierte Dateien', ', '.join([os.path.basename(f) for f in self.log_files])])
            writer.writerow([])
            writer.writerow(['IP', 'Requests', 'Percentage'])

            for ip, count in self.stats['top_ips'].most_common():
                percentage = (count / self.stats['total_requests']) * 100
                writer.writerow([ip, count, f"{percentage:.2f}%"])

        print(f"\n💾 CSV Export gespeichert: {filename}")

def main():
    parser = argparse.ArgumentParser(
        description='nginx Multi-Log Access Analyzer mit Zeitfilter',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""
VERFÜGBARE LOG-DATEIEN:
{chr(10).join([f"  {name}: {path}" for name, path in LOG_FILES.items()])}

ZEITFILTER:
  heute           - Nur heutige Einträge
  diese_woche     - Einträge seit Montag dieser Woche
  dieser_monat    - Einträge seit 1. des aktuellen Monats
  gesamter_zeitraum - Alle verfügbaren Einträge (Standard)

BEISPIELE:
  {sys.argv[0]} start wiki --zeit heute
  {sys.argv[0]} alle --zeit diese_woche --csv
  {sys.argv[0]} immich bilder --zeit dieser_monat
        """
    )

    parser.add_argument('logs', nargs='+',
                       choices=list(LOG_FILES.keys()) + ['alle'],
                       help='Log-Dateien zum Analysieren (oder "alle" für alle)')

    parser.add_argument('--zeit', '--time-filter',
                       choices=['heute', 'diese_woche', 'dieser_monat', 'gesamter_zeitraum'],
                       default='gesamter_zeitraum',
                       help='Zeitfilter für die Analyse (Standard: gesamter_zeitraum)')

    parser.add_argument('--csv', action='store_true',
                       help='Exportiere Ergebnisse als CSV')

    parser.add_argument('--csv-file',
                       help='CSV Dateiname (automatisch generiert wenn nicht angegeben)')

    args = parser.parse_args()

    # Log-Dateien auswählen
    if 'alle' in args.logs:
        selected_logs = list(LOG_FILES.values())
    else:
        selected_logs = [LOG_FILES[log] for log in args.logs if log in LOG_FILES]

    if not selected_logs:
        print("❌ Keine gültigen Log-Dateien ausgewählt!")
        sys.exit(1)

    # Analyzer initialisieren und ausführen
    analyzer = NginxLogAnalyzer(selected_logs, args.zeit)

    if analyzer.parse_log_files():
        analyzer.print_report()

        if args.csv:
            analyzer.export_csv(args.csv_file)
    else:
        print("❌ Keine Log-Dateien konnten verarbeitet werden!")
        sys.exit(1)

    print(f"\n✅ Analyse abgeschlossen!")

if __name__ == "__main__":
    main()
