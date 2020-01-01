require 'faraday'
require 'json'
require 'redcarpet'

CONF_SPACE = ''
HOST = 'https://<account>.atlassian.net'
EMAIL = ''
TOKEN = ''
DIR_PATH = ''

category_to_ancestor_ids = {}

class Confluence
  def initialize
    @host = HOST
    @conn = Faraday.new(url: @host) do |faraday|
      faraday.request :url_encoded # encode post params
      faraday.adapter :net_http # Net::HTTP
      faraday.basic_auth(EMAIL, TOKEN)
    end
  end

  def create_page(title, body, ancestor_id = nil)
    response = @conn.post do |req|
      req.url '/wiki/rest/api/content/'
      req.headers['Content-Type'] = 'application/json'
      req.body = {
        "type": 'page',
        "title": title,
        "space": { "key": CONF_SPACE },
        "body": {
          "storage": {
            "value": body,
            "representation": 'storage',
          },
        },
      }
      .tap{ |req_body| break req_body.merge(ancestors: [{ "id": ancestor_id&.to_s }]) unless ancestor_id.nil? }
      .compact.to_json
    end
    if response.status == 200
      JSON.parse(response.body)
    else
      if JSON.parse(response.body)["message"].index("exists:")
        p "SKIP: #{title}"
      else
        p JSON.parse(response.body)
        p "ERROR: #{title}"
      end
      nil
    end
  end

  def get_pages
    response = @conn.get do |req|
      req.url '/wiki/rest/api/content/'
      req.headers['Content-Type'] = 'application/json'
    end
    print response.body
  end

  def get_page(content_id)
    response = @conn.get do |req|
      req.url "/wiki/rest/api/content/#{content_id}"
      req.headers['Content-Type'] = 'application/json'
    end
    print response.body
  end
end

class Esa
  def initialize(path)
    File.open(path, 'r') do |file|
      @content = file.read
      metadata_raw, @body = @content.split("\n---\n")
      @metadata = metadata_raw.split("\n").reject { |x| x == '---' }.map { |x| result = x.split(': '); result.push('') if result.count == 1; result }.to_h
    end

    options = {
        filter_html:     true,
        hard_wrap:       true,
        space_after_headers: true,
    }

    extensions = {
        autolink:           true,
        no_intra_emphasis:  true,
        fenced_code_blocks: true,
        tables:             true,
    }

    renderer = Redcarpet::Render::HTML.new(options)
    @markdown = Redcarpet::Markdown.new(renderer, extensions)
  end

  def title
    @metadata['title'].strip.tr('"', '')
  end

  def body_html
    @markdown.render(@body)
  end

  def category
    @metadata['category'].to_s
  end
end

confl = Confluence.new

# create page
Dir.glob("#{DIR_PATH}**/*").each do |path|
  p path
  if path.match?('md$')
    # File
    esa = Esa.new(path)
    confl.create_page(esa.title, esa.body_html, category_to_ancestor_ids[esa.category])
  else
    # Directory
    parent_path = path.gsub(/#{DIR_PATH}/, '')
    if category_to_ancestor_ids.has_key?(parent_path)
      p "SKIP:#{parent_path}"
      next
    end

    level_count = parent_path.split('/').count
    if level_count == 1
      # Parent Page
      confl_page = confl.create_page(parent_path, '')
      category_to_ancestor_ids["#{parent_path}"] = confl_page["id"] unless confl_page.nil?
      p category_to_ancestor_ids
    elsif level_count > 1
      # Child Page
      page_name = parent_path.split('/')[-1]
      parent_key = parent_path.gsub(/\/#{page_name}/, '')
      parent_id = category_to_ancestor_ids["#{parent_key}"]
      confl_page = confl.create_page(page_name, '', parent_id)
      category_to_ancestor_ids["#{parent_path}"] = confl_page["id"] unless confl_page.nil?
      p category_to_ancestor_ids
    else
      # Error
      next
    end
  end
end
