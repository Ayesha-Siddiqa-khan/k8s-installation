#Run this on your local machine or AWS CloudShell:
 
aws ecr create-repository --repository-name todo-app --region us-east-1

#Run login again
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 257536659737.dkr.ecr.us-east-1.amazonaws.com