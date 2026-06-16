aws sts get-caller-identity
{
  "Account": "123456789012"
}

# AWS Console → IAM → Identity providers → Add provider
#Select:
Provider type: OpenID Connect
#Use these exact values:
Provider URL:https://token.actions.githubusercontent.com

Audience:sts.amazonaws.com
#Then click:
Add provider

#Go to:
IAM → Roles → Create role
#Choose:
Trusted entity type: Web identity
#Then select:
Identity provider:token.actions.githubusercontent.com

Audience:sts.amazonaws.com

GitHub organization:YOUR_GITHUB_USERNAME

GitHub repository:releaseguard

GitHub branch:
main
#Click Next. step 3
#For beginner setup, attach these policies:
AmazonEC2ContainerRegistryPowerUser
AmazonECS_FullAccess
#next
Then role name:releaseguard-github-actions-role


#Step 5: Edit Trust Policy

#After role creation, open:

#IAM → Roles → releaseguard-github-actions-role → Trust relationships → Edit trust policy

Paste this policy.

Replace:

ACCOUNT_ID
YOUR_GITHUB_USERNAME

#with your real values.

{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/releaseguard:ref:refs/heads/main"
        }
      }
    }
  ]
}

#update 

#Step 6: Copy Role ARN

#After saving the role, copy the role ARN.

#It will look like:

arn:aws:iam::123456789012:role/releaseguard-github-actions-role


#Step 7: Add it to GitHub Secrets

#Go to your GitHub repository:

#releaseguard → Settings → Secrets and variables → Actions → Secrets → New repository secret

#Add:

Name:AWS_ROLE_ARN

Value:arn:aws:iam::123456789012:role/releaseguard-github-actions-role

#Step 8: Add GitHub Variables
#Go to:
Settings → Secrets and variables → Actions → Variables
#Add:
AWS_REGION = us-east-1
ECR_REPOSITORY = releaseguard
ECS_CLUSTER = releaseguard
ECS_SERVICE = releaseguard-service
API_URL = your backend URL later

#Step 9: Test OIDC first

For self-managed Kubernetes, that access is usually one of these:

#Option 1: SSH into master/control-plane server
#Option 2: Use kubeconfig as a GitHub secret
#Option 3: Use AWS SSM to run commands on the EC2 instance