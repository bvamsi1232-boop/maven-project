# Jenkins Setup with IAM Role for AWS Access

## Overview
This guide shows how to configure Jenkins to use an EC2 IAM role for AWS authentication instead of hardcoded credentials.

## Prerequisites
- Jenkins running on an EC2 instance
- EC2 instance has an IAM role attached (currently: `EC2_Role`)
- Pipeline: AWS Steps plugin installed in Jenkins

## Current Setup

Your Jenkins EC2 instance details:
```
Account ID: 086266612868
Instance ID: i-08c4ecbcabf2fc99f
IAM Role: EC2_Role
Region: ap-south-1
```

Your Jenkinsfile is configured with:
```groovy
withAWS(region: '${AWS_REGION}') {
  // AWS operations automatically use EC2 IAM role
}
```

## Verification Steps

### 1. Verify IAM Role is Attached to Jenkins EC2 Instance

In AWS Console:
1. Go to **EC2 Dashboard** → **Instances**
2. Find your Jenkins instance (ID: `i-08c4ecbcabf2fc99f`)
3. Click on the instance
4. In the **Details** tab, look for **IAM Role**: Should show `EC2_Role`

### 2. Verify EC2_Role Has Required Permissions

The `EC2_Role` should have these permissions:
- `eks:DescribeCluster` - to get cluster details
- `eks:DescribeUpdate` - for updates
- `sts:GetCallerIdentity` - to verify credentials
- `ecr:GetAuthorizationToken` - for ECR login
- `ecr:GetDownloadUrlForLayer` - for ECR operations
- `s3:GetObject` - to download WAR from S3
- `s3:PutObject` - to upload artifacts to S3

Check the IAM role in AWS:
1. Go to **IAM** → **Roles** → **EC2_Role**
2. Check **Permissions** tab
3. Verify it has `AdministratorAccess` or at least the permissions above
4. If not, add them (you can attach a policy with the required permissions)

### 3. Verify AWS CLI Works on Jenkins EC2

SSH into Jenkins EC2 instance and run:
```bash
# Check AWS credentials from instance role
aws sts get-caller-identity

# Output should show:
# {
#     "UserId": "AROARIFPEBSCKI64KEEYH:i-08c4ecbcabf2fc99f",
#     "Account": "086266612868",
#     "Arn": "arn:aws:sts::086266612868:assumed-role/EC2_Role/i-08c4ecbcabf2fc99f"
# }
```

### 4. Verify Jenkins Has Pipeline AWS Steps Plugin

In Jenkins:
1. Go to **Manage Jenkins** → **Manage Plugins**
2. Search for **"pipeline-aws"**
3. Should show **Pipeline: AWS Steps** as installed
4. If not installed, install it and restart Jenkins

## How IAM Role Authentication Works

```
Jenkins Pipeline (Jenkinsfile)
         ↓
    withAWS() block
         ↓
  Pipeline AWS Steps Plugin
         ↓
  EC2 Instance Metadata Service (169.254.169.254)
         ↓
  IAM Role → Temporary Credentials
         ↓
  AWS API Calls (EKS, ECR, S3)
```

The plugin automatically:
1. Queries the EC2 instance metadata service
2. Gets temporary credentials from the IAM role
3. Credentials are auto-rotated (expires in ~1 hour)
4. No hardcoded keys or secrets needed

## Jenkins Pipeline Stages Using IAM Role

### Stage 1: Upload WAR to S3
```groovy
stage('Upload WAR to S3') {
  steps {
    withAWS(region: '${AWS_REGION}') {
      sh 'aws s3 cp ${WAR_PATH} s3://${S3_BUCKET}/${WAR_S3_KEY}'
    }
  }
}
```
Uses S3 permissions from IAM role

### Stage 2: Docker Build & ECR Push
```groovy
stage('Remote Docker Build, Run & Push') {
  agent { label 'docker' }
  steps {
    withAWS(region: '${AWS_REGION}') {
      sh 'aws ecr get-login-password ... | docker login ...'
      sh 'docker push ${IMAGE_TAG}'
    }
  }
}
```
Uses ECR permissions from IAM role

### Stage 3: Deploy to EKS
```groovy
stage('Deploy to EKS') {
  agent { label 'docker' }
  steps {
    withAWS(region: '${AWS_REGION}') {
      sh 'aws eks describe-cluster ...'
      sh 'aws eks get-token ...'
      sh 'kubectl apply -f ${K8S_MANIFEST_DIR}'
    }
  }
}
```
Uses EKS permissions from IAM role

## Troubleshooting

### Error: "the server has asked for the client to provide credentials"
**Cause**: IAM role doesn't have EKS permissions
**Solution**: Add `eks:*` permissions to `EC2_Role`

### Error: "Unable to authenticate with ECR"
**Cause**: IAM role doesn't have ECR permissions
**Solution**: Add `ecr:*` permissions to `EC2_Role`

### Error: "AccessDenied to S3"
**Cause**: IAM role doesn't have S3 permissions
**Solution**: Add `s3:*` permissions to `EC2_Role`

### Credentials Not Picked Up
**Check**:
1. Jenkins is running on EC2 (not local machine)
2. EC2 instance has IAM role attached
3. IAM role has required permissions
4. Restart Jenkins: `sudo systemctl restart jenkins`

## Testing from Jenkins Docker Agent

The Docker agent (label: 'docker') also needs access to AWS. It should:
1. Run on Jenkins EC2 instance
2. Have access to the instance's IAM role through metadata service
3. Have AWS CLI installed (`curl https://...aws.../awscli... | bash`)

## Next Steps

1. **Verify IAM role permissions** (see Verification Steps above)
2. **Ensure Pipeline AWS Steps plugin is installed** in Jenkins
3. **Run a test build** in Jenkins
4. **Monitor logs** for any credential errors

## Security Benefits

✅ No access keys stored in Jenkins  
✅ No secrets in Jenkinsfile or logs  
✅ Temporary credentials auto-rotated  
✅ Credentials scoped to EC2 instance only  
✅ Full audit trail in CloudTrail  
✅ Follows AWS IAM best practices  

---

For more info: https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/iam-roles-for-amazon-ec2.html
