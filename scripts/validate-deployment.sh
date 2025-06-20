#!/bin/bash
# Single-instance wrapper for post-deployment validation script

set -e

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOCK_FILE="/tmp/post-deploy-validation.lock"
PID_FILE="/tmp/post-deploy-validation.pid"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if another validation is already running
check_running_validation() {
    if [ -f "$PID_FILE" ]; then
        local existing_pid=$(cat "$PID_FILE")
        if ps -p "$existing_pid" > /dev/null 2>&1; then
            local cmd=$(ps -p "$existing_pid" -o cmd --no-headers 2>/dev/null)
            if [[ "$cmd" == *"post-deploy-validate.sh"* ]]; then
                return 0  # Process is running
            fi
        fi
        # PID file exists but process is dead, clean up
        rm -f "$PID_FILE"
    fi
    return 1  # No process running
}

# Stop all running validation scripts
stop_all_validations() {
    log_info "Stopping all running validation scripts..."
    
    # Kill by script name
    if pgrep -f "post-deploy-validate.sh" > /dev/null; then
        pkill -TERM -f "post-deploy-validate.sh"
        sleep 2
        
        # Force kill if still running
        if pgrep -f "post-deploy-validate.sh" > /dev/null; then
            log_warning "Force killing remaining validation processes..."
            pkill -9 -f "post-deploy-validate.sh"
        fi
    fi
    
    # Clean up monitoring processes
    local logs_dir="${SCRIPT_DIR}/../logs"
    if [ -f "${logs_dir}/monitoring.pid" ]; then
        local monitor_pid=$(cat "${logs_dir}/monitoring.pid")
        if ps -p "$monitor_pid" > /dev/null 2>&1; then
            log_info "Stopping background monitoring process (PID: $monitor_pid)..."
            kill "$monitor_pid" 2>/dev/null || true
        fi
        rm -f "${logs_dir}/monitoring.pid"
    fi
    
    # Clean up lock and PID files
    rm -f "$LOCK_FILE" "$PID_FILE"
    
    log_success "All validation processes stopped"
}

# Show status of running validations
show_status() {
    echo "🔍 Validation Status:"
    
    if check_running_validation; then
        local existing_pid=$(cat "$PID_FILE")
        local start_time=$(ps -p "$existing_pid" -o lstart --no-headers 2>/dev/null || echo "Unknown")
        echo "   Status: ✅ Running"
        echo "   PID: $existing_pid"
        echo "   Started: $start_time"
        
        # Check for monitoring process
        local logs_dir="${SCRIPT_DIR}/../logs"
        if [ -f "${logs_dir}/monitoring.pid" ]; then
            local monitor_pid=$(cat "${logs_dir}/monitoring.pid")
            if ps -p "$monitor_pid" > /dev/null 2>&1; then
                echo "   Monitoring PID: $monitor_pid"
            fi
        fi
        
        # Show recent logs
        local latest_log=$(ls -t "${logs_dir}"/validation-*.log 2>/dev/null | head -1)
        if [ -n "$latest_log" ]; then
            echo "   Latest Log: $latest_log"
            echo "   Recent Activity:"
            tail -3 "$latest_log" | sed 's/^/      /'
        fi
    else
        echo "   Status: ❌ Not running"
        
        # Check for orphaned processes
        local orphans=$(pgrep -f "post-deploy-validate.sh" 2>/dev/null || true)
        if [ -n "$orphans" ]; then
            echo "   ⚠️  Orphaned processes detected: $orphans"
            echo "   Run: $0 --stop to clean up"
        fi
    fi
}

# Start validation with single instance protection
start_validation() {
    log_info "Starting deployment validation..."
    
    # Check if already running
    if check_running_validation; then
        local existing_pid=$(cat "$PID_FILE")
        log_error "Validation script already running (PID: $existing_pid)"
        log_info "Use '$0 --status' to check status or '$0 --stop' to stop it"
        exit 1
    fi
    
    # Check for orphaned processes
    if pgrep -f "post-deploy-validate.sh" > /dev/null; then
        log_warning "Found orphaned validation processes. Cleaning up..."
        stop_all_validations
        sleep 1
    fi
    
    # Use flock for exclusive execution
    log_info "Acquiring validation lock..."
    
    (
        # Acquire lock
        if ! flock -n 200; then
            log_error "Could not acquire validation lock. Another instance may be starting."
            exit 1
        fi
        
        log_success "Lock acquired. Starting validation script..."
        
        # Start the actual validation script
        cd "${SCRIPT_DIR}/.."
        ./scripts/post-deploy-validate.sh &
        local validation_pid=$!
        
        # Store PID
        echo "$validation_pid" > "$PID_FILE"
        
        log_success "Validation started (PID: $validation_pid)"
        log_info "Use '$0 --status' to monitor progress"
        log_info "Use '$0 --stop' to stop validation"
        log_info "Use '$0 --logs' to follow logs"
        
        # Wait for the process to complete
        wait "$validation_pid"
        local exit_code=$?
        
        # Clean up
        rm -f "$PID_FILE"
        
        case $exit_code in
            0)
                log_success "Validation completed successfully"
                ;;
            1)
                log_error "Validation failed"
                ;;
            2)
                log_warning "Validation failed but rollback succeeded"
                ;;
            130)
                log_warning "Validation was interrupted"
                ;;
            *)
                log_error "Validation exited with code: $exit_code"
                ;;
        esac
        
        exit $exit_code
        
    ) 200>"$LOCK_FILE"
}

# Follow validation logs
follow_logs() {
    local logs_dir="${SCRIPT_DIR}/../logs"
    local latest_log=$(ls -t "${logs_dir}"/validation-*.log 2>/dev/null | head -1)
    
    if [ -n "$latest_log" ]; then
        log_info "Following log: $latest_log"
        tail -f "$latest_log"
    else
        log_error "No validation logs found in $logs_dir"
        exit 1
    fi
}

# Show usage
show_usage() {
    echo "🚀 Deployment Validation Wrapper"
    echo ""
    echo "Usage: $0 [OPTION]"
    echo ""
    echo "Options:"
    echo "  --start, -s     Start validation (default action)"
    echo "  --stop          Stop all running validations"
    echo "  --status        Show validation status"
    echo "  --logs, -l      Follow validation logs"
    echo "  --help, -h      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0              # Start validation"
    echo "  $0 --status     # Check if validation is running"
    echo "  $0 --stop       # Stop all validations"
    echo "  $0 --logs       # Follow current validation logs"
}

# Cleanup on exit
cleanup() {
    if [ -f "$PID_FILE" ]; then
        local pid=$(cat "$PID_FILE")
        if ! ps -p "$pid" > /dev/null 2>&1; then
            rm -f "$PID_FILE"
        fi
    fi
}

trap cleanup EXIT

# Main execution
case "${1:-}" in
    --start|-s|"")
        start_validation
        ;;
    --stop)
        stop_all_validations
        ;;
    --status)
        show_status
        ;;
    --logs|-l)
        follow_logs
        ;;
    --help|-h)
        show_usage
        ;;
    *)
        log_error "Unknown option: $1"
        show_usage
        exit 1
        ;;
esac