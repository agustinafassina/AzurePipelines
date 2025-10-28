#!/usr/bin/bash
DOCKER_REPOSITORYNAME=api-test
sudo apt-get install -y wget gnupg2
sudo apt install jq -y
wget https://github.com/aquasecurity/trivy/releases/download/v0.67.0/trivy_0.67.0_Linux-64bit.deb
sudo dpkg -i trivy_0.67.0_Linux-64bit.deb

echo "Docker image '$DOCKER_REPOSITORYNAME' built successfully."

# Run vulnerability scan with Trivy
echo "Starting vulnerability scan on the image..."
trivy image --severity CRITICAL,HIGH,MEDIUM,LOW --exit-code 1 "$DOCKER_REPOSITORYNAME"

# Check scan result
if [ $? -ne 0 ]; then
echo "Vulnerabilities detected in image '$DOCKER_REPOSITORYNAME'."
exit 1
else
echo "No critical, high, or medium vulnerabilities found."
exit 0
fi