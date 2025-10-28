#!/usr/bin/bash
docker_repositoryname=api-test
sudo apt-get install -y wget gnupg2
sudo apt install jq -y
wget https://github.com/aquasecurity/trivy/releases/download/v0.67.0/trivy_0.67.0_Linux-64bit.deb
sudo dpkg -i trivy_0.67.0_Linux-64bit.deb

echo "Docker image '$docker_repositoryname' built successfully."

# Run vulnerability scan with Trivy
echo "Starting vulnerability scan on the image..."
trivy image --severity CRITICAL,HIGH,MEDIUM,LOW --exit-code 1 "$docker_repositoryname"

# Check scan result
if [ $? -ne 0 ]; then
echo "Vulnerabilities detected in image '$docker_repositoryname'."
exit 1
else
echo "No critical, high, or medium vulnerabilities found."
exit 0
fi