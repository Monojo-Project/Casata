#!/bin/bash
# /usr/local/casata/modules/remove.sh

GLOBAL_ROOT="/usr/local/casata"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Parsear flags y nombre del paquete
AUTO_YES=0
USER_INSTALL=0
PKG_NAME=""

for arg in "$@"; do
    if [ "$arg" == "-y" ]; then AUTO_YES=1;
    elif [ "$arg" == "--user" ]; then USER_INSTALL=1;
    else PKG_NAME=$arg; fi
done

[ -z "$PKG_NAME" ] && { echo -e "${RED}Error: Falta el nombre del paquete.${NC}"; exit 1; }

# Configurar rutas según el tipo de desinstalación
if [ $USER_INSTALL -eq 1 ]; then
    APPS_DIR="$HOME/.local/casata/apps"
    GUIDE_TARGET="GUIDE-USER.json"
    INSTALL_TYPE="Usuario"
else
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Error: La desinstalación global requiere permisos de root.${NC}"
        echo -e "Usa ${YELLOW}sudo casata remove $PKG_NAME${NC} o ${YELLOW}casata remove --user $PKG_NAME${NC}."
        exit 1
    fi
    APPS_DIR="$GLOBAL_ROOT/apps"
    GUIDE_TARGET="GUIDE.json"
    INSTALL_TYPE="Global"
fi

APP_DIR="$APPS_DIR/${PKG_NAME}"

if [ ! -d "$APP_DIR" ]; then
    echo -e "${RED}Error: El paquete '$PKG_NAME' no parece estar instalado ($INSTALL_TYPE).${NC}"
    exit 1
fi

if [ $AUTO_YES -eq 0 ]; then
    echo -e "${YELLOW}Se eliminará $PKG_NAME ($INSTALL_TYPE) y todos sus enlaces del sistema.${NC}"
    read -p "¿Estás seguro? [S/n] " response
    if [[ "$response" =~ ^([nN][oO]|[nN])$ ]]; then
        echo "Desinstalación abortada."
        exit 0
    fi
fi

echo -e "${GREEN}Desinstalando $PKG_NAME ($INSTALL_TYPE)...${NC}"

GUIDE_FILE="$APP_DIR/$GUIDE_TARGET"

# Eliminar enlaces simbólicos
if [ -f "$GUIDE_FILE" ]; then
    echo " -> Eliminando enlaces del sistema..."
    jq -c '.links[]' "$GUIDE_FILE" | while read -r item; do
        DEST=$(echo "$item" | jq -r '.dest')
        LINK_NAME=$(echo "$item" | jq -r '.name')

        [ "$DEST" == "null" ] || [ "$LINK_NAME" == "null" ] && continue

        # Expansión de variables de usuario
        DEST="${DEST/#\~/$HOME}"
        DEST="${DEST//\$HOME/$HOME}"

        TARGET_LINK="$DEST/$LINK_NAME"

        # Solo borramos si el archivo existe y es un enlace simbólico (-L)
        if [ -L "$TARGET_LINK" ]; then
            rm -f "$TARGET_LINK"
            echo -e "   [-] Enlace eliminado: ${RED}$LINK_NAME${NC}"
        else
            if [ -e "$TARGET_LINK" ]; then
                echo -e "   [!] Omitido (no es un enlace): $TARGET_LINK"
            else
                echo -e "   [=] No existía: $LINK_NAME"
            fi
        fi
    done
else
    echo -e "${YELLOW}Aviso: No se encontró $GUIDE_TARGET. No se eliminarán enlaces, solo la carpeta base.${NC}"
fi

# Eliminar la carpeta de la aplicación
echo " -> Eliminando archivos base de la aplicación..."
rm -rf "$APP_DIR"

echo -e "\n${GREEN}¡$PKG_NAME desinstalado correctamente!${NC}"
