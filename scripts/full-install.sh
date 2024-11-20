#!/bin/bash

instDir="/opt/shield"
password_flag=false

# Define color codes
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
NC="\033[0m" # No Color

# Function to download a file to the specified directory
download_file() {
    local url=$1
    local filename=$(basename "$url")
    local filepath="$instDir/$filename"

    echo -e "${YELLOW}Downloading $filename to $instDir... ${NC}"
    curl -fsSL "$url" -o "$filepath"
    echo -e "${GREEN}$filename downloaded to $instDir! ${NC}"

    echo "$filepath"
}

# Function to check if a directory exists and ask to overwrite it
ensure_directory() {
    local directory=$1

    if [ ! -d "$directory" ]; then
        echo -e "${RED}$directory does not exist. Exiting.${NC}"
        exit 1
    fi
}

# Function to set the password in the .env file
set_password() {
    local password="$1"
    local env_filepath="$instDir/.env"
    echo -e "PASSWORD='$password'" > "$env_filepath"
    echo -e "${GREEN}Password set successfully.${NC}"
}

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
        -P|--password)
            password_flag=true
            password="$2"
            shift
            shift
            ;;
        *)
            shift
            ;;
    esac
done

echo -e "${YELLOW}Waiting 10 Seconds Before Starting Installation ${NC}"
sleep 10

# Check if installation directory exists
ensure_directory "$instDir"

echo -e "${YELLOW}Installing Shield Scanner and its Dependencies ${NC}"

# Install Docker
echo -e "${YELLOW}Installing Docker... ${NC}"
curl -fsSL https://get.docker.com | sh || { echo -e "${RED}Docker installation script failed. ${NC}" && echo -e "${YELLOW}Reach out to Shield team for assistance in manual installation. ${NC}"; exit 1; }

# Check if Docker installation was successful
if command -v docker &> /dev/null ; then
    echo -e "${GREEN}Docker Installed successfully! ${NC}"
else
    echo -e "${RED}Docker installation failed.${NC}"
    echo -e "${YELLOW}Reach out to Shield team for assistance in manual installation. ${NC}"
    exit 1
fi

# Start Docker Daemon
echo -e "${YELLOW}Starting Docker daemon... ${NC}"
if command -v systemctl &> /dev/null; then
    sudo systemctl start docker
    sudo systemctl enable docker
elif command -v service &> /dev/null; then
    sudo service docker start
else
    echo -e "${RED}Cannot determine the init system to start Docker. Please start Docker manually.${NC}"
    echo -e "${YELLOW}Reach out to Shield team for assistance in manual installation. ${NC}"
    exit 1
fi

# Check if Docker daemon started successfully
if sudo docker info &> /dev/null ; then
    echo -e "${GREEN}Docker daemon started successfully! ${NC}"
else
    echo -e "${RED}Failed to start Docker daemon. Exiting with code 1.${NC}"
    exit 1
fi

# Download Compose File
compose_filepath=$(download_file "https://raw.githubusercontent.com/Shield-Cyber/ShieldCyber-REST-API/main/compose.yml")

# Set password if flag is provided
if [ "$password_flag" = true ]; then
    set_password "$password"
else
    # Check if .env file exists
    env_filepath="$instDir/.env"
    if [ -f "$env_filepath" ]; then
        # .env file exists, ask user if they want to update the password
        read -p "$(echo -e "${YELLOW}Installation Found: Do you want to update the password? (y/N): ${NC}")" update_choice

        if [ "$update_choice" == "y" ]; then
            read -sp "Enter Shield Scanner / API Admin Password: " password
            echo -e "\nPASSWORD=$password" > "$env_filepath"
            echo -e "\n${GREEN}Password updated successfully.${NC}"
        else
            echo -e "\n${YELLOW}Skipping password update.${NC}"
        fi
    else
        # .env file doesn't exist, create and update it
        read -sp "Enter Shield Scanner / API Admin Password: " password
        echo -e "\nPASSWORD=$password" > "$env_filepath"
    fi
fi

# Start Shield Scanner
echo -e "\n${GREEN}Starting Shield Scanner${NC}"
echo -e "${YELLOW}This may take a moment the first time.${NC}"

docker compose -f /opt/shield/compose.yml up -d > /dev/null 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}Shield Scanner Startup Complete ${NC}" 
    echo -e "${YELLOW}Please allow up to 30 minutes for the vulnerability database to download before setting up and starting scans. ${NC}"
else
    echo -e "${RED}Shield Scanner Startup Failed ${NC}"
    echo -e "${YELLOW}Reach out to Shield team for assistance in manual installation. ${NC}"
fi