Kind      = "proxy-defaults"
Name      = "global"

AccessLogs {
  Enabled = true
  Type = "file"
  Path = "/alloc/logs/envoy-access.log"
  JsonFormat = "[%START_TIME%] \"%REQ(:METHOD)% %REQ(X-ENVOY-ORIGINAL-PATH?:PATH)% %PROTOCOL%\" %RESPONSE_CODE% %RESPONSE_FLAGS% %BYTES_RECEIVED% %BYTES_SENT% %DURATION% %RESP(X-ENVOY-UPSTREAM-SERVICE-TIME)% \"%REQ(X-FORWARDED-FOR)%\" \"%REQ(USER-AGENT)%\" \"%REQ(X-REQUEST-ID)%\" \"%REQ(:AUTHORITY)%\" \"%UPSTREAM_HOST%\""
}

Config {
  # Enable metrics collection
  envoy_prometheus_bind_addr = "0.0.0.0:9102"
}