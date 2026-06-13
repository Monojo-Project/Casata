#!/bin/bash
# /usr/local/casata/modules/search.sh

TEXTO=$1
DATA_DIR="/usr/local/casata/data"

echo -e "${YELLOW}Resultados de búsqueda para:${NC} $TEXTO\n"
FOUND=0

if [ -z "$(ls -A "$DATA_DIR" 2>/dev/null)" ]; then
    echo "La base de datos local está vacía. Ejecuta 'casata update' primero."
    exit 0
fi

for DB_FILE in "$DATA_DIR"/*.json; do
    # Leer campos usando jq
    PKG_NAME=$(jq -r '.name' "$DB_FILE")
    PKG_DESC=$(jq -r '.description // "Sin descripción"' "$DB_FILE")
    
    # Comprobar si el texto coincide con el nombre o la descripción (case-insensitive)
    if [[ "${PKG_NAME,,}" == *"${TEXTO,,}"* ]] || [[ "${PKG_DESC,,}" == *"${TEXTO,,}"* ]]; then
        echo -e "${GREEN}$PKG_NAME${NC} - $PKG_DESC"
        FOUND=$((FOUND + 1))
    fi
done

if [ $FOUND -eq 0 ]; then
    echo -e "${RED}No se encontraron paquetes que coincidan con '${TEXTO}'.${NC}"
fi
