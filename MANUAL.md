# DB Fleet Inspector build manual

## Part 1: Tools and AWS access
**1\. Install Terraform and the AWS CLI.**

- brew install hashicorp/tap/terraform awscli

**Why:** Terraform creates infrastructure from code, and the AWS CLI provides terminal access to AWS. It also stores the credentials Terraform will use.

**2. Verify the installation.**

- terraform version && aws --version

**Why:** This confirms that both tools are installed and available in the terminal.

**3\. Create a monthly cost budget:** Budgets \> Create budget \> Use a template \> Monthly cost budget, \$10, your email.

**Why:** AWS resources cost money while they run. The budget sends alerts, but it does not stop resources automatically.

**4\. Create the IAM user terraform-admin:** IAM \> Users \> Create user, no console access, Attach policies directly \> AdministratorAccess.

**Why:** The root user is not for daily work. Broad permissions speed up this learning project, but they should be restricted in production. Later, we will use OIDC for GitHub Actions to avoid storing long-lived keys.

**5\. Create an access key:** terraform-admin \> Security credentials \> Create access key \> Command Line Interface (CLI). Then run aws configure and enter the keys, region eu-central-1, format json.

**Why:** The keys are stored locally in \~/.aws, so the terminal does not ask for them each time. This is a long-lived secret: never share it in chat or commit it to Git.

**6\. Check the identity:** aws sts get-caller-identity

**Why:** This confirms the terminal uses terraform-admin. The Arn field must show that user name.

## Part 2: Project and GitHub

**7\. Create the project folder:** mkdir \-p \~/Desktop/db-fleet-inspector && cd \~/Desktop/db-fleet-inspector

**Why:** All project code stays in one place, separate from everything else.

**8\. Initialize Git:** git init \-b main

**Why:** Git records every change, so we can review the history and undo mistakes.

**9\. Create .gitignore:** exclude .terraform/, \*.tfstate, \*.tfstate.\*, \*.tfvars, .env and .DS\_Store.

**Why:** Terraform state can contain passwords in plain text, so it must never be committed to Git.

**10\. Create the first commit:** git add .gitignore && git commit \-m Init

**Why:** We save a safe starting point before adding any code.

**11\. Install the GitHub CLI:** brew install gh

**Why:** The GitHub CLI manages repositories and sign-in from the terminal.

**12\. Sign in to GitHub:** gh auth login (GitHub.com, HTTPS, browser)

**Why:** This lets Git push code to your account.

**13\. Create the private repository and push:** gh repo create db-fleet-inspector with the private, source and push options (exact command in chat)

**Why:** The code gets a remote copy, and the private setting keeps it closed until we review it.

## Part 3: Network (VPC)

**14\. Create provider.tf:** Terraform settings, AWS provider, region eu-central-1

**Why:** Terraform needs the provider plugin to call the AWS API, and the region sets where resources are created.

**15\. Create network.tf:** VPC, internet gateway, 2 public and 2 private subnets in 2 AZs, public route table

**Why:** EC2 will sit in a public subnet. Aurora will sit in private subnets with no internet route, across 2 AZs as RDS requires.

**16\. Initialize Terraform:** terraform init

**Why:** This downloads the AWS provider and prepares the working directory.

**17\. Preview the changes:** terraform plan

**Why:** Plan shows what Terraform would create without changing anything in AWS.

**Exact commands and code**

**Step 9: .gitignore**

```bash
printf '.terraform/\n*.tfstate\n*.tfstate.*\n*.tfvars\n.env\n.DS_Store\n' > .gitignore
```

**Step 13: create repository**

```bash
gh repo create db-fleet-inspector --private --source=. --push
```

**Step 14: provider.tf**

Full code: [provider.tf](provider.tf)

**Step 15: network.tf**

Full code: [network.tf](network.tf)

**18\. Create the network**

```bash
terraform apply
```

**Why:** Terraform shows the plan again and creates the resources only after you type yes. VPCs, subnets and route tables have no hourly charge.

**19\. Save the code**

```bash
git add . && git commit -m "Add network" && git push
```

**Why:** The code is committed and pushed to GitHub. The .gitignore file keeps the state file out of Git.

## Part 4: Aurora database

**20\. Create database.tf**

Full code: [database.tf](database.tf)

**Why:** Defines a private, encrypted Aurora PostgreSQL cluster with 7-day backups, a writer and a reader in two AZs. Only the app security group can reach port 5432\. AWS stores the master password in Secrets Manager.

**21\. Preview the database**

```bash
terraform plan
```

**Why:** Expect 6 to add. Check nothing existing is replaced.

**22\. Create the database**

```bash
terraform apply
```

**Why:** Creates the cluster after you type yes. This takes about 10 to 15 minutes and costs money while running.

**23\. Save the code**

```bash
git add database.tf git commit -m "Add Aurora cluster" git push
```

**Why:**  Saves the database code to GitHub.

**Issue during steps 22-23: AWS Free plan limits**

**Error 1:** backup retention of 7 days exceeded the Free plan limit (FreeTierRestrictionError).

**Error 2:** on the Free plan, Aurora requires express configuration, which runs outside your VPC. That breaks the private-subnet design.

**Fix:** upgraded the account to the Paid plan (the \$140 credits stayed), kept retention at 7 days, and ran terraform apply again. Terraform added only the 3 missing resources: the cluster and 2 instances. The cluster took 32 seconds; an instance took about 11 minutes.

**Why:** A successful plan doesn't guarantee a successful apply. Plan compares code with state, but account limits can fail at the API call.

**Key terms:** A cluster is the whole database: shared storage plus instances. An instance is the server that handles queries. The writer handles writes, the reader handles reads, and if the writer fails, a reader takes over.

## Part 5: Website on EC2

**24\. Create app.tf**

Full code: [app.tf](app.tf)

**Why:** Defines the EC2 server in a public subnet, its firewall rules, and an IAM role that lets it read only the database secret. Admin access goes through Session Manager, so SSH stays closed.

**25\. Preview the plan**

```bash
terraform plan
```

**Why:** Expect 8 to add, 0 to change, 0 to destroy.

**26\. Create the server**

```bash
terraform apply
```

**Why:** Creates the EC2 server and its permissions after you type yes. The output shows its public IP. Expect Resources: 8 added.

**27\. Save the code**

```bash
git add app.tf git commit -m "Add EC2 app server" git push
```

**Why:** Saves only the server code to GitHub.

**28\. Get the database address (on the Mac)**

```bash
aws rds describe-db-clusters --db-cluster-identifier fleet-aurora --query 'DBClusters[0].Endpoint' --output text
```

**Why:** The endpoint is the stable address of the writer. Copy it for step 32\.

**29\. Install the Session Manager plugin (on the Mac)**

```bash
brew install --cask session-manager-plugin
```

**Why:** Lets the AWS CLI open a shell on the server.

**30\. Open a shell on the server**

```bash
aws ssm start-session --target i-01964ac3e7b6810e9
```

**Why:** Connects through AWS using IAM, so port 22 stays closed. The prompt changes to sh-5.2\$.

**31\. Test the secret (on the server)**

```bash
aws secretsmanager get-secret-value --region eu-central-1 --secret-id 'rds!cluster-e6990eb8-520f-4126-ad9b-261968d0d744' --query Name --output text
```

**Why:** Proves the IAM role can read the secret. Printing only the Name keeps the password off the screen.

**32\. Test the database connection (on the server)**

```bash
timeout 10 bash -c '</dev/tcp/PASTE_ENDPOINT/5432' && echo DB_REACHABLE
```

**Why:** Replace PASTE\_ENDPOINT with the address from step 28\. DB\_REACHABLE proves the network path and security groups work.

**33\. Leave the server**

```bash
exit
```

**Why:** Returns to the Mac.

## Part 6: Inspector app

**34\. Allow the server to read database settings (on the Mac)**

Full code: [app.tf](app.tf)

**Why:** The inspector checks settings through the AWS API. This role can only read them, not change anything. Describe actions need Resource \* here, which is an acceptable trade-off for read-only access.

**35\. Apply the change**

```bash
terraform apply
```

**Why:** Expect 1 to add, 0 to change, 0 to destroy. Type yes.

**36\. Save the code**

```bash
git add app.tf git commit -m "Allow reading RDS settings" git push
```

**Why:** Saves the permission change to GitHub.

**37\. Create the inspector (on the Mac)**

Full code: [app/inspector.py](app/inspector.py)

**Why:** A small Python web server. On each page load it reads settings from the AWS API and prints PASS or FAIL for each check.

**38\. Create the deploy script (on the Mac)**

Full code: [deploy.sh](deploy.sh)

**Why:** Sends the code to the server through AWS Systems Manager, with no SSH. GitHub Actions will reuse this script later.

**39\. Save the code**

```bash
git add app deploy.sh git commit -m "Add inspector app" git push
```

**Why:** Saves the app and the deploy script to GitHub.

**40\. Open a shell on the server**

```bash
aws ssm start-session --target i-01964ac3e7b6810e9
```

**Why:** Everything until step 43 runs on the server.

**41\. Install the AWS library (on the server)**

```bash
sudo dnf install -y python3-pip && sudo pip3 install boto3
```

**Why:** boto3 is the Python library that talks to the AWS API.

**42\. Register the app as a service (on the server)**

```bash
sudo tee /etc/systemd/system/inspector.service > /dev/null <<'EOF'
[Unit]
Description=DB Fleet Inspector
After=network-online.target
[Service]
ExecStart=/usr/bin/python3 /opt/inspector.py
Restart=always
[Install]
WantedBy=multi-user.target
EOF
sudo systemctl daemon-reload
sudo systemctl enable inspector
```

**Why:** systemd keeps the app running and restarts it after a crash or reboot.

**43\. Leave the server**

```bash
exit
```

**Why:** Returns to the Mac.

**44\. Deploy the app (on the Mac)**

```bash
./deploy.sh
```

**Why:** Sends the code through Systems Manager and starts the service. It prints a command ID.

**45\. Open the site:** http\://18.192.26.28

**Why:** Shows the live inspector. Expect PASS on four checks and FAIL on deletion protection.

## Part 7: Failover test

**46\. See which instance is the writer (on the Mac)**

```bash
aws rds describe-db-clusters --db-cluster-identifier fleet-aurora --query 'DBClusters[0].DBClusterMembers[].[DBInstanceIdentifier,IsClusterWriter]' --output text
```

**Why:** True marks the writer. Note which instance it is.

**47\. Trigger a failover**

```bash
aws rds failover-db-cluster --db-cluster-identifier fleet-aurora
```

**Why:** Asks Aurora to promote the reader, which simulates losing the writer.

**48\. Check again after 60 seconds**

```bash
aws rds describe-db-clusters --db-cluster-identifier fleet-aurora --query 'DBClusters[0].DBClusterMembers[].[DBInstanceIdentifier,IsClusterWriter]' --output text
```

**Why:** True should now be on the other instance. Same data, same endpoint, new writer.

## Part 8: Backup and restore

**49\. Restore to a new cluster (on the Mac)**

```bash
aws rds restore-db-cluster-to-point-in-time \
  --source-db-cluster-identifier fleet-aurora \
  --db-cluster-identifier fleet-restore \
  --use-latest-restorable-time \
  --db-subnet-group-name fleet-db-subnets \
  --vpc-security-group-ids sg-0fb9f549d68e1e0a7 \
  --serverless-v2-scaling-configuration MinCapacity=0,MaxCapacity=1,SecondsUntilAutoPause=300 \
  --query DBCluster.Status --output text
```

**Why:** Point-in-time recovery always creates a new cluster, so the original stays untouched. This one has storage only, no instances.

**50\. Check the status**

```bash
aws rds describe-db-clusters --db-cluster-identifier fleet-restore --query 'DBClusters[0].[Status,EarliestRestorableTime,StorageEncrypted]' --output text
```

**Why:** Repeat every few minutes until it says available. Restore time grows with data size.

**51\. Delete the restored cluster**

```bash
aws rds delete-db-cluster --db-cluster-identifier fleet-restore --skip-final-snapshot --query DBCluster.Status --output text
```

**Why:** It was created outside Terraform, so Terraform would not remove it. Expect deleting.

## Part 9: Monitoring with CloudWatch

**52\.** In VS Code, create monitoring.tf in the project root, paste this code and save.

Full code: [monitoring.tf](monitoring.tf)

**Why:** It defines an alarm that fires when average database CPU stays above 80% for two 5-minute periods.

**53\.** Preview the change. Expect: Plan: 1 to add, 0 to change, 0 to destroy.

```bash
terraform plan
```

**Why:** It shows what Terraform will do before anything changes.

**54\.** Apply the change and type yes when asked.

```bash
terraform apply
```

**Why:** It creates the alarm in AWS.

**55\.** Check the alarm. Expect fleet-aurora-high-cpu with state OK or INSUFFICIENT\_DATA.

```bash
aws cloudwatch describe-alarms --alarm-names fleet-aurora-high-cpu --query 'MetricAlarms[0].[AlarmName,StateValue]' --output text
```

**Why:** It confirms the alarm exists and shows its current state.

## Part 10: Deploy with GitHub Actions and OIDC

**56\.** In VS Code, create github.tf in the project root, paste this code and save.

Full code: [github.tf](github.tf)

**Why:** It lets only the main branch of this repository get temporary AWS credentials, limited to deploying on this server.

**57\.** Apply the change. Check that the plan says 3 to add, 0 to change, 0 to destroy, then type yes.

```bash
terraform apply
```

**Why:** It creates the trust link and the role in AWS.

**58\.** In VS Code, create the file .github/workflows/deploy.yml, paste this code and save.

Full code: [.github/workflows/deploy.yml](.github/workflows/deploy.yml)

**Why:** It tells GitHub to run the deploy after each push to main that changes the app.

**59\.** Commit and push. Run the three commands one at a time.

```bash
git add -A git commit -m "Add monitoring and GitHub deploy" git push
```

**Why:** The push saves the work in GitHub and starts the first deploy.

**60\.** Open the Actions page and wait for a green check on Deploy inspector.

```bash
open https://github.com/Danylyuk/db-fleet-inspector/actions
```

**Why:** The green check proves that GitHub reached AWS without stored keys and that the command finished on the server.

**61\.** In github.tf, replace the whole :sub line with this line and save. This corrects step 56\.

```bash
"token.actions.githubusercontent.com:sub" = "repo:Danylyuk@7465458/db-fleet-inspector@1441122977:ref:refs/heads/main"
```

**Why:** GitHub sends an immutable subject with the numeric owner and repository IDs, so the trust policy must match it exactly.

**62\.** Apply the change. Check that the plan says 0 to add, 1 to change, 0 to destroy, then type yes.

```bash
terraform apply
```

**Why:** It updates the trust policy in AWS.

**63\.** Rerun the failed deploy.

```bash
gh run rerun 41338011103 -R Danylyuk/db-fleet-inspector
```

**Why:** It repeats the same deploy with the corrected trust policy.

## Part 11: README

**64\.** In VS Code, create README.md in the project root, paste this text and save.

Full code: [README.md](README.md)

**Why:** It explains the project, its design and its limits to anyone who opens the repository.

**65\.** Commit and push. Run the three commands one at a time.

```bash
git add README.md git commit -m "Add README" git push
```

**Why:** It publishes the README in GitHub. This file does not trigger a deploy.

