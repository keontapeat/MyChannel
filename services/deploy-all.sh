#!/usr/bin/env bash

# Deploy All MyChannel Services to Google Cloud Run
# This script deploys all microservices with proper configuration

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
# Prefer explicit env var, else use current gcloud config project
PROJECT_ID=${GOOGLE_CLOUD_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null)}
if [ -z "$PROJECT_ID" ]; then
    PROJECT_ID="mychannel-ca26d"
fi
REGION=${REGION:-"us-central1"}
ENVIRONMENT=${ENVIRONMENT:-"production"}

# Service configurations (service memory cpu max_instances concurrency min_instances)
SERVICES_CONFIG=$(cat << 'EOF'
auth 1Gi 1 300 80 2
content 2Gi 2 500 80 2
upload 4Gi 2 200 20 1
transcode 8Gi 4 200 1 0
events 1Gi 1 300 80 1
recommendations 2Gi 2 300 50 1
creator 1Gi 1 200 50 1
search 2Gi 2 500 80 2
moderation 2Gi 2 300 40 1
EOF
)

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if gcloud is installed
    if ! command -v gcloud &> /dev/null; then
        log_error "gcloud CLI is not installed. Please install it first."
        exit 1
    fi
    
    # Check if docker is installed
    if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed. Please install it first."
        exit 1
    fi
    
    # Check if logged into gcloud
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        log_error "Not logged into gcloud. Please run 'gcloud auth login' first."
        exit 1
    fi
    
    # Set the project
    gcloud config set project $PROJECT_ID
    
    log_success "Prerequisites check passed"
}

build_and_deploy_service() {
    local service=$1
    local memory=$2
    local cpu=$3
    local max_instances=$4
    local concurrency=$5
    local min_instances=$6
    
    log_info "Building and deploying $service service..."
    
    # Build the container image
    log_info "Building container image for $service..."
    gcloud builds submit \
        --config services/cloudbuild-$service.yaml \
        --substitutions=_SERVICE_NAME=$service,_REGION=$REGION \
        . || {
        log_error "Failed to build $service"
        return 1
    }

    if gcloud run services describe mychannel-$service --region=$REGION >/dev/null 2>&1; then
        log_info "Updating scaling for $service..."
        gcloud run services update mychannel-$service \
            --region=$REGION \
            --platform=managed \
            --cpu=$cpu \
            --memory=$memory \
            --concurrency=$concurrency \
            --max-instances=$max_instances \
            --min-instances=$min_instances \
            --timeout=60s \
            >/dev/null || log_warning "Could not update scaling for $service (will be applied on first deploy)."
    else
        log_warning "Service mychannel-$service not found yet; scaling will be applied on first deploy."
    fi
    
    log_success "Successfully built and deployed $service service"
}

deploy_all_services() {
    log_info "Starting deployment of all services..."
    
    local failed_services=()
    local successful_count=0
    local total_services=$(awk 'NF>=2 {n++} END{print n+0}' <<< "$SERVICES_CONFIG")
    
    while read -r service memory cpu max_instances concurrency min_instances; do
        [ -z "$service" ] && continue
        
        if build_and_deploy_service "$service" "$memory" "$cpu" "$max_instances" "$concurrency" "$min_instances"; then
            log_success "✅ $service deployed successfully"
            successful_count=$((successful_count+1))
        else
            log_error "❌ $service deployment failed"
            failed_services+=("$service")
        fi
        
        echo "" # Add spacing between services
    done <<< "$SERVICES_CONFIG"
    
    # Report results
    echo "================================================="
    log_info "Deployment Summary"
    echo "================================================="
    
    log_info "Successfully deployed: $successful_count/$total_services services"
    
    if [ ${#failed_services[@]} -gt 0 ]; then
        log_warning "Failed services: ${failed_services[*]}"
        exit 1
    else
        log_success "🎉 All services deployed successfully!"
    fi
}

setup_load_balancer() {
    log_info "Setting up load balancer and API gateway..."
    
    # Create a simple load balancer configuration
    # This would typically involve setting up Cloud Load Balancer
    # For now, we'll just output the service URLs
    
    echo ""
    echo "================================================="
    log_info "Service URLs"
    echo "================================================="
    
    while read -r service _; do
        [ -z "$service" ] && continue
        local url=$(gcloud run services describe mychannel-$service \
            --region=$REGION \
            --format="value(status.url)" 2>/dev/null || echo "Not deployed")
        echo "$service: $url"
    done <<< "$SERVICES_CONFIG"
}

create_secrets() {
    log_info "Creating secrets in Secret Manager..."
    
    # Create secrets for sensitive configuration
    local secrets=(
        "jwt-secret"
        "supabase-service-key"
        "openai-api-key"
        "sendgrid-api-key"
    )
    
    for secret in "${secrets[@]}"; do
        if ! gcloud secrets describe $secret &>/dev/null; then
            log_info "Creating secret: $secret"
            echo "placeholder-value" | gcloud secrets create $secret --data-file=-
            log_warning "⚠️  Remember to update the value for secret: $secret"
        else
            log_info "Secret $secret already exists"
        fi
    done
}

main() {
    echo "================================================="
    echo "🚀 MyChannel Services Deployment Script"
    echo "================================================="
    echo "Project: $PROJECT_ID"
    echo "Region: $REGION"
    echo "Environment: $ENVIRONMENT"
    echo "================================================="
    echo ""
    
    check_prerequisites
    create_secrets
    deploy_all_services
    setup_load_balancer
    
    echo ""
    echo "================================================="
    log_success "🎉 Deployment completed successfully!"
    echo "================================================="
    echo ""
    log_info "Next steps:"
    echo "1. Update secret values in Google Secret Manager"
    echo "2. Configure your domain and SSL certificates"
    echo "3. Set up monitoring and alerting"
    echo "4. Update your iOS app with the new service URLs"
    echo ""
}

# Handle script arguments
case "${1:-all}" in
    "check")
        check_prerequisites
        ;;
    "secrets")
        create_secrets
        ;;
    "auth"|"content"|"upload"|"transcode"|"events"|"recommendations"|"creator"|"search"|"moderation")
        check_prerequisites
        line=$(echo "$SERVICES_CONFIG" | awk -v svc="$1" '$1==svc {print}')
        if [ -z "$line" ]; then
            log_error "Service config for $1 not found"
            exit 1
        fi
        read -r _ memory cpu max_instances concurrency min_instances <<< "$line"
        build_and_deploy_service "$1" "$memory" "$cpu" "$max_instances" "$concurrency" "$min_instances"
        ;;
    "all"|*)
        main
        ;;
esac

