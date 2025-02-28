#!/bin/bash

# macOS System Inventory Script
# This script analyzes your macOS system to detect package managers,
# environment managers, interprets your PATH to determine the context
# of various commands, and lists all available versions of programming
# languages with instructions on how to switch between them.

# Terminal colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Header function
print_header() {
  echo -e "\n${BLUE}${BOLD}=============== $1 ===============${NC}\n"
}

# Subheader function
print_subheader() {
  echo -e "\n${CYAN}${BOLD}--- $1 ---${NC}\n"
}

# Success message
print_success() {
  echo -e "${GREEN}✓ $1${NC}"
}

# Warning message
print_warning() {
  echo -e "${YELLOW}⚠ $1${NC}"
}

# Error message
print_error() {
  echo -e "${RED}✗ $1${NC}"
}

# Info message
print_info() {
  echo -e "${PURPLE}ℹ $1${NC}"
}

# Create a temporary file for the report
REPORT_FILE=$(mktemp)
echo "# macOS System Inventory Report" > $REPORT_FILE
echo "Generated on $(date)" >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Function to check if a command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Function to get the real path of a command (resolving symlinks)
get_real_path() {
  if command_exists "$1"; then
    local cmd_path=$(which "$1")
    if [ -L "$cmd_path" ]; then
      local real_path=$(readlink "$cmd_path")
      # If the path is not absolute, make it absolute
      if [[ "$real_path" != /* ]]; then
        real_path="$(dirname "$cmd_path")/$real_path"
      fi
      echo "$cmd_path -> $real_path"
    else
      echo "$cmd_path"
    fi
  else
    echo "not found"
  fi
}

# Start the inventory
print_header "macOS SYSTEM INVENTORY"
echo "# macOS System Inventory" >> $REPORT_FILE
echo "Running on: $(sw_vers -productName) $(sw_vers -productVersion) ($(sw_vers -buildVersion))" >> $REPORT_FILE
echo "Architecture: $(uname -m)" >> $REPORT_FILE
echo "" >> $REPORT_FILE

print_info "Running on: $(sw_vers -productName) $(sw_vers -productVersion) ($(sw_vers -buildVersion))"
print_info "Architecture: $(uname -m)"

# Check PATH and analyze it
print_header "PATH ANALYSIS"
echo "## PATH Analysis" >> $REPORT_FILE
echo "Your current PATH is set to:" >> $REPORT_FILE
echo '```' >> $REPORT_FILE
echo "$PATH" | tr ':' '\n' >> $REPORT_FILE
echo '```' >> $REPORT_FILE
echo "" >> $REPORT_FILE

echo -e "Your current PATH is set to:"
echo "$PATH" | tr ':' '\n' | while read -r path_entry; do
  if [ -d "$path_entry" ]; then
    print_success "$path_entry (directory exists)"
  else
    print_warning "$path_entry (directory does not exist)"
  fi
done

# Analyze PATH order and precedence
print_subheader "PATH Precedence Analysis"
echo "### PATH Precedence Analysis" >> $REPORT_FILE
echo "The following shows which directories take precedence in your PATH:" >> $REPORT_FILE
echo "" >> $REPORT_FILE

PATH_ARRAY=($(echo "$PATH" | tr ':' ' '))
echo "PATH search order:" >> $REPORT_FILE
for i in "${!PATH_ARRAY[@]}"; do
  echo "$((i+1)). ${PATH_ARRAY[$i]}" >> $REPORT_FILE
done
echo "" >> $REPORT_FILE

# Look for evidence of package managers
print_header "PACKAGE MANAGERS"
echo "## Package Managers" >> $REPORT_FILE

# Check for Homebrew
print_subheader "Homebrew"
echo "### Homebrew" >> $REPORT_FILE
if command_exists brew; then
  brew_path=$(get_real_path "brew")
  brew_version=$(brew --version | head -n 1)
  brew_prefix=$(brew --prefix)
  print_success "Homebrew is installed: $brew_version"
  print_info "Homebrew executable: $brew_path"
  print_info "Homebrew prefix: $brew_prefix"
  echo "Status: Installed" >> $REPORT_FILE
  echo "Version: $brew_version" >> $REPORT_FILE
  echo "Executable: $brew_path" >> $REPORT_FILE
  echo "Prefix: $brew_prefix" >> $REPORT_FILE
  
  # List installed packages
  echo "Installed packages (first 10 shown):" >> $REPORT_FILE
  brew list --formula | head -10 | sed 's/^/- /' >> $REPORT_FILE
  if [ $(brew list --formula | wc -l) -gt 10 ]; then
    echo "- ... ($(brew list --formula | wc -l | tr -d ' ') total packages)" >> $REPORT_FILE
  fi
else
  if [ -d "/usr/local/Homebrew" ] || [ -d "/opt/homebrew" ]; then
    print_warning "Homebrew directory exists but 'brew' command not in PATH"
    echo "Status: Directory exists but 'brew' command not in PATH" >> $REPORT_FILE
  else
    print_error "Homebrew is not installed"
    echo "Status: Not installed" >> $REPORT_FILE
  fi
fi
echo "" >> $REPORT_FILE

# Check for MacPorts
print_subheader "MacPorts"
echo "### MacPorts" >> $REPORT_FILE
if command_exists port; then
  port_path=$(get_real_path "port")
  port_version=$(port version | head -n 1)
  print_success "MacPorts is installed: $port_version"
  print_info "MacPorts executable: $port_path"
  echo "Status: Installed" >> $REPORT_FILE
  echo "Version: $port_version" >> $REPORT_FILE
  echo "Executable: $port_path" >> $REPORT_FILE
  
  # List installed packages
  if command_exists port; then
    echo "Installed packages (first 10 shown):" >> $REPORT_FILE
    port installed | grep -v "^The following" | head -10 | sed 's/^/- /' >> $REPORT_FILE
    if [ $(port installed | grep -v "^The following" | wc -l) -gt 10 ]; then
      echo "- ... ($(port installed | grep -v "^The following" | wc -l | tr -d ' ') total packages)" >> $REPORT_FILE
    fi
  fi
else
  if [ -d "/opt/local" ]; then
    print_warning "MacPorts directory exists but 'port' command not in PATH"
    echo "Status: Directory exists but 'port' command not in PATH" >> $REPORT_FILE
  else
    print_error "MacPorts is not installed"
    echo "Status: Not installed" >> $REPORT_FILE
  fi
fi
echo "" >> $REPORT_FILE

# Check for Fink
print_subheader "Fink"
echo "### Fink" >> $REPORT_FILE
if command_exists fink; then
  fink_path=$(get_real_path "fink")
  fink_version=$(fink --version 2>/dev/null || echo "Version info not available")
  print_success "Fink is installed: $fink_version"
  print_info "Fink executable: $fink_path"
  echo "Status: Installed" >> $REPORT_FILE
  echo "Version: $fink_version" >> $REPORT_FILE
  echo "Executable: $fink_path" >> $REPORT_FILE
else
  if [ -d "/sw" ]; then
    print_warning "Fink directory exists but 'fink' command not in PATH"
    echo "Status: Directory exists but 'fink' command not in PATH" >> $REPORT_FILE
  else
    print_error "Fink is not installed"
    echo "Status: Not installed" >> $REPORT_FILE
  fi
fi
echo "" >> $REPORT_FILE

# Check language-specific package managers
print_header "LANGUAGE PACKAGE MANAGERS"
echo "## Language Package Managers" >> $REPORT_FILE

# Check for npm/Node.js
print_subheader "Node.js and npm"
echo "### Node.js and npm" >> $REPORT_FILE
if command_exists node; then
  node_path=$(get_real_path "node")
  node_version=$(node --version 2>/dev/null)
  print_success "Node.js is installed: $node_version"
  print_info "Node.js executable: $node_path"
  echo "Node.js Status: Installed" >> $REPORT_FILE
  echo "Node.js Version: $node_version" >> $REPORT_FILE
  echo "Node.js Executable: $node_path" >> $REPORT_FILE
  
  if command_exists npm; then
    npm_path=$(get_real_path "npm")
    npm_version=$(npm --version 2>/dev/null)
    print_success "npm is installed: $npm_version"
    print_info "npm executable: $npm_path"
    npm_global_path=$(npm config get prefix 2>/dev/null)
    print_info "npm global packages path: $npm_global_path"
    echo "npm Status: Installed" >> $REPORT_FILE
    echo "npm Version: $npm_version" >> $REPORT_FILE
    echo "npm Executable: $npm_path" >> $REPORT_FILE
    echo "npm Global Path: $npm_global_path" >> $REPORT_FILE
    
    # List global npm packages
    echo "Global npm packages (first 10 shown):" >> $REPORT_FILE
    npm list -g --depth=0 2>/dev/null | grep -v "^├── " | grep -v "^└── " | head -10 | sed 's/^/- /' >> $REPORT_FILE
  else
    print_error "npm is not installed or not in PATH"
    echo "npm Status: Not installed or not in PATH" >> $REPORT_FILE
  fi
else
  print_error "Node.js is not installed or not in PATH"
  echo "Node.js Status: Not installed or not in PATH" >> $REPORT_FILE
fi
echo "" >> $REPORT_FILE

# Check for pip/Python
print_subheader "Python and pip"
echo "### Python and pip" >> $REPORT_FILE

# Create a function to check Python version
check_python() {
  local cmd=$1
  if command_exists "$cmd"; then
    local python_path=$(get_real_path "$cmd")
    local python_version=$($cmd --version 2>&1)
    local site_packages=$($cmd -c "import site; print(site.getsitepackages()[0])" 2>/dev/null)
    print_success "$cmd is installed: $python_version"
    print_info "$cmd executable: $python_path"
    print_info "$cmd site-packages: $site_packages"
    echo "$cmd Status: Installed" >> $REPORT_FILE
    echo "$cmd Version: $python_version" >> $REPORT_FILE
    echo "$cmd Executable: $python_path" >> $REPORT_FILE
    echo "$cmd Site-packages: $site_packages" >> $REPORT_FILE
    return 0
  else
    print_error "$cmd is not installed or not in PATH"
    echo "$cmd Status: Not installed or not in PATH" >> $REPORT_FILE
    return 1
  fi
}

# Check for both python and python3
check_python "python3"
check_python "python"

# Check for pip
if command_exists pip3; then
  pip_path=$(get_real_path "pip3")
  pip_version=$(pip3 --version 2>/dev/null)
  print_success "pip3 is installed: $pip_version"
  print_info "pip3 executable: $pip_path"
  echo "pip3 Status: Installed" >> $REPORT_FILE
  echo "pip3 Version: $pip_version" >> $REPORT_FILE
  echo "pip3 Executable: $pip_path" >> $REPORT_FILE
  
  # List pip packages
  echo "pip3 packages (first 10 shown):" >> $REPORT_FILE
  pip3 list 2>/dev/null | tail -n +3 | head -10 | sed 's/^/- /' >> $REPORT_FILE
elif command_exists pip; then
  pip_path=$(get_real_path "pip")
  pip_version=$(pip --version 2>/dev/null)
  print_success "pip is installed: $pip_version"
  print_info "pip executable: $pip_path"
  echo "pip Status: Installed" >> $REPORT_FILE
  echo "pip Version: $pip_version" >> $REPORT_FILE
  echo "pip Executable: $pip_path" >> $REPORT_FILE
  
  # List pip packages
  echo "pip packages (first 10 shown):" >> $REPORT_FILE
  pip list 2>/dev/null | tail -n +3 | head -10 | sed 's/^/- /' >> $REPORT_FILE
else
  print_error "pip is not installed or not in PATH"
  echo "pip Status: Not installed or not in PATH" >> $REPORT_FILE
fi
echo "" >> $REPORT_FILE

# Check for gem/Ruby
print_subheader "Ruby and gem"
echo "### Ruby and gem" >> $REPORT_FILE
if command_exists ruby; then
  ruby_path=$(get_real_path "ruby")
  ruby_version=$(ruby --version 2>/dev/null)
  print_success "Ruby is installed: $ruby_version"
  print_info "Ruby executable: $ruby_path"
  echo "Ruby Status: Installed" >> $REPORT_FILE
  echo "Ruby Version: $ruby_version" >> $REPORT_FILE
  echo "Ruby Executable: $ruby_path" >> $REPORT_FILE
  
  if command_exists gem; then
    gem_path=$(get_real_path "gem")
    gem_version=$(gem --version 2>/dev/null)
    print_success "gem is installed: $gem_version"
    print_info "gem executable: $gem_path"
    echo "gem Status: Installed" >> $REPORT_FILE
    echo "gem Version: $gem_version" >> $REPORT_FILE
    echo "gem Executable: $gem_path" >> $REPORT_FILE
    
    # List gem packages
    echo "Installed gems (first 10 shown):" >> $REPORT_FILE
    gem list 2>/dev/null | head -10 | sed 's/^/- /' >> $REPORT_FILE
  else
    print_error "gem is not installed or not in PATH"
    echo "gem Status: Not installed or not in PATH" >> $REPORT_FILE
  fi
else
  print_error "Ruby is not installed or not in PATH"
  echo "Ruby Status: Not installed or not in PATH" >> $REPORT_FILE
fi
echo "" >> $REPORT_FILE

# Check environment managers
print_header "ENVIRONMENT MANAGERS"
echo "## Environment Managers" >> $REPORT_FILE

# Check for pyenv
print_subheader "pyenv (Python)"
echo "### pyenv (Python)" >> $REPORT_FILE
if command_exists pyenv; then
  pyenv_path=$(get_real_path "pyenv")
  pyenv_version=$(pyenv --version 2>/dev/null)
  pyenv_root=$(pyenv root 2>/dev/null)
  print_success "pyenv is installed: $pyenv_version"
  print_info "pyenv executable: $pyenv_path"
  print_info "pyenv root: $pyenv_root"
  echo "Status: Installed" >> $REPORT_FILE
  echo "Version: $pyenv_version" >> $REPORT_FILE
  echo "Executable: $pyenv_path" >> $REPORT_FILE
  echo "Root Directory: $pyenv_root" >> $REPORT_FILE
  
  # List pyenv versions
  echo "Installed Python versions:" >> $REPORT_FILE
  pyenv versions 2>/dev/null | sed 's/^/- /' >> $REPORT_FILE
else
  if [ -d "$HOME/.pyenv" ]; then
    print_warning "pyenv directory exists but 'pyenv' command not in PATH"
    echo "Status: Directory exists ($HOME/.pyenv) but 'pyenv' command not in PATH" >> $REPORT_FILE
  else
    print_error "pyenv is not installed"
    echo "Status: Not installed" >> $REPORT_FILE
  fi
fi
echo "" >> $REPORT_FILE

# Check for virtualenv
print_subheader "virtualenv (Python)"
echo "### virtualenv (Python)" >> $REPORT_FILE
if command_exists virtualenv; then
  virtualenv_path=$(get_real_path "virtualenv")
  virtualenv_version=$(virtualenv --version 2>/dev/null)
  print_success "virtualenv is installed: $virtualenv_version"
  print_info "virtualenv executable: $virtualenv_path"
  echo "Status: Installed" >> $REPORT_FILE
  echo "Version: $virtualenv_version" >> $REPORT_FILE
  echo "Executable: $virtualenv_path" >> $REPORT_FILE
  
  # Check for active virtualenv
  if [ -n "$VIRTUAL_ENV" ]; then
    print_success "Active virtualenv: $VIRTUAL_ENV"
    echo "Active virtualenv: $VIRTUAL_ENV" >> $REPORT_FILE
  else
    print_info "No active virtualenv detected"
    echo "Active virtualenv: None" >> $REPORT_FILE
  fi
else
  print_error "virtualenv is not installed or not in PATH"
  echo "Status: Not installed or not in PATH" >> $REPORT_FILE
fi
echo "" >> $REPORT_FILE

# Check for nvm
print_subheader "nvm (Node Version Manager)"
echo "### nvm (Node Version Manager)" >> $REPORT_FILE
if [ -n "$NVM_DIR" ] && [ -s "$NVM_DIR/nvm.sh" ]; then
  if command_exists nvm; then
    nvm_version=$(nvm --version 2>/dev/null)
    print_success "nvm is installed: $nvm_version"
    print_info "nvm directory: $NVM_DIR"
    echo "Status: Installed" >> $REPORT_FILE
    echo "Version: $nvm_version" >> $REPORT_FILE
    echo "Directory: $NVM_DIR" >> $REPORT_FILE
    
    # Get current Node.js version
    current_node_version=$(nvm current 2>/dev/null)
    if [ -n "$current_node_version" ]; then
      print_info "Current Node.js version: $current_node_version"
      echo "Current Node.js version: $current_node_version" >> $REPORT_FILE
    fi
    
    # List all installed Node.js versions
    node_versions=$(nvm ls 2>/dev/null | grep -E "v[0-9]+\.[0-9]+\.[0-9]+" | sed 's/->.*$//' | sed 's/^.*v/v/' | tr -d ' ')
    if [ -n "$node_versions" ]; then
      print_success "Installed Node.js versions:"
      echo "Installed Node.js versions:" >> $REPORT_FILE
      for version in $node_versions; do
        if [[ "$version" == *"$current_node_version"* ]]; then
          print_info "  - $version (current)"
          echo "- $version (current) - Located at: $NVM_DIR/versions/node/$version/bin/node" >> $REPORT_FILE
        else
          print_info "  - $version"
          echo "- $version - Located at: $NVM_DIR/versions/node/$version/bin/node" >> $REPORT_FILE
        fi
      done
      
      # Provide instructions for switching Node.js versions
      echo "" >> $REPORT_FILE
      echo "**How to switch between nvm Node.js versions:**" >> $REPORT_FILE
      echo "" >> $REPORT_FILE
      echo "1. **Use a specific version for the current shell:**" >> $REPORT_FILE
      echo "   \`\`\`bash" >> $REPORT_FILE
      echo "   nvm use 16.20.0" >> $REPORT_FILE
      echo "   \`\`\`" >> $REPORT_FILE
      echo "" >> $REPORT_FILE
      echo "2. **Set default version (for new shells):**" >> $REPORT_FILE
      echo "   \`\`\`bash" >> $REPORT_FILE
      echo "   nvm alias default 16.20.0" >> $REPORT_FILE
      echo "   \`\`\`" >> $REPORT_FILE
      echo "" >> $REPORT_FILE
      echo "3. **Use latest LTS version:**" >> $REPORT_FILE
      echo "   \`\`\`bash" >> $REPORT_FILE
      echo "   nvm use --lts" >> $REPORT_FILE
      echo "   \`\`\`" >> $REPORT_FILE
    else
      print_warning "No Node.js versions found through nvm"
      echo "No Node.js versions found through nvm" >> $REPORT_FILE
    fi
  else
    print_warning "nvm seems to be installed but not properly loaded"
    echo "Status: Installed but not properly loaded" >> $REPORT_FILE
    echo "Directory: $NVM_DIR" >> $REPORT_FILE
  fi
elif [ -d "$HOME/.nvm" ]; then
  print_warning "nvm directory exists but nvm might not be properly configured"
  echo "Status: Directory exists ($HOME/.nvm) but might not be properly configured" >> $REPORT_FILE
else
  print_error "nvm is not installed"
  echo "Status: Not installed" >> $REPORT_FILE
fi
echo "" >> $REPORT_FILE

# Check for conda/Anaconda/Miniconda
print_subheader "conda (Anaconda/Miniconda)"
echo "### conda (Anaconda/Miniconda)" >> $REPORT_FILE
if command_exists conda; then
  conda_path=$(get_real_path "conda")
  conda_version=$(conda --version 2>/dev/null)
  conda_root=$(conda info --base 2>/dev/null)
  print_success "conda is installed: $conda_version"
  print_info "conda executable: $conda_path"
  print_info "conda root directory: $conda_root"
  echo "Status: Installed" >> $REPORT_FILE
  echo "Version: $conda_version" >> $REPORT_FILE
  echo "Executable: $conda_path" >> $REPORT_FILE
  echo "Root Directory: $conda_root" >> $REPORT_FILE
  
  # Check for active conda environment
  if [ -n "$CONDA_DEFAULT_ENV" ] && [ "$CONDA_DEFAULT_ENV" != "base" ]; then
    print_success "Active conda environment: $CONDA_DEFAULT_ENV"
    echo "Active Environment: $CONDA_DEFAULT_ENV" >> $REPORT_FILE
  else
    print_info "No active conda environment detected (or using base)"
    echo "Active Environment: base or none" >> $REPORT_FILE
  fi
  
  # List conda environments with Python versions
  echo "Conda environments:" >> $REPORT_FILE
  conda_envs=$(conda env list 2>/dev/null | grep -v "#")
  if [ -n "$conda_envs" ]; then
    print_success "Found conda environments:"
    echo "$conda_envs" | while read -r line; do
      env_name=$(echo "$line" | awk '{print $1}')
      env_path=$(echo "$line" | awk '{print $2}')
      
      # Skip lines without proper environment name
      if [[ "$env_name" == "*" ]]; then
        env_name=$(echo "$line" | awk '{print $2}')
        env_path=$(echo "$line" | awk '{print $3}')
      fi
      
      # Get Python version in this environment
      if [ -f "$env_path/bin/python" ]; then
        env_python_version=$("$env_path/bin/python" --version 2>&1)
        print_info "  - $env_name ($env_python_version)"
        echo "- $env_name ($env_python_version) - Located at: $env_path" >> $REPORT_FILE
      else
        print_info "  - $env_name"
        echo "- $env_name - Located at: $env_path" >> $REPORT_FILE
      fi
    done
    
    # Provide instructions for switching conda environments
    echo "" >> $REPORT_FILE
    echo "**How to switch between conda environments:**" >> $REPORT_FILE
    echo "" >> $REPORT_FILE
    echo "1. **Activate an environment:**" >> $REPORT_FILE
    echo "   \`\`\`bash" >> $REPORT_FILE
    echo "   conda activate environment_name" >> $REPORT_FILE
    echo "   \`\`\`" >> $REPORT_FILE
    echo "" >> $REPORT_FILE
    echo "2. **Deactivate current environment (return to base):**" >> $REPORT_FILE
    echo "   \`\`\`bash" >> $REPORT_FILE
    echo "   conda deactivate" >> $REPORT_FILE
    echo "   \`\`\`" >> $REPORT_FILE
    echo "" >> $REPORT_FILE
    echo "3. **Create a new environment with specific Python version:**" >> $REPORT_FILE
    echo "   \`\`\`bash" >> $REPORT_FILE
    echo "   conda create -n new_env python=3.12" >> $REPORT_FILE
    echo "   \`\`\`" >> $REPORT_FILE
  else
    print_warning "No conda environments found"
    echo "No conda environments found" >> $REPORT_FILE
  fi
else
  if [ -d "$HOME/anaconda3" ] || [ -d "$HOME/miniconda3" ]; then
    print_warning "Anaconda/Miniconda directory exists but 'conda' command not in PATH"
    echo "Status: Directory exists (~/anaconda3 or ~/miniconda3) but 'conda' command not in PATH" >> $REPORT_FILE
  else
    print_error "conda is not installed"
    echo "Status: Not installed" >> $REPORT_FILE
  fi
fi
echo "" >> $REPORT_FILE

# Check common command resolutions
print_header "COMMAND RESOLUTION"
echo "## Command Resolution" >> $REPORT_FILE
echo "This section shows which version of a command will be executed when you type it." >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Function to check command resolution
check_command() {
  local cmd=$1
  echo "### $cmd" >> $REPORT_FILE
  if command_exists "$cmd"; then
    local path=$(get_real_path "$cmd")
    local version=$($cmd --version 2>&1 | head -n 1)
    print_success "'$cmd' will execute: $path"
    print_info "Version: $version"
    echo "'$cmd' resolves to: $path" >> $REPORT_FILE
    echo "Version: $version" >> $REPORT_FILE
  else
    print_error "'$cmd' command not found"
    echo "'$cmd' command not found" >> $REPORT_FILE
  fi
  echo "" >> $REPORT_FILE
}

print_subheader "Common Commands"
check_command "python"
check_command "python3"
check_command "pip"
check_command "pip3"
check_command "node"
check_command "npm"
check_command "ruby"
check_command "gem"
check_command "perl"
check_command "java"
check_command "go"
check_command "php"

# Shell configuration files
print_header "SHELL CONFIGURATION"
echo "## Shell Configuration" >> $REPORT_FILE

# Detect current shell
current_shell=$(echo $SHELL)
print_info "Current shell: $current_shell"
echo "Current shell: $current_shell" >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Check for shell config files
print_subheader "Configuration Files"
echo "### Configuration Files" >> $REPORT_FILE

# Function to check shell config file
check_config_file() {
  local file=$1
  echo "#### $file" >> $REPORT_FILE
  if [ -f "$file" ]; then
    print_success "$file exists"
    echo "Status: Exists" >> $REPORT_FILE
    
    # Check for package manager configurations
    echo "References to package/environment managers:" >> $REPORT_FILE
    
    # Check for Homebrew
    if grep -q "brew" "$file"; then
      echo "- Homebrew configuration found" >> $REPORT_FILE
    fi
    
    # Check for MacPorts
    if grep -q "/opt/local" "$file"; then
      echo "- MacPorts configuration found" >> $REPORT_FILE
    fi
    
    # Check for Fink
    if grep -q "/sw/" "$file"; then
      echo "- Fink configuration found" >> $REPORT_FILE
    fi
    
    # Check for pyenv
    if grep -q "pyenv" "$file"; then
      echo "- pyenv configuration found" >> $REPORT_FILE
    fi
    
    # Check for nvm
    if grep -q "nvm" "$file"; then
      echo "- nvm configuration found" >> $REPORT_FILE
    fi
    
    # Check for conda
    if grep -q "conda" "$file"; then
      echo "- conda configuration found" >> $REPORT_FILE
    fi
    
    # Check for custom PATH modifications
    if grep -q "export PATH" "$file"; then
      echo "- Custom PATH modifications found" >> $REPORT_FILE
    fi
  else
    print_error "$file does not exist"
    echo "Status: Does not exist" >> $REPORT_FILE
  fi
  echo "" >> $REPORT_FILE
}

# Check common shell config files
check_config_file "$HOME/.bashrc"
check_config_file "$HOME/.bash_profile"
check_config_file "$HOME/.profile"
check_config_file "$HOME/.zshrc"
check_config_file "$HOME/.zprofile"

# Additional available versions from homebrew
print_header "ADDITIONAL AVAILABLE VERSIONS"
echo "## Additional Available Versions" >> $REPORT_FILE

print_subheader "Homebrew Available Versions"
echo "### Homebrew Available Versions" >> $REPORT_FILE

if command_exists brew; then
  # Check for available but not installed Python versions
  print_info "Checking for available Python versions in Homebrew..."
  echo "#### Available Python Versions" >> $REPORT_FILE
  
  # Get installed versions
  installed_pythons=$(brew list | grep -E "^python@|^python$" | sed 's/python@//g' | sed 's/python/default/g')
  
  # Get available versions (formulas that exist but might not be installed)
  available_pythons=$(brew search python | grep -E "^python@[0-9]" | sed 's/python@//g')
  
  # Find versions that are available but not installed
  not_installed=""
  for version in $available_pythons; do
    if ! echo "$installed_pythons" | grep -q "$version"; then
      not_installed="$not_installed $version"
    fi
  done
  
  if [ -n "$not_installed" ]; then
    print_info "Python versions available for installation via Homebrew:"
    echo "Python versions available for installation via Homebrew:" >> $REPORT_FILE
    for version in $not_installed; do
      print_info "  - Python $version"
      echo "- Python $version (can be installed with: brew install python@$version)" >> $REPORT_FILE
    done
  else
    print_info "All available Homebrew Python versions are already installed"
    echo "All available Homebrew Python versions are already installed" >> $REPORT_FILE
  fi
  
  # Check for other common language versions available in Homebrew
  echo "" >> $REPORT_FILE
  echo "#### Other Available Language Versions" >> $REPORT_FILE
  
  # Node.js versions
  print_info "Checking for available Node.js versions in Homebrew..."
  installed_nodes=$(brew list | grep -E "^node@|^node$" | sed 's/node@//g' | sed 's/node/default/g')
  available_nodes=$(brew search node | grep -E "^node@[0-9]" | sed 's/node@//g')
  
  not_installed=""
  for version in $available_nodes; do
    if ! echo "$installed_nodes" | grep -q "$version"; then
      not_installed="$not_installed $version"
    fi
  done
  
  if [ -n "$not_installed" ]; then
    print_info "Node.js versions available for installation via Homebrew:"
    echo "Node.js versions available for installation via Homebrew:" >> $REPORT_FILE
    for version in $not_installed; do
      print_info "  - Node.js $version"
      echo "- Node.js $version (can be installed with: brew install node@$version)" >> $REPORT_FILE
    done
  else
    print_info "All available Homebrew Node.js versions are already installed or none are available"
    echo "All available Homebrew Node.js versions are already installed or none are available" >> $REPORT_FILE
  fi
  
  # PHP versions
  echo "" >> $REPORT_FILE
  print_info "Checking for available PHP versions in Homebrew..."
  installed_phps=$(brew list | grep -E "^php@|^php$" | sed 's/php@//g' | sed 's/php/default/g')
  available_phps=$(brew search php | grep -E "^php@[0-9]" | sed 's/php@//g')
  
  not_installed=""
  for version in $available_phps; do
    if ! echo "$installed_phps" | grep -q "$version"; then
      not_installed="$not_installed $version"
    fi
  done
  
  if [ -n "$not_installed" ]; then
    print_info "PHP versions available for installation via Homebrew:"
    echo "PHP versions available for installation via Homebrew:" >> $REPORT_FILE
    for version in $not_installed; do
      print_info "  - PHP $version"
      echo "- PHP $version (can be installed with: brew install php@$version)" >> $REPORT_FILE
    done
  else
    print_info "All available Homebrew PHP versions are already installed or none are available"
    echo "All available Homebrew PHP versions are already installed or none are available" >> $REPORT_FILE
  fi
fi

# Final summary
print_header "SUMMARY RECOMMENDATIONS"
echo "## Summary and Recommendations" >> $REPORT_FILE

# Add recommendations based on findings
echo "Based on the analysis, here are some recommendations:" >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Add general recommendations
echo "### General Recommendations" >> $REPORT_FILE
echo "" >> $REPORT_FILE
echo "1. **Use environment managers over direct switching:**" >> $REPORT_FILE
echo "   - For Python: Use pyenv or conda instead of brew switching" >> $REPORT_FILE
echo "   - For Node.js: Use nvm instead of brew switching" >> $REPORT_FILE
echo "   - For PHP: Consider php-version or similar tools" >> $REPORT_FILE
echo "" >> $REPORT_FILE
echo "2. **Organize your PATH effectively:**" >> $REPORT_FILE
echo "   - Place user directories before system directories" >> $REPORT_FILE
echo "   - Ensure environment managers are properly configured in your shell" >> $REPORT_FILE
echo "" >> $REPORT_FILE
echo "3. **Create project-specific environments:**" >> $REPORT_FILE
echo "   - Python: Use virtualenv/venv for per-project isolation" >> $REPORT_FILE
echo "   - Node.js: Use local package.json and npm instead of global installations" >> $REPORT_FILE
echo "" >> $REPORT_FILE
echo "4. **Maintain consistency:**" >> $REPORT_FILE
echo "   - Pick one package manager (Homebrew OR MacPorts OR Fink)" >> $REPORT_FILE
echo "   - Document your environment setup for reproducibility" >> $REPORT_FILE
echo "" >> $REPORT_FILE

# Move report to home directory with timestamp
REPORT_TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
FINAL_REPORT="$HOME/macos_inventory_${REPORT_TIMESTAMP}.md"
mv $REPORT_FILE $FINAL_REPORT

print_success "Inventory completed!"
print_info "A detailed report has been saved to: $FINAL_REPORT"
echo "You can view it with: open $FINAL_REPORT"
