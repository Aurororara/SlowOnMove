#!/bin/bash
set -e

echo "Checking Python version..."
python3 --version

echo "Creating backend directory and virtual environment..."
mkdir -p backend
cd backend
python3 -m venv venv

echo "Activating virtual environment... and installing packages..."
source venv/bin/activate
pip install --upgrade pip
pip install django djangorestframework psycopg2-binary djangorestframework-simplejwt django-cors-headers

echo "Creating Django project and core apps..."
if [ ! -f manage.py ]; then
    django-admin startproject slow_on_move .
fi
if [ ! -d core ]; then
    python manage.py startapp core
fi
if [ ! -d api ]; then
    python manage.py startapp api
fi

echo "Django setup complete."
