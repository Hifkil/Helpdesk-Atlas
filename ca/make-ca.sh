#!/bin/bash
set -e
# 1. CA racine Atlas (5 ans) — la clé part au coffre, PAS dans Git
openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 \
  -keyout ca-root.key -out ca-root.crt -days 1825 -nodes \
  -subj "/C=FR/O=PME Atlas/CN=Atlas Internal Root CA"

# 2. Clé + CSR serveur helpdesk
openssl req -newkey ec -pkeyopt ec_paramgen_curve:P-256 \
  -keyout helpdesk.key -out helpdesk.csr -nodes \
  -subj "/C=FR/O=PME Atlas/CN=helpdesk.atlas.local"

# 3. Signature avec SAN (1 an)
cat > helpdesk.ext << 'EXT'
subjectAltName = DNS:helpdesk.atlas.local, DNS:glpi01.atlas.local, IP:10.20.0.10
extendedKeyUsage = serverAuth
EXT
openssl x509 -req -in helpdesk.csr -CA ca-root.crt -CAkey ca-root.key \
  -CAcreateserial -out helpdesk.crt -days 365 -extfile helpdesk.ext
openssl verify -CAfile ca-root.crt helpdesk.crt
