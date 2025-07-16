"""
Benötigte Python Bibliotheken:
- psutil: System and process utilities
- requests: HTTP library for Pushover API

Installation auf Arch Linux:
    sudo pacman -S python-psutil python-requests

Installation auf Debian/Ubuntu:
    sudo apt update
    sudo apt install python3-psutil python3-requests

Note: Installing via system package manager (pacman/apt) is preferred 
as it integrates better with the system package management and 
ensures compatibility with system updates.

Alternative installation mit pip (für den Fall das!):
    sudo pacman -S python-pip  # Arch Linux
    sudo apt install python3-pip  # Debian/Ubuntu
    pip install psutil requests


Funktionen bis jetzt 17.11.24:
- Pushover-nachrichten  besiger  CPU, Speicher- oder Festplattenauslastung / Verte können angepasst werden
- Pushover-nachrichten bei Ausfall und erneuter Start vordefinierter Dienste
- Pushover-nachrichten bei einer erfolgrteichen Anmeldung über ssh mit LoginName und IP 





"""

import psutil
import requests
import time
from datetime import datetime
import subprocess
import re

class ServerMonitor:
    def __init__(self, pushover_user_key, pushover_api_token):
        self.pushover_user_key = pushover_user_key
        self.pushover_api_token = pushover_api_token
        self.thresholds = {
            'cpu_percent': 80.0,        # Einstellungen für die Obergrenzen
            'memory_percent': 85.0,
            'disk_percent': 90.0
        }
        self.last_alerts = {
            'cpu': 0,
            'memory': 0,
            'disk': 0,
        }
        self.service_status = {}
        self.last_login_check = datetime.now()
        self.last_ssh_logins = set()  # Speichert die letzten SSH-Logins
        self.alert_cooldown = 60

    def check_service_status(self, service_name):
        """Verbesserte Dienst-Überprüfung mit systemctl"""
        try:
            result = subprocess.run(['systemctl', 'is-active', service_name], 
                                 capture_output=True, 
                                 text=True)
            return result.stdout.strip() == 'active'
        except Exception as e:
            print(f"Error checking service {service_name}: {e}")
            return False

    def initial_service_check(self, services):
        """Initiale Überprüfung aller Dienste"""
        print("Performing initial service check...")
        offline_services = []
        
        for service in services:
            if not self.check_service_status(service):
                offline_services.append(service)
                self.service_status[service] = False
            else:
                self.service_status[service] = True
        
        if offline_services:
            message = f"Initial check - Services offline: {', '.join(offline_services)}"
            self.send_pushover_alert(message, priority=2)
            print(message)
    
    def send_pushover_alert(self, message, priority=1):
        """Send alert via Pushover API with improved error handling"""
        payload = {
            'token': self.pushover_api_token,
            'user': self.pushover_user_key,
            'message': message,
            'priority': priority,
            'title': 'Server Alert'
        }
        
        # Füge expire und retry für Emergency-Priorität (2) hinzu
        if priority == 2:
            payload.update({
                'expire': 10800,  # 3 Stunden in Sekunden
                'retry': 60       # Wiederholung alle 60 Sekunden
            })
        
        try:
            response = requests.post(
                'https://api.pushover.net/1/messages.json',
                data=payload,
                timeout=10
            )
            if response.status_code == 200:
                print(f"Alert sent successfully: {message}")
            else:
                print(f"Failed to send alert: {response.status_code}")
                print(f"Response content: {response.text}")
            return response.status_code == 200
        except requests.RequestException as e:
            print(f"Network error sending alert: {e}")
            return False
        except Exception as e:
            print(f"Unexpected error sending alert: {e}")
            return False

    def monitor_services(self, services):
        """Verbesserte Service-Überwachung mit Benachrichtigungen für Wiederherstellung"""
        for service in services:
            try:
                current_status = self.check_service_status(service)
                previous_status = self.service_status.get(service, True)
                
                # Service ist ausgefallen
                if not current_status and previous_status:
                    alert_message = f'Service {service} is not running!'
                    alert_sent = self.send_pushover_alert(alert_message, priority=2)
                    
                    if alert_sent:
                        print(f"Service Alert sent! {service} is not running!")
                    else:
                        print(f"Failed to send alert for {service}")
                
                # Service ist wieder verfügbar
                elif current_status and not previous_status:
                    recovery_message = f'Service {service} has recovered and is now running!'
                    alert_sent = self.send_pushover_alert(recovery_message, priority=1)
                    
                    if alert_sent:
                        print(f"Recovery Alert sent! {service} is running again!")
                    else:
                        print(f"Failed to send recovery alert for {service}")
                
                self.service_status[service] = current_status
                
            except Exception as e:
                print(f"Error monitoring service {service}: {e}")

    def check_system_resources(self):
        """Check system resources and send alerts if thresholds are exceeded"""
        try:
            # CPU Usage
            cpu_percent = psutil.cpu_percent(interval=1)
            if cpu_percent > self.thresholds['cpu_percent'] and time.time() - self.last_alerts['cpu'] > self.alert_cooldown:
                self.send_pushover_alert(
                    f'High CPU Usage: {cpu_percent}% (Threshold: {self.thresholds["cpu_percent"]}%)'
                )
                self.last_alerts['cpu'] = time.time()

            # Memory Usage
            memory = psutil.virtual_memory()
            if memory.percent > self.thresholds['memory_percent'] and time.time() - self.last_alerts['memory'] > self.alert_cooldown:
                self.send_pushover_alert(
                    f'High Memory Usage: {memory.percent}% (Threshold: {self.thresholds["memory_percent"]}%)'
                )
                self.last_alerts['memory'] = time.time()

            # Disk Usage
            disk = psutil.disk_usage('/')
            if disk.percent > self.thresholds['disk_percent'] and time.time() - self.last_alerts['disk'] > self.alert_cooldown:
                self.send_pushover_alert(
                    f'High Disk Usage: {disk.percent}% (Threshold: {self.thresholds["disk_percent"]}%)'
                )
                self.last_alerts['disk'] = time.time()

        except Exception as e:
            print(f"Error checking system resources: {e}")

    def check_ssh_logins(self):
        """Überwacht SSH-Logins durch Prüfung der Auth-Log mit Deduplizierung"""
        try:
            current_time = datetime.now()
            # Benutze die Zeit seit der letzten Prüfung
            time_diff = (current_time - self.last_login_check).total_seconds()
            since_param = f"{int(time_diff + 5)}s ago"  # +5 Sekunden Überlappung zur Sicherheit
            
            output = subprocess.check_output(
                ['journalctl', '-u', 'sshd', '--since', since_param],
                universal_newlines=True
            )
            
            login_pattern = r'Accepted (?:password|publickey) for (\w+) from ([\d\.]+)'
            matches = re.finditer(login_pattern, output)
            
            current_logins = set()
            for match in matches:
                username = match.group(1)
                ip = match.group(2)
                login_info = f"{username}:{ip}"
                current_logins.add(login_info)
            
            # Finde nur neue Logins
            new_logins = current_logins - self.last_ssh_logins
            
            # Sende Benachrichtigungen nur für neue Logins
            for login_info in new_logins:
                username, ip = login_info.split(':')
                message = f'SSH Login: User {username} from IP {ip}'
                self.send_pushover_alert(message, priority=1)
                print(f"SSH Alert sent! {message}")
            
            # Aktualisiere den Zustand
            self.last_ssh_logins = current_logins
            self.last_login_check = current_time
            
        except Exception as e:
            print(f"Error checking SSH logins: {str(e)}")

def main():
    # Replace with your Pushover credentials
    PUSHOVER_USER_KEY = 'unuvrsdj79pn1wtj41uckk7pqz2ioq'
    PUSHOVER_API_TOKEN = 'a69x6xu2dmre7oecv5jnwhh1z5mux3'
    
    SERVICES_TO_MONITOR = [
        'sshd.service',
        'mysqld.service'
    ]
    
    monitor = ServerMonitor(PUSHOVER_USER_KEY, PUSHOVER_API_TOKEN)
    
    try:
        # Send test notification on startup
        monitor.send_pushover_alert('Server monitoring started', priority=0)
        print("Monitoring started...")
        
        # Initiale Überprüfung
        monitor.initial_service_check(SERVICES_TO_MONITOR)
        
        while True:
            try:
                monitor.check_system_resources()
                monitor.monitor_services(SERVICES_TO_MONITOR)
                monitor.check_ssh_logins()
                time.sleep(2)
                
            except Exception as e:
                error_msg = f'Monitoring error: {str(e)}'
                monitor.send_pushover_alert(error_msg, priority=2)
                print(error_msg)
                time.sleep(60)
                
    except KeyboardInterrupt:
        print("\nMonitoring stopped by user")
    except Exception as e:
        print(f"Critical error in main loop: {e}")

if __name__ == "__main__":
    main()
