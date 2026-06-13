#!/bin/bash
# /usr/local/casata/modules/add.sh

TYPE=$1
URL=$2

CASATA_ROOT="/usr/local/casata"
METAREPOS_DIR="$CASATA_ROOT/repos/metarepos"
SINGREPOS_DIR="$CASATA_ROOT/repos/singrepos"
DATA_DIR="$CASATA_ROOT/data"

mkdir -p "$METAREPOS_DIR" "$SINGREPOS_DIR" "$DATA_DIR"

if ! command -v jq &> /dev/null || ! command -v wget &> /dev/null; then
    echo -e "${RED}Error: Se requieren 'jq' y 'wget' instalados.${NC}"
    exit 1
fi

if [ "$TYPE" == "repo" ]; then
    echo -e "${GREEN}Descargando metarepo...${NC}"
    TEMP_FILE=$(mktemp)
    if wget -qO "$TEMP_FILE" "$URL"; then
        REPO_NAME=$(jq -r '.name // keys[0]' "$TEMP_FILE")
        mv "$TEMP_FILE" "$METAREPOS_DIR/${REPO_NAME}.json"
        echo -e "${GREEN}Metarepo [${REPO_NAME}] guardado con éxito.${NC}"
    else
        echo -e "${RED}Error al descargar el metarepo.${NC}"; rm -f "$TEMP_FILE"; exit 1
    fi

elif [ "$TYPE" == "singrepo" ]; then
    echo -e "${GREEN}Descargando singrepo...${NC}"
    TEMP_FILE=$(mktemp)
    if wget -qO "$TEMP_FILE" "$URL"; then
        PKG_NAME=$(jq -r '.name' "$TEMP_FILE")
        DATA_URL=$(jq -r '.data_url' "$TEMP_FILE")
        
        if [ "$PKG_NAME" == "null" ] || [ "$DATA_URL" == "null" ]; then
            echo -e "${RED}Error: El JSON del singrepo no tiene una estructura válida (name/data_url).${NC}"
            rm -f "$TEMP_FILE"; exit 1
        fi
        
        # Guardar Singrepo
        mv "$TEMP_FILE" "$SINGREPOS_DIR/${PKG_NAME}.json"
        echo -e "${GREEN}Singrepo [${PKG_NAME}] registrado.${NC}"
        
        # Descargar su base de datos correspondiente inmediatamente
        echo -n "  -> Descargando metadatos para la base de datos local... "
        if wget -qO "$DATA_DIR/${PKG_NAME}.json" "$DATA_URL"; then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${RED}FALLO (No se pudo obtener el archivo de datos)${NC}"
        fi
    else
        echo -e "${RED}Error al descargar el singrepo.${NC}"; rm -f "$TEMP_FILE"; exit 1
    fi
fi
