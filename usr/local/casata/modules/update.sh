#!/bin/bash
# /usr/local/casata/modules/update.sh

CASATA_ROOT="/usr/local/casata"
METAREPOS_DIR="$CASATA_ROOT/repos/metarepos"
SINGREPOS_DIR="$CASATA_ROOT/repos/singrepos"
DATA_DIR="$CASATA_ROOT/data"

echo -e "${YELLOW}Actualizando ecosistema de paquetes Casata...${NC}"

if [ -z "$(ls -A "$METAREPOS_DIR" 2>/dev/null)" ]; then
    echo -e "${RED}No hay metarepos agregados. Usa 'casata add repo URL' primero.${NC}"
    exit 0
fi

for REPO_FILE in "$METAREPOS_DIR"/*.json; do
    REPO_NAME=$(jq -r '.name // "Desconocido"' "$REPO_FILE")
    echo -e "\n${GREEN}► Sincronizando desde metarepo:${NC} $REPO_NAME"

    # Leer los paquetes del metarepo (ignorando la clave "name")
    while read -r PKG_NAME SINGREPO_URL; do
        if [ -z "$PKG_NAME" ] || [ -z "$SINGREPO_URL" ]; then continue; fi
        
        echo -e "  -> Procesando paquete: ${YELLOW}$PKG_NAME${NC}"
        
        # 1. Descargar el Singrepo
        if wget -qO "$SINGREPOS_DIR/${PKG_NAME}.json" "$SINGREPO_URL"; then
            
            # 2. Leer la URL de los datos desde el singrepo recién bajado
            DATA_URL=$(jq -r '.data_url' "$SINGREPOS_DIR/${PKG_NAME}.json")
            
            if [ "$DATA_URL" != "null" ] && [ -n "$DATA_URL" ]; then
                # 3. Descargar los metadatos a la base de datos local
                echo -n "     ↳ Actualizando base de datos local... "
                if wget -qO "$DATA_DIR/${PKG_NAME}.json" "$DATA_URL"; then
                    echo -e "${GREEN}COMPLETO${NC}"
                else
                    echo -e "${RED}FALLO (Metadatos)${NC}"
                fi
            fi
        else
            echo -e "     ${RED}↳ FALLO al conectar con el singrepo${NC}"
        fi
        
    done < <(jq -r 'to_entries[] | select(.key != "name" and (.value | type == "string")) | "\(.key) \(.value)"' "$REPO_FILE")
done

echo -e "\n${YELLOW}Base de datos de Casata actualizada correctamente.${NC}"
