# Dernier Metro — Paris API

Une API minimaliste pour aider les usagers à savoir s'ils peuvent attraper le dernier métro à Paris.

## 🚇 Contexte

Imaginez Lina, 00:58, elle sort d'un concert à Châtelet. Elle doit prendre la ligne 1. A-t-elle le temps d'attraper le dernier métro ?

Cette API répond en quelques millisecondes avec la prochaine rame et si c'est la dernière.

**Note :** Pas de données temps réel. Les horaires sont simulés pour se concentrer sur les fondamentaux backend et la containerisation.

## 🎯 Fonctionnalités

### Endpoints disponibles

- `GET /health` → Vérification de l'état de l'API
- `GET /next-metro?station=NAME` → Informations sur le prochain métro

### Modèle métier

- **Plage de service :** 05:30 → 01:15 (fictif)
- **Fréquence :** 3 minutes
- **Dernier métro :** entre 00:45 et 01:15 (`isLast = true`)

## 🚀 Installation et lancement

### Méthode 1 : Installation locale

```bash
# Installation des dépendances
npm install

# Lancement du serveur
npm start
```

Le serveur démarre sur `http://localhost:3000` (port configurable via `PORT` env var).

### Méthode 2 : Docker

```bash
# Construction de l'image
docker build -f Dockerfile.v1 -t dernier-metro .

# Lancement du conteneur
docker run -p 3002:3000 dernier-metro
```

### Méthode 3 : Docker Compose (Recommandé)

```bash
# Lancement de l'ensemble des services
docker-compose up --build

# Arrêt des services
docker-compose down
```

## 📚 Documentation API

### Interface Swagger UI

La documentation interactive est disponible via Swagger UI :

- **URL :** http://localhost:3002/api-docs
- **Spécification OpenAPI :** http://localhost:3002/api-docs.json

### Services disponibles avec Docker Compose

- **API :** http://localhost:3002
- **Swagger UI intégré :** http://localhost:3002/api-docs
- **Swagger UI standalone :** http://localhost:8080 (optionnel)

## 📋 Exemples d'utilisation

### Test de santé
```bash
curl http://localhost:3002/health
```
**Réponse :**
```json
{"status":"ok"}
```

### Informations métro
```bash
curl "http://localhost:3002/next-metro?station=Chatelet"
```
**Réponse :**
```json
{
  "station": "Chatelet",
  "line": "M1", 
  "headwayMin": 3,
  "nextArrival": "12:34",
  "isLast": false,
  "tz": "Europe/Paris"
}
```

### Gestion des erreurs

#### Station manquante
```bash
curl "http://localhost:3002/next-metro"
```
**Réponse (400) :**
```json
{"error":"missing station"}
```

#### Route inexistante
```bash
curl "http://localhost:3002/unknown"
```
**Réponse (404) :**
```json
{"error":"route not found"}
```

## 🔧 Configuration

- **PORT :** Port d'écoute du serveur (défaut: 3000)

Exemple :
```bash
PORT=3001 npm start
```

Avec Docker :
```bash
docker run -p 3001:3000 -e PORT=3000 dernier-metro
```

## 📊 Logs

L'API génère des logs pour chaque requête au format :
```
GET /next-metro - 200 - 15ms
```

## 🏗️ Architecture

- **Express.js :** Serveur web et routage
- **Node.js 18 Alpine :** Runtime et image Docker
- **JSON uniquement :** Toutes les réponses sont en JSON

## 🐛 Dépannage

### Problèmes courants

1. **Port déjà utilisé**
   ```bash
   # Changer le mapping de port
   docker run -p 3001:3000 dernier-metro
   ```

2. **Module Express non trouvé**
   ```bash
   npm install
   ```

3. **Pas de réponse**
   - Vérifier que le port est correct
   - Vérifier les logs pour les erreurs

## 🎯 Prochaines étapes

- [x] Intégration Swagger UI pour la documentation interactive
- [x] Docker Compose pour l'orchestration  
- [x] Spécification OpenAPI complète
- [ ] Défis bonus (variables ENV, multiple passages, validation stations)

---

**Note :** Ce projet est pédagogique. Les horaires et lignes sont simulés. Aucune intégration RATP temps réel n'est requise.
