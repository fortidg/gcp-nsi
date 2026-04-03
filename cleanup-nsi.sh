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

# Helper: delete a resource and treat NOT_FOUND as success; exit on other errors
delete_or_skip() {
    local desc="$1"
    shift
    local output
    output=$("$@" 2>&1)
    local rc=$?
    if [[ $rc -eq 0 ]]; then
        print_status "Deleted: $desc"
    elif echo "$output" | grep -qE "NOT_FOUND|was not found|Could not fetch resource|already deleted"; then
        print_warning "$desc not found, skipping"
    else
        print_error "Failed to delete $desc:"
        echo "$output" >&2
        CLEANUP_ERRORS=$((CLEANUP_ERRORS + 1))
    fi
}

# Delete NSI resources in the correct order (reverse of creation)
cleanup_nsi_resources() {
    CLEANUP_ERRORS=0

    print_step "1. Removing firewall policy association..."
    delete_or_skip "firewall policy association newfgt-nsi-policy-assoc" \
        gcloud compute network-firewall-policies associations delete \
            --name newfgt-nsi-policy-assoc \
            --global-firewall-policy \
            --firewall-policy newfgt-nsi \
            --project "$PROJECT_ID" \
            --quiet

    print_step "2. Deleting firewall policy rules..."
    delete_or_skip "firewall policy rule 11" \
        gcloud compute network-firewall-policies rules delete 11 \
            --firewall-policy newfgt-nsi \
            --global-firewall-policy \
            --project "$PROJECT_ID" \
            --quiet

    delete_or_skip "firewall policy rule 10" \
        gcloud compute network-firewall-policies rules delete 10 \
            --firewall-policy newfgt-nsi \
            --global-firewall-policy \
            --project "$PROJECT_ID" \
            --quiet

    print_step "3. Deleting firewall policy..."
    delete_or_skip "firewall policy newfgt-nsi" \
        gcloud compute network-firewall-policies delete newfgt-nsi \
            --project "$PROJECT_ID" \
            --global \
            --quiet

    print_step "4. Deleting security profile group..."
    delete_or_skip "security profile group newfgt-nsi-ftnt-spg1" \
        gcloud beta network-security security-profile-groups delete newfgt-nsi-ftnt-spg1 \
            --billing-project "$PROJECT_ID" \
            --organization "$ORGANIZATION_ID" \
            --location global \
            --quiet

    print_step "5. Deleting security profile..."
    delete_or_skip "security profile newfgt-nsi-ftnt-sp1" \
        gcloud beta network-security security-profiles custom-intercept delete newfgt-nsi-ftnt-sp1 \
            --billing-project "$PROJECT_ID" \
            --organization "$ORGANIZATION_ID" \
            --location global \
            --quiet

    print_step "6. Deleting intercept endpoint group association..."
    delete_or_skip "intercept endpoint group association new-fgt-nsi-ftnt-epg-assoc" \
        gcloud beta network-security intercept-endpoint-group-associations delete new-fgt-nsi-ftnt-epg-assoc \
            --project "$PROJECT_ID" \
            --location global \
            --quiet

    print_step "7. Deleting intercept endpoint group..."
    # Wait for the async association deletion to fully propagate before removing the group
    print_status "Waiting 20s for endpoint group association deletion to propagate..."
    sleep 20
    delete_or_skip "intercept endpoint group newfgt-nsi-ftnt-epg" \
        gcloud beta network-security intercept-endpoint-groups delete newfgt-nsi-ftnt-epg \
            --project "$PROJECT_ID" \
            --location global \
            --quiet

    print_step "8. Deleting intercept deployments..."
    delete_or_skip "intercept deployment fgt-nsi-us-central1a" \
        gcloud beta network-security intercept-deployments delete fgt-nsi-us-central1a \
            --location=us-central1-a \
            --project="$PROJECT_ID" \
            --quiet

    delete_or_skip "intercept deployment fgt-nsi-us-central1b" \
        gcloud beta network-security intercept-deployments delete fgt-nsi-us-central1b \
            --location=us-central1-b \
            --project="$PROJECT_ID" \
            --quiet

    delete_or_skip "intercept deployment fgt-nsi-us-central1c1" \
        gcloud beta network-security intercept-deployments delete fgt-nsi-us-central1c1 \
            --location=us-central1-c \
            --project="$PROJECT_ID" \
            --quiet

    if [[ $CLEANUP_ERRORS -gt 0 ]]; then
        print_error "$CLEANUP_ERRORS resource(s) failed to delete. Resolve the errors above before continuing."
        exit 1
    fi

    print_step "9. Deleting intercept deployment group..."
    # Wait for async deployment deletions to settle before removing the group
    print_status "Waiting 15s for deployment deletions to propagate..."
    sleep 15
    delete_or_skip "intercept deployment group newfgt-nsi-ftnt-dg" \
        gcloud beta network-security intercept-deployment-groups delete newfgt-nsi-ftnt-dg \
            --location global \
            --project "$PROJECT_ID" \
            --quiet

    if [[ $CLEANUP_ERRORS -gt 0 ]]; then
        print_error "Intercept deployment group deletion failed. Resolve errors above before running terraform destroy."
        exit 1
    fi
}

# Main execution
main() {
    print_status "Starting NSI cleanup script..."

    check_variables
    cleanup_nsi_resources

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