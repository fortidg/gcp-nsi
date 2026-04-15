#!/bin/bash

# Complete NSI Setup Script
# Run this script after terraform apply to complete the NSI configuration

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
        exit 1
    fi
    
    if [ -z "$ORGANIZATION_ID" ]; then
        print_error "ORGANIZATION_ID environment variable is required"
        exit 1
    fi
    
    print_status "Using PROJECT_ID: $PROJECT_ID"
    print_status "Using ORGANIZATION_ID: $ORGANIZATION_ID"
}

# Get Terraform outputs
get_terraform_outputs() {
    print_status "Getting Terraform outputs..."

    INSPECTION_NETWORK=$(terraform output -json vpc_networks | jq -r '.inspection_vpc.name')
    WEB_NETWORK=$(terraform output -json vpc_networks | jq -r '.web_vpc.name')
    WEB2_NETWORK=$(terraform output -json vpc_networks | jq -r '.web2_vpc.name')

    FORWARDING_RULE_A=$(terraform output -json forwarding_rules | jq -r '."us-central1-a".name')
    FORWARDING_RULE_B=$(terraform output -json forwarding_rules | jq -r '."us-central1-b".name')
    FORWARDING_RULE_C=$(terraform output -json forwarding_rules | jq -r '."us-central1-c".name')

    print_status "Inspection Network: $INSPECTION_NETWORK"
    print_status "Web Network: $WEB_NETWORK"
    print_status "Web2 Network: $WEB2_NETWORK"
    print_status "Forwarding Rules: $FORWARDING_RULE_A, $FORWARDING_RULE_B, $FORWARDING_RULE_C"
}

# Create NSI resources
create_nsi_resources() {
    print_step "1. Creating intercept deployment group..."
    gcloud beta network-security intercept-deployment-groups create newfgt-nsi-ftnt-dg \
        --location global \
        --project "$PROJECT_ID" \
        --network "$INSPECTION_NETWORK" \
        --no-async || {
        print_warning "Intercept deployment group may already exist, continuing..."
    }
    
    print_step "2. Creating intercept deployments for each zone..."
    
    gcloud beta network-security intercept-deployments create fgt-nsi-us-central1a \
        --location=us-central1-a \
        --project="$PROJECT_ID" \
        --forwarding-rule="$FORWARDING_RULE_A" \
        --intercept-deployment-group="projects/$PROJECT_ID/locations/global/interceptDeploymentGroups/newfgt-nsi-ftnt-dg" \
        --forwarding-rule-location=us-central1 \
        --no-async || {
        print_warning "Intercept deployment us-central1a may already exist, continuing..."
    }
    
    gcloud beta network-security intercept-deployments create fgt-nsi-us-central1b \
        --location=us-central1-b \
        --project="$PROJECT_ID" \
        --forwarding-rule="$FORWARDING_RULE_B" \
        --intercept-deployment-group="projects/$PROJECT_ID/locations/global/interceptDeploymentGroups/newfgt-nsi-ftnt-dg" \
        --forwarding-rule-location=us-central1 \
        --no-async || {
        print_warning "Intercept deployment us-central1b may already exist, continuing..."
    }
    
    gcloud beta network-security intercept-deployments create fgt-nsi-us-central1c1 \
        --location=us-central1-c \
        --project="$PROJECT_ID" \
        --forwarding-rule="$FORWARDING_RULE_C" \
        --intercept-deployment-group="projects/$PROJECT_ID/locations/global/interceptDeploymentGroups/newfgt-nsi-ftnt-dg" \
        --forwarding-rule-location=us-central1 \
        --no-async || {
        print_warning "Intercept deployment us-central1c may already exist, continuing..."
    }
    
    print_step "3. Creating intercept endpoint group..."
    gcloud beta network-security intercept-endpoint-groups create newfgt-nsi-ftnt-epg \
        --intercept-deployment-group newfgt-nsi-ftnt-dg \
        --project "$PROJECT_ID" \
        --location global \
        --no-async || {
        print_warning "Intercept endpoint group may already exist, continuing..."
    }
    
    print_step "4. Associating endpoint group with web VPCs..."

    # Associate with first Web VPC
    gcloud beta network-security intercept-endpoint-group-associations create new-fgt-nsi-ftnt-epg-assoc \
        --intercept-endpoint-group newfgt-nsi-ftnt-epg \
        --network "$WEB_NETWORK" \
        --project "$PROJECT_ID" \
        --location global \
        --no-async || {
        print_warning "Intercept endpoint group association for Web VPC may already exist, continuing..."
    }

    # Associate with second Web VPC
    gcloud beta network-security intercept-endpoint-group-associations create new-fgt-nsi-ftnt-epg-assoc-web2 \
        --intercept-endpoint-group newfgt-nsi-ftnt-epg \
        --network "$WEB2_NETWORK" \
        --project "$PROJECT_ID" \
        --location global \
        --no-async || {
        print_warning "Intercept endpoint group association for Web2 VPC may already exist, continuing..."
    }
    
    print_step "5. Creating security profile..."
    gcloud beta network-security security-profiles custom-intercept create newfgt-nsi-ftnt-sp1 \
        --intercept-endpoint-group newfgt-nsi-ftnt-epg \
        --billing-project "$PROJECT_ID" \
        --organization "$ORGANIZATION_ID" \
        --location global || {
        print_warning "Security profile may already exist, continuing..."
    }
    
    print_step "6. Creating security profile group..."
    gcloud beta network-security security-profile-groups create newfgt-nsi-ftnt-spg1 \
        --custom-intercept-profile newfgt-nsi-ftnt-sp1 \
        --billing-project "$PROJECT_ID" \
        --organization "$ORGANIZATION_ID" \
        --location global || {
        print_warning "Security profile group may already exist, continuing..."
    }
    
    print_step "7. Creating firewall policy..."
    gcloud compute network-firewall-policies create newfgt-nsi \
        --project "$PROJECT_ID" \
        --global || {
        print_warning "Firewall policy may already exist, continuing..."
    }
    
    print_step "8. Creating firewall policy rules..."
    gcloud beta compute network-firewall-policies rules create 10 \
        --action=APPLY_SECURITY_PROFILE_GROUP \
        --firewall-policy newfgt-nsi \
        --global-firewall-policy \
        --security-profile-group "organizations/$ORGANIZATION_ID/locations/global/securityProfileGroups/newfgt-nsi-ftnt-spg1" \
        --layer4-configs all \
        --src-ip-ranges 0.0.0.0/0 \
        --dest-ip-ranges 0.0.0.0/0 \
        --direction INGRESS || {
        print_warning "Firewall policy rule 10 may already exist, continuing..."
    }
    
    gcloud beta compute network-firewall-policies rules create 11 \
        --action=APPLY_SECURITY_PROFILE_GROUP \
        --firewall-policy newfgt-nsi \
        --global-firewall-policy \
        --security-profile-group "organizations/$ORGANIZATION_ID/locations/global/securityProfileGroups/newfgt-nsi-ftnt-spg1" \
        --layer4-configs all \
        --src-ip-ranges 0.0.0.0/0 \
        --dest-ip-ranges 0.0.0.0/0 \
        --direction EGRESS || {
        print_warning "Firewall policy rule 11 may already exist, continuing..."
    }
    
    print_step "9. Associating policy with web VPCs..."

    # Associate with first Web VPC
    gcloud compute network-firewall-policies associations create \
        --name newfgt-nsi-policy-assoc \
        --global-firewall-policy \
        --firewall-policy newfgt-nsi \
        --network "$WEB_NETWORK" \
        --project "$PROJECT_ID" || {
        print_warning "Firewall policy association for Web VPC may already exist, continuing..."
    }

    # Associate with second Web VPC
    gcloud compute network-firewall-policies associations create \
        --name newfgt-nsi-policy-assoc-web2 \
        --global-firewall-policy \
        --firewall-policy newfgt-nsi \
        --network "$WEB2_NETWORK" \
        --project "$PROJECT_ID" || {
        print_warning "Firewall policy association for Web2 VPC may already exist, continuing..."
    }
}

# Main execution
main() {
    print_status "Starting NSI setup script..."
    
    check_variables
    get_terraform_outputs
    create_nsi_resources
    
    print_status "NSI setup completed successfully!"
    print_status "Your FortiGate NSI deployment is now ready for traffic inspection."
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
    print_error "Please set PROJECT_ID and ORGANIZATION_ID environment variables"
    exit 1
fi