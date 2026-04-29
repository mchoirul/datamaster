#!/bin/bash
# Setup Python virtual environment and install dependencies

set -e

VENV_PATH="YOUR_VENV_PATH"
DEMO_ROOT="YOUR_WORKSPACE/demo-datastream-append"
REQUIREMENTS_FILE="${DEMO_ROOT}/requirements.txt"

echo "============================================================"
echo "Setting up Python Environment"
echo "============================================================"
echo "Virtual environment: ${VENV_PATH}"
echo "Requirements: ${REQUIREMENTS_FILE}"
echo ""

# Check if venv exists
if [ ! -d "${VENV_PATH}" ]; then
  echo "❌ Error: Virtual environment not found at ${VENV_PATH}"
  echo "Expected path: ${VENV_PATH}"
  exit 1
fi

echo "✅ Virtual environment found"
echo ""

# Activate virtual environment
echo "Activating virtual environment..."
source ${VENV_PATH}/bin/activate

# Verify activation
if [ -z "$VIRTUAL_ENV" ]; then
  echo "❌ Error: Failed to activate virtual environment"
  exit 1
fi

echo "✅ Virtual environment activated: ${VIRTUAL_ENV}"
echo ""

# Upgrade pip
echo "Upgrading pip..."
pip install --upgrade pip -q

# Install dependencies
echo "Installing Python dependencies..."
pip install -r ${REQUIREMENTS_FILE}

echo ""
echo "============================================================"
echo "✅ Python environment setup complete!"
echo "============================================================"
echo ""
echo "Installed packages:"
pip list | grep -E "(psycopg2|Faker|google-cloud-bigquery)"
echo ""
echo "Virtual environment: ${VENV_PATH}"
echo ""
echo "To activate manually:"
echo "  source ${VENV_PATH}/bin/activate"
echo ""
echo "Next step: ./01_create_cloudsql.sh"
