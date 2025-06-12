#!/bin/bash

# Schedule App Deployment Script for Linux Server
# Enhanced version with better error handling and user experience

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Emojis for better UX
SUCCESS="✅"
ERROR="❌"
WARNING="⚠️"
INFO="ℹ️"
ROCKET="🚀"
GEAR="⚙️"
DATABASE="🗄️"

# Script configuration
SCRIPT_VERSION="2.0.0"
APP_NAME="Schedule App"
APP_DIR="/var/www/schedule-app"
SERVICE_NAME="schedule-app"
NGINX_SITE="schedule-app"

# Function to print colored output
print_status() {
    echo -e "${GREEN}${SUCCESS}${NC} $1"
}

print_error() {
    echo -e "${RED}${ERROR}${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}${WARNING}${NC} $1"
}

print_info() {
    echo -e "${BLUE}${INFO}${NC} $1"
}

print_header() {
    echo -e "${PURPLE}${GEAR}${NC} $1"
}

print_step() {
    echo -e "${CYAN}${ROCKET}${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check system requirements
check_system_requirements() {
    print_header "Checking system requirements..."
    
    # Check if running on supported OS
    if [[ ! -f /etc/os-release ]]; then
        print_error "Cannot detect OS version. This script supports Ubuntu/Debian systems."
        exit 1
    fi
    
    source /etc/os-release
    if [[ "$ID" != "ubuntu" && "$ID" != "debian" ]]; then
        print_warning "This script is designed for Ubuntu/Debian. Your OS: $PRETTY_NAME"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    # Check available disk space (minimum 5GB)
    available_space=$(df / | awk 'NR==2 {print $4}')
    if [[ $available_space -lt 5242880 ]]; then  # 5GB in KB
        print_warning "Low disk space detected. Recommended: 10GB+, Available: $(df -h / | awk 'NR==2 {print $4}')"
    fi
    
    # Check available memory (minimum 512MB)
    available_memory=$(free -m | awk 'NR==2{printf "%.0f", $7}')
    if [[ $available_memory -lt 512 ]]; then
        print_warning "Low memory detected. Recommended: 1GB+, Available: ${available_memory}MB"
    fi
    
    print_status "System requirements checked"
}

# Function to cleanup on exit
cleanup() {
    if [[ -n "$FLASK_PID" ]]; then
        print_info "Cleaning up Flask process..."
        kill $FLASK_PID 2>/dev/null || true
        wait $FLASK_PID 2>/dev/null || true
    fi
}

# Set up cleanup trap
trap cleanup EXIT

# Function to show progress
show_progress() {
    local current=$1
    local total=$2
    local task=$3
    local percent=$((current * 100 / total))
    printf "\r${CYAN}Progress: ${NC}[%-20s] %d%% - %s" $(printf "#%.0s" $(seq 1 $((percent/5)))) $percent "$task"
    if [[ $current -eq $total ]]; then
        echo
    fi
}

# Function to install packages with progress
install_packages() {
    local packages=("$@")
    local total=${#packages[@]}
    
    print_step "Installing system packages..."
    
    for i in "${!packages[@]}"; do
        show_progress $((i+1)) $total "Installing ${packages[$i]}"
        sudo apt install -y "${packages[$i]}" >/dev/null 2>&1
    done
    
    print_status "All packages installed successfully"
}

# Function to backup existing installation
backup_existing() {
    if [[ -d "$APP_DIR" ]]; then
        print_warning "Existing installation found at $APP_DIR"
        local backup_dir="${APP_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
        
        read -p "Create backup? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            print_step "Creating backup at $backup_dir..."
            sudo cp -r "$APP_DIR" "$backup_dir"
            print_status "Backup created successfully"
        fi
        
        print_step "Removing existing installation..."
        sudo rm -rf "$APP_DIR"
    fi
}

# Function to create systemd service with better configuration
create_systemd_service() {
    print_step "Creating optimized systemd service..."
    
    sudo tee /etc/systemd/system/${SERVICE_NAME}.service > /dev/null << EOF
[Unit]
Description=${APP_NAME} Flask Backend
Documentation=https://github.com/yourusername/schedule-app
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=60
StartLimitBurst=3

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=$APP_DIR
Environment=PATH=$APP_DIR/venv/bin
Environment=PYTHONPATH=$APP_DIR
Environment=FLASK_ENV=production
ExecStart=$APP_DIR/venv/bin/python backend/app.py
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=mixed
KillSignal=SIGINT
TimeoutStopSec=5
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal
SyslogIdentifier=${SERVICE_NAME}

# Security settings
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=$APP_DIR
CapabilityBoundingSet=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
EOF

    print_status "Systemd service created with security enhancements"
}

# Function to create optimized nginx configuration
create_nginx_config() {
    print_step "Creating optimized Nginx configuration..."
    
    sudo tee /etc/nginx/sites-available/${NGINX_SITE} > /dev/null << EOF
server {
    listen 80;
    server_name _;
    
    # Security headers
    add_header X-Frame-Options DENY;
    add_header X-Content-Type-Options nosniff;
    add_header X-XSS-Protection "1; mode=block";
    add_header Referrer-Policy strict-origin-when-cross-origin;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css text/xml text/javascript application/javascript application/json;
    
    # Frontend static files
    location / {
        root $APP_DIR/frontend/dist;
        try_files \$uri \$uri/ /index.html;
        
        # Cache static assets
        location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
    }
    
    # Backend API
    location /api {
        proxy_pass http://127.0.0.1:5001;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_connect_timeout 30s;
        proxy_send_timeout 30s;
        proxy_read_timeout 30s;
        proxy_buffering off;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "healthy\n";
        add_header Content-Type text/plain;
    }
}
EOF

    print_status "Nginx configuration created with optimizations"
}

# Function to perform health checks
perform_health_checks() {
    print_header "Performing health checks..."
    
    local checks_passed=0
    local total_checks=4
    
    # Check 1: Backend service status
    show_progress 1 $total_checks "Checking backend service"
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        ((checks_passed++))
    fi
    
    # Check 2: Nginx service status
    show_progress 2 $total_checks "Checking Nginx service"
    if systemctl is-active --quiet nginx; then
        ((checks_passed++))
    fi
    
    # Check 3: HTTP response
    show_progress 3 $total_checks "Testing HTTP response"
    if curl -s -o /dev/null -w "%{http_code}" http://localhost | grep -q "200"; then
        ((checks_passed++))
    fi
    
    # Check 4: API endpoint
    show_progress 4 $total_checks "Testing API endpoint"
    if curl -s -f http://localhost/api/user >/dev/null 2>&1; then
        ((checks_passed++))
    fi
    
    echo
    if [[ $checks_passed -eq $total_checks ]]; then
        print_status "All health checks passed ($checks_passed/$total_checks)"
    else
        print_warning "Some health checks failed ($checks_passed/$total_checks)"
    fi
}

# Function to display service status
show_service_status() {
    print_header "Service Status Overview"
    
    echo "Backend Service:"
    if systemctl is-active --quiet ${SERVICE_NAME}; then
        echo -e "  ${GREEN}● Running${NC} - $(systemctl show -p ActiveState --value ${SERVICE_NAME})"
    else
        echo -e "  ${RED}● Failed${NC} - $(systemctl show -p ActiveState --value ${SERVICE_NAME})"
    fi
    
    echo "Nginx Service:"
    if systemctl is-active --quiet nginx; then
        echo -e "  ${GREEN}● Running${NC} - $(systemctl show -p ActiveState --value nginx)"
    else
        echo -e "  ${RED}● Failed${NC} - $(systemctl show -p ActiveState --value nginx)"
    fi
    
    echo "Memory Usage:"
    echo "  $(free -h | awk 'NR==2{printf "Used: %s / %s (%.0f%%)", $3, $2, $3*100/$2}')"
    
    echo "Disk Usage:"
    echo "  $(df -h / | awk 'NR==2{printf "Used: %s / %s (%s)", $3, $2, $5}')"
}

# Main execution starts here
main() {
    clear
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                    📅 Schedule App Deployer                  ║"
    echo "║                        Version $SCRIPT_VERSION                        ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # Check if running as root
    if [[ $EUID -eq 0 ]]; then
        print_error "This script should not be run as root for security reasons"
        print_info "Please run as a regular user with sudo privileges"
        exit 1
    fi

    # Parse command line arguments
    PRODUCTION_MODE=false
    SKIP_TESTS=false
    FORCE_INSTALL=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --production)
                PRODUCTION_MODE=true
                shift
                ;;
            --skip-tests)
                SKIP_TESTS=true
                shift
                ;;
            --force)
                FORCE_INSTALL=true
                shift
                ;;
            --help|-h)
                echo "Usage: $0 [OPTIONS]"
                echo "Options:"
                echo "  --production    Deploy for production (no test data)"
                echo "  --skip-tests    Skip health checks"
                echo "  --force         Force installation (skip confirmations)"
                echo "  --help, -h      Show this help message"
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Display configuration
    print_info "Deployment Configuration:"
    echo "  Mode: $(if [[ "$PRODUCTION_MODE" == true ]]; then echo "Production"; else echo "Development"; fi)"
    echo "  App Directory: $APP_DIR"
    echo "  Service Name: $SERVICE_NAME"
    echo "  Skip Tests: $SKIP_TESTS"
    echo ""

    if [[ "$FORCE_INSTALL" != true ]]; then
        print_warning "This will install system packages and modify system configuration"
        print_info "Press Ctrl+C to cancel or wait 5 seconds to continue..."
        sleep 5
    fi

    # System checks
    check_system_requirements

    # Backup existing installation
    backup_existing

    # Update system packages
    print_step "Updating system package list..."
    sudo apt update >/dev/null 2>&1
    print_status "Package list updated"

    # Install required packages
    local packages=(
        "python3" "python3-pip" "python3-venv" 
        "nodejs" "npm" "nginx" 
        "curl" "git" "htop"
    )
    install_packages "${packages[@]}"

    # Create app directory with proper permissions
    print_step "Setting up application directory..."
    sudo mkdir -p $APP_DIR
    sudo chown $USER:$USER $APP_DIR
    print_status "Application directory ready"

    # Copy application files
    print_step "Copying application files..."
    cp -r backend/ $APP_DIR/
    cp -r frontend/ $APP_DIR/
    cp requirements.txt $APP_DIR/
    cp test_multi_user.py $APP_DIR/
    print_status "Application files copied"

    cd $APP_DIR

    # Setup Python backend
    print_step "Setting up Python virtual environment..."
    python3 -m venv venv
    source venv/bin/activate
    
    print_step "Installing Python dependencies..."
    pip install --upgrade pip >/dev/null 2>&1
    pip install -r requirements.txt >/dev/null 2>&1
    print_status "Python backend ready"

    # Setup Node.js frontend
    print_step "Installing Node.js dependencies..."
    cd frontend
    npm install >/dev/null 2>&1
    
    print_step "Building frontend application..."
    npm run build >/dev/null 2>&1
    cd ..
    print_status "Frontend application built"

    # Create systemd service
    create_systemd_service

    # Create nginx configuration
    create_nginx_config

    # Enable nginx site
    print_step "Configuring Nginx..."
    sudo ln -sf /etc/nginx/sites-available/${NGINX_SITE} /etc/nginx/sites-enabled/
    sudo rm -f /etc/nginx/sites-enabled/default
    
    # Test nginx configuration
    if ! sudo nginx -t >/dev/null 2>&1; then
        print_error "Nginx configuration test failed"
        exit 1
    fi
    print_status "Nginx configured successfully"

    # Initialize database
    print_step "Initializing database..."
    source venv/bin/activate

    # Start Flask app temporarily to initialize database
    python backend/app.py &
    FLASK_PID=$!
    sleep 8

    # Check if Flask app started successfully
    if ! ps -p $FLASK_PID > /dev/null; then
        print_error "Failed to start Flask app for database initialization"
        exit 1
    fi

    print_status "${DATABASE} Database initialized successfully"
    kill $FLASK_PID 2>/dev/null || true
    wait $FLASK_PID 2>/dev/null || true
    FLASK_PID=""

    # Create test users only in development mode
    if [[ "$PRODUCTION_MODE" == false ]]; then
        print_step "Creating test users for demonstration..."
        python test_multi_user.py >/dev/null 2>&1
        print_status "Demo users created successfully"
    else
        print_info "Production mode - skipping test data creation"
    fi

    # Start and enable services
    print_step "Starting and enabling services..."
    sudo systemctl daemon-reload
    sudo systemctl enable ${SERVICE_NAME} >/dev/null 2>&1
    sudo systemctl start ${SERVICE_NAME}
    sudo systemctl enable nginx >/dev/null 2>&1
    sudo systemctl restart nginx
    print_status "Services started and enabled"

    # Wait for services to stabilize
    sleep 3

    # Perform health checks
    if [[ "$SKIP_TESTS" != true ]]; then
        perform_health_checks
    fi

    # Show final status
    echo
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                   🎉 DEPLOYMENT COMPLETE! 🎉                 ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo

    show_service_status

    echo
    print_header "Access Information"
    local server_ip=$(hostname -I | awk '{print $1}')
    echo "🌐 Web Application: http://$server_ip"
    echo "🔗 Health Check: http://$server_ip/health"
    
    if [[ "$PRODUCTION_MODE" == false ]]; then
        echo
        print_header "Demo Users (Development Mode)"
        echo "👩‍💻 alice / password123 (Frontend Development)"
        echo "👨‍💻 bob / password123 (Backend Development)"
        echo "🎨 charlie / password123 (UI/UX Design)"
        echo "📊 diana / password123 (Data Analysis)"
    else
        echo
        print_info "Production deployment complete - create your first user via the web interface"
    fi

    echo
    print_header "Management Commands"
    echo "📊 View backend logs: sudo journalctl -u ${SERVICE_NAME} -f"
    echo "📊 View nginx logs: sudo tail -f /var/log/nginx/error.log"
    echo "🔄 Restart backend: sudo systemctl restart ${SERVICE_NAME}"
    echo "🔄 Restart nginx: sudo systemctl restart nginx"
    echo "🔧 Check status: sudo systemctl status ${SERVICE_NAME}"
    
    echo
    print_header "Troubleshooting"
    echo "🔍 Backend not starting: Check logs and database permissions"
    echo "🔍 Nginx 502 error: Ensure backend service is running"
    echo "🔍 Permission issues: Check $APP_DIR ownership"
    
    echo
    print_success "🚀 ${APP_NAME} is now ready for use!"
}

# Run main function
main "$@" 