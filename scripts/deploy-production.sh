#!/bin/bash
# Script de déploiement production - API Dernier Metro Paris
# Version: 1.0.0
# Usage: ./deploy-production.sh [version]

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
readonly LOG_FILE="/var/log/dernier-metro/deploy.log"
readonly BACKUP_DIR="/opt/dernier-metro/backups"
readonly DATA_DIR="/opt/dernier-metro/data"

# Couleurs
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m' # No Color

# Variables
VERSION=${1:-"latest"}
DEPLOYMENT_ID=$(date +%Y%m%d_%H%M%S)
ROLLBACK_VERSION=""

# Fonctions utilitaires
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $*" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE" >&2
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "$LOG_FILE"
}

# Vérifications pré-déploiement
check_prerequisites() {
    log "🔍 Vérification des prérequis..."
    
    # Vérifier Docker
    if ! command -v docker &> /dev/null; then
        error "Docker n'est pas installé"
        exit 1
    fi
    
    # Vérifier Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        error "Docker Compose n'est pas installé"
        exit 1
    fi
    
    # Vérifier les permissions
    if [[ $EUID -ne 0 ]]; then
        error "Ce script doit être exécuté en tant que root"
        exit 1
    fi
    
    # Vérifier l'espace disque
    local available_space
    available_space=$(df /opt | tail -1 | awk '{print $4}')
    if [[ $available_space -lt 1048576 ]]; then # 1GB en KB
        error "Espace disque insuffisant (minimum 1GB requis)"
        exit 1
    fi
    
    success "Prérequis validés"
}

# Configuration de l'environnement
setup_environment() {
    log "⚙️ Configuration de l'environnement de production..."
    
    # Créer les répertoires nécessaires
    mkdir -p "$DATA_DIR"/{postgres,redis}
    mkdir -p "$BACKUP_DIR"
    mkdir -p /opt/dernier-metro/logs/{nginx,api}
    mkdir -p /opt/dernier-metro/secrets
    
    # Permissions sécurisées
    chmod 700 /opt/dernier-metro/secrets
    chown -R 999:999 "$DATA_DIR/postgres"  # postgres user
    chown -R 999:999 "$DATA_DIR/redis"     # redis user
    
    # Générer les secrets s'ils n'existent pas
    if [[ ! -f /opt/dernier-metro/secrets/db_password.txt ]]; then
        openssl rand -base64 32 > /opt/dernier-metro/secrets/db_password.txt
        chmod 600 /opt/dernier-metro/secrets/db_password.txt
        warning "Nouveau mot de passe DB généré"
    fi
    
    if [[ ! -f /opt/dernier-metro/secrets/jwt_secret.txt ]]; then
        openssl rand -base64 64 > /opt/dernier-metro/secrets/jwt_secret.txt
        chmod 600 /opt/dernier-metro/secrets/jwt_secret.txt
        warning "Nouveau secret JWT généré"
    fi
    
    success "Environnement configuré"
}

# Sauvegarde avant déploiement
backup_current_deployment() {
    log "💾 Sauvegarde du déploiement actuel..."
    
    local backup_path="$BACKUP_DIR/backup_$DEPLOYMENT_ID"
    mkdir -p "$backup_path"
    
    # Sauvegarder la base de données
    if docker-compose -f docker-compose.prod.yml ps postgres | grep -q "Up"; then
        log "Sauvegarde de la base de données..."
        docker-compose -f docker-compose.prod.yml exec -T postgres \
            pg_dump -U metro_prod_user dernier_metro_prod > "$backup_path/database.sql"
        
        if [[ $? -eq 0 ]]; then
            success "Base de données sauvegardée"
        else
            error "Échec de la sauvegarde de la base de données"
            exit 1
        fi
    fi
    
    # Sauvegarder la configuration
    cp -r /opt/dernier-metro/secrets "$backup_path/"
    
    # Identifier la version actuelle pour rollback
    if docker images --format "table {{.Repository}}:{{.Tag}}" | grep -q "dernier_metro"; then
        ROLLBACK_VERSION=$(docker images --format "{{.Tag}}" ghcr.io/asapabro/projet-dernier_metro | head -1)
        echo "$ROLLBACK_VERSION" > "$backup_path/previous_version.txt"
    fi
    
    success "Sauvegarde terminée: $backup_path"
}

# Test de santé
health_check() {
    log "🏥 Vérification de la santé des services..."
    
    local max_attempts=30
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        if curl -f -s http://localhost/health > /dev/null; then
            success "API opérationnelle"
            return 0
        fi
        
        log "Tentative $attempt/$max_attempts - En attente..."
        sleep 10
        ((attempt++))
    done
    
    error "L'API ne répond pas après $max_attempts tentatives"
    return 1
}

# Déploiement principal
deploy() {
    log "🚀 Démarrage du déploiement version $VERSION..."
    
    cd "$PROJECT_DIR"
    
    # Télécharger la nouvelle image
    log "📥 Téléchargement de l'image Docker..."
    docker pull "ghcr.io/asapabro/projet-dernier_metro:$VERSION"
    
    # Mettre à jour le tag latest
    docker tag "ghcr.io/asapabro/projet-dernier_metro:$VERSION" \
               "ghcr.io/asapabro/projet-dernier_metro:latest"
    
    # Déploiement avec zero-downtime
    log "🔄 Déploiement rolling update..."
    
    # Variables d'environnement pour production
    export POSTGRES_DB=dernier_metro_prod
    export POSTGRES_USER=metro_prod_user
    export CORS_ORIGIN=https://dernier-metro.fr
    export RATE_LIMIT_MAX=100
    export REDIS_PASSWORD=$(openssl rand -base64 32)
    
    # Lancer les nouveaux services
    docker-compose -f docker-compose.prod.yml up -d --remove-orphans
    
    # Attendre que les services soient prêts
    log "⏳ Attente de la disponibilité des services..."
    sleep 30
    
    # Test de santé
    if health_check; then
        success "Déploiement réussi !"
        
        # Nettoyer les anciennes images
        log "🧹 Nettoyage des anciennes images..."
        docker image prune -f
        
        # Log des métriques post-déploiement
        log "📊 Métriques post-déploiement:"
        docker-compose -f docker-compose.prod.yml ps
        docker stats --no-stream
        
    else
        error "Échec du déploiement - Démarrage du rollback"
        rollback
        exit 1
    fi
}

# Rollback en cas d'échec
rollback() {
    warning "🔄 Rollback vers la version précédente..."
    
    if [[ -n "$ROLLBACK_VERSION" ]]; then
        docker tag "ghcr.io/asapabro/projet-dernier_metro:$ROLLBACK_VERSION" \
                   "ghcr.io/asapabro/projet-dernier_metro:latest"
        
        docker-compose -f docker-compose.prod.yml up -d
        
        if health_check; then
            warning "Rollback réussi vers $ROLLBACK_VERSION"
        else
            error "Échec du rollback - Intervention manuelle requise"
        fi
    else
        error "Aucune version de rollback disponible"
    fi
}

# Notifications post-déploiement
notify_deployment() {
    local status=$1
    local webhook_url="${SLACK_WEBHOOK_URL:-}"
    
    if [[ -n "$webhook_url" ]]; then
        local color="good"
        local emoji="✅"
        
        if [[ "$status" != "success" ]]; then
            color="danger"
            emoji="❌"
        fi
        
        curl -X POST -H 'Content-type: application/json' \
            --data "{
                \"attachments\": [{
                    \"color\": \"$color\",
                    \"title\": \"$emoji Déploiement API Dernier Metro\",
                    \"fields\": [
                        {\"title\": \"Version\", \"value\": \"$VERSION\", \"short\": true},
                        {\"title\": \"Statut\", \"value\": \"$status\", \"short\": true},
                        {\"title\": \"Timestamp\", \"value\": \"$(date)\", \"short\": false}
                    ]
                }]
            }" \
            "$webhook_url"
    fi
}

# Gestion des signaux
cleanup() {
    log "🧹 Nettoyage en cours..."
    # Nettoyage si nécessaire
}

trap cleanup EXIT

# Script principal
main() {
    log "🎯 === DÉPLOIEMENT PRODUCTION API DERNIER METRO ==="
    log "Version: $VERSION"
    log "Deployment ID: $DEPLOYMENT_ID"
    
    check_prerequisites
    setup_environment
    backup_current_deployment
    
    if deploy; then
        success "🎉 Déploiement terminé avec succès !"
        notify_deployment "success"
    else
        error "💥 Échec du déploiement"
        notify_deployment "failed"
        exit 1
    fi
}

# Exécution si script appelé directement
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
