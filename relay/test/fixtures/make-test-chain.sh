#!/bin/sh
# Makes the TEST certificate chain the relay tests sign with (a stand-in for Apple's root → WWDR intermediate → App
# Store signing leaf, with the same Apple marker extensions). Test-only: the relay trusts this root only when the test
# env sets TEST_ROOT_SHA256. Run from anywhere: sh relay/test/fixtures/make-test-chain.sh
set -e
cd "$(dirname "$0")"
cat > ext.cnf <<'EOF'
[req]
distinguished_name=dn
[dn]
[ca]
basicConstraints=critical,CA:TRUE
keyUsage=critical,keyCertSign,cRLSign
[inter]
basicConstraints=critical,CA:TRUE,pathlen:0
keyUsage=critical,keyCertSign,cRLSign
1.2.840.113635.100.6.2.1=ASN1:NULL
[leaf]
basicConstraints=critical,CA:FALSE
keyUsage=critical,digitalSignature
1.2.840.113635.100.6.11.1=ASN1:NULL
EOF
openssl ecparam -name secp384r1 -genkey -noout -out root.key
openssl req -new -x509 -key root.key -sha384 -days 36500 -subj "/CN=Test Root CA - G3" -config ext.cnf -extensions ca -out root.pem
openssl ecparam -name secp384r1 -genkey -noout -out inter.key
openssl req -new -key inter.key -subj "/CN=Test WWDR G6" -config ext.cnf -out inter.csr
openssl x509 -req -in inter.csr -CA root.pem -CAkey root.key -CAcreateserial -sha384 -days 36500 -extfile ext.cnf -extensions inter -out inter.pem
openssl ecparam -name prime256v1 -genkey -noout -out leaf.key
openssl req -new -key leaf.key -subj "/CN=Test StoreKit Signing" -config ext.cnf -out leaf.csr
openssl x509 -req -in leaf.csr -CA inter.pem -CAkey inter.key -CAcreateserial -sha256 -days 36500 -extfile ext.cnf -extensions leaf -out leaf.pem
# An "Xcode" leaf without the Apple marker (must be refused).
openssl req -new -key leaf.key -subj "/CN=Test Unmarked Leaf" -config ext.cnf -out plain.csr
openssl x509 -req -in plain.csr -CA inter.pem -CAkey inter.key -CAcreateserial -sha256 -days 36500 -extfile ext.cnf -extensions ca -out plain-leaf.pem
openssl pkcs8 -topk8 -nocrypt -in leaf.key -out leaf.pk8.pem
rm -f *.csr *.srl ext.cnf root.key inter.key leaf.key
echo "test chain written"
