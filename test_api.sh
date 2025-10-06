#!/bin/bash

# Script de validation des endpoints de l'API Dernier Metro
# Phase 1 - Database validation

echo "🧪 === VALIDATION API DERNIER METRO - PHASE 1 DATABASE ==="
echo ""

BASE_URL="http://localhost:3002"

echo "📍 1. Test de santé de l'API..."
curl -s "$BASE_URL/health" | jq '.'
echo ""

echo "🚉 2. Test de la liste des stations..."
curl -s "$BASE_URL/stations" | jq '.count, .stations[:3]'
echo ""

echo "🚊 3. Test métro station existante (Châtelet)..."
curl -s "$BASE_URL/next-metro?station=chatelet" | jq '.'
echo ""

echo "🚊 4. Test métro station avec nom complet..."
curl -s "$BASE_URL/next-metro?station=Châtelet" | jq '.'
echo ""

echo "❌ 5. Test station inexistante (avec suggestions)..."
curl -s "$BASE_URL/next-metro?station=nonexistent" | jq '.'
echo ""

echo "❌ 6. Test paramètre manquant..."
curl -s "$BASE_URL/next-metro" | jq '.'
echo ""

echo "❌ 7. Test route inexistante..."
curl -s "$BASE_URL/unknown" | jq '.'
echo ""

echo "📚 8. Test spécification OpenAPI..."
curl -s "$BASE_URL/api-docs.json" | jq '.info.title, .info.version'
echo ""

echo "✅ === FIN DES TESTS ==="
