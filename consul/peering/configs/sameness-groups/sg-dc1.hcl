Kind                     = "sameness-group"
Name                     = "api-services"
Partition                = "default"
DefaultForFailover = true
Members = [
    { Partition = "default" },
    { Peer      = "gcp-dc2-default" }
]
