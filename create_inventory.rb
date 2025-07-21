#!/usr/bin/env ruby

require 'json'
require 'yaml'

def fetch_inventory_json
  # get json list of active vmfloaty VMs
  output = `floaty list --active --json`.strip

  # abort if empty string returned, i.e., no vmfloaty VMs
  raise 'Error fetching inventory json: Do you have any vmfloaty VMs?' if output.empty?

  output
end

# JSON input (replace with actual command output)
# json_input = '{"gavin.didrichsen-1739534997862":{"state":"allocated","last_processed":"2025-02-14 18:47:17 +0000","requested":true,"requested_status":"win-2019-x86_64 (ready: 0, pending: 1)","audit_log":{"2025-02-14 12:10:24 +0000":"Failure to safely allocate. Allocated resources are empty or nil","2025-02-14 12:13:07 +0000":"Allocated swivel-fusion.delivery.puppetlabs.net for job gavin.didrichsen-1739534997862","2025-02-14 12:13:40 +0000":"Not a Jenkins job. Could not determine status."},"allocated_resources":[{"hostname":"swivel-fusion.delivery.puppetlabs.net","type":"win-2019-x86_64","engine":"ondemand"}],"request":{"resources":{"win-2019-x86_64":1},"job":{"id":"gavin.didrichsen-1739534997862","tags":{"user":"gavin.didrichsen"},"user":"gavin.didrichsen","time-received":"2025-02-14 12:09:58 +0000"},"priority":1,"vm_token":"XXXX"}},"gavin.didrichsen-1739541771983":{"state":"allocated","last_processed":"2025-02-14 18:47:17 +0000","requested":true,"requested_status":"redhat-8-x86_64 (ready: 0, pending: 1)","audit_log":{"2025-02-14 14:03:01 +0000":"Failure to safely allocate. Allocated resources are empty or nil","2025-02-14 14:04:30 +0000":"Allocated dry-regression.delivery.puppetlabs.net for job gavin.didrichsen-1739541771983","2025-02-14 14:05:00 +0000":"Not a Jenkins job. Could not determine status."},"allocated_resources":[{"hostname":"dry-regression.delivery.puppetlabs.net","type":"redhat-8-x86_64","engine":"ondemand"}],"request":{"resources":{"redhat-8-x86_64":1},"job":{"id":"gavin.didrichsen-1739541771983","tags":{"user":"gavin.didrichsen"},"user":"gavin.didrichsen","time-received":"2025-02-14 14:02:52 +0000"},"priority":1,"vm_token":"XXXX"}},"gavin.didrichsen-1739534985058":{"state":"filled","last_processed":"2025-02-14 18:47:11 +0000","allocated_resources":[{"hostname":"unimposing-poll.delivery.puppetlabs.net","type":"win-2019-x86_64","engine":"ondemand"}],"audit_log":{"2025-02-14 12:10:16 +0000":"Failure to safely allocate. Allocated resources are empty or nil","2025-02-14 12:48:56 +0000":"Allocated unimposing-poll.delivery.puppetlabs.net for job gavin.didrichsen-1739534985058","2025-02-14 12:49:33 +0000":"Not a Jenkins job. Could not determine status."},"requested":true,"requested_status":"win-2019-x86_64 (ready: 0, pending: 1)","request":{"resources":{"win-2019-x86_64":1},"job":{"id":"gavin.didrichsen-1739534985058","tags":{"user":"gavin.didrichsen"},"user":"gavin.didrichsen","time-received":"2025-02-14 12:09:45 +0000"},"priority":3,"vm_token":"XXXX"}}}'
json_input = fetch_inventory_json

# Parse JSON
data = JSON.parse(json_input)

# Extract targets
targets = data.values.flat_map { |job|
  job["allocated_resources"].map do |resource|
    {
      "name" => resource["hostname"].split(".").first,
      "uri" => resource["hostname"]
    }
  end
}

# Group targets
windows_targets = data.values.flat_map { |job|
  job["allocated_resources"].select { |r| r["type"].include?("win") }.map { |r| r["hostname"].split(".").first }
}

linux_targets = data.values.flat_map { |job|
  job["allocated_resources"].select { |r| r["type"].include?("redhat") }.map { |r| r["hostname"].split(".").first }
}

# Construct inventory
inventory = {
  "targets" => targets,
  "groups" => [
    {
      "name" => "windows",
      "config" => {
        "transport" => "ssh",
        "ssh" => {
          "_plugin" => "yaml",
          "filepath" => "~/.secrets/bolt/windows/credentials.yaml"
        }
      },
      "targets" => windows_targets
    },
    {
      "name" => "linux",
      "config" => {
        "transport" => "ssh",
        "ssh" => {
          "native-ssh" => true,
          "load-config" => true,
          "login-shell" => "bash",
          "tty" => false,
          "host-key-check" => false,
          "run-as" => "root",
          "user" => "root",
        }
      },
      "targets" => linux_targets
    }
  ]
}

# Output YAML
puts inventory.to_yaml