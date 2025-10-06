#!/bin/bash
# Déploiement Blue-Green - API Dernier Metro Paris
# Version: 1.0.0
# Permet un déploiement sans interruption de service

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
readonly HEALTH_ENDPOINT="http://localhost:3000/health"
readonly HEALTH_TIMEOUT=60
readonly HEALTH_INTERVAL=5

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Variables
NEW_VERSION=${1:-"latest"}
CURRENT_COLOR=""
NEW_COLOR=""
DEPLOYMENT_ID=$(date +%Y%m%d_%H%M%S)

# Fonctions utilitaires
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

# Déterminer la couleur actuelle
detect_current_color() {
    log "🔍 Détection de l'environnement actuel..."
    
    if docker-compose -f docker-compose.blue.yml ps api 2>/dev/null | grep -q "Up"; then
        CURRENT_COLOR="blue"
        NEW_COLOR="green"
    elif docker-compose -f docker-compose.green.yml ps api 2>/dev/null | grep -q "Up"; then
        CURRENT_COLOR="green"
        NEW_COLOR="blue"
    else
        # Premier déploiement
        CURRENT_COLOR=""
        NEW_COLOR="blue"
        warning "Aucun environnement actif détecté - Premier déploiement"
    fi
    
    log "Couleur actuelle: ${CURRENT_COLOR:-none}"
    log "Nouvelle couleur: $NEW_COLOR"
}

# Générer les fichiers docker-compose dynamiques
generate_compose_files() {
    log "📝 Génération des fichiers de configuration..."
    
    # Compose file Blue
    cat > docker-compose.blue.yml << EOF
version: '3.8'

services:
  api:
    image: ghcr.io/asapabro/projet-dernier_metro:${NEW_VERSION}
    container_name: dernier-metro-api-blue
    restart: unless-stopped
    ports:
      - "3001:3000"  # Port Blue
    environment:
      NODE_ENV: production
      PORT: 3000
      DB_HOST: postgres
      DB_PORT: 5432
      DB_NAME: dernier_metro_prod
      DB_USER: metro_prod_user
      DB_PASSWORD_FILE: /run/secrets/db_password
      COLOR_DEPLOYMENT: blue
    secrets:
      - db_password
    volumes:
      - api_logs_blue:/var/log/api
    networks:
      - api_network
    depends_on:
      - postgres

  postgres:
    image: postgres:15-alpine
    container_name: dernier-metro-db-shared
    restart: unless-stopped
    environment:
      POSTGRES_DB: dernier_metro_prod
      POSTGRES_USER: metro_prod_user
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./db/init:/docker-entrypoint-initdb.d:ro
    networks:
      - api_network

secrets:
  db_password:
    file: ./secrets/db_password.txt

volumes:
  postgres_data:
    external: true
  api_logs_blue:

networks:
  api_network:
    external: true
EOF

    # Compose file Green
    cat > docker-compose.green.yml << EOF
version: '3.8'

services:
  api:
    image: ghcr.io/asapabro/projet-dernier_metro:${NEW_VERSION}
    container_name: dernier-metro-api-green
    restart: unless-stopped
    ports:
      - "3002:3000"  # Port Green
    environment:
      NODE_ENV: production
      PORT: 3000
      DB_HOST: postgres
      DB_PORT: 5432
      DB_NAME: dernier_metro_prod
      DB_USER: metro_prod_user
      DB_PASSWORD_FILE: /run/secrets/db_password
      COLOR_DEPLOYMENT: green
    secrets:
      - db_password
    volumes:
      - api_logs_green:/var/log/api
    networks:
      - api_network
    depends_on:
      - postgres

  postgres:
    image: postgres:15-alpine
    container_name: dernier-metro-db-shared
    restart: unless-stopped
    environment:
      POSTGRES_DB: dernier_metro_prod
      POSTGRES_USER: metro_prod_user
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
    secrets:
      - db_password
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./db/init:/docker-entrypoint-initdb.d:ro
    networks:
      - api_network

secrets:
  db_password:
    file: ./secrets/db_password.txt

volumes:
  postgres_data:
    external: true
  api_logs_green:

networks:
  api_network:
    external: true
EOF

    success "Fichiers de configuration générés"
}

# Configuration Nginx pour Blue-Green
generate_nginx_config() {
    local active_color=$1
    local active_port=""
    
    if [[ "$active_color" == "blue" ]]; then
        active_port="3001"
    else
        active_port="3002"
    fi
    
    log "🔧 Configuration Nginx pour l'environnement $active_color (port $active_port)..."
    
    cat > nginx/nginx.bg.conf << EOF
# Configuration Nginx Blue-Green - API Dernier Metro Paris
# Active: $active_color (port $active_port)

upstream api_backend {
    server localhost:${active_port} max_fails=3 fail_timeout=30s;
    keepalive 32;
}

# Configuration identique au nginx.prod.conf mais avec upstream dynamique
server {
    listen 80;
    server_name api.dernier-metro.fr;
    
    location /health {
        proxy_pass http://api_backend/health;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        access_log off;
    }
    
    location /api/ {
        proxy_pass http://api_backend;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Header pour identifier la couleur active
    add_header X-Deployment-Color "$active_color" always;
}
EOF
}

# Test de santé avec timeout
health_check() {
    local port=$1
    local max_attempts=$((HEALTH_TIMEOUT / HEALTH_INTERVAL))
    local attempt=1
    
    log "🏥 Test de santé sur le port $port..."
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -f -s "http://localhost:$port/health" > /dev/null; then
            success "Service sain sur le port $port"
            return 0
        fi
        
        log "Tentative $attempt/$max_attempts..."
        sleep $HEALTH_INTERVAL
        ((attempt++))
    done
    
    error "Service non disponible sur le port $port après ${HEALTH_TIMEOUT}s"
    return 1
}

# Tests de fumée complets
smoke_tests() {
    local port=$1
    local base_url="http://localhost:$port"
    
    log "🧪 Exécution des tests de fumée sur le port $port..."
    
    # Test health endpoint
    if ! curl -f -s "$base_url/health" | jq -e '.status == "ok"' > /dev/null; then
        error "Test health failed"
        return 1
    fi
    
    # Test API endpoints
    if ! curl -f -s "$base_url/api/v1/metro/info" | jq -e '.is_service_active != null' > /dev/null; then
        error "Test metro info failed"
        return 1
    fi
    
    if ! curl -f -s "$base_url/api/v1/stations" | jq -e '.stations | length > 0' > /dev/null; then
        error "Test stations list failed"
        return 1
    fi
    
    success "Tous les tests de fumée ont réussi"
    return 0
}

# Déploiement de la nouvelle version
deploy_new_version() {
    log "🚀 Déploiement de la nouvelle version ($NEW_COLOR)..."
    
    cd "$PROJECT_DIR"
    
    # Télécharger la nouvelle image
    log "📥 Téléchargement de l'image $NEW_VERSION..."
    docker pull "ghcr.io/asapabro/projet-dernier_metro:$NEW_VERSION"
    
    # Générer les configurations
    generate_compose_files
    
    # Créer le réseau et les volumes si nécessaire
    docker network create api_network 2>/dev/null || true
    docker volume create postgres_data 2>/dev/null || true
    
    # Démarrer le nouvel environnement
    log "🔄 Démarrage de l'environnement $NEW_COLOR..."
    docker-compose -f "docker-compose.${NEW_COLOR}.yml" up -d
    
    # Attendre que les services soient prêts
    sleep 20
    
    # Test de santé
    local new_port=""
    if [[ "$NEW_COLOR" == "blue" ]]; then
        new_port="3001"
    else
        new_port="3002"
    fi
    
    if health_check "$new_port" && smoke_tests "$new_port"; then
        success "Nouvelle version déployée avec succès"
        return 0
    else
        error "Échec du déploiement de la nouvelle version"
        return 1
    fi
}

# Basculement du trafic
switch_traffic() {
    log "🔄 Basculement du trafic vers $NEW_COLOR..."
    
    # Générer la nouvelle configuration Nginx
    generate_nginx_config "$NEW_COLOR"
    
    # Recharger Nginx (à adapter selon votre configuration)
    if command -v nginx &> /dev/null; then
        nginx -s reload
    elif docker ps --filter "name=nginx" --format "{{.Names}}" | grep -q nginx; then
        docker exec nginx nginx -s reload
    else
        warning "Nginx non trouvé - Configuration manuelle requise"
        log "Veuillez basculer manuellement le load balancer vers le port approprié"
    fi
    
    success "Trafic basculé vers $NEW_COLOR"
}

# Nettoyage de l'ancien environnement
cleanup_old_version() {
    if [[ -n "$CURRENT_COLOR" ]]; then
        log "🧹 Nettoyage de l'ancien environnement ($CURRENT_COLOR)..."
        
        # Attendre un délai de grâce
        log "Attente de 30 secondes pour finaliser les requêtes en cours..."
        sleep 30
        
        # Arrêter l'ancien environnement
        docker-compose -f "docker-compose.${CURRENT_COLOR}.yml" down
        
        success "Ancien environnement nettoyé"
    fi
}

# Rollback en cas d'échec
rollback() {
    if [[ -n "$CURRENT_COLOR" ]]; then
        warning "🔄 Rollback vers $CURRENT_COLOR..."
        
        # Remettre la configuration Nginx précédente
        generate_nginx_config "$CURRENT_COLOR"
        
        if command -v nginx &> /dev/null; then
            nginx -s reload
        fi
        
        # Arrêter le nouvel environnement défaillant
        docker-compose -f "docker-compose.${NEW_COLOR}.yml" down
        
        warning "Rollback terminé"
    else
        error "Aucun environnement de rollback disponible"
    fi
}

# Vérification des prérequis
check_prerequisites() {
    log "🔍 Vérification des prérequis..."
    
    # Vérifier les outils nécessaires
    for tool in docker docker-compose curl jq; do
        if ! command -v "$tool" &> /dev/null; then
            error "$tool n'est pas installé"
            exit 1
        fi
    done
    
    # Vérifier les secrets
    if [[ ! -f ./secrets/db_password.txt ]]; then
        error "Fichier de mot de passe base de données manquant"
        exit 1
    fi
    
    success "Prérequis validés"
}

# Script principal
main() {
    log "🎯 === DÉPLOIEMENT BLUE-GREEN API DERNIER METRO ==="
    log "Version à déployer: $NEW_VERSION"
    log "ID de déploiement: $DEPLOYMENT_ID"
    
    check_prerequisites
    detect_current_color
    
    if deploy_new_version; then
        switch_traffic
        
        # Valider le déploiement final
        sleep 10
        if health_check "80"; then
            cleanup_old_version
            success "🎉 Déploiement Blue-Green terminé avec succès !"
            log "Environnement actif: $NEW_COLOR"
        else
            error "Validation finale échouée"
            rollback
            exit 1
        fi
    else
        error "💥 Échec du déploiement"
        rollback
        exit 1
    fi
}

# Gestion des signaux
trap 'error "Interruption détectée"; rollback; exit 130' INT TERM

# Exécution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
