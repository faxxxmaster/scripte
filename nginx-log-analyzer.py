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
"""

import re
import sys
import argparse
from collections import Counter, defaultdict
from datetime import datetime, timedelta, date
import ipaddress
import os

# ANSI Farbcodes für Terminal-Ausgabe
class Colors:
    # Farben
    RED = '\033[91m'
    GREEN = '\033[92m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    MAGENTA = '\033[95m'
    CYAN = '\033[96m'
    WHITE = '\033[97m'
    GRAY = '\033[90m'

    # Styles
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'
    RESET = '\033[0m'

    # Kombinationen
    HEADER = BOLD + CYAN
    SUCCESS = BOLD + GREEN
    WARNING = BOLD + YELLOW
    ERROR = BOLD + RED
    INFO = BOLD + BLUE

    @staticmethod
    def colorize(text, color):
        """Färbt Text ein"""
        return f"{color}{text}{Colors.RESET}"

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
        print(f"\n{Colors.HEADER}🔍 NGINX LOG ANALYZER - Zeitfilter: {self.time_filter.upper()}{Colors.RESET}")
        print(Colors.colorize("="*80, Colors.CYAN))

        total_processed = 0

        for log_file in self.log_files:
            if not os.path.exists(log_file):
                print(f"{Colors.ERROR}❌ Datei nicht gefunden: {log_file}{Colors.RESET}")
                continue

            print(f"\n{Colors.INFO}📁 Analysiere: {Colors.RESET}{Colors.BOLD}{log_file}{Colors.RESET}")
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
                print(f"   {Colors.SUCCESS}✓ {file_entries:,} Einträge (im Zeitraum) verarbeitet{Colors.RESET}")

            except Exception as e:
                print(f"   {Colors.ERROR}❌ Fehler beim Lesen: {e}{Colors.RESET}")
                continue

        print(f"\n{Colors.SUCCESS}✅ Gesamt verarbeitet: {total_processed:,} Log-Einträge{Colors.RESET}")
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
        print(f"\n{Colors.HEADER}{'='*80}")
        print(f"NGINX MULTI-LOG ANALYSE - {self.get_time_filter_description().upper()}")
        print(f"{'='*80}{Colors.RESET}")

        # Log-Dateien Übersicht
        if len(self.log_files) > 1:
            print(f"\n{Colors.INFO}📁 ANALYSIERTE LOG-DATEIEN:{Colors.RESET}")
            for source_file, stats in self.stats['log_file_stats'].items():
                unique_ips = len(stats['unique_ips'])
                print(f"   {Colors.CYAN}{source_file:<25}{Colors.RESET} {Colors.BOLD}{stats['requests']:>8,}{Colors.RESET} requests, {Colors.YELLOW}{unique_ips:>6,}{Colors.RESET} unique IPs")

        # Grundlegende Statistiken
        print(f"\n{Colors.INFO}📊 GRUNDSTATISTIKEN ({self.get_time_filter_description()}):{Colors.RESET}")
        print(f"   {Colors.BOLD}Gesamte Requests:{Colors.RESET} {Colors.GREEN}{self.stats['total_requests']:,}{Colors.RESET}")
        print(f"   {Colors.BOLD}Eindeutige IPs:{Colors.RESET} {Colors.YELLOW}{len(self.stats['unique_ips']):,}{Colors.RESET}")
        print(f"   {Colors.BOLD}Datenübertragung:{Colors.RESET} {Colors.CYAN}{self.format_bytes(self.stats['bytes_transferred'])}{Colors.RESET}")
        print(f"   {Colors.BOLD}Bot-Requests:{Colors.RESET} {Colors.MAGENTA}{sum(self.stats['bot_requests'].values()):,}{Colors.RESET}")
        print(f"   {Colors.BOLD}Fehler-Requests:{Colors.RESET} {Colors.RED}{len(self.stats['error_requests']):,}{Colors.RESET}")

        # Nur relevante Abschnitte anzeigen wenn Daten vorhanden
        if not self.stats['total_requests']:
            print(f"\n{Colors.ERROR}❌ Keine Daten für Zeitraum '{self.time_filter}' gefunden!{Colors.RESET}")
            return

        # Top IPs
        print(f"\n{Colors.INFO}🌐 TOP 20 IP-ADRESSEN:{Colors.RESET}")
        for i, (ip, count) in enumerate(self.stats['top_ips'].most_common(20), 1):
            percentage = (count / self.stats['total_requests']) * 100
            # Farbe basierend auf Ranking
            if i <= 3:
                ip_color = Colors.RED
            elif i <= 10:
                ip_color = Colors.YELLOW
            else:
                ip_color = Colors.WHITE
            print(f"   {Colors.GRAY}{i:>2}.{Colors.RESET} {Colors.colorize(ip, ip_color):<15} {Colors.BOLD}{count:>8,}{Colors.RESET} requests ({Colors.GREEN}{percentage:>5.1f}%{Colors.RESET})")

        # Status Codes
        print(f"\n{Colors.INFO}📈 HTTP STATUS CODES:{Colors.RESET}")
        for status, count in sorted(self.stats['status_codes'].items()):
            percentage = (count / self.stats['total_requests']) * 100
            status_text = self._get_status_text(status)

            # Farbe basierend auf Status Code
            if 200 <= status < 300:
                status_color = Colors.GREEN
            elif 300 <= status < 400:
                status_color = Colors.BLUE
            elif 400 <= status < 500:
                status_color = Colors.YELLOW
            else:
                status_color = Colors.RED

            print(f"   {Colors.colorize(str(status), status_color)} {status_text:<20} {Colors.BOLD}{count:>8,}{Colors.RESET} ({Colors.GREEN}{percentage:>5.1f}%{Colors.RESET})")

        # HTTP Methods
        print(f"\n{Colors.INFO}🔧 HTTP METHODS:{Colors.RESET}")
        for method, count in self.stats['methods'].most_common():
            percentage = (count / self.stats['total_requests']) * 100
            method_color = Colors.GREEN if method == 'GET' else Colors.YELLOW if method == 'POST' else Colors.CYAN
            print(f"   {Colors.colorize(method, method_color):<8} {Colors.BOLD}{count:>8,}{Colors.RESET} ({Colors.GREEN}{percentage:>5.1f}%{Colors.RESET})")

        # Top Pages
        print(f"\n{Colors.INFO}📄 TOP 10 AUFGERUFENE SEITEN:{Colors.RESET}")
        for i, (path, count) in enumerate(self.stats['top_pages'].most_common(10), 1):
            percentage = (count / self.stats['total_requests']) * 100
            path_display = path[:50] + "..." if len(path) > 50 else path
            print(f"   {Colors.GRAY}{i:>2}.{Colors.RESET} {Colors.BOLD}{count:>6,}{Colors.RESET} ({Colors.GREEN}{percentage:>5.1f}%{Colors.RESET}) {Colors.CYAN}{path_display}{Colors.RESET}")

        # Hourly Traffic (nur wenn relevant)
        if self.time_filter in ['heute', 'diese_woche']:
            print(f"\n{Colors.INFO}⏰ TRAFFIC NACH STUNDEN:{Colors.RESET}")
            for hour in range(24):
                count = self.stats['hourly_traffic'][hour]
                if count > 0:
                    percentage = (count / self.stats['total_requests']) * 100
                    bar_length = min(int(percentage), 50)
                    bar = Colors.GREEN + "█" * bar_length + Colors.RESET
                    print(f"   {Colors.BOLD}{hour:>2}:00{Colors.RESET} {Colors.BOLD}{count:>6,}{Colors.RESET} {bar} ({Colors.GREEN}{percentage:>5.1f}%{Colors.RESET})")

        # Daily Traffic
        if self.stats['daily_traffic']:
            days_to_show = 7 if self.time_filter != 'heute' else 1
            print(f"\n{Colors.INFO}📅 TRAFFIC NACH TAGEN (letzte {days_to_show}):{Colors.RESET}")
            for date_str, count in sorted(self.stats['daily_traffic'].items())[-days_to_show:]:
                percentage = (count / self.stats['total_requests']) * 100
                print(f"   {Colors.CYAN}{date_str}{Colors.RESET} {Colors.BOLD}{count:>8,}{Colors.RESET} ({Colors.GREEN}{percentage:>5.1f}%{Colors.RESET})")

        # Top User Agents
        print(f"\n{Colors.INFO}🤖 TOP 5 USER AGENTS:{Colors.RESET}")
        for i, (ua, count) in enumerate(self.stats['user_agents'].most_common(5), 1):
            percentage = (count / self.stats['total_requests']) * 100
            ua_display = ua[:70] + "..." if len(ua) > 70 else ua
            print(f"   {Colors.GRAY}{i}.{Colors.RESET} {Colors.BOLD}{count:>6,}{Colors.RESET} ({Colors.GREEN}{percentage:>5.1f}%{Colors.RESET}) {Colors.GRAY}{ua_display}{Colors.RESET}")

        # Bot Traffic
        if self.stats['bot_requests']:
            print(f"\n{Colors.WARNING}🕷️  TOP BOT IPs:{Colors.RESET}")
            for ip, count in self.stats['bot_requests'].most_common(5):
                print(f"   {Colors.MAGENTA}{ip:<15}{Colors.RESET} {Colors.BOLD}{count:>6,}{Colors.RESET} bot requests")

        # Suspicious Activity
        if self.stats['suspicious_ips']:
            print(f"\n{Colors.WARNING}⚠️  VERDÄCHTIGE IPs:{Colors.RESET}")
            for ip, count in self.stats['suspicious_ips'].most_common(10):
                print(f"   {Colors.RED}{ip:<15}{Colors.RESET} {Colors.BOLD}{count:>6,}{Colors.RESET} verdächtige requests")

        # Recent Errors
        if self.stats['error_requests']:
            print(f"\n{Colors.ERROR}❌ LETZTE 5 FEHLER-REQUESTS:{Colors.RESET}")
            for error in self.stats['error_requests'][-5:]:
                status_color = Colors.YELLOW if 400 <= error['status'] < 500 else Colors.RED
                print(f"   {Colors.colorize(str(error['status']), status_color)} {Colors.RED}{error['ip']}{Colors.RESET} {Colors.GRAY}{error['path'][:40]}{Colors.RESET} [{Colors.CYAN}{error['source']}{Colors.RESET}]")

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

        print(f"\n{Colors.SUCCESS}💾 CSV Export gespeichert: {filename}{Colors.RESET}")

def main():
    parser = argparse.ArgumentParser(
        description='nginx Multi-Log Access Analyzer mit Zeitfilter',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=f"""
{Colors.HEADER}VERFÜGBARE LOG-DATEIEN:{Colors.RESET}
{chr(10).join([f"  {Colors.CYAN}{name}{Colors.RESET}: {path}" for name, path in LOG_FILES.items()])}

{Colors.HEADER}ZEITFILTER:{Colors.RESET}
  {Colors.GREEN}heute{Colors.RESET}           - Nur heutige Einträge
  {Colors.YELLOW}diese_woche{Colors.RESET}     - Einträge seit Montag dieser Woche
  {Colors.BLUE}dieser_monat{Colors.RESET}    - Einträge seit 1. des aktuellen Monats
  {Colors.MAGENTA}gesamter_zeitraum{Colors.RESET} - Alle verfügbaren Einträge (Standard)

{Colors.HEADER}BEISPIELE:{Colors.RESET}
  {Colors.CYAN}{sys.argv[0]} start wiki --zeit heute{Colors.RESET}
  {Colors.CYAN}{sys.argv[0]} alle --zeit diese_woche --csv{Colors.RESET}
  {Colors.CYAN}{sys.argv[0]} immich bilder --zeit dieser_monat{Colors.RESET}
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
        print(f"{Colors.ERROR}❌ Keine gültigen Log-Dateien ausgewählt!{Colors.RESET}")
        sys.exit(1)

    # Analyzer initialisieren und ausführen
    analyzer = NginxLogAnalyzer(selected_logs, args.zeit)

    if analyzer.parse_log_files():
        analyzer.print_report()

        if args.csv:
            analyzer.export_csv(args.csv_file)
    else:
        print(f"{Colors.ERROR}❌ Keine Log-Dateien konnten verarbeitet werden!{Colors.RESET}")
        sys.exit(1)

    print(f"\n{Colors.SUCCESS}✅ Analyse abgeschlossen!{Colors.RESET}")

if __name__ == "__main__":
    main()
