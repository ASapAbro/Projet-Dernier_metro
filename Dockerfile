# Dockerfile pour l'API Dernier Metro Paris
# Version: 1.0.0 - Optimisé pour CI/CD

# ===== Stage 1: Base =====
FROM node:18-alpine AS base

# Métadonnées
LABEL maintainer="API Dernier Metro Team"
LABEL version="1.0.0"
LABEL description="API REST pour les horaires du dernier métro parisien"

# Variables d'environnement par défaut
ENV NODE_ENV=production
ENV PORT=3000
ENV LOG_LEVEL=info

# Création d'un utilisateur non-root pour la sécurité
RUN addgroup -g 1001 -S metro && \
    adduser -S metro -u 1001

# Installation des dépendances système nécessaires
RUN apk add --no-cache \
    dumb-init \
    postgresql-client \
    curl \
    && rm -rf /var/cache/apk/*

# Répertoire de travail
WORKDIR /app

# Copie des fichiers de dépendances
COPY package*.json ./

# ===== Stage 2: Dependencies =====
FROM base AS dependencies

# Installation des dépendances (avec cache layer)
RUN npm ci --only=production --silent && \
    npm cache clean --force

# ===== Stage 3: Development =====
FROM dependencies AS development

# Installation des dépendances de développement
RUN npm ci --silent

# Copie du code source
COPY . .

# Changement de propriétaire des fichiers
RUN chown -R metro:metro /app

# Utilisateur non-root
USER metro

# Port exposé
EXPOSE 3000

# Commande de développement
CMD ["npm", "run", "dev"]

# ===== Stage 4: Testing =====
FROM development AS testing

# Variables d'environnement pour les tests
ENV NODE_ENV=test
ENV DB_HOST=localhost
ENV DB_PORT=5432
ENV DB_NAME=dernier_metro_test
ENV DB_USER=metro_user
ENV DB_PASSWORD=metro_password

# Copie des fichiers de test
COPY tests/ tests/
COPY jest.config.js ./

# Utilisateur root temporairement pour les tests CI
USER root

# Installation des outils de test additionnels
RUN apk add --no-cache \
    bash \
    git \
    && rm -rf /var/cache/apk/*

# Retour à l'utilisateur non-root
USER metro

# Commande par défaut pour les tests
CMD ["npm", "run", "test:ci"]

# ===== Stage 5: Production =====
FROM base AS production

# Copie des dépendances de production uniquement
COPY --from=dependencies /app/node_modules ./node_modules

# Copie du code source (optimisé pour production)
COPY --chown=metro:metro src/ src/
COPY --chown=metro:metro swagger.js ./
COPY --chown=metro:metro server.js ./
COPY --chown=metro:metro package.json ./

# Configuration de sécurité
USER metro

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:$PORT/health || exit 1

# Port exposé
EXPOSE 3000

# Point d'entrée avec dumb-init pour une gestion propre des signaux
ENTRYPOINT ["/usr/bin/dumb-init", "--"]

# Commande par défaut
CMD ["node", "server.js"]

# ===== Étiquettes de métadonnées =====
ARG BUILD_DATE
ARG VCS_REF
ARG VERSION

LABEL org.opencontainers.image.created=$BUILD_DATE
LABEL org.opencontainers.image.url="https://github.com/ASapAbro/Projet-Dernier_metro"
LABEL org.opencontainers.image.source="https://github.com/ASapAbro/Projet-Dernier_metro"
LABEL org.opencontainers.image.version=$VERSION
LABEL org.opencontainers.image.revision=$VCS_REF
LABEL org.opencontainers.image.vendor="Dernier Metro API Team"
LABEL org.opencontainers.image.title="Dernier Metro API"
LABEL org.opencontainers.image.description="API REST pour consulter les horaires du dernier métro parisien"
LABEL org.opencontainers.image.authors="team@dernier-metro.fr"
