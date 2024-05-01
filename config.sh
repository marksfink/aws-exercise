#!/bin/bash

# This is for generating a random JWT secret key.
function rand-str {
    # Return random alpha-numeric string of given LENGTH
    #
    # Usage: VALUE=$(rand-str $LENGTH)
    #    or: VALUE=$(rand-str)

    local DEFAULT_LENGTH=64
    local LENGTH=${1:-$DEFAULT_LENGTH}

    LC_ALL=C tr -dc A-Za-z0-9 </dev/urandom | head -c $LENGTH
    # LC_ALL=C: required for Mac OS X - https://unix.stackexchange.com/a/363194/403075
    # -dc: delete complementary set == delete all except given set
}


# Install kubectl
apt install -y apt-transport-https ca-certificates curl gpg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.29/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.29/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list
apt update
apt install -y kubectl

# Install eksctl
PLATFORM=$(uname -s)_amd64
curl -sLO "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_$PLATFORM.tar.gz"
curl -sL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_checksums.txt" | grep $PLATFORM | sha256sum --check
tar -xzf eksctl_$PLATFORM.tar.gz -C /tmp && rm eksctl_$PLATFORM.tar.gz
sudo mv /tmp/eksctl /usr/local/bin

# Install helm
curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
sudo apt-get install apt-transport-https --yes
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm

# Schedule mongo backups
crontab -l > crontab_new
echo "0 0 * * * /usr/local/bin/mongo_backups.sh" >> crontab_new
crontab crontab_new
rm crontab_new

# Create K8s manifest for tasky
source /home/bitnami/.mongodb/mongo_backups
JWT_SECRET=`rand-str`
HOSTNAME=`hostname`

cat >> /home/bitnami/tasky.yaml<< EOF
---
apiVersion: v1
kind: Namespace
metadata:
  name: tasky
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: cluster-admin-role-binding
subjects:
- kind: ServiceAccount
  name: default
  namespace: tasky
roleRef:
  kind: ClusterRole
  name: cluster-admin
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: tasky
  labels:
    name: tasky
  namespace: tasky
spec:
  replicas: 1
  selector:
    matchLabels:
      name: tasky
  template:
    metadata:
      labels:
        name: tasky
    spec:
      containers:
      - name: tasky
        image: marksfink/tasky:latest
        env:
          - name: MONGODB_URI
            value: mongodb://$MONGO_USER:$MONGO_PASS@$HOSTNAME:27017
          - name: SECRET_KEY
            value: $JWT_SECRET
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  name: tasky
  labels:
    name: tasky
  namespace: tasky
  annotations:
    service.beta.kubernetes.io/aws-load-balancer-type: nlb
    service.beta.kubernetes.io/aws-load-balancer-nlb-target-type: ip
    service.beta.kubernetes.io/aws-load-balancer-scheme: internet-facing
spec:
  ports:
  - port: 50080
    targetPort: 8080
  selector:
    name: tasky
  type: LoadBalancer
EOF
chown bitnami:bitnami /home/bitnami/tasky.yaml
chmod 660 /home/bitnami/tasky.yaml
