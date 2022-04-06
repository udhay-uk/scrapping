require 'rubygems'
require 'byebug'
require 'logger'
require 'csv'
require 'nokogiri'
require 'faraday'
require 'fileutils'

$medium = ARGV.first
raise "medium is a required argument" if $medium.nil?
base_path = "#{ENV["HOME"]}/git/metacritic_scrapping"
$logger = Logger.new("log/scrape_game#{$medium}.log")
$logger.level = Logger::INFO

FileUtils.mkdir_p "cache/#{$medium}/games"
FileUtils.mkdir_p "output/"

def get_page(url, file_name)
  file_path = "cache/#{$medium}/games/#{file_name}#{url.hash}.html"
  content_text = nil
  begin
    if(File.exists?(file_path))
      content_text = File.read(file_path) 
    else
      $logger.info "Fetching document for #{$medium}..."
      response = Faraday.get(url, {view: "condensed"})
      File.open(file_path, 'w') { |file| file.write(response.body) }
      $logger.info "Cache created for #{$medium}..."
      content_text = response.body
    end
    Nokogiri::HTML(content_text)
  rescue StandardError => e
    $logger.info "Error in processing #{url}.."
    $logger.error e
  end
end

def read_list_records(document)
  
end

def read_details_record(document)
  pub_links = document.css('li.summary_detail.publisher > span.data > a')
  pub_details = pub_links.map do |pub_a|
    pub_url = "https://www.metacritic.com" + pub_a.attribute('href')
    pub_name = pub_a.text.strip
    "#{pub_name}|#{pub_url}"
  end

  dev_links = document.css('li.summary_detail.developer > span.data > a')
  dev_details = dev_links.map do |dev_a|
    dev_url = "https://www.metacritic.com" + dev_a.attribute('href')
    dev_name = dev_a.text.strip
    "#{dev_name}|#{dev_url}"
  end
  
  gen_spans = document.css('li.summary_detail.product_genre > span.data')
  genres = gen_spans.map do |gen_span|
    genre = gen_span.text.strip
    "#{genre}"
  end
  
  rating_span = document.css('li.summary_detail.product_rating > span.data')
  rating = rating_span.first&.text&.strip
  [pub_details.join(","), dev_details.join(","), genres.join(","), rating]
end

$logger.info "Scrapping Started"
$logger.info "Reading medium: #{$medium}"
$logger.info "Fetching pages for #{$medium}"
output = CSV.open("#{base_path}/#{$medium}_final.csv", "a", col_sep: "\t")
csv_file = CSV.open("#{base_path}/output/#{$medium}.csv", col_sep: "\t")


records = csv_file.map do |row|
  url = row[0]
  document = get_page(url, row[1].gsub(/[^A-Za-z0-9]/,""))
  $logger.info "Reading document for #{url}..."
  record = read_details_record(document) if(document)
  row + record
end.compact


CSV.open("output/#{$medium}_games.csv", "w", col_sep: "\t") do |csv|
  records.map do |rec|
    csv << rec
  end
end
