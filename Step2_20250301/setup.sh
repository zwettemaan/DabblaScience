#!/bin/bash

# Define VM name and configuration
VM_NAME="python-ds"
CPU="2"
MEM="4G"
DISK="10G"
JUPYTER_PASSWORD="datascience" # Default password, can be changed

# Define directory structure
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SETUP_DIR="${SCRIPT_DIR}/ds-setup"
MAC_ENV_DIR="${SETUP_DIR}/mac_env"
VM_SCRIPTS_DIR="${SETUP_DIR}/vm_scripts"
MODELS_DIR="${SETUP_DIR}/models"

# Color output for better readability
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check for errors
check_error() {
  local retval=$?
  if [ $retval -ne 0 ]; then
    echo -e "${YELLOW}Error occurred. Exiting...${NC}"
    exit $retval
  fi
}

echo -e "${GREEN}Setting up Python Data Science environment with Mac as Virtual GPU...${NC}"

# Create directory structure
echo -e "${GREEN}Creating directory structure...${NC}"
mkdir -p "${SETUP_DIR}"
mkdir -p "${MAC_ENV_DIR}"
mkdir -p "${VM_SCRIPTS_DIR}"
mkdir -p "${MODELS_DIR}"
check_error

# Check if VM with the same name exists and delete it if it does
if multipass info $VM_NAME &>/dev/null; then
    echo -e "${GREEN}Removing existing VM with the same name...${NC}"
    multipass stop $VM_NAME
    multipass delete $VM_NAME
    multipass purge
fi

# Set up Mac Python environment
echo -e "${GREEN}Setting up Mac Python environment...${NC}"
python3 -m venv "${MAC_ENV_DIR}/macenv"
check_error

# Activate Mac environment and install packages
source "${MAC_ENV_DIR}/macenv/bin/activate"
pip install --upgrade pip
pip install numpy pandas transformers torch accelerate huggingface_hub
check_error

# Download a small model from HuggingFace
echo -e "${GREEN}Downloading tiny-llama model from HuggingFace...${NC}"
cat > "${MAC_ENV_DIR}/download_model.py" << EOF
import os
from huggingface_hub import snapshot_download

# Set model ID
model_id = "TinyLlama/TinyLlama-1.1B-Chat-v1.0"

# Set download directory
download_dir = os.path.join("${MODELS_DIR}", "tiny-llama")

# Download model
snapshot_download(repo_id=model_id, local_dir=download_dir, local_dir_use_symlinks=False)
print(f"Model downloaded to {download_dir}")
EOF

python "${MAC_ENV_DIR}/download_model.py"
check_error

# Create Mac GPU server service
echo -e "${GREEN}Creating Mac GPU server service...${NC}"
cat > "${MAC_ENV_DIR}/mac_gpu_server.py" << EOF
#!/usr/bin/env python3
"""
Mac GPU Server - Provides a simple API for VM to access Mac's processing power
"""
import os
import sys
import json
import torch
import socket
import numpy as np
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import parse_qs, urlparse
from transformers import AutoTokenizer, AutoModelForCausalLM

# Configuration
HOST = '0.0.0.0'
PORT = 5000
MODEL_DIR = os.path.join("${MODELS_DIR}", "tiny-llama")

# Load the model and tokenizer
print("Loading model and tokenizer...")
tokenizer = AutoTokenizer.from_pretrained(MODEL_DIR)
model = AutoModelForCausalLM.from_pretrained(
    MODEL_DIR, 
    torch_dtype=torch.float16,
    device_map="auto"
)

class GPURequestHandler(BaseHTTPRequestHandler):
    def _set_headers(self, content_type="application/json"):
        self.send_response(200)
        self.send_header('Content-Type', content_type)
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        self.end_headers()
    
    def do_OPTIONS(self):
        self._set_headers()
        
    def do_GET(self):
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        if path == '/health':
            self._set_headers()
            self.wfile.write(json.dumps({'status': 'healthy'}).encode())
        elif path == '/info':
            self._set_headers()
            gpu_info = "Available" if torch.cuda.is_available() else "Not Available"
            if torch.cuda.is_available():
                gpu_info += f" ({torch.cuda.get_device_name(0)})"
            
            info = {
                'status': 'running',
                'host': socket.gethostname(),
                'gpu': gpu_info,
                'model': "TinyLlama-1.1B-Chat-v1.0"
            }
            self.wfile.write(json.dumps(info).encode())
        else:
            self.send_error(404, "Not Found")
    
    def do_POST(self):
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length).decode('utf-8')
        parsed_path = urlparse(self.path)
        path = parsed_path.path
        
        try:
            data = json.loads(post_data)
            
            if path == '/generate':
                prompt = data.get('prompt', '')
                max_length = data.get('max_length', 100)
                
                # Generate text
                inputs = tokenizer(prompt, return_tensors="pt").to(model.device)
                outputs = model.generate(
                    **inputs,
                    max_length=max_length,
                    do_sample=True,
                    temperature=0.7,
                    top_p=0.9,
                )
                response_text = tokenizer.decode(outputs[0], skip_special_tokens=True)
                
                self._set_headers()
                self.wfile.write(json.dumps({'generated_text': response_text}).encode())
            else:
                self.send_error(404, "Not Found")
        except Exception as e:
            self.send_error(500, str(e))

def run_server():
    print(f"Starting Mac GPU server on port {PORT}...")
    server = HTTPServer((HOST, PORT), GPURequestHandler)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    server.server_close()
    print("Server stopped.")

if __name__ == "__main__":
    run_server()
EOF

# Make the script executable
chmod +x "${MAC_ENV_DIR}/mac_gpu_server.py"

# Create Mac service control scripts
cat > "${SETUP_DIR}/start_mac_service.sh" << EOF
#!/bin/bash
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
source "\${SCRIPT_DIR}/mac_env/macenv/bin/activate"
python "\${SCRIPT_DIR}/mac_env/mac_gpu_server.py"
EOF
chmod +x "${SETUP_DIR}/start_mac_service.sh"

# Launch new Ubuntu VM
echo -e "${GREEN}Launching new Ubuntu VM...${NC}"
multipass launch --name $VM_NAME --cpus $CPU --memory $MEM --disk $DISK
check_error

# Create setup script for the VM
echo -e "${GREEN}Creating setup script for the VM...${NC}"
cat > "${VM_SCRIPTS_DIR}/setup_vm.sh" << 'EOF'
#!/bin/bash

# Update and install Python and pip
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3 python3-pip python3-dev python3-venv curl

# Create virtual environment
echo "Creating Python virtual environment..."
mkdir -p /home/ubuntu/python_env
python3 -m venv /home/ubuntu/python_env/dsenv

# Activate environment and install packages
echo "Installing packages..."
source /home/ubuntu/python_env/dsenv/bin/activate
pip install --upgrade pip
pip install jupyter numpy pandas matplotlib scikit-learn scipy seaborn plotly requests

# Configure Jupyter for remote access
echo "Configuring Jupyter..."
mkdir -p /home/ubuntu/.jupyter
jupyter notebook --generate-config

# Set Jupyter password (provided as argument)
JUPYTER_PASSWORD=$1
if [ -z "$JUPYTER_PASSWORD" ]; then
    echo "No password provided, using default password: datascience"
    JUPYTER_PASSWORD="datascience"
fi

# Generate password hash
echo "Generating password hash for Jupyter..."
PASSWORD_HASH=$(python3 -c "from jupyter_server.auth import passwd; print(passwd('$JUPYTER_PASSWORD'))")
echo "Jupyter will be secured with a password (hash: ${PASSWORD_HASH:0:10}...)"

# Configure Jupyter
cat > /home/ubuntu/.jupyter/jupyter_notebook_config.py << EOCNF
c.ServerApp.ip = '0.0.0.0'
c.ServerApp.port = 8888
c.ServerApp.open_browser = False
c.PasswordIdentityProvider.hashed_password = '$PASSWORD_HASH'
c.ServerApp.allow_origin = '*'
c.ServerApp.root_dir = '/home/ubuntu/notebooks'
EOCNF

# Create notebooks directory
mkdir -p /home/ubuntu/notebooks

# Create a simple module and install it properly
mkdir -p /home/ubuntu/mac_gpu_client_module
cat > /home/ubuntu/mac_gpu_client_module/setup.py << EOSetup
from setuptools import setup

setup(
    name="mac_gpu_client",
    version="0.1",
    py_modules=["mac_gpu_client"],
)
EOSetup

cat > /home/ubuntu/mac_gpu_client_module/mac_gpu_client.py << EOCLIENT
"""
Client utility to connect to the Mac GPU service
"""
import json
import requests

class MacGPUClient:
    def __init__(self, host='host.multipass', port=5000):
        self.base_url = f"http://{host}:{port}"
    
    def health_check(self):
        """Check if the GPU service is healthy"""
        try:
            response = requests.get(f"{self.base_url}/health")
            return response.json()
        except:
            return {'status': 'unhealthy', 'error': 'Connection failed'}
    
    def get_info(self):
        """Get information about the GPU service"""
        try:
            response = requests.get(f"{self.base_url}/info")
            return response.json()
        except:
            return {'error': 'Connection failed'}
    
    def generate_text(self, prompt, max_length=100):
        """Generate text using the model on Mac"""
        try:
            data = {
                'prompt': prompt,
                'max_length': max_length
            }
            response = requests.post(
                f"{self.base_url}/generate",
                data=json.dumps(data),
                headers={'Content-Type': 'application/json'}
            )
            return response.json()
        except Exception as e:
            return {'error': str(e)}
EOCLIENT

# Create a test notebook for Mac GPU integration
cat > /home/ubuntu/notebooks/test_mac_gpu.ipynb << EONB
{
 "cells": [
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "# Mac GPU Integration Test\n",
    "This notebook tests the integration with the Mac's GPU service."
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "import mac_gpu_client\n",
    "\n",
    "# Create client\n",
    "client = mac_gpu_client.MacGPUClient()\n",
    "\n",
    "# Check health\n",
    "health = client.health_check()\n",
    "print(\"Health check:\", health)"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "# Get service info\n",
    "info = client.get_info()\n",
    "print(\"Service info:\")\n",
    "for key, value in info.items():\n",
    "    print(f\"  {key}: {value}\")"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "# Test text generation\n",
    "prompt = \"Explain the benefits of using virtual machines for development in three sentences:\"\n",
    "result = client.generate_text(prompt, max_length=200)\n",
    "\n",
    "if 'error' in result:\n",
    "    print(f\"Error: {result['error']}\")\n",
    "else:\n",
    "    print(\"Generated text:\")\n",
    "    print(result['generated_text'])"
   ]
  }
 ],
 "metadata": {
  "kernelspec": {
   "display_name": "Python 3",
   "language": "python",
   "name": "python3"
  },
  "language_info": {
   "codemirror_mode": {
    "name": "ipython",
    "version": 3
   },
   "file_extension": ".py",
   "mimetype": "text/x-python",
   "name": "python",
   "nbconvert_exporter": "python",
   "pygments_lexer": "ipython3",
   "version": "3.10.12"
  }
 },
 "nbformat": 4,
 "nbformat_minor": 4
}
EONB

# Create a regular test notebook
cat > /home/ubuntu/notebooks/test_notebook.ipynb << EONB
{
 "cells": [
  {
   "cell_type": "markdown",
   "metadata": {},
   "source": [
    "# Test Notebook\n",
    "This is a test notebook to verify that your setup is working correctly."
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "import numpy as np\n",
    "import pandas as pd\n",
    "import matplotlib.pyplot as plt\n",
    "\n",
    "print(\"Numpy version:\", np.__version__)\n",
    "print(\"Pandas version:\", pd.__version__)"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "# Create some test data\n",
    "data = np.random.randn(100, 2)\n",
    "df = pd.DataFrame(data, columns=['A', 'B'])\n",
    "df.head()"
   ]
  },
  {
   "cell_type": "code",
   "execution_count": null,
   "metadata": {},
   "outputs": [],
   "source": [
    "# Plot the data\n",
    "plt.figure(figsize=(10, 6))\n",
    "plt.scatter(df['A'], df['B'])\n",
    "plt.title('Test Plot')\n",
    "plt.xlabel('A')\n",
    "plt.ylabel('B')\n",
    "plt.grid(True)\n",
    "plt.show()"
   ]
  }
 ],
 "metadata": {
  "kernelspec": {
   "display_name": "Python 3",
   "language": "python",
   "name": "python3"
  },
  "language_info": {
   "codemirror_mode": {
    "name": "ipython",
    "version": 3
   },
   "file_extension": ".py",
   "mimetype": "text/x-python",
   "name": "python",
   "nbconvert_exporter": "python",
   "pygments_lexer": "ipython3",
   "version": "3.10.12"
  }
 },
 "nbformat": 4,
 "nbformat_minor": 4
}
EONB

# Create a script to start Jupyter
cat > /home/ubuntu/start_jupyter.sh << EOSH
#!/bin/bash
source /home/ubuntu/python_env/dsenv/bin/activate
cd /home/ubuntu/notebooks
jupyter notebook
EOSH

# Install the mac_gpu_client module
cd /home/ubuntu/mac_gpu_client_module
source /home/ubuntu/python_env/dsenv/bin/activate
pip install -e .

chmod +x /home/ubuntu/start_jupyter.sh

echo "Setup complete. Jupyter password: $JUPYTER_PASSWORD"
echo "Run ~/start_jupyter.sh to start Jupyter Notebook server"
EOF

# Transfer the setup script to the VM
echo -e "${GREEN}Transferring setup script to VM...${NC}"
multipass transfer "${VM_SCRIPTS_DIR}/setup_vm.sh" $VM_NAME:/home/ubuntu/setup_vm.sh
multipass exec $VM_NAME -- chmod +x /home/ubuntu/setup_vm.sh

# Execute the setup script inside the VM with the password
echo -e "${GREEN}Executing setup script inside VM...${NC}"
multipass exec $VM_NAME -- /home/ubuntu/setup_vm.sh "${JUPYTER_PASSWORD}"
check_error

# Configure hosts entries for better connectivity
echo -e "${GREEN}Configuring networking...${NC}"

# Get VM IP address
VM_IP_ADDRESS=$(multipass info $VM_NAME --format json | python3 -c "import sys, json; print(json.load(sys.stdin)['info']['$VM_NAME']['ipv4'][0])")

# Get Mac IP address visible to the VM
MAC_IP_ADDRESS=$(ifconfig | grep -E "inet ([0-9]{1,3}\.){3}[0-9]{1,3}" | grep -v 127.0.0.1 | awk '{print $2}' | head -1)

# Update VM's hosts file to add entry for the Mac
echo -e "${GREEN}Adding host.multipass entry to VM hosts file...${NC}"
multipass exec $VM_NAME -- bash -c "echo '$MAC_IP_ADDRESS host.multipass' | sudo tee -a /etc/hosts"

# Create convenience scripts
echo -e "${GREEN}Creating convenience scripts...${NC}"

# Script to start the Mac GPU service
cat > "${SETUP_DIR}/start_mac_service.sh" << EOF
#!/bin/bash
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
source "\${SCRIPT_DIR}/mac_env/macenv/bin/activate"
python "\${SCRIPT_DIR}/mac_env/mac_gpu_server.py"
EOF
chmod +x "${SETUP_DIR}/start_mac_service.sh"

# Script to open Jupyter in browser
cat > "${SETUP_DIR}/open_jupyter.sh" << EOF
#!/bin/bash
open http://$VM_IP_ADDRESS:8888
EOF
chmod +x "${SETUP_DIR}/open_jupyter.sh"

# Script to start Jupyter on VM
cat > "${SETUP_DIR}/start_jupyter.sh" << EOF
#!/bin/bash
multipass exec $VM_NAME -- /home/ubuntu/start_jupyter.sh
EOF
chmod +x "${SETUP_DIR}/start_jupyter.sh"

# Script to reset everything
cat > "${SETUP_DIR}/reset_environment.sh" << EOF
#!/bin/bash
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"

echo "Stopping Mac GPU service..."
pkill -f "python.*mac_gpu_server.py" || true

echo "Stopping and removing VM..."
multipass stop $VM_NAME
multipass delete $VM_NAME
multipass purge

echo "Environment reset complete."
echo "To completely remove all files, delete the directory: ${SETUP_DIR}"
EOF
chmod +x "${SETUP_DIR}/reset_environment.sh"

# Create a master script to start everything
cat > "${SCRIPT_DIR}/start_environment.sh" << EOF
#!/bin/bash
SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"

# Start Mac GPU service in the background
"\${SCRIPT_DIR}/ds-setup/start_mac_service.sh" &
MAC_SERVICE_PID=\$!

# Wait for the service to start
sleep 2
echo "Mac GPU service started with PID \${MAC_SERVICE_PID}"

# Start Jupyter in the VM
"\${SCRIPT_DIR}/ds-setup/start_jupyter.sh" &
JUPYTER_PID=\$!

# Open Jupyter in the browser
sleep 3
"\${SCRIPT_DIR}/ds-setup/open_jupyter.sh"

echo "Environment started. Press Ctrl+C to shut down."
wait \$MAC_SERVICE_PID
EOF
chmod +x "${SCRIPT_DIR}/start_environment.sh"

# Display information
echo -e "${GREEN}Setup complete!${NC}"
echo -e "Jupyter notebook is available at: ${GREEN}http://$VM_IP_ADDRESS:8888${NC}"
echo -e "Jupyter password: ${GREEN}${JUPYTER_PASSWORD}${NC}"
echo -e "Mac GPU service will run on: ${GREEN}http://$MAC_IP_ADDRESS:5000${NC}"
echo ""
echo "Scripts created:"
echo "  ${SCRIPT_DIR}/start_environment.sh - Start everything in one command"
echo "  ${SETUP_DIR}/start_mac_service.sh - Start Mac GPU service"
echo "  ${SETUP_DIR}/start_jupyter.sh - Start Jupyter server on the VM"
echo "  ${SETUP_DIR}/open_jupyter.sh - Open Jupyter in your Mac's browser"
echo "  ${SETUP_DIR}/reset_environment.sh - Reset the environment (stop services, delete VM)"
echo ""
echo -e "${GREEN}To start the environment:${NC}"
echo "  ${SCRIPT_DIR}/start_environment.sh"
echo ""
echo -e "${YELLOW}Note: The tiny-llama model has been downloaded to ${MODELS_DIR}/tiny-llama${NC}"
