aws_region  = "ap-south-1"
environment = "production"

# Add new repositories here - this file is safe to edit
# The script will not overwrite your changes
ecr_repositories = [
  {
    name             = "non-ai-api"
    scan_on_push     = false
    lifecycle_policy = "standard"
  },
  {
    name             = "rag-api"
    scan_on_push     = false
    lifecycle_policy = "standard"
  },
  {
    name             = "sentiment-api"
    scan_on_push     = false
    lifecycle_policy = "standard"
  },
  {
    name             = "intent-api"
    scan_on_push     = false
    lifecycle_policy = "standard"
  },
  {
    name             = "langgraph-api"
    scan_on_push     = false
    lifecycle_policy = "standard"
  },
  {
    name             = "frontend-api"
    scan_on_push     = false
    lifecycle_policy = "standard"
  }
  # Add more repositories above this line
]
