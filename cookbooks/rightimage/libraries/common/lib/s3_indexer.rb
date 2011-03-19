module RightImage

  class S3HtmlIndexer

  def initialize(bucket, id=nil, key=nil)
    @s3 = RightAws::S3.new(id, key)
    @bucket = @s3.bucket(bucket)
    @keys = @bucket.keys
    @auto_hash = Hash.new{ |h,k| h[k] = Hash.new &h.default_proc }
  end

  def to_html(filename)
    # Create hash hierarchy from bucket list
    @keys.reject! { |path| path.full_name =~ /index.html/ }
    @keys.each do |path| 
      sub = @auto_hash
      path.full_name.split( "/" ).each do |dir| 
        sub = sub[dir] 
      end
      sub[:link] = fix_public_endpoint(path.public_link)
      sub[:size] = path.size
    end

    # make a non-auto hash copy
    dirs = Hash.new
    dirs = dirs.merge(@auto_hash)

    # visualize hierarchy
    dirs.each do |k,v|
      @file = File.open(filename, "w")
      output("<html>")
      add_style
      display_dirs(k,v)
      output("</html>")
      @file.close
    end
  end
  
  def upload_index(filename)
    @bucket.put("index.html", File.open(filename), {}, 'public-read')
  end
  
  private 
    
    def display_dirs(k,v,level=0)
      return unless v
      unless v.keys.include?(:link)
        add_header(k, level)
        v.each do |k2, v2|
          display_dirs(k2, v2, level+1)
        end
        add_footer(k, level)
      else
        output("<tr class='code'>")
        output("<td><a href='#{v[:link]}'>#{k}</a></td>")
        output("<td>#{v[:size].to_i/(1024*1024)}MB</td>")
        output("</tr>")
      end
    end
    
    def add_header(str, level)
      case level
      when 0
        # bucket name
        output("<div id='header'><img alt='Embedded Image' width='140' height='19' src='#{encoded_logo}' /></div>")
        output("<div class='bucket common'>#{str.gsub(/rightscale-/,"").capitalize}</div>")
      when 1
        # Hypervisor 
        output("<div class='hypervisor common'>")
        output("<h#{level-1}>#{str.capitalize} Hypervisor</h#{level-1}>\n")
        output("</div>")
        output("<div class='platform common'>")
      when 2
        # OS
        output("<h#{level}>#{str.capitalize}</h#{level}>\n")
        output("<div class='platform'>")
      when 3
        # Version
        output("<div class='version common'>#{str}</div>\n")
        output("<div class='platform common'>")
        output("<table style='padding:none; size:90%'>")
        output("<tr style='border: solid 1px black;'>")
        output("<th>Image</th>")
        output("<th>Size</th>")
        output("</tr>")
      else
        # image
        # output("<div class='platform'>")
      end
    end
    
    def add_footer(str, level)
      case level
      when 0
      when 1
        output("</div>")
        output("<br/><br/>")
      when 2
        output("</div>")
      when 3
        output("</table>")
        output("</div>")
        output("<br/><br/>")
      else
        # output("</div>")
      end
    end

    # https://s3.amazonaws.com/rightscale-cloudstack/foo
    # to
    # https://rightscale-cloudstack.s3.amazonaws.com 
    def fix_public_endpoint(link)
      link_ary = link.split("/")
      bucket = link_ary[3]
      host = link_ary[2]
      link_ary[2] = "#{bucket}.#{host}"
      link_ary.delete_at(3)
      link_ary.join("/")
    end
    
    def output(str)
      @file.write "#{str}\n" if @file
      p str
    end

    def add_style
      output "<style>"
      output( "body {min-width: 600px; margin:0; padding:0; font-size:70.5%; /* font-family:'Lucida Sans', Verdana, Arial, sans-serif; */ font-family:'Lucida Grande','Lucida Sans Unicode','Lucida Sans',Verdana,lucida,sans-serif; background:#FFF; height:100%}
    html {height:100%}
    a img {border:none}
    a {color:#1e4a7e}
    table { width:90% }
    th { text-align:left }

    #header {
    	background:#235186; 
    	padding:2px 20px; 
    	position:relative; 
    	height:25px;
    }

    #header #logo {
    	margin-top:3px; 
    }

    .common {
      font-size: 16px;
      margin-left:auto;
      margin-right:auto;
      font-weight: bold;
    	padding:2px 20px; 
    	position:relative; 
    }

    .bucket {
      font-size: 24px;
      color: #F5F2A9;
    	background:#235186; 
    	padding:10px 30px 20px; 
    }
   
    .version {
      color: #F5F2A9;
    	background:#235186; 
    }

    .hypervisor {
      color: #235186;
    	background:#F5F2A9; 
    }

    .platform {
    	background: #FFFFFF;
    	width:90%;
    	margin-left: auto ;
      margin-right: auto ;
      position: relative;
    }
    .code {
    	font-family:'Courier New', monospace;
    	position:relative;
    	left:10px;
    }
    ")
      output "</style>"
    end
    
    def encoded_logo
      "data:image/png;base64,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%3D%3D"
    end
  
  end
end


  
