# AWS + DuckDNS + Nginx + SSL Commands
# Project: Zeenkaar Fashion Style
# Domain: zeenkaarfashionstyle.duckdns.org
# Public IPv4 used in DuckDNS: 3.238.140.125
# Control-plane private IP seen in terminal: 10.0.1.217
# Kubernetes NodePort used by the app: 30080

################################################################################
# 1) AWS Security Group checklist, done in AWS Console
################################################################################

# Inbound rules needed for this setup:
# TCP 80   from 0.0.0.0/0     # HTTP and Let's Encrypt validation
# TCP 443  from 0.0.0.0/0     # HTTPS public website
# TCP 30000-32767 from 0.0.0.0/0  # Kubernetes NodePort testing/direct access
#
# After the Nginx reverse proxy works, for better security you can restrict or
# remove public access to 30000-32767 and keep only ports 80 and 443 public.

################################################################################
# 2) Quick health checks
################################################################################

# Check if the Kubernetes app is reachable through the NodePort from the server.
curl -I http://10.0.1.217:30080/
curl -I http://127.0.0.1:30080/

# Check Kubernetes services and pods.
kubectl get svc -A
kubectl get pods -A -o wide

# Check Nginx and Certbot versions.
nginx -v
certbot --version

################################################################################
# 3) Install Nginx and the Certbot Nginx plugin on Ubuntu
################################################################################

sudo apt update
sudo apt install -y nginx python3-certbot-nginx
sudo systemctl enable --now nginx

# Optional: if you installed Certbot using snap, this is also okay.
# sudo snap install --classic certbot
# sudo ln -sf /snap/bin/certbot /usr/bin/certbot

################################################################################
# 4) Get or renew the HTTPS certificate
################################################################################

# IMPORTANT: Give only the domain name. Do NOT add :30080 here.
sudo certbot --nginx -d zeenkaarfashionstyle.duckdns.org

# Test auto-renewal.
sudo certbot renew --dry-run

################################################################################
# 5) Configure Nginx as a reverse proxy to the Kubernetes NodePort
################################################################################

# Backup the existing default config.
sudo cp /etc/nginx/sites-enabled/default /etc/nginx/sites-enabled/default.bak.$(date +%F-%H%M%S)

# Create a new site config.
sudo tee /etc/nginx/sites-available/zeenkaar > /dev/null <<'EOF'
server {
    listen 80;
    server_name zeenkaarfashionstyle.duckdns.org;

    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }

    location / {
        return 301 https://$host$request_uri;
    }
}

server {
    listen 443 ssl;
    server_name zeenkaarfashionstyle.duckdns.org;

    ssl_certificate /etc/letsencrypt/live/zeenkaarfashionstyle.duckdns.org/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/zeenkaarfashionstyle.duckdns.org/privkey.pem;
    include /etc/letsencrypt/options-ssl-nginx.conf;
    ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;

    location / {
        proxy_pass http://10.0.1.217:30080;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOF

# Enable this config as the default site.
sudo ln -sf /etc/nginx/sites-available/zeenkaar /etc/nginx/sites-enabled/default

# Test and reload Nginx.
sudo nginx -t
sudo systemctl reload nginx

################################################################################
# 6) Test the final clean URL
################################################################################

curl -I https://zeenkaarfashionstyle.duckdns.org

# Browser / WhatsApp final link:
# https://zeenkaarfashionstyle.duckdns.org

################################################################################
# 7) Troubleshooting commands
################################################################################

# If the final URL shows the Nginx default page, re-check the proxy config.
sudo nginx -T | sed -n '/server_name zeenkaarfashionstyle.duckdns.org/,+80p'

# If you get 502 Bad Gateway, Nginx cannot reach the app.
curl -I http://10.0.1.217:30080/
kubectl get svc -A
kubectl get pods -A -o wide
sudo tail -n 80 /var/log/nginx/error.log

# If Nginx is not running:
sudo systemctl status nginx --no-pager
sudo systemctl restart nginx

# If the certificate needs checking:
sudo certbot certificates
sudo certbot renew --dry-run
