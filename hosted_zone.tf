data "aws_route53_zone" "parent" {
  name         = var.parent_hosted_zone
  private_zone = false
}

resource "aws_route53_zone" "public" {
  count = var.create_public_hosted_zone ? 1 : 0

  name = "${var.prefix}.${var.parent_hosted_zone}"

  tags = {
    Name = "${var.prefix}.${var.parent_hosted_zone}"
  }
}

resource "aws_route53_record" "public_ns" {
  count = var.create_public_hosted_zone ? 1 : 0

  zone_id = data.aws_route53_zone.parent.zone_id

  name = aws_route53_zone.public[0].name

  type = "NS"

  ttl = 300

  records = aws_route53_zone.public[0].name_servers
}

resource "aws_route53_zone" "private" {
  count = var.create_private_hosted_zone ? 1 : 0

  name = "${var.prefix}.${var.parent_hosted_zone}"

  vpc {
    vpc_id = aws_vpc.csk.id
  }

  tags = {
    Name = "${var.prefix}.${var.parent_hosted_zone}"
  }
}