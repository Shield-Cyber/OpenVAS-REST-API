
#!/bin/bash

# Exit on any errors
set -e

# Color codes for output messages
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[1;33m"
NC="\033[0m" # No Color

# Default values for flags
subscriptionID=""
locationName=""
subscriptionAPIKey=""
instDir="/opt/shield/scripts"
downloadURL="https://raw.githubusercontent.com/Shield-Cyber/ShieldCyber-REST-API/main/scripts/"

# Help message for usage
usage() {
    echo -e "${YELLOW}Usage: $0 [options]${NC}"
    echo "Options:"
    echo "  -s    Subscription ID"
    echo "  -l    Location Name"
    echo "  -k    Subscription API Key"
    echo "  -h    Display this help message"
    exit 1
}

# Parse command line options
while getopts ":s:l:k:h" opt; do
    case ${opt} in
        s )
            subscriptionID=$OPTARG
            ;;
        l )
            locationName=$OPTARG
            ;;
        k )
            subscriptionAPIKey=$OPTARG
            ;;
        h )
            usage
            ;;
        \? )
            echo -e "${RED}Invalid Option: -$OPTARG${NC}" 1>&2
            usage
            ;;
        : )
            echo -e "${RED}Invalid Option: -$OPTARG requires an argument${NC}" 1>&2
            usage
            ;;
    esac
done
shift $((OPTIND -1))

# Function to ensure directory exists
ensure_directory() {
    local directory=$1

    if [ ! -d "$directory" ]; then
        mkdir -p "$directory"
        echo -e "${YELLOW}$directory created.${NC}"
    fi
}

# Function to download a file
download_file() {
    local url=$downloadURL$1
    local filename=$(basename "$url")
    local filepath="$instDir/$filename"

    ensure_directory "$instDir"

    echo -e "${YELLOW}Downloading $filename to $instDir...${NC}"
    curl -sS "$url" -o "$filepath"
    echo -e "${GREEN}$filename downloaded to $instDir!${NC}"
}

# Install prerequisites
sudo apt update -y && sudo apt upgrade -y 
echo "Installing prerequisites..."
sudo apt update -y
sudo apt install wget -y
curl -o packages-microsoft-prod.deb https://packages.microsoft.com/config/debian/12/packages-microsoft-prod.deb # Someone needs to make this dynamic and check the OS version.
sudo dpkg -i packages-microsoft-prod.deb
sudo rm packages-microsoft-prod.deb
sudo apt update -y
sudo apt install -y dotnet-sdk-8.0
sudo apt install -y aspnetcore-runtime-8.0
sudo apt install -y jq 
sudo apt install -y unzip
sudo apt install -y curl
sudo apt update -y

# Download and setup Shield Linux Scanner Service
echo "Downloading and setting up Shield Linux Scanner Service..."
mkdir -p /opt/shield
cd /opt/shield
wget https://shieldcyberstoregen.blob.core.windows.net/sc-shield-services/shield-linux.zip -O shield-linux.zip
unzip -o shield-linux.zip -d /opt/shield
rm -rf /opt/shield/__MACOSX
if [ -d "/opt/shield/shield-linux" ]; then
    mv /opt/shield/shield-linux/* /opt/shield/
    rmdir /opt/shield/shield-linux
fi
sudo chmod +x /opt/shield/ShieldCyber.Agent.Shield

# Ensure /opt/shield directory exists
ensure_directory "/opt/shield"

# Update appsettings.json
echo "Updating appsettings.json..."
jq --arg subscriptionID "$subscriptionID" \
   --arg locationName "$locationName" \
   --arg subscriptionAPIKey "$subscriptionAPIKey" \
   '.AppSettings.SubscriptionId = $subscriptionID | .AppSettings.LocationName = $locationName | .AppSettings.SubscriptionApiKey = $subscriptionAPIKey' \
   /opt/shield/appsettings.json > /opt/shield/appsettings.tmp.json
mv /opt/shield/appsettings.tmp.json /opt/shield/appsettings.json

# Create the ShieldCyberAgent Service
echo "Setting up ShieldCyberAgent Service..."
sudo cp /opt/shield/ShieldCyber.Agent.Shield.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable ShieldCyber.Agent.Shield.service
sudo systemctl start ShieldCyber.Agent.Shield.service
echo -e "${GREEN}ShieldCyberAgent Service setup complete.${NC}"

# Download Shield Executable and Helper Scripts
echo -e "${YELLOW}Setting up Shield Scanner Software...${NC}"
curl -sSo /usr/local/bin/shield https://raw.githubusercontent.com/Shield-Cyber/ShieldCyber-REST-API/main/scripts/shield
chmod +x /usr/local/bin/shield
download_file full-install.sh
download_file vuln-update.sh
download_file full-update.sh
echo -e "${GREEN}Shield Scanner Software setup complete.${NC}"

# Download update-service.sh to /opt/shield
echo "Downloading update-service.sh to /opt/shield..."
curl -sS "https://raw.githubusercontent.com/Shield-Cyber/ShieldCyber-REST-API/main/update-service.sh" -o "/opt/shield/update-service.sh"
# Alternatively, you can use wget:
# wget https://raw.githubusercontent.com/Shield-Cyber/ShieldCyber-REST-API/main/update-service.sh -O /opt/shield/update-service.sh

# Set executable permission for the script
chmod +x /opt/shield/update-service.sh

echo -e "${GREEN}update-service.sh downloaded and setup complete.${NC}"