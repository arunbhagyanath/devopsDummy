#!/bin/bash
sudo apt-get update
sudo apt-get install python-pip python-dev nginx -y
pip install uwsgi
useradd -d /opt/apphome -m appuser
mkdir -p /var/log/uwsgi/
chown appuser:appuser /var/log/uwsgi/
unlink /etc/nginx/sites-enabled/default