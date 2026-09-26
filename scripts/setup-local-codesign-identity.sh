#!/bin/bash
set -euo pipefail

IDENTITY_NAME="${1:-Prompt Manager Local Code Signing}"
KEYCHAIN="${KEYCHAIN:-$(security default-keychain | tr -d ' "')} "
KEYCHAIN="${KEYCHAIN% }"

if security find-identity -v -p codesigning 2>/dev/null | grep -F "\"$IDENTITY_NAME\"" >/dev/null; then
    echo "✅ Code-signing identity already exists: $IDENTITY_NAME"
    exit 0
fi

TMP_DIR="$(mktemp -d)"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT

OPENSSL_CONFIG="$TMP_DIR/codesign.cnf"
KEY_FILE="$TMP_DIR/codesign.key"
CERT_FILE="$TMP_DIR/codesign.crt"
P12_FILE="$TMP_DIR/codesign.p12"

cat > "$OPENSSL_CONFIG" <<EOF
[ req ]
default_bits = 2048
distinguished_name = req_distinguished_name
x509_extensions = v3_req
prompt = no

[ req_distinguished_name ]
CN = $IDENTITY_NAME

[ v3_req ]
basicConstraints = critical,CA:TRUE
keyUsage = critical,digitalSignature,keyCertSign
extendedKeyUsage = critical,codeSigning
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
EOF

echo "🔐 Creating local code-signing certificate: $IDENTITY_NAME"
openssl req -new -newkey rsa:2048 -nodes -x509 -days 3650 \
    -config "$OPENSSL_CONFIG" \
    -keyout "$KEY_FILE" \
    -out "$CERT_FILE" >/dev/null 2>&1

openssl pkcs12 -export \
    -inkey "$KEY_FILE" \
    -in "$CERT_FILE" \
    -out "$P12_FILE" \
    -passout pass: >/dev/null 2>&1

echo "📥 Importing identity into: $KEYCHAIN"
security import "$P12_FILE" -k "$KEYCHAIN" -P "" -T /usr/bin/codesign -T /usr/bin/security >/dev/null

echo "✅ Trusting certificate for code signing in your login keychain"
security add-trusted-cert -d -r trustRoot -p codeSign -k "$KEYCHAIN" "$CERT_FILE" >/dev/null

if security find-identity -v -p codesigning 2>/dev/null | grep -F "\"$IDENTITY_NAME\"" >/dev/null; then
    cat > "$(dirname "$0")/../local.config" <<EOF
# Local developer signing identity.
# Keeps the app's Keychain access stable across rebuilds so "Always Allow" sticks.
SIGNING_IDENTITY="$IDENTITY_NAME"
EOF
    echo "✅ Ready. Wrote local.config with SIGNING_IDENTITY=\"$IDENTITY_NAME\""
    echo "ℹ️  You may get one final Keychain prompt after the next rebuild; choose Always Allow once for the newly signed app."
else
    echo "❌ The identity was imported, but macOS did not report it as a valid code-signing identity."
    echo "   Open Keychain Access and verify/trust: $IDENTITY_NAME"
    exit 1
fi
