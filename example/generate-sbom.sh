#!/bin/bash
set -euxo pipefail

name_prefix="${1:-ubuntu-26.04-uefi-amd64}"

# see https://github.com/anchore/syft/releases
# renovate: datasource=github-releases depName=anchore/syft
SYFT_VERSION='1.51.0'

# see https://github.com/anchore/grype/releases
# renovate: datasource=github-releases depName=anchore/grype
GRYPE_VERSION='0.118.0'

# download and install syft.
if ! command -v syft >/dev/null 2>&1; then
    syft_url="https://github.com/anchore/syft/releases/download/v${SYFT_VERSION}/syft_${SYFT_VERSION}_linux_amd64.deb"
    t="$(mktemp -q -d --suffix=.syft)"
    wget -q -O "$t/syft_${SYFT_VERSION}_linux_amd64.deb" "$syft_url"
    dpkg -i "$t/syft_${SYFT_VERSION}_linux_amd64.deb"
    rm -rf "$t"
fi

# download and install grype.
if ! command -v grype >/dev/null 2>&1; then
    grype_url="https://github.com/anchore/grype/releases/download/v${GRYPE_VERSION}/grype_${GRYPE_VERSION}_linux_amd64.deb"
    t="$(mktemp -q -d --suffix=.grype)"
    wget -q -O "$t/grype_${GRYPE_VERSION}_linux_amd64.deb" "$grype_url"
    dpkg -i "$t/grype_${GRYPE_VERSION}_linux_amd64.deb"
    rm -rf "$t"
fi

# download and install the grype templates.
templates=(
    html.tmpl
)
for template in "${templates[@]}"; do
    if ! test -f "/usr/local/share/grype/templates/$template"; then
        grype_template_url="https://github.com/anchore/grype/raw/refs/tags/v${GRYPE_VERSION}/templates/$template"
        install -d /usr/local/share/grype/templates
        wget -q -O "/usr/local/share/grype/templates/$template" "$grype_template_url"
    fi
done

# install jq.
apt-get install -y jq

# share the files with the host machine.
pushd /vagrant

# generate the SBOM.
echo "Generating the SBOM of the installed dpkg packages..."
syft \
    scan \
    dir:/ \
    --override-default-catalogers=file,dpkg-db-cataloger \
    --output "json=$name_prefix-sbom.json"

# show a summary of the SBOM.
# NB to list all the packages execute:
#       jq -r '.artifacts[] | select(.type == "deb") | .name + " " + .version' "$name_prefix-sbom.json" | sort
cat <<EOF

Used Syft catalogers:

$(jq -r '.descriptor.configuration.catalogers.used[]' "$name_prefix-sbom.json")

Types of artifacts in the SBOM:

$(jq -r '.artifacts[] | .type' "$name_prefix-sbom.json" | sort --unique)
EOF

# scan the SBOM for vulnerabilities.
echo "Scanning the SBOM for vulnerabilities and saving output as json..."
grype \
    "$name_prefix-sbom.json" \
    --output "json=$name_prefix-sbom-vulnerabilities.json"
echo "Scanning the SBOM for vulnerabilities and saving output as html..."
grype \
    "$name_prefix-sbom.json" \
    --output "template=$name_prefix-sbom-vulnerabilities.html" \
    --template /usr/local/share/grype/templates/html.tmpl

# show a summary of the vulnerabilities.
# NB you can also filter them, e.g., by fix state:
#     jq -r '.matches[] | select(.vulnerability.fix.state == "fixed") | .vulnerability.id' "$name_prefix-sbom-vulnerabilities.json" | sort --unique
cat <<EOF

Number of vulnerabilities:

$(jq -r '.matches[] | .vulnerability.id' "$name_prefix-sbom-vulnerabilities.json" | sort --unique --reverse | wc -l)

The most recent vulnerabilities:

$(jq -r '.matches[] | .vulnerability.id' "$name_prefix-sbom-vulnerabilities.json" | sort --unique --reverse | head -n 10)
EOF
