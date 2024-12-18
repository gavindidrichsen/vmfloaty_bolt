#!/usr/bin/env ruby
require 'json'
require 'yaml'
require 'fileutils'

class InventoryManager
  def initialize(vmfloaty_dir = File.expand_path('~/.vmfloaty'))
    # ensure the $vmfloaty_dir exists
    FileUtils.mkdir_p(vmfloaty_dir)
    @vmfloaty_dir = vmfloaty_dir
    @inventory_json = fetch_inventory_json
  end

  def process_inventory
    parsed_json = parse_inventory_json
    save_inventory_yaml(parsed_json)
    generate_ssh_config(parsed_json)
  end

  private

  def fetch_inventory_json
    # get json list of active vmfloaty VMs
    output = `floaty list --active --service vmpooler --json`.strip

    # abort if empty string returned, i.e., no vmfloaty VMs
    raise 'Error fetching inventory json: Do you have any vmfloaty VMs?' if output.empty?

    output
  end

  def parse_inventory_json
    return [] if @inventory_json.empty?

    begin
      JSON.parse(@inventory_json)
    rescue JSON::ParserError => e
      puts "Error parsing JSON: #{e.message}"
      {}
    end
  end

  def save_inventory_yaml(parsed_json)
    output = {
      'config' => {
        'transport' => 'ssh',
        'ssh' => {
          'native-ssh' => true,
          'load-config' => true,
          'login-shell' => 'bash',
          'tty' => false,
          'host-key-check' => false,
          'run-as' => 'root',
          'user' => 'root'
        }
      },
      'targets' => []
    }

    # loop over each vmfloaty VM and create a bolt ssh target
    parsed_json.each do |_key, value|
      target = {
        'name' => value['fqdn'].split('.').first,
        'uri' => value['fqdn'],
        'alias' => [],
        'config' => {
          'transport' => 'ssh'
        }
      }

      output['targets'] << target
    end

    output_file_path = File.join(@vmfloaty_dir, 'inventory.yaml')
    begin
      File.open(output_file_path, 'w') { |file| file.write(output.to_yaml) }
      puts "Inventory.yaml generated successfully at #{output_file_path}"
    rescue StandardError => e
      puts "Error writing YAML file: #{e.message}"
      exit(1)
    end
  end

  def generate_ssh_config(parsed_json)
    ssh_config = "Host >>>>>vmfloaty_VMs<<<<<\n"

    # loop over each vmfloaty VM and create an ssh config entry
    parsed_json.each do |_key, value|
      fqdn = value['fqdn']
      ssh_config += "Host #{fqdn}\n"

      # if the VM domain name matches then use perforce smallstep ssh config
      if fqdn.include?('vmpooler-prod.puppet.net')
        ssh_config += "  Include '/Users/gavin.didrichsen/.step/ssh/includes'\n"
      else
        ssh_config += "  User root\n"
        ssh_config += "  IdentityFile ~/.ssh/id_rsa-acceptance\n"
        ssh_config += "  StrictHostKeyChecking no\n"
        ssh_config += "  UserKnownHostsFile /dev/null\n"
      end
    end

    output_file_path = File.join(@vmfloaty_dir, '.ssh_config')
    begin
      File.open(output_file_path, 'w') { |file| file.write(ssh_config) }
      puts ".ssh_config generated successfully at #{output_file_path}"
    rescue StandardError => e
      puts "Error writing SSH config file: #{e.message}"
      exit(1)
    end
  end
end


if __FILE__ == $PROGRAM_NAME
  inventory_manager = InventoryManager.new
  inventory_manager.process_inventory
end
