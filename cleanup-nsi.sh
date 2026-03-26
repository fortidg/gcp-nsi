#!/bin/bash

# NSI Cleanup Script
# Run this script before terraform destroy to clean up manually created NSI resources

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Check if required variables are set
check_variables() {
    if [ -z "$PROJECT_ID" ]; then
        print_error "PROJECT_ID environment variable is required"
        print_error "Usage: PROJECT_ID=your-project-id ORGANIZATION_ID=your-org-id $0"
        exit 1
    fi
    
    if [ -z "$ORGANIZATION_ID" ]; then
        print_error "ORGANIZATION_ID environment variable is required"
        print_error "Usage: PROJECT_ID=your-project-id ORGANIZATION_ID=your-org-id $0"
        exit 1
    fi
    
    print_status "Using PROJECT_ID: $PROJECT_ID"
    print_status "Using ORGANIZATION_ID: $ORGANIZATION_ID"
}

# Delete NSI resources in the correct order (reverse of creation)
cleanup_nsi_resources() {
    print_step "1. Removing firewall policy association..."
    gcloud compute network-firewall-policies associations delete newfgt-nsi-policy-assoc \
        --global-firewall-policy \
        --firewall-policy newfgt-nsi \
        --project "$PROJECT_ID" \
        --quiet || {
        print_warning "Firewall policy association may not exist or already deleted"
    }
    
    print_step "2. Deleting firewall policy rules..."
    gcloud compute network-firewall-policies rules delete 11 \
        --firewall-policy newfgt-nsi \
        --global-firewall-policy \
        --project "$PROJECT_ID" \
        --quiet || {
        print_warning "Firewall policy rule 11 may not exist or already deleted"
    }
    
    gcloud compute network-firewall-policies rules delete 10 \
        --firewall-policy newfgt-nsi \
        --global-firewall-policy \
        --project "$PROJECT_ID" \
        --quiet || {
        print_warning "Firewall policy rule 10 may not exist or already deleted"
    }
    
    print_step "3. Deleting firewall policy..."
    gcloud compute network-firewall-policies delete newfgt-nsi \
        --project "$PROJECT_ID" \
        --global \
        --quiet || {
        print_warning "Firewall policy may not exist or already deleted"
    }
    
    print_step "4. Deleting security profile group..."
    gcloud beta network-security security-profile-groups delete newfgt-nsi-ftnt-spg1 \
        --billing-project "$PROJECT_ID" \
        --organization "$ORGANIZATION_ID" \
        --location global \
        --quiet || {
        print_warning "Security profile group may not exist or already deleted"
    }
    
    print_step "5. Deleting security profile..."
    gcloud beta network-security security-profiles custom-intercept delete newfgt-nsi-ftnt-sp1 \
        --billing-project "$PROJECT_ID" \
        --organization "$ORGANIZATION_ID" \
        --location global \
        --quiet || {
        print_warning "Security profile may not exist or already deleted"
    }
    
    print_step "6. Deleting intercept endpoint group association..."
    gcloud beta network-security intercept-endpoint-group-associations delete new-fgt-nsi-ftnt-epg-assoc \
        --project "$PROJECT_ID" \
        --location global \
        --quiet || {
        print_warning "Intercept endpoint group association may not exist or already deleted"
    }
    
    print_step "7. Deleting intercept endpoint group..."
    gcloud beta network-security intercept-endpoint-groups delete newfgt-nsi-ftnt-epg \
        --project "$PROJECT_ID" \
        --location global \
        --quiet || {
        print_warning "Intercept endpoint group may not exist or already deleted"
    }
    
    print_step "8. Deleting intercept deployments..."
    gcloud beta network-security intercept-deployments delete fgt-nsi-us-central1a \
        --location=us-central1-a \
        --project="$PROJECT_ID" \
        --quiet || {
        print_warning "Intercept deployment us-central1a may not exist or already deleted"
    }
    
    gcloud beta network-security intercept-deployments delete fgt-nsi-us-central1b \
        --location=us-central1-b \
        --project="$PROJECT_ID" \
        --quiet || {
        print_warning "Intercept deployment us-central1b may not exist or already deleted"
    }
    
    gcloud beta network-security intercept-deployments delete fgt-nsi-us-central1c1 \
        --location=us-central1c \
        --project="$PROJECT_ID" \
        --quiet || {
        print_warning "Intercept deployment us-central1c may not exist or already deleted"
    }
    
    print_step "9. Deleting intercept deployment group..."
    gcloud beta network-security intercept-deployment-groups delete newfgt-nsi-ftnt-dg \
        --location global \
        --project "$PROJECT_ID" \
        --quiet || {
        print_warning "Intercept deployment group may not exist or already deleted"
    }
}

# Wait for cleanup to complete
wait_for_cleanup() {
    print_status "Waiting for cleanup operations to complete..."
    sleep 30
    print_status "Cleanup operations should now be complete."
    print_status "You can now run 'terraform destroy --auto-approve' safely."
}

# Main execution
main() {
    print_status "Starting NSI cleanup script..."
    
    check_variables
    cleanup_nsi_resources
    wait_for_cleanup
    
    print_status "NSI cleanup completed successfully!"
    print_status "You can now proceed with 'terraform destroy --auto-approve'"
}

# Check if environment variables are set and run
if [ -n "$PROJECT_ID" ] && [ -n "$ORGANIZATION_ID" ]; then
    main
else
    echo "Usage: $0"
    echo ""
    echo "Environment variables required:"
    echo "  PROJECT_ID      - GCP Project ID"
    echo "  ORGANIZATION_ID - GCP Organization ID"
    echo ""
    echo "Example:"
    echo "  export PROJECT_ID=your-project-id"
    echo "  export ORGANIZATION_ID=123456789012"
    echo "  $0"
    echo ""
    echo "Or run directly:"
    echo "  PROJECT_ID=your-project-id ORGANIZATION_ID=your-org-id $0"
    echo ""
    print_error "Please set PROJECT_ID and ORGANIZATION_ID environment variables"
    exit 1
fi