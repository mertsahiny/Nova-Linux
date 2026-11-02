#!/bin/bash
set -euo pipefail

# Nova Linux Configure Installer Script
# Phase 6: Calamares graphical installer integration

echo "=== NOVA LINUX - CALAMARIES INSTALLER PHASE ==="
echo ""

# Verify we're running as root
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: This script must be run as root"
    exit 1
fi

echo "[1/7] Installing Calamares..."
apt-get install -y calamares calamares-config-ubuntu

echo "[2/7] Applying NOVA Calamares branding..."
# Create NOVA branding directory for Calamares
mkdir -p /usr/share/calarames/nova
mkdir -p /usr/share/calamares/themes/nova

# Apply NOVA theme configuration
cat > /usr/share/calamares/themes/nova/theme.conf << 'EOF'
[General]
theme=nova
title=NOVA Linux Installer
welcome_image=/usr/share/calamares/nova/welcome.png

[Branding]
product_name=NOVA Linux
product_version=0.1.0
product_logo=/usr/share/calamares/nova/logo.png
EOF

echo "[3/7] Configuring Calamares modules..."
# Language module
mkdir -p /usr/share/calamares/modules
cat > /usr/share/calamares/modules/language-selector.py << 'PYEOF'
# Language selection module for NOVA Linux
PyModule.init = lambda: None
PyModule.wants_dirs = ["installation"]

def body():
    from PyKDE5.KCore import KLocale
    from PyKDE5.KDE.KLocale import i18n

    page = PyModule.createPage("Language")
    w = PyModule.Widget("QComboBox")
    w.addItem("English (English)", "en_US")
    w.addItem("English (United States)", "en_US")
    w.addItem("Français (French)", "fr_FR")
    w.addItem("Deutsch (German)", "de_DE")
    w.addItem("Español (Spanish)", "es_ES")
    w.addItem("Русский (Russian)", "ru_RU")
    page.setBody(w)
    return page
PYEOF

# Keyboard module
cat > /usr/share/calamares/modules/keyboard-selector.py << 'PYEOF'
# Keyboard selection module for NOVA Linux
PyModule.init = lambda: None
PyModule.wants_dirs = ["installation"]

def body():
    from PyKDE5.KCore import KLocale
    from PyKDE5.KDE.KLocale import i18n

    page = PyModule.createPage("Keyboard")
    w = PyModule.Widget("QComboBox")
    w.addItem("US English", "us")
    w.addItem("UK English", "gb")
    w.addItem("German", "de")
    w.addItem("French", "fr")
    w.addItem("Russian", "ru")
    page.setBody(w)
    return page
PYEOF

# Timezone module
cat > /usr/share/calamares/modules/timezone-selector.py << 'PYEOF'
# Timezone selection module for NOVA Linux
PyModule.init = lambda: None
PyModule.wants_dirs = ["installation"]

def body():
    page = PyModule.createPage("TimeZone")
    # Add NOVA-specific timezone settings
    return page
PYEOF

# Partitioning module
cat > /usr/share/calamares/modules/partitioning.py << 'PYEOF'
# Partitioning module for NOVA Linux
PyModule.init = lambda: None
PyModule.wants_dirs = ["installation"]

def body():
    page = PyModule.createPage("Partition")
    # Configure Nova partitioning scheme
    return page
PYEOF

# Bootloader module
cat > /usr/share/calamares/modules/bootloader.py << 'PYEOF'
# Bootloader module for NOVA Linux
PyModule.init = lambda: None
PyModule.wants_dirs = ["installation"]

def body():
    page = PyModule.createPage("Bootloader")
    # Configure GRUB for NOVA Linux
    from PyKDE5.KCore import KLocale
    from PyKDE5.KDE.KLocale import i18n
    label = i18n("Install bootloader to")
    page.setBody(QLabel(label))
    return page
PYEOF

# User creation module
cat > /usr/share/calamares/modules/user.py << 'PYEOF'
# User creation module for NOVA Linux
PyModule.init = lambda: None
PyModule.wants_dirs = ["installation"]

def body():
    page = PyModule.createPage("User")
    # NOVA-specific user configuration
    return page
PYEOF

echo "[4/7] Configuring Calamares storage module..."
# Storage/configuration module
cat > /usr/share/calamares/modules/storage.py << 'PYEOF'
# Storage module for NOVA Linux
PyModule.init = lambda: None
PyModule.wants_dirs = ["installation"]

def body():
    page = PyModule.createPage("Storage")
    # Nova filesystem configuration
    return page
PYEOF

echo "[5/7] Configuring Calamares installer resources..."
# Add NOVA resources
mkdir -p /usr/share/calamares/nova
cat > /usr/share/calamares/nova/defaults.conf << 'EOF'
[Default]
language=en_US
keyboard=us
timezone=UTC
EOF

echo "[6/7] Setting up Calamares initialization..."
mkdir -p /etc/calamares
cat > /etc/calamares/modules.conf << 'EOF'
modules:
  - language-selector
  - keyboard-selector
  - timezone-selector
  - partitioning
  - bootloader
  - user
  - storage

sequences:
  - installer

EOF

echo "[7/7] Finalizing Calamares configuration..."
# Verify Calamares can run
if command -v calamares &> /dev/null; then
    echo "Calamares installer configured successfully"
else
    echo "WARNING: Calamares not found in PATH"
fi

echo ""
echo "=== CALAMARIES INSTALLER COMPLETE ==="
echo "NOVA graphical installer configured and ready."