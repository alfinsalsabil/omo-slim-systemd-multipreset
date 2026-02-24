#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]; then
  echo "❌ Please run as root (sudo ./install.sh)"
  exit 1
fi

# Detect the real user and home directory securely
REAL_USER="${SUDO_USER:-$USER}"
REAL_HOME=$(getent passwd "$REAL_USER" | cut -d: -f6)
REAL_GROUP=$(id -gn "$REAL_USER")

echo "==============================================="
echo "  omo-slim Multipreset Systemd Installer"
echo "==============================================="
echo "Target User: $REAL_USER ($REAL_HOME)"
echo ""

read -p "Enter OpenCode WebUI Username: " OC_USER
read -s -p "Enter OpenCode WebUI Password: " OC_PASS
echo -e "\n"

echo "Which Auth Method do you use?"
echo "1) Official API Key (e.g., GOOGLE_GENERATIVE_AI_API_KEY)"
echo "2) OAuth / Token Plugin (e.g., opencode-antigravity-auth, opencode-ag-auth)"
read -p "Select [1/2]: " AUTH_METHOD

API_KEY_ENV=""
if [ "$AUTH_METHOD" == "1" ]; then
    read -p "Enter your API Key: " API_KEY
    API_KEY_ENV="GOOGLE_GENERATIVE_AI_API_KEY=$API_KEY"
fi

echo -e "\n⚙️ Generating Environment files..."
mkdir -p /etc/opencode

# Define preset ports (Modify if your setup uses different ports)
declare -A PORTS=( ["maks"]="4001" ["mid"]="4002" ["low"]="4003" )

for PRESET in maks mid low; do
    ENV_FILE="/etc/opencode/opencode-$PRESET.env"
    echo "OPENCODE_SERVER_PASSWORD=$OC_PASS" > "$ENV_FILE"
    echo "OPENCODE_SERVER_USERNAME=$OC_USER" >> "$ENV_FILE"
    echo "PORT=${PORTS[$PRESET]}" >> "$ENV_FILE"
    echo "OH_MY_OPENCODE_SLIM_PRESET=$PRESET" >> "$ENV_FILE"
    echo "XDG_DATA_HOME=$REAL_HOME/.local/share/opencode-$PRESET" >> "$ENV_FILE"
    
    if [ "$AUTH_METHOD" == "1" ]; then
        echo "$API_KEY_ENV" >> "$ENV_FILE"
    fi
    
    chmod 600 "$ENV_FILE"
    echo "✔ Created $ENV_FILE"
done

echo -e "\n📂 Setting up Data Directories..."
for PRESET in maks mid low; do
    TARGET_DIR="$REAL_HOME/.local/share/opencode-$PRESET/opencode"
    mkdir -p "$TARGET_DIR"
    chown -R "$REAL_USER:$REAL_GROUP" "$REAL_HOME/.local/share/opencode-$PRESET"
done

if [ "$AUTH_METHOD" == "2" ]; then
    echo -e "\n🔐 Setting up OAuth State..."
    SOURCE_AUTH="$REAL_HOME/.local/share/opencode/auth.json"
    
    for PRESET in maks mid low; do
        TARGET_DIR="$REAL_HOME/.local/share/opencode-$PRESET/opencode"
        
        if [ -f "$SOURCE_AUTH" ]; then
            cp "$SOURCE_AUTH" "$TARGET_DIR/auth.json"
            chmod 600 "$TARGET_DIR/auth.json"
            # Ensure the user retains ownership of the copied file
            chown "$REAL_USER:$REAL_GROUP" "$TARGET_DIR/auth.json"
            echo "✔ Copied auth.json to $PRESET profile."
        else
            echo "⚠ WARNING: $SOURCE_AUTH not found!"
            echo "  Please run 'opencode auth login' manually later, and copy auth.json to:"
            echo "  $TARGET_DIR/auth.json"
        fi
    done
fi

echo -e "\n🚀 Deploying Systemd Template..."
mkdir -p /etc/systemd/system

# Substitute User dynamically based on REAL_USER using | as delimiter
sed "s|User=fine|User=$REAL_USER|g" templates/opencode@.service > /tmp/opencode@.service
sed -i "s|Group=fine|Group=$REAL_GROUP|g" /tmp/opencode@.service
sed -i "s|WorkingDirectory=\"/home/fine\"|WorkingDirectory=\"$REAL_HOME\"|g" /tmp/opencode@.service
sed -i "s|ExecStart=\"/home/fine|ExecStart=\"$REAL_HOME|g" /tmp/opencode@.service

cp /tmp/opencode@.service /etc/systemd/system/opencode@.service
rm /tmp/opencode@.service

systemctl daemon-reload
echo "✔ Systemd reloaded."

echo -e "\n⚡ Starting all presets (low, mid, maks)..."
systemctl enable --now opencode@low opencode@mid opencode@maks

echo -e "\n==============================================="
echo "✅ Installation Complete!"
echo "Check status with: systemctl status 'opencode@*'"
echo "If using Cloudflare Tunnel, don't forget to update your config-snippet.yml!"
echo "==============================================="
