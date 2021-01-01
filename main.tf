locals {
  api_url              = "${aws_api_gateway_deployment._.invoke_url}${aws_api_gateway_stage._.stage_name}"
  api_name             = var.api_name
}

data "template_file" "_" {
  template = var.api_template

  vars = var.api_template_vars
}

resource "aws_api_gateway_rest_api" "_" {
  name           = local.api_name
  api_key_source = "HEADER"

  body = data.template_file._.rendered
}

resource "aws_api_gateway_deployment" "_" {
  rest_api_id = aws_api_gateway_rest_api._.id
  stage_name  = ""

  lifecycle {
    create_before_destroy = true
  }
  
  triggers = {
    redeployment = sha1(data.template_file._.rendered)
  }
}

resource "aws_api_gateway_stage" "_" {
  stage_name    = var.namespace
  rest_api_id   = aws_api_gateway_rest_api._.id
  deployment_id = aws_api_gateway_deployment._.id

  xray_tracing_enabled = var.xray_tracing_enabled

  tags = {
    Environment = var.namespace
    Name        = var.resource_tag_name
  }
}

resource "aws_api_gateway_method_settings" "_" {
  rest_api_id = aws_api_gateway_rest_api._.id
  stage_name  = aws_api_gateway_stage._.stage_name
  method_path = "*/*"

  settings {
    throttling_burst_limit = var.api_throttling_burst_limit
    throttling_rate_limit  = var.api_throttling_rate_limit
    metrics_enabled        = var.api_metrics_enabled
    logging_level          = var.api_logging_level
    data_trace_enabled     = var.api_data_trace_enabled
  }
}

# -----------------------------------------------------------------------------
# CloudWatch: API Gateway 
# -----------------------------------------------------------------------------
module "cloudwatch_alarms_apigateway" {
  source = "./cloudwatch-alarms-apigateway"

  namespace         = var.namespace
  region            = var.region
  resource_tag_name = var.resource_tag_name

  api_name  = local.api_name
  api_stage = aws_api_gateway_stage._.stage_name

  resources = var.resources

  create_latency_alarm      = var.create_latency_alarm
  latency_threshold_p95     = var.latency_threshold_p95
  latency_threshold_p99     = var.latency_threshold_p99
  latency_evaluationPeriods = var.latency_evaluationPeriods

  fourRate_threshold         = var.fourRate_threshold
  fourRate_evaluationPeriods = var.fourRate_evaluationPeriods

  fiveRate_threshold         = var.fiveRate_threshold
  fiveRate_evaluationPeriods = var.fiveRate_evaluationPeriods

}
