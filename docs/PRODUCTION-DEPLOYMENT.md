# 🚀 Guide de Déploiement Production - API Dernier Metro Paris

## Vue d'ensemble

Ce guide détaille le processus de déploiement en production de l'API Dernier Metro Paris avec une architecture haute disponibilité, monitoring avancé et déploiement Blue-Green zéro downtime.

## 🏗️ Architecture Production

### Composants Principaux

```
Internet → Nginx (SSL/Reverse Proxy) → API Node.js → PostgreSQL
                      ↓
              Monitoring Stack (Prometheus/Grafana)
                      ↓
              Cache Layer (Redis)
```

### Services Déployés

- **API Principal** : Node.js Express avec clustering
- **Base de Données** : PostgreSQL 15 avec optimisations
- **Reverse Proxy** : Nginx avec SSL et load balancing
- **Cache** : Redis pour optimisation performances
- **Monitoring** : Prometheus + Grafana + AlertManager
- **Logs** : Collecte centralisée avec rotation

## 🛠️ Prérequis Infrastructure

### Serveur Production (Recommandations)

```bash
# Spécifications minimales
CPU: 2 vCPU
RAM: 4 GB
Stockage: 40 GB SSD
Réseau: 100 Mbps

# Spécifications recommandées
CPU: 4 vCPU
RAM: 8 GB
Stockage: 100 GB SSD
Réseau: 1 Gbps
```

### Logiciels Requis

```bash
# Installation Ubuntu/Debian
sudo apt update && sudo apt install -y \
    docker.io \
    docker-compose \
    nginx \
    certbot \
    python3-certbot-nginx \
    curl \
    jq \
    htop \
    git

# Démarrage des services
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker $USER
```

## 📦 Installation Initiale

### 1. Préparation du Serveur

```bash
# Créer l'utilisateur de déploiement
sudo useradd -m -s /bin/bash dernier-metro
sudo usermod -aG docker dernier-metro
sudo mkdir -p /opt/dernier-metro
sudo chown dernier-metro:dernier-metro /opt/dernier-metro

# Structure des répertoires
sudo -u dernier-metro mkdir -p /opt/dernier-metro/{data,logs,backups,secrets}
sudo -u dernier-metro mkdir -p /opt/dernier-metro/data/{postgres,redis}
sudo -u dernier-metro mkdir -p /opt/dernier-metro/logs/{nginx,api}
```

### 2. Configuration SSL

```bash
# Obtenir les certificats SSL
sudo certbot --nginx -d api.dernier-metro.fr

# Automatiser le renouvellement
echo "0 12 * * * /usr/bin/certbot renew --quiet" | sudo crontab -
```

### 3. Configuration Secrets

```bash
# Générer les secrets de production
cd /opt/dernier-metro/secrets

# Mot de passe base de données (32 caractères)
openssl rand -base64 32 > db_password.txt

# Secret JWT (64 caractères)
openssl rand -base64 64 > jwt_secret.txt

# Mot de passe Redis
openssl rand -base64 32 > redis_password.txt

# Sécuriser les permissions
chmod 600 *.txt
chown dernier-metro:dernier-metro *.txt
```

## 🚀 Déploiement Production

### Méthode 1: Déploiement Standard

```bash
# Cloner le repository
cd /opt/dernier-metro
git clone https://github.com/ASapAbro/Projet-Dernier_metro.git app
cd app

# Copier la configuration production
cp .env.production.example .env.production

# Éditer les variables d'environnement
nano .env.production

# Déployer
sudo ./scripts/deploy-production.sh latest
```

### Méthode 2: Déploiement Blue-Green (Recommandé)

```bash
# Premier déploiement
sudo ./scripts/blue-green-deploy.sh latest

# Déploiements suivants (zéro downtime)
sudo ./scripts/blue-green-deploy.sh v1.2.0
```

## 📊 Configuration Monitoring

### Prometheus

```bash
# Accès interface Prometheus
http://your-server:9090

# Métriques principales surveillées:
- http_requests_total
- http_request_duration_seconds
- process_cpu_seconds_total
- process_resident_memory_bytes
- pg_up, redis_up
```

### Grafana

```bash
# Installation Grafana
docker run -d \
  --name grafana \
  -p 3000:3000 \
  -v grafana-storage:/var/lib/grafana \
  -e "GF_SECURITY_ADMIN_PASSWORD=admin" \
  grafana/grafana

# Importer le dashboard
# Aller sur http://your-server:3000
# Importer monitoring/grafana-dashboard.json
```

### Alertes

```bash
# Configuration Slack (optionnel)
export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK"

# Les alertes sont configurées pour:
- API indisponible (> 30s)
- Latence élevée (> 1s)
- Taux d'erreur > 5%
- Utilisation CPU > 80%
- Utilisation mémoire > 90%
- Espace disque < 10%
```

## 🔧 Maintenance

### Sauvegardes Automatiques

```bash
# Script de sauvegarde (à placer dans crontab)
cat > /opt/dernier-metro/backup-daily.sh << 'EOF'
#!/bin/bash
BACKUP_DIR="/opt/dernier-metro/backups/$(date +%Y%m%d)"
mkdir -p "$BACKUP_DIR"

# Sauvegarde base de données
docker exec dernier-metro-db-prod pg_dump -U metro_prod_user dernier_metro_prod > "$BACKUP_DIR/database.sql"

# Sauvegarde configuration
cp -r /opt/dernier-metro/secrets "$BACKUP_DIR/"

# Nettoyage (garder 30 jours)
find /opt/dernier-metro/backups -type d -mtime +30 -exec rm -rf {} \;
EOF

chmod +x /opt/dernier-metro/backup-daily.sh

# Ajouter au crontab
echo "0 2 * * * /opt/dernier-metro/backup-daily.sh" | crontab -
```

### Mise à Jour

```bash
# Mise à jour mineure (patch/bugfix)
./scripts/blue-green-deploy.sh v1.0.1

# Mise à jour majeure avec migration DB
./scripts/deploy-production.sh v2.0.0

# Rollback si nécessaire
docker tag ghcr.io/asapabro/projet-dernier_metro:v1.0.0 \
           ghcr.io/asapabro/projet-dernier_metro:latest
./scripts/blue-green-deploy.sh latest
```

### Logs et Debugging

```bash
# Consulter les logs
docker logs dernier-metro-api-prod
docker logs dernier-metro-db-prod
docker logs dernier-metro-proxy-prod

# Logs temps réel
docker logs -f dernier-metro-api-prod

# Métriques système
docker stats
htop

# Accès shell container
docker exec -it dernier-metro-api-prod sh
```

## 🔐 Sécurité

### Bonnes Pratiques Appliquées

- ✅ Containers en lecture seule
- ✅ Utilisateurs non-root dans containers
- ✅ Secrets Docker pour données sensibles
- ✅ SSL/TLS avec certificats Let's Encrypt
- ✅ Rate limiting sur Nginx
- ✅ Headers de sécurité HTTP
- ✅ Isolation réseau containers
- ✅ Monitoring et alertes sécurité

### Firewall Recommandé

```bash
# Configuration UFW
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
```

## 📋 Checklist de Déploiement

### Pré-déploiement
- [ ] Serveur configuré avec prérequis
- [ ] SSL/TLS certificats en place
- [ ] Secrets générés et sécurisés
- [ ] Sauvegardes configurées
- [ ] Monitoring opérationnel

### Déploiement
- [ ] Image Docker construite et testée
- [ ] Tests CI/CD passés
- [ ] Migration base de données (si nécessaire)
- [ ] Déploiement Blue-Green exécuté
- [ ] Tests de fumée validés

### Post-déploiement
- [ ] API accessible et fonctionnelle
- [ ] Métriques remontées dans Grafana
- [ ] Alertes configurées
- [ ] Documentation mise à jour
- [ ] Équipe notifiée

## 🆘 Dépannage

### Problèmes Courants

#### API ne démarre pas
```bash
# Vérifier les logs
docker logs dernier-metro-api-prod

# Vérifier la configuration
docker exec dernier-metro-api-prod env

# Tester la connectivité DB
docker exec dernier-metro-api-prod pg_isready -h postgres -U metro_prod_user
```

#### Performance dégradée
```bash
# Vérifier les métriques
curl http://localhost:9090/metrics

# Analyser les logs Nginx
tail -f /opt/dernier-metro/logs/nginx/access.log

# Profiling Node.js (si nécessaire)
docker exec dernier-metro-api-prod node --inspect server.js
```

#### Rollback d'urgence
```bash
# Rollback automatique
./scripts/blue-green-deploy.sh $(cat /opt/dernier-metro/backups/latest/previous_version.txt)

# Rollback manuel
docker-compose -f docker-compose.prod.yml down
docker-compose -f docker-compose.prod.yml up -d
```

## 📞 Support

### Contacts d'Urgence
- **DevOps Lead**: [contact]
- **Database Admin**: [contact]
- **Security Team**: [contact]

### Liens Utiles
- **Grafana**: http://your-server:3000
- **Prometheus**: http://your-server:9090
- **API Health**: https://api.dernier-metro.fr/health
- **Documentation**: https://github.com/ASapAbro/Projet-Dernier_metro

---

**🚀 API Dernier Metro Paris - Production Ready ! 🎉**
