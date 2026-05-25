#!/bin/bash

# MyChannel API Server Startup Script
# This script sets up and starts the API server on GCE instances

set -e

# Update system
apt-get update
apt-get install -y curl wget gnupg2 software-properties-common

# Install Node.js 18
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
apt-get install -y nodejs

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
usermod -aG docker $USER

# Install Docker Compose
curl -L "https://github.com/docker/compose/releases/download/v2.20.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Create application directory
mkdir -p /opt/mychannel
cd /opt/mychannel

# Create systemd service for the API
cat > /etc/systemd/system/mychannel-api.service << 'EOF'
[Unit]
Description=MyChannel API Server
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/opt/mychannel
ExecStart=/usr/bin/node server.js
Restart=always
RestartSec=10
Environment=NODE_ENV=production
Environment=PORT=8080

[Install]
WantedBy=multi-user.target
EOF

# Create basic API server
cat > /opt/mychannel/package.json << 'EOF'
{
  "name": "mychannel-api",
  "version": "1.0.0",
  "description": "MyChannel API Server",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.18.2",
    "cors": "^2.8.5",
    "helmet": "^7.0.0",
    "compression": "^1.7.4"
  }
}
EOF

cat > /opt/mychannel/server.js << 'EOF'
const express = require('express');
const cors = require('cors');
const helmet = require('helmet');
const compression = require('compression');

const app = express();
const PORT = process.env.PORT || 8080;

// Middleware
app.use(helmet());
app.use(compression());
app.use(cors());
app.use(express.json({ limit: '10mb' }));

// Health check endpoint
app.get('/health', (req, res) => {
  res.status(200).json({
    status: 'healthy',
    timestamp: new Date().toISOString(),
    uptime: process.uptime()
  });
});

// API endpoints
app.get('/api/videos', (req, res) => {
  res.json({
    videos: [],
    total: 0,
    page: 1
  });
});

app.get('/api/videos/:id', (req, res) => {
  res.json({
    id: req.params.id,
    title: 'Sample Video',
    description: 'Sample video description',
    url: 'https://example.com/video.mp4'
  });
});

// Error handling
app.use((err, req, res, next) => {
  console.error(err.stack);
  res.status(500).json({ error: 'Internal server error' });
});

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`MyChannel API server running on port ${PORT}`);
});
EOF

# Install dependencies
npm install

# Enable and start the service
systemctl daemon-reload
systemctl enable mychannel-api
systemctl start mychannel-api

# Install monitoring agent
curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
bash add-google-cloud-ops-agent-repo.sh --also-install

# Configure firewall
ufw allow 8080/tcp
ufw allow 22/tcp
ufw --force enable

# Create log rotation
cat > /etc/logrotate.d/mychannel << 'EOF'
/var/log/mychannel/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 root root
    postrotate
        systemctl reload mychannel-api
    endscript
}
EOF

# Create log directory
mkdir -p /var/log/mychannel

echo "MyChannel API server setup complete"

