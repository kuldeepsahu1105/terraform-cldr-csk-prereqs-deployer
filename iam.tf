locals {
  route53_zone_arns = concat(
    var.create_public_hosted_zone ? [
      aws_route53_zone.public[0].arn
    ] : [],

    var.create_private_hosted_zone ? [
      aws_route53_zone.private[0].arn
    ] : [],

    [
      "arn:aws:route53:::change/*"
    ]
  )
}

# ------- IAM User + Policies (optional) -------

resource "aws_iam_user" "restricted" {
  count = var.create_iam_user ? 1 : 0

  name = local.iam_user_name
  path = "/"

  tags = {
    Name  = local.iam_user_name
    Owner = var.owner
  }
}

resource "aws_iam_access_key" "aws_keys" {
  count = var.create_iam_user ? 1 : 0
  user  = aws_iam_user.restricted[0].name
}

# Automatically Create the CSV File Locally
resource "local_file" "credentials_csv" {
  count           = var.create_iam_user ? 1 : 0
  filename        = "${path.module}/${var.prefix}-iam-credentials.csv"
  file_permission = "0600" # Restricts file access to the owner only for security

  # Constructs the CSV header and injects the sensitive values into the row
  content = <<EOF
User Name,Access key ID,Secret access key
${aws_iam_user.restricted[0].name},${aws_iam_access_key.aws_keys[0].id},${aws_iam_access_key.aws_keys[0].secret}
EOF
}

data "aws_iam_policy_document" "ccf_restricted" {

  statement {
    sid    = "EC2VpcScoped"
    effect = "Allow"

    actions = [
      "ec2:AssignPrivateIpAddresses",
      "ec2:AuthorizeSecurityGroupEgress",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:DeleteNetworkInterface",
      "ec2:DeleteSecurityGroup",
      "ec2:ModifyNetworkInterfaceAttribute",
      "ec2:RevokeSecurityGroupEgress",
      "ec2:RevokeSecurityGroupIngress",
      "ec2:UnassignPrivateIpAddresses"
    ]

    resources = ["*"]

    condition {
      test     = "ArnLike"
      variable = "ec2:Vpc"
      values = [
        "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:vpc/${aws_vpc.csk.id}"
      ]
    }
  }

  statement {
    sid    = "EC2SecurityGroup"
    effect = "Allow"

    actions = [
      "ec2:CreateSecurityGroup"
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:security-group/*",
      "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:vpc/${aws_vpc.csk.id}"
    ]
  }

  statement {
    sid    = "EC2SubnetScoped"
    effect = "Allow"

    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:RequestSpotInstances",
      "ec2:RunInstances"
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:subnet/*"
    ]

    condition {
      test     = "ArnLike"
      variable = "ec2:Vpc"
      values = [
        "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:vpc/${aws_vpc.csk.id}"
      ]
    }
  }

  statement {
    sid    = "EC2ProvisionOther"
    effect = "Allow"

    actions = [
      "ec2:CreateNetworkInterface",
      "ec2:RequestSpotInstances",
      "ec2:RunInstances"
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:elastic-ip/*",
      "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:image/*",
      "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:instance/*",
      "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:key-pair/*",
      "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:network-interface/*",
      "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:security-group/*",
      "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:spot-instances-request/*",
      "arn:${data.aws_partition.current.partition}:ec2:${var.aws_region}:*:volume/*"
    ]
  }

  statement {
    sid    = "EC2InstanceTagScoped"
    effect = "Allow"

    actions = [
      "ec2:GetConsoleScreenshot",
      "ec2:ModifyInstanceAttribute",
      "ec2:RebootInstances",
      "ec2:StartInstances",
      "ec2:StopInstances",
      "ec2:TerminateInstances"
    ]

    resources = ["*"]

    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/owner"
      values   = ["taikun"]
    }
  }

  statement {
    sid    = "EC2MultiResourceInstanceTagScoped"
    effect = "Allow"

    actions = [
      "ec2:AttachNetworkInterface",
      "ec2:AttachVolume",
      "ec2:DetachNetworkInterface",
      "ec2:DetachVolume"
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:ec2:*:*:instance/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "ec2:ResourceTag/owner"
      values   = ["taikun"]
    }
  }

  statement {
    sid    = "EC2MultiResourceOther"
    effect = "Allow"

    actions = [
      "ec2:AttachNetworkInterface",
      "ec2:AttachVolume",
      "ec2:DetachNetworkInterface",
      "ec2:DetachVolume"
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:ec2:*:*:network-interface/*",
      "arn:${data.aws_partition.current.partition}:ec2:*:*:volume/*"
    ]
  }

  statement {
    sid    = "EC2NoVpcRestriction"
    effect = "Allow"

    actions = [
      "ec2:AllocateAddress",
      "ec2:AssociateAddress",
      "ec2:CancelSpotInstanceRequests",
      "ec2:CreateTags",
      "ec2:CreateVolume",
      "ec2:DeleteKeyPair",
      "ec2:DeleteTags",
      "ec2:DeleteVolume",
      "ec2:Describe*",
      "ec2:DisassociateAddress",
      "ec2:GetCoipPoolUsage",
      "ec2:ImportKeyPair",
      "ec2:ModifyVolume",
      "ec2:ReleaseAddress"
    ]

    resources = ["*"]
  }

  statement {
    sid = "ELB"

    effect = "Allow"

    actions = [
      "elasticloadbalancing:AddListenerCertificates",
      "elasticloadbalancing:AddTags",
      "elasticloadbalancing:CreateListener",
      "elasticloadbalancing:CreateLoadBalancer",
      "elasticloadbalancing:CreateRule",
      "elasticloadbalancing:CreateTargetGroup",
      "elasticloadbalancing:DeleteListener",
      "elasticloadbalancing:DeleteLoadBalancer",
      "elasticloadbalancing:DeleteRule",
      "elasticloadbalancing:DeleteTargetGroup",
      "elasticloadbalancing:DeregisterTargets",
      "elasticloadbalancing:Describe*",
      "elasticloadbalancing:ModifyListener",
      "elasticloadbalancing:ModifyLoadBalancerAttributes",
      "elasticloadbalancing:ModifyRule",
      "elasticloadbalancing:ModifyTargetGroup",
      "elasticloadbalancing:ModifyTargetGroupAttributes",
      "elasticloadbalancing:RegisterTargets",
      "elasticloadbalancing:RemoveListenerCertificates",
      "elasticloadbalancing:RemoveTags",
      "elasticloadbalancing:SetIpAddressType",
      "elasticloadbalancing:SetSecurityGroups",
      "elasticloadbalancing:SetSubnets",
      "elasticloadbalancing:SetWebAcl"
    ]

    resources = ["*"]
  }

  statement {
    sid = "OtherServices"

    effect = "Allow"

    actions = [
      "elasticfilesystem:DescribeFileSystems",
      "elasticfilesystem:DescribeMountTargets",
      "pricing:GetProducts",
      "servicequotas:Get*",
      "servicequotas:List*",
      "sts:GetCallerIdentity"
    ]

    resources = ["*"]
  }

  statement {
    sid = "IAMReadOnly"

    effect = "Allow"

    actions = [
      "iam:GetInstanceProfile",
      "iam:GetPolicy",
      "iam:GetPolicyVersion",
      "iam:GetRole",
      "iam:GetRolePolicy",
      "iam:ListAttachedGroupPolicies",
      "iam:ListAttachedRolePolicies",
      "iam:ListAttachedUserPolicies",
      "iam:ListEntitiesForPolicy",
      "iam:ListInstanceProfilesForRole",
      "iam:ListPolicyVersions",
      "iam:ListRolePolicies"
    ]

    resources = ["*"]
  }

  statement {
    sid = "IAMRoleWrite"

    effect = "Allow"

    actions = [
      "iam:CreateRole",
      "iam:DeleteRole",
      "iam:DeleteRolePolicy",
      "iam:PutRolePolicy",
      "iam:UpdateAssumeRolePolicy"
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:iam::*:role/cldr-csk-*",
      "arn:${data.aws_partition.current.partition}:iam::*:role/cldr/csk/*"
    ]
  }

  statement {
    sid = "IAMAttachDetachPolicy"

    effect = "Allow"

    actions = [
      "iam:AttachRolePolicy",
      "iam:DetachRolePolicy"
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:iam::*:role/cldr-csk-*",
      "arn:${data.aws_partition.current.partition}:iam::*:role/cldr/csk/*"
    ]

    condition {
      test     = "ArnLike"
      variable = "iam:PolicyARN"

      values = [
        "arn:${data.aws_partition.current.partition}:iam::*:policy/cldr-csk-*",
        "arn:${data.aws_partition.current.partition}:iam::*:policy/cldr/csk/*"
      ]
    }
  }

  statement {
    sid = "IAMInstanceProfileWrite"

    effect = "Allow"

    actions = [
      "iam:AddRoleToInstanceProfile",
      "iam:CreateInstanceProfile",
      "iam:DeleteInstanceProfile",
      "iam:RemoveRoleFromInstanceProfile"
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:iam::*:instance-profile/cldr-csk-*",
      "arn:${data.aws_partition.current.partition}:iam::*:instance-profile/cldr/csk/*"
    ]
  }

  statement {
    sid = "IAMPolicyWrite"

    effect = "Allow"

    actions = [
      "iam:CreatePolicy",
      "iam:CreatePolicyVersion",
      "iam:DeletePolicy"
    ]

    resources = [
      "arn:${data.aws_partition.current.partition}:iam::*:policy/cldr-csk-*",
      "arn:${data.aws_partition.current.partition}:iam::*:policy/cldr/csk/*"
    ]
  }

  statement {
    sid = "IAMPassRole"

    effect = "Allow"

    actions = ["iam:PassRole"]

    resources = [
      "arn:${data.aws_partition.current.partition}:iam::*:role/cldr-csk-*",
      "arn:${data.aws_partition.current.partition}:iam::*:role/cldr/csk/*"
    ]

    condition {
      test     = "StringEquals"
      variable = "iam:PassedToService"

      values = [
        "ec2.amazonaws.com",
        "elasticloadbalancing.amazonaws.com"
      ]
    }
  }

  statement {
    sid = "IAMServiceLinkedRole"

    effect = "Allow"

    actions = ["iam:CreateServiceLinkedRole"]

    resources = [
      "arn:${data.aws_partition.current.partition}:iam::*:role/aws-service-role/elasticloadbalancing.amazonaws.com/*",
      "arn:${data.aws_partition.current.partition}:iam::*:role/aws-service-role/spot.amazonaws.com/*"
    ]
  }
}

resource "aws_iam_policy" "ccf_restricted" {
  count = var.create_iam_policies ? 1 : 0

  name   = "ccf-restricted-${var.prefix}-policy"
  policy = data.aws_iam_policy_document.ccf_restricted.json
}

data "aws_iam_policy_document" "route53" {

  statement {

    effect = "Allow"

    actions = [
      "route53:GetHostedZone",
      "route53:ListResourceRecordSets",
      "route53:ChangeResourceRecordSets",
      "route53:GetChange"
    ]

    resources = local.route53_zone_arns
  }

  statement {

    effect = "Allow"

    actions = [
      "route53:ListHostedZones",
      "route53:ListHostedZonesByName"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_policy" "route53" {
  count = var.create_iam_policies ? 1 : 0

  name   = "ccf-route53-${var.prefix}-policy"
  policy = data.aws_iam_policy_document.route53.json
}

data "aws_iam_policy_document" "s3_backup" {

  statement {

    sid = "AllowBucketList"

    effect = "Allow"

    actions = [
      "s3:ListBucket"
    ]

    resources = [
      "${aws_s3_bucket.csk[0].arn}"
    ]
  }

  statement {

    sid = "AllowObjectReadWrite"

    effect = "Allow"

    actions = [
      "s3:PutObject",
      "s3:PutObjectTagging",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:DeleteObject"
    ]

    resources = [
      "${aws_s3_bucket.csk[0].arn}/*"
    ]
  }
}

resource "aws_iam_policy" "s3_backup" {
  count = var.create_iam_policies ? 1 : 0

  name   = "ccf-s3-backup-${var.prefix}-policy"
  policy = data.aws_iam_policy_document.s3_backup.json
}

resource "aws_iam_user_policy_attachment" "s3_backup" {
  count = var.create_iam_user && var.create_iam_policies ? 1 : 0

  user       = aws_iam_user.restricted[0].name
  policy_arn = aws_iam_policy.s3_backup[0].arn
}

resource "aws_iam_user_policy_attachment" "route53" {
  count = var.create_iam_user && var.create_iam_policies ? 1 : 0

  user       = aws_iam_user.restricted[0].name
  policy_arn = aws_iam_policy.route53[0].arn
}

resource "aws_iam_user_policy_attachment" "ccf" {
  count = var.create_iam_user && var.create_iam_policies ? 1 : 0

  user       = aws_iam_user.restricted[0].name
  policy_arn = aws_iam_policy.ccf_restricted[0].arn
}