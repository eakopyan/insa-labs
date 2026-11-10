#!/bin/bash
set -euo pipefail

# Usage : sudo ./configure_containerd_registry.sh IP:PORT

CONFIG="/etc/containerd/config.toml"
CERTS_DIR="/etc/containerd/certs.d"

if [[ $EUID -ne 0 ]]; then
    echo "Erreur : exécuter avec sudo."
    exit 1
fi

if [[ $# -ne 1 ]]; then
    echo "Usage : $0 <IP-REGISTRY>:<PORT>"
    exit 1
fi

REGISTRY="$1"
REGISTRY_DIR="${CERTS_DIR}/${REGISTRY}"

echo "Configuration du Registry ${REGISTRY}..."

# 1. Vérification de la présence de la configuration
if [[ ! -f "$CONFIG" ]]; then
    echo "Erreur : $CONFIG introuvable."
    exit 1
fi

# 2. Configuration du Registry
mkdir -p "$REGISTRY_DIR"

cat > "${REGISTRY_DIR}/hosts.toml" <<EOF
server = "http://${REGISTRY}"

[host."http://${REGISTRY}"]
  capabilities = ["pull", "resolve"]
EOF

# 3. Sauvegarde de la configuration
BACKUP="${CONFIG}.bak.$(date +%Y%m%d-%H%M%S)"
cp -a "$CONFIG" "$BACKUP"

# 4. Modification de la section CRI v1 existante
python3 - "$CONFIG" "$CERTS_DIR" <<'PY'
import re
import sys
from pathlib import Path

config = Path(sys.argv[1])
registry_path = sys.argv[2]

text = config.read_text()

# Accepte les deux styles de guillemets et l'indentation.
header_pattern = (
    r"""(?m)^[ \t]*\[plugins\."""
    r"""(?:'io\.containerd\.cri\.v1\.images'|"""
    r"""\"io\.containerd\.cri\.v1\.images\")"""
    r"""\.registry\][ \t]*$"""
)

matches = list(re.finditer(header_pattern, text))

if len(matches) != 1:
    raise SystemExit(
        f"Erreur : {len(matches)} section(s) CRI v1 registry trouvée(s). "
        "Modification annulée."
    )

header = matches[0]
next_table = re.search(
    r"(?m)^[ \t]*\[",
    text[header.end():]
)

end = (
    header.end() + next_table.start()
    if next_table
    else len(text)
)

body = text[header.end():end]

path_pattern = r"""(?m)^([ \t]*config_path[ \t]*=[ \t]*)(['"]).*?\2[ \t]*$"""

if re.search(path_pattern, body):
    body = re.sub(
        path_pattern,
        lambda m: m.group(1) + "'" + registry_path + "'",
        body,
        count=1
    )
else:
    body = "\n  config_path = '" + registry_path + "'\n" + body

text = text[:header.end()] + body + text[end:]
config.write_text(text)

print("Section CRI v1 registry mise à jour.")
PY

# 5. Validation avant redémarrage
if ! containerd --config "$CONFIG" config dump >/dev/null; then
    echo "Configuration invalide : restauration."
    cp "$BACKUP" "$CONFIG"
    exit 1
fi

# 6. Redémarrage
if ! systemctl restart containerd; then
    echo "Échec du redémarrage : restauration."
    cp "$BACKUP" "$CONFIG"
    systemctl reset-failed containerd
    systemctl restart containerd || true
    exit 1
fi

echo "Configuration terminée."
systemctl --no-pager --full status containerd
