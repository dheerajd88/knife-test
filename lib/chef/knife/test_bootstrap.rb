require 'chef/knife'
require 'erubis'
require 'securerandom'
module MyTestBootstrap
  class TestBootstrap < Chef::Knife

    deps do
      require "chef/knife/core/bootstrap_context"
      require "chef/json_compat"
      require "tempfile"
      require "highline"
      require "net/ssh"
      require "net/ssh/multi"
      require 'chef/knife/bootstrap'
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
        :description => "The ssh port. Default is 22."

      option :use_sudo_password,
        :long => "--use-sudo-password",
        :description => "Execute the bootstrap via sudo with password",
        :boolean => false
# This method creates a TCP socket instance from which we can read/write. OR checking tcp ssh connection.
# Takes array of socket and check if in that socket if it's possible to read/write.
# Throws errors based upon the response.
# rescue clauses are provided to handle exceptions due to possible Network errors. 
# ensure block makes sure that created socket is closed.
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
        validate_name_args!        
        @node_name = Array(@name_args).first
        server = @node_name
        $stdout.sync = true
        ui.info("Bootstrapping Chef on #{ui.color(@node_name, :bold)}")
        validate_params!
        bootstrap_exec(server)        
      end
# This method returns bootstrap template which is responsible for installing chef-client.
# This template is picked up from chef and uses the script when bootstrap is run

      def default_bootstrap_template
      	'chef-full'
      end

# This method will validate arguement for command if FQDN or IP provided or not

      def validate_name_args!
           if Array(@name_args).first.nil?
             ui.error("Must pass an FQDN or ip to bootstrap")
             exit 1
           end
      end
# This method accepts FQDN/IP of server, check for ssh connection and run the bootstrap. 
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

# This method accepts FQDN and port, Creates instance and bundles the required parameters to the object 
        def bootstrap_for_node(fqdn, port)
          bootstrap = Chef::Knife::Bootstrap.new
          bootstrap.name_args = [fqdn]
          bootstrap.config[:ssh_user] = locate_config_value(:ssh_user)
          bootstrap.config[:ssh_password] = locate_config_value(:ssh_password)
          bootstrap.config[:ssh_port] = port
          bootstrap.config[:use_sudo] = true unless locate_config_value(:ssh_user) == 'root'
          bootstrap.config[:use_sudo_password] = true if bootstrap.config[:use_sudo]
          bootstrap
        end
# This method validates the options provided .

      def validate_params!
        if locate_config_value(:ssh_password) and (locate_config_value(:ssh_password).length <= 6 and locate_config_value(:ssh_password).length >= 72)
          ui.error("The supplied password must be 6-72 characters long and meet password complexity requirements")
          exit 1
        end
      end

# Checks if value is set either from chef config or knife file
      def locate_config_value(key)
        key = key.to_sym
        config[key] || Chef::Config[:knife][key]
      end

    end
  end