apiVersion: v1
kind: ConfigMap
data:
  mapRoles: |
${chomp(aws_auth_configmap_yaml)}
%{ for role in system_masters_roles ~}
    - rolearn: arn:aws:iam::${aws_account_id}:role/${role}
      username: ${role}
      groups:
        - system:masters
%{ endfor ~}
