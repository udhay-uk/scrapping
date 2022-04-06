require 'rubygems'
require 'byebug'
require 'logger'
require 'csv'
require 'nokogiri'
require 'faraday'
require 'fileutils'

$medium = ARGV[0].strip
$total_pages = ARGV[1].strip.to_i
$url = "https://www.metacritic.com/browse/games/release-date/available/#{$medium}/date"

$logger = Logger.new("log/scrape_#{$medium}.log")
$logger.level = Logger::INFO

FileUtils.mkdir_p "cache/#{$medium}/pages/"
FileUtils.mkdir_p "output/"

def get_page(page)
  file_path = "cache/#{$medium}/pages/#{page}.html"
  return File.read(file_path) if(File.exists?(file_path))

  begin
    $logger.info "Fetching document for #{page}..."
    response = Faraday.get($url, {view: "condensed", page: page})
    File.open(file_path, 'w') { |file| file.write(response.body) }
    $logger.info "Cache created for #{page}..."
    response.body
  rescue StandardError => e
    $logger.info "Error in processing #{page}: #{$url}..."
    $logger.error e
  end
end

def get_all_records
  records = []
  $total_pages.times do |page|
    body_text = get_page(page)
    $logger.info "Reading document for #{page}..."
    document = Nokogiri::HTML(body_text) rescue nil
    next if document.nil?
    rows = document.css('table.clamp-list tr')
    records << rows.map do |row|
      a = row.css('td.details a').first
      link = "https://www.metacritic.com" + a['href']
      title = a.css('h3').text.strip
      platform = row.css('div.platform .data').text.strip
      date = row.css('td.details > span').text.strip
      {link: link, title: title, platform: platform, date: date}
    end
  end
  records.flatten
end

def fetch_all_pages
  $total_pages.times do |page|
    sleep(1)
  end
end

$logger.info "Scrapping Started"
$logger.info "Reading medium: #{$medium}"
$logger.info "Fetching #{$total_pages} pages for #{$medium}"
records = get_all_records
CSV.open("output/#{$medium}.csv", "w", col_sep: "\t") do |csv|
  records.map do |rec|
    csv << rec.values
  end
end
