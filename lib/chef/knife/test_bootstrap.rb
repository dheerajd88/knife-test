require 'chef/knife'
require 'erubis'
require "chef/knife/bootstrap/client_builder"
require 'chef/knife/azure_base'
require 'securerandom'
#require 'chef/knife/bootstrap/bootstrap_options'
module MyTestBootstrap
  class TestBootstrap < Chef::Knife
  	#include Knife::AzureBase
    deps do
      require "chef/knife/core/bootstrap_context"
      require "chef/json_compat"
      require "tempfile"
      require "highline"
      require "net/ssh"
      require "net/ssh/multi"
      require "chef/knife/ssh"
      require 'chef/knife/bootstrap'
      require 'chef/knife/azure_base'
      Chef::Knife::Ssh.load_deps
      Chef::Knife::Bootstrap.load_deps
    end
    banner "knife test bootstrap SERVER(options)"
      attr_accessor :initial_sleep_delay

      option :ssh_user,
        :short => "-x USERNAME",
        :long => "--ssh-user USERNAME",
        :description => "The ssh username",
        :default => "root"

      option :ssh_password,
        :short => "-P PASSWORD",
        :long => "--ssh-password PASSWORD",
        :description => "The ssh password"

      option :ssh_port,
        :long => "--ssh-port PORT",
        :description => "The ssh port. Default is 22. If --azure-connect-to-existing-dns set then default SSH port is random"

      option :node_ssl_verify_mode,
        :long        => "--node-ssl-verify-mode [peer|none]",
        :description => "Whether or not to verify the SSL cert for all HTTPS requests.",
        :proc        => Proc.new { |v|
          valid_values = ["none", "peer"]
          unless valid_values.include?(v)
            raise "Invalid value '#{v}' for --node-ssl-verify-mode. Valid values are: #{valid_values.join(", ")}"
          end
        }

      option :node_verify_api_cert,
        :long        => "--[no-]node-verify-api-cert",
        :description => "Verify the SSL cert for HTTPS requests to the Chef server API.",
        :boolean     => true    

      option :azure_storage_account,
        :short => "-a NAME",
        :long => "--azure-storage-account NAME",
        :description => "Required for advanced server-create option.
                                      A name for the storage account that is unique within Windows Azure. Storage account names must be
                                      between 3 and 24 characters in length and use numbers and lower-case letters only.
                                      This name is the DNS prefix name and can be used to access blobs, queues, and tables in the storage account.
                                      For example: http://ServiceName.blob.core.windows.net/mycontainer/"
      option :identity_file,
        :long => "--identity-file FILENAME",
        :description => "SSH identity file for authentication, optional. It is the RSA private key path. Specify either ssh-password or identity-file"

      option :identity_file_passphrase,
        :long => "--identity-file-passphrase PASSWORD",
        :description => "SSH key passphrase. Optional, specify if passphrase for identity-file exists"

      option :thumbprint,
        :long => "--thumbprint THUMBPRINT",
        :description => "The thumprint of the ssl certificate"

      option :cert_passphrase,
        :long => "--cert-passphrase PASSWORD",
        :description => "SSL Certificate Password"

      option :cert_path,
        :long => "--cert-path PATH",
        :description => "SSL Certificate Path"
      option :forward_agent,
        :short => "-A",
        :long => "--forward-agent",
        :description =>  "Enable SSH agent forwarding",
        :boolean => true

      option :json_attributes,
        :short => "-j JSON",
        :long => "--json-attributes JSON",
        :description => "A JSON string to be added to the first run of chef-client",
        :proc => lambda { |o| JSON.parse(o) }

      option :host_key_verify,
        :long => "--[no-]host-key-verify",
        :description => "Verify host key, enabled by default.",
        :boolean => true,
        :default => true

      option :bootstrap_url,
        :long => "--bootstrap-url URL",
        :description => "URL to a custom installation script",
        :proc        => Proc.new { |u| Chef::Config[:knife][:bootstrap_url] = u }

      option :bootstrap_wget_options,
        :long        => "--bootstrap-wget-options OPTIONS",
        :description => "Add options to wget when installing chef-client",
        :proc        => Proc.new { |wo| Chef::Config[:knife][:bootstrap_wget_options] = wo }

      option :bootstrap_curl_options,
        :long        => "--bootstrap-curl-options OPTIONS",
        :description => "Add options to curl when install chef-client",
        :proc        => Proc.new { |co| Chef::Config[:knife][:bootstrap_curl_options] = co }

      option :use_sudo_password,
        :long => "--use-sudo-password",
        :description => "Execute the bootstrap via sudo with password",
        :boolean => false

      def tcp_test_ssh(fqdn, sshport)
        tcp_socket = TCPSocket.new(fqdn, sshport)
        readable = IO.select([tcp_socket], nil, nil, 5)
        if readable
          Chef::Log.debug("sshd accepting connections on #{fqdn}, banner is #{tcp_socket.gets}")
          yield
          true
        else
          false
        end
      rescue SocketError
        sleep 2
        false
      rescue Errno::ETIMEDOUT
        false
      rescue Errno::EPERM
        false
      rescue Errno::ECONNREFUSED
        sleep 2
        false
      rescue Errno::EHOSTUNREACH
        sleep 2
        false
      ensure
        tcp_socket && tcp_socket.close
      end                                      




     def run
     #			unless name_args.size == 1
     #			puts "Please provide server IP to bootstrap"
     #  		show_usage
     #			exit 1
     #			end
        validate_name_args!        
        @node_name = Array(@name_args).first
        server = @node_name
        $stdout.sync = true
        ui.info("Bootstrapping Chef on #{ui.color(@node_name, :bold)}")
        validate_params!
        bootstrap_exec(server)        
      end

      def default_bootstrap_template
      	'chef-full'
      end



      def validate_name_args!
           if Array(@name_args).first.nil?
             ui.error("Must pass an FQDN or ip to bootstrap")
             exit 1
           end
      end
      def bootstrap_exec(server)
          fqdn = server
          port = locate_config_value(:ssh_port)
          print ui.color("Waiting for sshd on #{fqdn}:#{port}", :magenta)
          print(".") until tcp_test_ssh(fqdn,port) {
              sleep @initial_sleep_delay ||= 10
              puts("done")
            }
          puts("\n")
          bootstrap_for_node(fqdn, port).run
      end     
        def bootstrap_for_node(fqdn, port)
          bootstrap = Chef::Knife::Bootstrap.new
          bootstrap.name_args = [fqdn]
          bootstrap.config[:ssh_user] = locate_config_value(:ssh_user)
          bootstrap.config[:ssh_password] = locate_config_value(:ssh_password)
          bootstrap.config[:ssh_port] = port
          bootstrap.config[:identity_file] = locate_config_value(:identity_file)
          bootstrap.config[:chef_node_name] = locate_config_value(:chef_node_name)
          bootstrap.config[:use_sudo] = true unless locate_config_value(:ssh_user) == 'root'
          bootstrap.config[:use_sudo_password] = true if bootstrap.config[:use_sudo]
          bootstrap.config[:environment] = locate_config_value(:environment)
          # may be needed for vpc_mode
          bootstrap.config[:host_key_verify] = config[:host_key_verify]
          Chef::Config[:knife][:secret] = config[:encrypted_data_bag_secret] if config[:encrypted_data_bag_secret]
          Chef::Config[:knife][:secret_file] = config[:encrypted_data_bag_secret_file] if config[:encrypted_data_bag_secret_file]
          bootstrap.config[:secret] = locate_config_value(:secret) || locate_config_value(:encrypted_data_bag_secret)
          bootstrap.config[:secret_file] = locate_config_value(:secret_file) || locate_config_value(:encrypted_data_bag_secret_file)
          bootstrap.config[:bootstrap_install_command] = locate_config_value(:bootstrap_install_command)
          bootstrap.config[:bootstrap_wget_options] = locate_config_value(:bootstrap_wget_options)
          bootstrap.config[:bootstrap_curl_options] = locate_config_value(:bootstrap_curl_options)
          bootstrap.config[:run_list] = locate_config_value(:run_list)
          bootstrap.config[:prerelease] = locate_config_value(:prerelease)
          bootstrap.config[:first_boot_attributes] = locate_config_value(:json_attributes) || {}
          bootstrap.config[:bootstrap_version] = locate_config_value(:bootstrap_version)
          bootstrap.config[:distro] = locate_config_value(:distro) || default_bootstrap_template
          # setting bootstrap_template value to template_file for backward
          bootstrap.config[:template_file] = locate_config_value(:template_file) || locate_config_value(:bootstrap_template)
          bootstrap.config[:node_ssl_verify_mode] = locate_config_value(:node_ssl_verify_mode)
          bootstrap.config[:node_verify_api_cert] = locate_config_value(:node_verify_api_cert)
          bootstrap.config[:bootstrap_no_proxy] = locate_config_value(:bootstrap_no_proxy)
          bootstrap.config[:bootstrap_url] = locate_config_value(:bootstrap_url)
          bootstrap.config[:bootstrap_vault_file] = locate_config_value(:bootstrap_vault_file)
          bootstrap.config[:bootstrap_vault_json] = locate_config_value(:bootstrap_vault_json)
          bootstrap.config[:bootstrap_vault_item] = locate_config_value(:bootstrap_vault_item)
        
          bootstrap
        end
      def validate!(keys)
        errors = []
        keys.each do |k|
          if locate_config_value(k).nil?
            errors << "You did not provide a valid '#{pretty_key(k)}' value. Please set knife[:#{k}] in your knife.rb or pass as an option."
          end
        end
        if errors.each{|e| ui.error(e)}.any?
          exit 1
        end
      end
      def validate_params!
      end

      def locate_config_value(key)
        key = key.to_sym
        config[key] || Chef::Config[:knife][key]
      end        
    end
  end