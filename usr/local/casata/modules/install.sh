#!/bin/bash
# /usr/local/casata/modules/install.sh

GLOBAL_ROOT="/usr/local/casata"
SINGREPOS_DIR="$GLOBAL_ROOT/repos/singrepos"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Parsear flags y nombre del paquete
AUTO_YES=0
DOWNLOAD_ONLY=0
USER_INSTALL=0
PKG_NAME=""

for arg in "$@"; do
    if [ "$arg" == "-y" ]; then AUTO_YES=1;
    elif [ "$arg" == "-d" ]; then DOWNLOAD_ONLY=1;
    elif [ "$arg" == "--user" ]; then USER_INSTALL=1;
    else PKG_NAME=$arg; fi
done

[ -z "$PKG_NAME" ] && { echo -e "${RED}Error: Falta el nombre del paquete.${NC}"; exit 1; }

# Configurar rutas y validación
if [ $USER_INSTALL -eq 1 ]; then
    APPS_DIR="$HOME/.local/casata/apps"
    GUIDE_TARGET="GUIDE-USER.json"
    INSTALL_TYPE="Usuario"
else
    if [ "$EUID" -ne 0 ]; then
        echo -e "${RED}Error: La instalación global requiere permisos de root.${NC}"
        exit 1
    fi
    APPS_DIR="$GLOBAL_ROOT/apps"
    GUIDE_TARGET="GUIDE.json"
    INSTALL_TYPE="Global"
fi

mkdir -p "$APPS_DIR"

SINGREPO_FILE="$SINGREPOS_DIR/${PKG_NAME}.json"
APP_DIR="$APPS_DIR/${PKG_NAME}"

if [ ! -f "$SINGREPO_FILE" ]; then
    echo -e "${RED}Error: El singrepo de '$PKG_NAME' no existe.${NC}"
    exit 1
fi

# Pregunta confirmación
if [ $AUTO_YES -eq 0 ]; then
    read -p "¿Deseas proceder con la instalación ($INSTALL_TYPE) de $PKG_NAME? [S/n] " response
    [[ "$response" =~ ^([nN][oO]|[nN])$ ]] && { echo "Aborted."; exit 0; }
fi

DOWNLOAD_URL=$(jq -r '.download_url // .url' "$SINGREPO_FILE")
[ -z "$DOWNLOAD_URL" ] && { echo -e "${RED}Error: URL no encontrada.${NC}"; exit 1; }

echo -e "${GREEN}Preparando instalación de $PKG_NAME...${NC}"

# Descarga y Extracción
TEMP_FILE=$(mktemp)
EXTRACT_DIR=$(mktemp -d)

wget -q --show-progress -O "$TEMP_FILE" "$DOWNLOAD_URL" || { echo -e "${RED}Error descarga.${NC}"; rm -rf "$TEMP_FILE" "$EXTRACT_DIR"; exit 1; }

if [[ "$DOWNLOAD_URL" == *.zip ]]; then unzip -q "$TEMP_FILE" -d "$EXTRACT_DIR"
elif [[ "$DOWNLOAD_URL" == *.tar.gz || "$DOWNLOAD_URL" == *.tgz ]]; then tar -xzf "$TEMP_FILE" -C "$EXTRACT_DIR"
elif [[ "$DOWNLOAD_URL" == *.tar.xz ]]; then tar -xJf "$TEMP_FILE" -C "$EXTRACT_DIR"
else echo -e "${RED}Formato no soportado.${NC}"; rm -rf "$TEMP_FILE" "$EXTRACT_DIR"; exit 1; fi

SRC_DIR=$(find "$EXTRACT_DIR" -name "VERSION" -exec dirname {} \; | head -n 1)
[ -z "$SRC_DIR" ] && SRC_DIR=$(ls -d "$EXTRACT_DIR"/*/ 2>/dev/null | head -n 1)
[ -z "$SRC_DIR" ] && SRC_DIR="$EXTRACT_DIR"

[ -d "$APP_DIR" ] && rm -rf "$APP_DIR"
mkdir -p "$APP_DIR"
mv "$SRC_DIR"/* "$APP_DIR/" 2>/dev/null || mv "$SRC_DIR/".* "$APP_DIR/" 2>/dev/null
rm -rf "$TEMP_FILE" "$EXTRACT_DIR"

if [ $DOWNLOAD_ONLY -eq 1 ]; then
    echo -e "${YELLOW}Modo -d: Descargado en $APP_DIR sin enlaces.${NC}"
    exit 0
fi

echo " -> Configurando enlaces (seguridad activa)..."
GUIDE_FILE="$APP_DIR/$GUIDE_TARGET"

if [ -f "$GUIDE_FILE" ]; then
    jq -c '.links[]' "$GUIDE_FILE" | while read -r item; do
        FILE=$(echo "$item" | jq -r '.file')
        DEST=$(echo "$item" | jq -r '.dest')
        LINK_NAME=$(echo "$item" | jq -r '.name')
        EXECUTABLE=$(echo "$item" | jq -r '.executable // false')

        [ "$FILE" == "null" ] || [ "$DEST" == "null" ] || [ "$LINK_NAME" == "null" ] && continue

        DEST="${DEST/#\~/$HOME}"
        DEST="${DEST//\$HOME/$HOME}"
        mkdir -p "$DEST"

        TARGET_LINK="$DEST/$LINK_NAME"

        # --- BLOQUE DE SEGURIDAD ---
        if [ -e "$TARGET_LINK" ] || [ -L "$TARGET_LINK" ]; then
            if [ -L "$TARGET_LINK" ] && [ "$(readlink "$TARGET_LINK")" == "$APP_DIR/$FILE" ]; then
                echo -e "   [=] Ya existe enlace correcto: $LINK_NAME"
            else
                echo -e "${RED}!!! ALERTA DE SEGURIDAD !!!${NC}"
                echo -e "${RED}El archivo '$TARGET_LINK' ya existe y no pertenece a este paquete.${NC}"
                echo -e "${RED}Abortando instalación para prevenir sobreescritura maliciosa.${NC}"
                rm -rf "$APP_DIR"
                exit 1
            fi
        else
            ln -s "$APP_DIR/$FILE" "$TARGET_LINK"

            # Si executable es true, dar permisos +x
            if [ "$EXECUTABLE" == "true" ]; then
                chmod +x "$APP_DIR/$FILE"
                echo -e "   [+] Enlazado: ${YELLOW}$LINK_NAME${NC} -> $DEST (ejecutable)"
            else
                echo -e "   [+] Enlazado: ${YELLOW}$LINK_NAME${NC} -> $DEST"
            fi
        fi
    done
else
    echo -e "${YELLOW}Aviso: No se encontró $GUIDE_TARGET.${NC}"
fi

echo -e "\n${GREEN}¡$PKG_NAME instalado correctamente!${NC}"
