**Deployment Instructions**

Upload config.sh and the 3 mongo scripts into an S3 bucket in your AWS account.  This will be your "deployment bucket" that you provide as a parameter in the main.yaml CloudFormation template.  Then run the main.yaml CloudFormation template and provide all the parameters.

When that completes:

1. Get the public IP address for the Mongo EC2 in the output of the CloudFormation stack. Login to the Mongo EC2 using:
```
ssh -i <key_pair.pem> bitnami@<ip_addr>
```

2. Look in /home/bitnami/bitnami_credentials for the Mongo root password.  Run `mongo_config.sh` which will prompt you for that root password.  The script then creates a more restricted Mongo user using the credentials provided earlier as CloudFormation parameters.  These credentials are used with the Tasky Web app and for backups.  Under normal circumstances (non-test), you would want to change that root password, store it in a password safe, then delete /home/bitnami/bitnami_credentials!

3. Get an AWS access key you can use with the AWS CLI on the Mongo host that will allow you to use kubectl with your EKS cluster.  For simplicity's sake, it should be with the account used to run the CloudFormation template.  That account has cluster admin rights in the EKS cluster already.  Set the access key on the Mongo host either with `aws configure` or with environment variables.  I prefer environment variables because they go away when you log out.

4. Add your EKS cluster to your kubeconfig with the following (substituting the region and cluster name appropriately -- and do the same for all subsequent commands below):
```
aws eks update-kubeconfig --region us-east-1 --name my-eks-cluster
```

5. Use `kubectl get nodes` to be sure it authenticates and returns results.
<br>
<br>
The following installs the AWS Load Balancer Controller into your EKS cluster, which is used to provision a public NLB for the Tasky Web app.  All of this can be done on the Mongo host using the access key configured above.

1. Create an OIDC Provider for your cluster with:
```
eksctl utils associate-iam-oidc-provider --region us-east-1 --cluster my-eks-cluster --approve
```

2. Run the following to create a policy used in the next step:
```
curl -o iam-policy.json https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.7.2/docs/install/iam_policy.json

aws iam create-policy \
--policy-name AWSLoadBalancerControllerIAMPolicy \
--policy-document file://iam-policy.json
```

3. Run this using the ARN of the policy created in step 2:
```
eksctl create iamserviceaccount \
--region=us-east-1 \
--cluster=my-eks-cluster \
--namespace=kube-system \
--name=aws-load-balancer-controller \
--attach-policy-arn=arn:aws:iam:<AWS Account>:policy/AWSLoadBalancerControllerIAMPolicy \
--override-existing-serviceaccounts \
--approve
```
This triggers a CloudFormation stack.  Check the status in the AWS Console.  When it completes, you can Ctrl-C at the command line.  The above command will hang for a long time even after the CloudFormation stack completes.  You don't need to wait on that.

4. Add eks-charts to your local Helm which provides the AWS Load Balancer Controller.
```
helm repo add eks https://aws.github.io/eks-charts
```

5. Install the AWS Load Balancer Controller using:
```
helm install aws-load-balancer-controller eks/aws-load-balancer-controller -n kube-system --set clusterName=my-eks-cluster --set serviceAccount.create=true --set serviceAccount.name=aws-load-balancer-controller --set enableServiceMutatorWebhook=false
```

Use `kubectl get pods -n kube-system` to wait for the AWS Load Balancer Controller pods to become ready, which can take a few seconds.

6. You will find tasky.yaml in /home/bitnami on the Mongo host.  You can deploy it now with:
```
kubectl create -f tasky.yaml
```

7. Go in the AWS Console, into EC2, Load Balancers.  You should see a load balancer in the process of provisioning (after you deploy tasky above).  This can take several minutes.  Wait for it to become ready/active.  Copy the pubic DNS name of the load balancer into your browser using port 50080 and you should see the Tasky app.
