#!/bin/bash

# Script to start/stop/update multiple docker-compose setups
# Place this script in /root/docker/ directory
############
# Faxxxmaster 03/2025
############
ACTION=$1
##########################
# Hier Pfade zu den containern eintragen!
##########################
DOCKER_DIRS=("/root/docker/immich-app" "/root/docker/otterwiki")

# Prüfen ob Parameter existiert
if [ -z "$ACTION" ]; then
  echo "Usage: $0 [start|stop|restart|status|update|cleanup]"
  exit 1
fi

# Funktion zum ausführen der entsprechenden docker compose Befehle
run_docker_compose() {
  local action=$1
  local dir=$2
  
  echo "=== Processing $dir ==="
  
  cd "$dir" || {
    echo "Error: Could not change to directory $dir"
    return 1
  }
  
  case "$action" in
    start)
      echo "Starting docker-compose in $dir..."
      docker compose up -d
      ;;
    stop)
      echo "Stopping docker-compose in $dir..."
      docker compose down
      ;;
    restart)
      echo "Restarting docker-compose in $dir..."
      docker compose down
      docker compose up -d
      ;;
    status)
      echo "Status of containers in $dir:"
      docker compose ps
      ;;
    update)
      echo "Updating containers in $dir..."
      docker compose pull
      docker compose down
      docker compose up -d
      ;;
    *)
      echo "Unknown action: $action"
      return 1
      ;;
  esac
  
  echo ""
}

# Cleanup function
cleanup_docker() {
  echo "=== Running Docker Cleanup ==="
  docker system prune -a --volumes -f
  echo "Docker cleanup completed."
}

# Ausführen der ausgewaehlten action
case "$ACTION" in
  start|stop|restart|status|update)
    for dir in "${DOCKER_DIRS[@]}"; do
      run_docker_compose "$ACTION" "$dir"
    done
    ;;
  cleanup)
    cleanup_docker
    ;;
  *)
    echo "Error: Invalid action. Use start, stop, restart, status, update or cleanup."
    exit 1
    ;;
esac

echo "All operations completed."
