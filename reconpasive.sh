#!/bin/bash

# Colores para feedback visual
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RESET='\033[0m'

DOMAIN=$1
OUT_DIR="recon_$DOMAIN/pasivo_validado"

# --- CHECK PREVIO ---
if [ -z "$DOMAIN" ]; then
    echo -e "${RED}[!] Uso: ./recon_pasivo_v5_full.sh <dominio.com>${RESET}"
    exit 1
fi

# Auto-fix para el error de GAU (crea el config si no existe)
if [ ! -f "$HOME/.gau.toml" ]; then
    touch "$HOME/.gau.toml"
fi

mkdir -p $OUT_DIR

echo -e "${YELLOW}[*] FASE 1: Recolección Pasiva Masiva${RESET}"

# 1. Subfinder
echo -e "${GREEN}[+] Ejecutando Subfinder...${RESET}"
subfinder -d $DOMAIN -all -silent > $OUT_DIR/subfinder.txt
COUNT_SUB=$(wc -l < $OUT_DIR/subfinder.txt)
echo -e "    -> Encontrados: ${CYAN}$COUNT_SUB${RESET}"

# 2. Assetfinder
echo -e "${GREEN}[+] Ejecutando Assetfinder...${RESET}"
assetfinder --subs-only $DOMAIN > $OUT_DIR/assetfinder.txt
COUNT_ASSET=$(wc -l < $OUT_DIR/assetfinder.txt)
echo -e "    -> Encontrados: ${CYAN}$COUNT_ASSET${RESET}"

# 3. Gau (Con Verbose)
echo -e "${GREEN}[+] Ejecutando GAU (Modo Verbose)...${RESET}"
echo -e "${BLUE}[INFO] Buscando en AlienVault, Wayback, CommonCrawl...${RESET}"
gau --subs --verbose $DOMAIN | cut -d "/" -f 3 | cut -d ":" -f 1 | sort -u | grep "\.$DOMAIN$" > $OUT_DIR/gau_subs.txt
COUNT_GAU=$(wc -l < $OUT_DIR/gau_subs.txt)
echo -e "    -> Encontrados por Gau: ${CYAN}$COUNT_GAU${RESET}"

# --- FUSIÓN ---
echo -e "${YELLOW}[*] Fusionando y deduplicando fuentes...${RESET}"
cat $OUT_DIR/*.txt | sort -u > $OUT_DIR/todos_candidatos.txt
TOTAL=$(wc -l < $OUT_DIR/todos_candidatos.txt)
echo -e "${CYAN}[INFO] Total de subdominios únicos (Pasivos): $TOTAL${RESET}"


echo -e "${YELLOW}[*] FASE 2: Validación y Extracción de Datos (Con Content-Length)${RESET}"
echo -e "${BLUE}[INFO] Filtrando vivos y obteniendo tecnologías + tamaño de respuesta...${RESET}"

# HTTPX ACTUALIZADO
# -content-length: Muestra el peso de la respuesta (Vital para diferenciar errores genéricos de contenido real)
httpx -l $OUT_DIR/todos_candidatos.txt \
    -title -tech-detect -status-code -content-length -follow-redirects -ip \
    -threads 50 \
    -o $OUT_DIR/httpx_full_output.txt \
    -silent

echo -e "${YELLOW}[*] FASE 3: Clasificación de Resultados${RESET}"

# 1. URLs vivas
cat $OUT_DIR/httpx_full_output.txt | awk '{print $1}' > $OUT_DIR/vivos_urls.txt

# 2. Respuestas 200 OK
grep "\[200\]" $OUT_DIR/httpx_full_output.txt > $OUT_DIR/juicy_200.txt

# 3. Prohibidos (403/401)
grep -E "\[403\]|\[401\]" $OUT_DIR/httpx_full_output.txt > $OUT_DIR/juicy_forbidden.txt

# 4. Paneles y Admin (Keywords)
grep -iE "login|admin|dashboard|panel|dev|staging|test|jenkins|jira|grafana|swagger|api|config" $OUT_DIR/httpx_full_output.txt > $OUT_DIR/juicy_high_priority.txt

# Contadores
C_VIVOS=$(wc -l < $OUT_DIR/vivos_urls.txt)
C_PRIO=$(wc -l < $OUT_DIR/juicy_high_priority.txt)

echo -e "${GREEN}[SUCCESS] Reconocimiento finalizado.${RESET}"
echo -e "----------------------------------------------------"
echo -e "Resultados en:           ${CYAN}$OUT_DIR${RESET}"
echo -e "Archivo Maestro:         ${CYAN}$OUT_DIR/httpx_full_output.txt${RESET} (Incluye Content-Length)"
echo -e "Subdominios Vivos:       ${GREEN}$C_VIVOS${RESET}"
echo -e "Objetivos Prioritarios:  ${RED}$C_PRIO${RESET}"
echo -e "----------------------------------------------------"
echo -e "${BLUE}TIP: Para ver los sitios más grandes, ejecuta:${RESET}"
echo -e "cat $OUT_DIR/httpx_full_output.txt | grep '\[200\]' | sort -k 5 -n"
                                                                              
