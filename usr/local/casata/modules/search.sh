#!/bin/bash
# /usr/local/casata/modules/search.sh

DATA_DIR="/usr/local/casata/data"

# Colores (ajusta según tus definiciones)
YELLOW="\e[33m"
GREEN="\e[32m"
RED="\e[31m"
NC="\e[0m"

# Función para listar todos los paquetes
list_all() {
    if [ -z "$(ls -A "$DATA_DIR" 2>/dev/null)" ]; then
        echo "La base de datos local está vacía. Ejecuta 'casata update' primero."
        exit 0
    fi
    for DB_FILE in "$DATA_DIR"/*.json; do
        PKG_NAME=$(jq -r '.name' "$DB_FILE")
        PKG_DESC=$(jq -r '.description // "Sin descripción"' "$DB_FILE")
        echo -e "${GREEN}$PKG_NAME${NC} - $PKG_DESC"
    done
}

# Si no hay argumentos -> listar todo
if [ $# -eq 0 ]; then
    echo -e "${YELLOW}Listando todos los paquetes disponibles:${NC}\n"
    list_all
    exit 0
fi

# Heurística: si hay más de un argumento, ver si parecen archivos del directorio actual (expansión de *)
expansion_globo=false
if [ $# -gt 1 ]; then
    # Comprobamos cuántos argumentos existen realmente como archivos/directorios en $PWD
    matches=0
    for arg in "$@"; do
        if [ -e "$arg" ]; then
            matches=$((matches + 1))
        fi
    done
    # Si la mayoría son archivos existentes, muy probablemente fue una expansión de *
    if [ $matches -gt 0 ]; then
        expansion_globo=true
    fi
fi

if $expansion_globo; then
    echo -e "${YELLOW}⚠️  Parece que usaste un metacarácter (*, ?, [) sin entrecomillar.${NC}"
    echo "   El shell expandió el patrón a los archivos del directorio actual."
    echo "   Para buscar con patrones glob, utiliza comillas: 'casata search \"patron\"'."
    echo "   Mostrando todos los paquetes disponibles en su lugar.\n"
    list_all
    exit 0
fi

# Si llegamos aquí, procesamos los argumentos normalmente
TEXTO="$1"  # solo consideramos el primer argumento para la búsqueda principal
texto_lower="${TEXTO,,}"

echo -e "${YELLOW}Resultados de búsqueda para:${NC} $TEXTO\n"
FOUND=0

if [ -z "$(ls -A "$DATA_DIR" 2>/dev/null)" ]; then
    echo "La base de datos local está vacía. Ejecuta 'casata update' primero."
    exit 0
fi

# Detectar si el texto contiene metacaracteres glob (*, ?, [)
if [[ "$texto_lower" == *[*?[]* ]]; then
    # MODO PATRÓN GLOB
    for DB_FILE in "$DATA_DIR"/*.json; do
        pkg_name=$(jq -r '.name' "$DB_FILE")
        pkg_desc=$(jq -r '.description // "Sin descripción"' "$DB_FILE")
        name_lower="${pkg_name,,}"
        desc_lower="${pkg_desc,,}"

        if [[ "$name_lower" == $texto_lower ]] || [[ "$desc_lower" == $texto_lower ]]; then
            echo -e "${GREEN}$pkg_name${NC} - $pkg_desc"
            FOUND=$((FOUND + 1))
        fi
    done
else
    # MODO SUBCADENA (comportamiento original)
    for DB_FILE in "$DATA_DIR"/*.json; do
        pkg_name=$(jq -r '.name' "$DB_FILE")
        pkg_desc=$(jq -r '.description // "Sin descripción"' "$DB_FILE")

        if [[ "${pkg_name,,}" == *"$texto_lower"* ]] || [[ "${pkg_desc,,}" == *"$texto_lower"* ]]; then
            echo -e "${GREEN}$pkg_name${NC} - $pkg_desc"
            FOUND=$((FOUND + 1))
        fi
    done
fi

if [ $FOUND -eq 0 ]; then
    echo -e "${RED}No se encontraron paquetes que coincidan con '${TEXTO}'.${NC}"
fi
