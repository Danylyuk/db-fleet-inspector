#!/bin/bash
set -e
CODE=$(base64 -i app/inspector.py | tr -d '\n')
aws ssm send-command \
  --region eu-central-1 \
  --instance-ids i-01964ac3e7b6810e9 \
  --document-name AWS-RunShellScript \
  --parameters "commands=['echo $CODE | base64 -d > /opt/inspector.py','systemctl restart inspector']" \
  --query Command.CommandId --output text
EOF
chmod +x deploy.sh