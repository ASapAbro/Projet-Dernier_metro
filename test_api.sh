#!/bin/bash
# Script de test d'intégration API
# Version: 1.0.0

set -e

BASE_URL="http://localhost:3000"
FAILED_TESTS=0
TOTAL_TESTS=0

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Fonction de test générique
test_endpoint() {
    local endpoint=$1
    local expected_status=$2
    local test_name=$3
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -e "${YELLOW}Test ${TOTAL_TESTS}: ${test_name}${NC}"
    
    response=$(curl -s -w "%{http_code}" -o /tmp/response.json "${BASE_URL}${endpoint}")
    status_code=$(echo "$response" | tail -c 4)
    
    if [ "$status_code" -eq "$expected_status" ]; then
        echo -e "${GREEN}✅ PASS - Status: $status_code${NC}"
        if [ -f /tmp/response.json ]; then
            echo "Response preview: $(head -c 200 /tmp/response.json)..."
        fi
    else
        echo -e "${RED}❌ FAIL - Expected: $expected_status, Got: $status_code${NC}"
        if [ -f /tmp/response.json ]; then
            echo "Error response: $(cat /tmp/response.json)"
        fi
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    echo ""
}

# Fonction pour tester avec contenu JSON
test_json_endpoint() {
    local endpoint=$1
    local expected_status=$2
    local test_name=$3
    local required_fields=$4
    
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    
    echo -e "${YELLOW}Test ${TOTAL_TESTS}: ${test_name}${NC}"
    
    response=$(curl -s -w "%{http_code}" -H "Accept: application/json" "${BASE_URL}${endpoint}")
    status_code=$(echo "$response" | tail -c 4)
    json_body=$(echo "$response" | head -c -4)
    
    if [ "$status_code" -eq "$expected_status" ]; then
        echo -e "${GREEN}✅ PASS - Status: $status_code${NC}"
        
        # Vérifier les champs requis si spécifiés
        if [ -n "$required_fields" ]; then
            for field in $required_fields; do
                if echo "$json_body" | grep -q "\"$field\""; then
                    echo "  ✅ Field '$field' present"
                else
                    echo -e "  ${RED}❌ Field '$field' missing${NC}"
                    FAILED_TESTS=$((FAILED_TESTS + 1))
                fi
            done
        fi
        
        echo "Response preview: $(echo "$json_body" | head -c 200)..."
    else
        echo -e "${RED}❌ FAIL - Expected: $expected_status, Got: $status_code${NC}"
        echo "Error response: $json_body"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
    echo ""
}

echo "� Démarrage des tests d'intégration API"
echo "Base URL: $BASE_URL"
echo "=========================================="

# Attendre que l'API soit prête
echo "⏳ Attente du démarrage de l'API..."
for i in {1..30}; do
    if curl -s -f "$BASE_URL/health" > /dev/null 2>&1; then
        echo "✅ API prête !"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "❌ Timeout: L'API n'a pas démarré dans les temps"
        exit 1
    fi
    sleep 1
done

echo ""

# Tests des endpoints
test_json_endpoint "/health" 200 "Health Check" "status timestamp"
test_json_endpoint "/api/v1/metro/info" 200 "Metro Info" "is_service_active next_closure"
test_json_endpoint "/api/v1/stations" 200 "Stations List" ""
test_json_endpoint "/api/v1/stations?search=chatelet" 200 "Stations Search" ""
test_endpoint "/api/v1/stations/1" 200 "Station by ID"
test_endpoint "/api/v1/stations/999999" 404 "Station Not Found"
test_endpoint "/api/unknown" 404 "Unknown Endpoint"

# Test avec méthode non autorisée
TOTAL_TESTS=$((TOTAL_TESTS + 1))
echo -e "${YELLOW}Test ${TOTAL_TESTS}: POST Method Not Allowed${NC}"
post_response=$(curl -s -w "%{http_code}" -X POST "${BASE_URL}/api/v1/stations")
post_status=$(echo "$post_response" | tail -c 4)
if [ "$post_status" -eq 405 ] || [ "$post_status" -eq 404 ]; then
    echo -e "${GREEN}✅ PASS - Status: $post_status${NC}"
else
    echo -e "${RED}❌ FAIL - Expected: 405 or 404, Got: $post_status${NC}"
    FAILED_TESTS=$((FAILED_TESTS + 1))
fi
echo ""

# Résultats finaux
echo "=========================================="
echo "� Résultats des tests:"
echo "Total: $TOTAL_TESTS"
echo -e "Réussis: ${GREEN}$((TOTAL_TESTS - FAILED_TESTS))${NC}"
echo -e "Échoués: ${RED}$FAILED_TESTS${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "${GREEN}🎉 Tous les tests sont passés !${NC}"
    exit 0
else
    echo -e "${RED}💥 $FAILED_TESTS test(s) ont échoué${NC}"
    exit 1
fi
