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
