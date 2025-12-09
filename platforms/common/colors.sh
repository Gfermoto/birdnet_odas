#!/bin/bash
# Цвета для вывода (используется всеми скриптами)

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

print_step() { echo -e "${GREEN}[*] $1${NC}"; }
print_info() { echo -e "${CYAN}[i] $1${NC}"; }
print_success() { echo -e "${GREEN}[+] $1${NC}"; }
print_error() { echo -e "${RED}[-] $1${NC}"; }
print_warning() { echo -e "${YELLOW}[!] $1${NC}"; }
