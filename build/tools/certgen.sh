#!/bin/sh

readonly caPath=${CA_PATH:-/etc/kubeedge/ca}
readonly caSubject=${CA_SUBJECT:-/C=CN/ST=Zhejiang/L=Hangzhou/O=KubeEdge/CN=kubeedge.io}
readonly certPath=${CERT_PATH:-/etc/kubeedge/certs}
readonly subject=${SUBJECT:-/C=CN/ST=Zhejiang/L=Hangzhou/O=KubeEdge/CN=kubeedge.io}

genCA() {
    openssl genrsa -des3 -out ${caPath}/ca.key -passout pass:kubeedge.io 4096
    openssl req -x509 -new -nodes -key ${caPath}/ca.key -sha256 -days 3650 \
    -subj ${subject} -passin pass:kubeedge.io -out ${caPath}/ca.crt
}

ensureCA() {
    if [ ! -e ${caPath}/ca.key ] || [ ! -e ${caPath}/ca.crt ]; then
        genCA
    fi
}

genCertAndKey() {
    ensureCA
    local name=$1
    openssl genrsa -out ${certPath}/${name}.key 2048
    openssl req -new -key ${certPath}/${name}.key -subj ${subject} -out ${certPath}/${name}.csr
    openssl x509 -req -in ${certPath}/${name}.csr -CA ${caPath}/ca.crt -CAkey ${caPath}/ca.key -CAcreateserial -passin pass:kubeedge.io -out ${certPath}/${name}.crt -days 365 -sha256
}

buildSecret() {
    local name="cloud"
    genCertAndKey ${name} > /dev/null 2>&1
    cat <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: edgecontroller
  namespace: kubeedge
  labels:
    k8s-app: kubeedge
    kubeedge: edgecontroller
stringData:
  ca.crt: |
$(pr -T -o 4 ${caPath}/ca.crt)
  cloud.crt: |
$(pr -T -o 4 ${certPath}/${name}.crt)
  cloud.key: |
$(pr -T -o 4 ${certPath}/${name}.key)

EOF
}

$1 $2
