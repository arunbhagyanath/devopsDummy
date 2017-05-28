#!/bin/bash
sudo apt-get update
sudo apt-get install python-pip python-dev nginx -y
pip install uwsgi
useradd appuser