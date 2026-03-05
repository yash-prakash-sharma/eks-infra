resource "aws_ecr_repository" "repos" {
  for_each = toset(var.repository_names)

  name                 = each.value
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.tags, {
    Name = each.value
  })
}

resource "aws_ecr_lifecycle_policy" "repos" {
  for_each = var.lifecycle_policy != null ? toset(var.repository_names) : toset([])

  repository = aws_ecr_repository.repos[each.value].name
  policy     = var.lifecycle_policy
}
