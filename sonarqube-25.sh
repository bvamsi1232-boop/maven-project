#!/bin/bash
exec > /var/log/sonarqube-25-install.log 2>&1
set -x

# -------------------------------
# 1. Install prerequisites
# -------------------------------
sudo apt-get update
sudo apt-get install -y openjdk-17-jdk unzip curl jq wget gnupg ca-certificates lsb-release

# -------------------------------
# 2. Apply sysctl settings
# -------------------------------
echo "vm.max_map_count=524288" | sudo tee -a /etc/sysctl.conf
echo "fs.file-max=131072" | sudo tee -a /etc/sysctl.conf
sudo sysctl -p

(crontab -l 2>/dev/null; echo "@reboot sysctl -w vm.max_map_count=524288") | crontab -
(crontab -l 2>/dev/null; echo "@reboot sysctl -w fs.file-max=131072") | crontab -

# -------------------------------
# 3. Install PostgreSQL 17
# -------------------------------
wget -qO - https://www.postgresql.org/media/keys/ACCC4CF8.asc | sudo apt-key add -
echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" | \
  sudo tee /etc/apt/sources.list.d/pgdg.list
sudo apt-get update
sudo apt-get install -y postgresql-17

# -------------------------------
# 4. Initialize PostgreSQL cluster
# -------------------------------
sudo pg_createcluster 17 main --start

sleep 3

# -------------------------------
# 5. Create sonar DB and user (your format)
# -------------------------------
SONAR_DB="sonar"
SONAR_USERNAME="sonaruser"
SONAR_PASSWORD="Sonar@123"

sudo -u postgres bash <<EOF
psql <<SQL
CREATE USER $SONAR_USERNAME WITH ENCRYPTED PASSWORD '$SONAR_PASSWORD';
CREATE DATABASE $SONAR_DB OWNER $SONAR_USERNAME;
GRANT ALL PRIVILEGES ON DATABASE $SONAR_DB TO $SONAR_USERNAME;
GRANT ALL ON SCHEMA public TO $SONAR_USERNAME;
ALTER SCHEMA public OWNER TO $SONAR_USERNAME;
\\l
\\du
SQL
exit
EOF

sleep 2

# -------------------------------
# 6. Setup sonar user environment
# -------------------------------
sudo groupadd sonar || true
id -u sonar &>/dev/null || sudo useradd -m -g sonar sonar
echo 'export SONAR_JAVA_PATH="/usr/bin/java"' | sudo tee /etc/profile.d/sonar.sh

# -------------------------------
# 7. Download and configure SonarQube
# -------------------------------
wget https://binaries.sonarsource.com/Distribution/sonarqube/sonarqube-25.9.0.112764.zip
unzip sonarqube-25.9.0.112764.zip
sudo mv sonarqube-25.9.0.112764 /opt/sonarqube25
sudo chown -R sonar:sonar /opt/sonarqube25

sleep 2

# Inject JDBC credentials
echo "sonar.jdbc.username=$SONAR_USER" | sudo tee -a /opt/sonarqube25/conf/sonar.properties
echo "sonar.jdbc.password=$SONAR_PASSWORD" | sudo tee -a /opt/sonarqube25/conf/sonar.properties
echo "sonar.jdbc.url=jdbc:postgresql://localhost/$SONAR_DB" | sudo tee -a /opt/sonarqube25/conf/sonar.properties

# Ensure sonar.sh is executable
chmod +x /opt/sonarqube25/bin/linux-x86-64/sonar.sh
echo "RUN_AS_USER=sonar" | sudo tee -a /opt/sonarqube25/bin/linux-x86-64/sonar.sh

# -------------------------------
# 8. Create systemd service
# -------------------------------
SERVICE_FILE="/etc/systemd/system/sonarqube25.service"
SONARQUBE_PATH="/opt/sonarqube25/bin/linux-x86-64"

sudo tee $SERVICE_FILE > /dev/null <<EOL
[Unit]
Description=SonarQube 25 Service
After=network.target network-online.target
Wants=network-online.target

[Service]
Type=forking
User=sonar
Group=sonar
ExecStart=${SONARQUBE_PATH}/sonar.sh start
ExecStop=${SONARQUBE_PATH}/sonar.sh stop
ExecReload=${SONARQUBE_PATH}/sonar.sh restart
Restart=always
RestartSec=10
LimitNOFILE=131072
LimitNPROC=8192

[Install]
WantedBy=multi-user.target
EOL

# -------------------------------
# 9. Start SonarQube and verify
# -------------------------------
sudo systemctl daemon-reexec
sudo systemctl enable sonarqube25
sudo systemctl start sonarqube25
sleep 10
sudo systemctl status sonarqube25


# check username and password configuration in sonarproperties files weather our script properly configured or not
# path: /opt/sonarqube25/conf/sonar.properties
# ==> ensure the following properties are set correctly:
# sonar.jdbc.username=sonaruser
# sonar.jdbc.password=Sonar@123
# sonar.jdbc.url=jdbc:postgresql://localhost/sonar

#  use below commands if postgres user need to grant permission to sonaruser

# su - postgres
# GRANT ALL PRIVILEGES ON DATABASE sonar TO sonaruser;
# GRANT ALL ON SCHEMA public TO sonaruser;
# ALTER SCHEMA public OWNER TO sonaruser;
# systemctl restart sonarqube25.service
# initial username and password to login sonarqube is admin | admin
# after that you can change password like ==> username:admin | password: 5iq0Tmdtnxg6Bgmn#

# debug the issue by restarting using command ==> systemctl restart sonarqube25.service
  # see live logs ==> tail -f /opt/sonarqube25/logs/web.log  (or other sonarlogs)

# sonar = squ_470a3ae7e85f98b32a4c23ca7c40d38304cefec0