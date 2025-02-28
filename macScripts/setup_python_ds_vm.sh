#!/bin/bash

# Define VM name and configuration
VM_NAME="python-ds"
CPU="2"
MEM="4G"
DISK="10G"

# Color output for better readability
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}Setting up Ubuntu VM with Python Data Science stack...${NC}"

# Check if VM with the same name exists and delete it if it does
if multipass info $VM_NAME &>/dev/null; then
    echo -e "${GREEN}Removing existing VM with the same name...${NC}"
    multipass delete $VM_NAME
    multipass purge
fi

# Launch new Ubuntu VM
echo -e "${GREEN}Launching new Ubuntu VM...${NC}"
multipass launch --name $VM_NAME --cpus $CPU --memory $MEM --disk $DISK

# Create setup script to run inside the VM
echo -e "${GREEN}Creating setup script for the VM...${NC}"
cat > setup_vm.sh << 'EOF'
#!/bin/bash

# Update and install Python and pip
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3 python3-pip python3-dev python3-venv

# Create virtual environment
echo "Creating Python virtual environment..."
mkdir -p /home/ubuntu/python_env
python3 -m venv /home/ubuntu/python_env/dsenv

# Activate environment and install packages
echo "Installing packages..."
source /home/ubuntu/python_env/dsenv/bin/activate
pip install --upgrade pip
pip install jupyter numpy pandas matplotlib scikit-learn scipy seaborn plotly

# Configure Jupyter for remote access
echo "Configuring Jupyter..."
mkdir -p /home/ubuntu/.jupyter
jupyter notebook --generate-config
python3 -c "from jupyter_server.auth import passwd; print(passwd())" > /home/ubuntu/.jupyter/password.txt

# Get password hash
PASSWORD_HASH=$(cat /home/ubuntu/.jupyter/password.txt)

# Configure Jupyter to listen on all interfaces
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

# Create a simple test notebook
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
   "version": "3.8.10"
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

chmod +x /home/ubuntu/start_jupyter.sh

echo "Setup complete. Jupyter password is saved to /home/ubuntu/.jupyter/password.txt"
echo "Run /home/ubuntu/start_jupyter.sh to start Jupyter Notebook server"
EOF

# Transfer the setup script to the VM
echo -e "${GREEN}Transferring setup script to VM...${NC}"
multipass transfer setup_vm.sh $VM_NAME:setup_vm.sh
multipass exec $VM_NAME -- chmod +x setup_vm.sh

# Execute the setup script inside the VM
echo -e "${GREEN}Executing setup script inside VM...${NC}"
multipass exec $VM_NAME -- ./setup_vm.sh

# Get VM IP address
IP_ADDRESS=$(multipass info $VM_NAME --format json | python3 -c "import sys, json; print(json.load(sys.stdin)['info']['$VM_NAME']['ipv4'][0])")

# Create convenience scripts for Mac
echo -e "${GREEN}Creating convenience scripts on your Mac...${NC}"

# Script to open Jupyter in browser
cat > open_jupyter.sh << EOF
#!/bin/bash
open http://$IP_ADDRESS:8888
EOF
chmod +x open_jupyter.sh

# Script to start Jupyter on VM
cat > start_jupyter.sh << EOF
#!/bin/bash
multipass exec $VM_NAME -- /home/ubuntu/start_jupyter.sh
EOF
chmod +x start_jupyter.sh

# Script to reset the entire environment
cat > reset_environment.sh << EOF
#!/bin/bash
VM_NAME="$VM_NAME"
echo "Resetting Python data science environment..."
multipass stop \$VM_NAME
multipass delete \$VM_NAME
multipass purge
echo "Environment reset complete. Run setup script again to create a fresh VM."
EOF
chmod +x reset_environment.sh

# Display information
echo -e "${GREEN}Setup complete!${NC}"
echo -e "Jupyter notebook is available at: ${GREEN}http://$IP_ADDRESS:8888${NC}"
echo -e "Password for Jupyter is stored in the VM at: ${GREEN}/home/ubuntu/.jupyter/password.txt${NC}"
echo ""
echo "To access the password, run:"
echo "  multipass exec $VM_NAME -- cat /home/ubuntu/.jupyter/password.txt"
echo ""
echo "Convenience scripts created:"
echo "  ./start_jupyter.sh - Start Jupyter server on the VM"
echo "  ./open_jupyter.sh - Open Jupyter in your Mac's browser"
echo "  ./reset_environment.sh - Reset the environment (delete VM)"
