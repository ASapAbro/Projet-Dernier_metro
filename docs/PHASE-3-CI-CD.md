# Phase 3 CI/CD - Infrastructure Complète

## 🏗️ Architecture CI/CD

Cette phase implémente une pipeline CI/CD complète avec deux alternatives :

### 🦊 GitLab CI/CD (`.gitlab-ci.yml`)

Pipeline en **4 étages** :

#### 1️⃣ **Stage: TEST**
- **test:unit** : Tests unitaires + couverture (60%+)
- **test:lint** : Validation syntaxe + audit sécurité npm  
- **test:api** : Tests d'intégration API avec PostgreSQL

#### 2️⃣ **Stage: BUILD** 
- **build:docker** : Construction image Docker multi-stage
- **build:test-docker** : Test de l'image construite

#### 3️⃣ **Stage: SECURITY**
- **security:npm-audit** : Scan vulnérabilités npm
- **security:container-scan** : Scan image Docker avec Trivy

#### 4️⃣ **Stage: DEPLOY**
- **deploy:staging** : Auto-deploy sur develop branch
- **deploy:production** : Deploy manuel sur main branch

### 🐙 GitHub Actions (`.github/workflows/ci-cd.yml`)

Pipeline équivalente avec :
- Tests multi-versions Node.js (18, 20)
- Build et push Docker Registry GitHub
- Scans de sécurité automatiques
- Déploiements environnements staging/production

## 🐳 Docker Multi-Stage

Le `Dockerfile` optimisé contient **5 stages** :

1. **base** : Image Alpine + utilisateur sécurisé
2. **dependencies** : Installation dépendances production
3. **development** : Environnement de développement
4. **testing** : Environnement de test CI
5. **production** : Image finale optimisée

## 🔒 Sécurité Intégrée

- **Trivy** : Scan vulnérabilités containers
- **npm audit** : Analyse dépendances Node.js  
- **Utilisateur non-root** dans containers
- **Health checks** automatiques
- **Gestion signaux** avec dumb-init

## 🧪 Tests Automatisés

- **Jest** : Framework de test (60% coverage)
- **Supertest** : Tests API endpoints
- **PostgreSQL service** : Base de données tests
- **Scripts bash** : Tests d'intégration

## 📊 Monitoring & Métriques

- **Coverage reports** : Rapports couverture code
- **Artefacts CI** : Stockage résultats tests
- **Health endpoints** : Monitoring applicatif
- **Logs structurés** : Debugging facilité

## 🚀 Utilisation

### Développement Local
```bash
# Tests
npm test
npm run test:coverage

# Docker build local
docker build -t api-dernier-metro .
docker run -p 3000:3000 api-dernier-metro
```

### CI/CD Automatique
- **Push sur develop** → Déploiement staging automatique
- **Push sur main** → Tests + déploiement production manuel
- **Pull requests** → Tests complets automatiques

### Scripts Disponibles
```bash
./test_api.sh          # Tests intégration API
docker-compose up -d   # Stack complète local
npm run test:watch     # Tests en mode watch
```

## 🔧 Configuration

Variables d'environnement CI/CD :
- `NODE_ENV` : Environnement (test/staging/production)
- `DB_HOST`, `DB_PORT`, `DB_NAME` : Configuration PostgreSQL  
- `CI_REGISTRY_*` : Configuration Docker Registry

## ✅ Validation Phase 3

- [x] Pipeline GitLab CI/CD complète
- [x] Pipeline GitHub Actions alternative  
- [x] Docker multi-stage optimisé
- [x] Tests automatisés (60% coverage)
- [x] Scans de sécurité intégrés
- [x] Déploiements automatisés
- [x] Monitoring et health checks
- [x] Documentation complète

**Prêt pour Phase 4 - Production ! 🎯**
