
resource "aws_cloudwatch_event_rule" "simulated_guardduty_finding" {
  name        = "${var.project_name}-simulated-finding-rule"
  description = "Detects simulated GuardDuty-style EC2 security findings"

  event_pattern = jsonencode({
    source = [
      "lab.guardduty-simulator"
    ]

    "detail-type" = [
      "Simulated GuardDuty Finding"
    ]

    detail = {
      findingType = [
        "UnauthorizedAccess:EC2/SSHBruteForce"
      ]

      resource = {
        resourceType = [
          "Instance"
        ]
      }
    }
  })

  tags = {
    Name = "${var.project_name}-simulated-finding-rule"
  }
}
