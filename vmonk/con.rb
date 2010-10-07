require 'rubygems'
require 'rest_connection'
require  File.join(File.dirname(__FILE__), 'lib', 'deployment_monk')
require 'highline/import'
require 'yaml'
require 'fileutils'
require 'ruby-debug'
require File.join(File.dirname(__FILE__), "lib", "storage")
require File.join(File.dirname(__FILE__), "lib", "cuke_monk")

class MenuMonk
  FEATURE_GLOB = File.join(File.dirname(__FILE__), "..", "**", "*.feature")
  CONFIG_DIR=File.join(File.dirname(__FILE__), "config")
  VIEWS=File.join(File.dirname(__FILE__), "app", "views")

  def initialize
# Create a color scheme, naming color patterns with symbol names.
    ft = HighLine::ColorScheme.new do |cs|
            cs[:headline] = [ :bold, :yellow, :on_black ]
            cs[:question] = [ :bold, :white, :on_blue]
            cs[:even_row] = [ :green, :on_black ]
            cs[:odd_row] = [ :magenta, :on_black ]
         end
    HighLine.color_scheme = ft
    @cm = CukeMonk.new
    do_dep_sets_menu
  end

  def do_dep_sets_menu
    valid_deps = Deployment.find(:all) {|dep| DeploymentSet.all(:tag.like => dep.nickname) }
    choose do |menu|
      say "<%= color('Main Menu', :headline) %>"
      menu.index = :number
      menu.choice "Create Deployment Set" do
        deployments_tag = ask("<%= color('Enter new deployments_tag:', :question) %>")
        templateset = do_templates_menu
        DeploymentSet.create(:tag => deployments_tag)
        @dm = DeploymentMonk.new(deployments_tag, templateset.templates.map(&:id))
      end
      menu.choice "Find Deployment Set" do
        deployments_tag = choose do |menu|
          menu.index = :number
          say "<%= color('What substring would you like to match deployments with?', :headline) %>"
          DeploymentSet.all.each {|d| menu.choice(d.tag)}
          menu.choice("manually enter tag") do
            deployments_tag = ask("Enter new deployments_tag:") 
            DeploymentSet.create(:tag => deployments_tag)
            deployments_tag
          end
        end
        begin
          @dm = DeploymentMonk.new(deployments_tag)
        rescue => e
          say e
          do_dep_sets_menu
        end
      end
    end
  end

  def do_templates_menu
    choose do |menu|
      template_view = IO.read(File.join(VIEWS, "template_sets.erb"))
      menu.layout = template_view
      menu.index = :number
      menu.choice("create") do
        ask("what template ids? (comma separated list)",
          lambda { |str| 
            new_ts = TemplateSet.create
            str.split(/,\s*/).each do |t|
              Template.create(:id => t.to_i, :template_set => new_ts)
            end
            new_ts
          })
      end
      TemplateSet.all.each do |ts|
        menu.choice(ts)
      end
    end
  end

  def load_common_inputs()
    loadables = Dir.glob(File.join(CONFIG_DIR, "**/*.json"))
    load_this = choose do |menu|
      menu.header = "Load deployment inputs from file:"
      menu.choices(*loadables)
      menu.choice("next") {return}
    end
    @dm.load_common_inputs(load_this)
  end

  def release_dns(tag=nil)
# does this messup datamapper?
    require 'sqlite3'
    SQLite3::Database.new(File.join(File.dirname(__FILE__), "..", "features", "shared.db")) do |db|
      if tag
        q = db.query("UPDATE mysql_dns SET owner=NULL where owner LIKE '#{tag}%'")
      else
        q = db.query("UPDATE mysql_dns SET owner=NULL")
      end
      q.close
      db.query("SELECT * FROM mysql_dns") do |result|
        puts result.entries
      end
    end
  end

## MAIN MENU
  def main()
    while(1)
      choose do |menu|
        menu.header = "Main Menu> #{@dm.tag}"
        menu.index = :number
        menu.choice("generate more") {@dm.generate_variations}
        menu.choice("load common inputs") { load_common_inputs() }
        menu.choice("RELEASE ALL dns") do
          release_dns
        end
        menu.choice("RELEASE dns") do
          release_dns(@dm.tag)
        end
        menu.choice("DESTROY all") do
          confirm = ask("Really destroy all these deployments? #{(@dm.variations.map &:nickname).join(',')}", lambda { |ans| true if (ans =~ /^[y,Y]{1}/) })
          @dm.destroy_all if confirm
        end 
        menu.choice("SPECIAL MySQL TERMINATE all") do
          @dm.variations.each do |deployment|
            deployment.reload
            deployment.servers.each do |server|
              puts server.state
              unless server.state == "stopped"
                st = ServerTemplate.find(server.server_template_href)
                terminate_script = st.executables.detect { |ex| ex.name =~ /TERMINATE/ }
                begin
                  server.run_executable(terminate_script)
                rescue => e
                  puts "WARNING: #{e}"
                end
              end
            end
          end
        end
        menu.choice("TERMINATE all") do
          @dm.variations.each do |deployment|
            deployment.reload
            deployment.servers.each do |server|
              server.stop
            end
          end
        end
        menu.choice("run cuke feature on all deployments") { run_cuke }
        menu.choice("wait for and generate reports") { generate_reports }
        menu.choices(*@dm.variations.map {|m| "#{m.nickname}" }) do |dep_href|
          deployment_menu(dep_href)
        end
        menu.choice("quit") { exit(0) }
        menu.choice("refresh")
      end
    end
  end

  def run_cuke(deployment=nil)
    loadables = Dir.glob(FEATURE_GLOB)
    feature_name = choose do |menu|
      menu.header = "Run Feature:"
      menu.choices(*loadables)
      menu.choice("cancel") {return}
    end
    FileUtils.mkdir_p("log")
    ENV['REST_CONNECTION_LOG'] = "log/rest_connection.log"
    if deployment
      @cm.run_test(deployment.nickname, feature_name)
    else
      deployment_nicknames = @dm.variations.map &:nickname
      @cm.run_tests(deployment_nicknames, feature_name)
    end
    #cm.generate_reports
  end

  def generate_reports
    @cm.generate_reports
  end

  def deployment_menu(deploy_href)
    deploy = Deployment.find_by_nickname_speed(deploy_href)
    puts "WARNING: found multiple deployments with the same nickname!" unless deploy.size == 1
    deploy = deploy.first
    deploy.servers.each {|s| s.settings}
    pp deploy
    choose do |menu|
      menu.choice("start") { deploy.servers.each {|s| s.start} }
      menu.choice("stop") { deploy.servers.each {|s| s.stop} }
      menu.choice("reboot") { deploy.servers.each {|s| s.reboot} }
      menu.choice("release DNS") { release_dns(deploy.nickname) }
      menu.choice("run cuke") {run_cuke(deploy)}
      menu.choice("back") 
    end
  end
end

m = MenuMonk.new
m.main

