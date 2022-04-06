require "google/apis/sheets_v4"
require "googleauth"
require "googleauth/stores/file_token_store"
require "fileutils"
require "csv"
require "byebug"

require "google/apis/drive_v3"

OOB_URI = "urn:ietf:wg:oauth:2.0:oob".freeze
APPLICATION_NAME = "UploadToSpreadsheet".freeze
CREDENTIALS_PATH = "google-credentials.json".freeze
TOKEN_PATH = "token.yaml".freeze
SCOPE = [
  Google::Apis::SheetsV4::AUTH_SPREADSHEETS,
  Google::Apis::DriveV3::AUTH_DRIVE_METADATA_READONLY
]
def authorize
  client_id = Google::Auth::ClientId.from_file CREDENTIALS_PATH
  token_store = Google::Auth::Stores::FileTokenStore.new file: TOKEN_PATH
  authorizer = Google::Auth::UserAuthorizer.new client_id, SCOPE, token_store
  user_id = "udhayakumarsmilingboy@gmail.com"
  credentials = authorizer.get_credentials user_id
  if credentials.nil?
    url = authorizer.get_authorization_url base_url: OOB_URI
    puts "Open the following URL in the browser and enter the " \
         "resulting code after authorization:\n" + url
    code = gets
    credentials = authorizer.get_and_store_credentials_from_code(
      user_id: user_id, code: code, base_url: OOB_URI
    )
  end
  credentials
end

def create_spreadsheet(name)
  drive_service = Google::Apis::DriveV3::DriveService.new
  drive_service.client_options.application_name = APPLICATION_NAME
  drive_service.authorization = authorize
  response = drive_service.list_files(
                              fields: "nextPageToken, files(id, name)",
                              page_size: 1,
                              q: "name='#{name}'"
                            )
  file = response.files.first
  spreadsheet_service = Google::Apis::SheetsV4::SheetsService.new
  spreadsheet_service.client_options.application_name = "spreadsheetuploadproject"
  spreadsheet_service.authorization = authorize
  if file.nil?
    spreadsheet = {
      properties: {
        title: name
      }
    }
    spreadsheet = spreadsheet_service.create_spreadsheet(spreadsheet, fields: 'spreadsheetId')
    return [spreadsheet_service, spreadsheet.spreadsheet_id]
  end
  [spreadsheet_service, file.id]
end

service, spreadsheet_id  = create_spreadsheet("VideoGameUniverse222")

rows = []
CSV.foreach("#{ENV["HOME"]}/git/metacritic_scrapping/output/pc_games.csv", col_sep: '\t', liberal_parsing: true) do |row|  
# CSV.read("/git/metacritic_scrapping/output/stadia_games.csv", col_sep: '\t', liberal_parsing: true) do |row|
  rows << row[0].split("\t")
end
# example = ["https://www.metacritic.com/game/pc/nightmare-reaper","Nightmare Reaper","PC","March 28, 2022","Blazing Bit Games|https://www.metacritic.com/company/blazing-bit-games","Blazing Bit Games|https://www.metacritic.com/company/blazing-bit-games,Blazing Bit Games|https://www.metacritic.com/company/blazing-bit-games".split(',').join("\n"),"Action,Shooter,First-Person,Arcade".split(',').join("\n"),"T"]
# rows = 10.times.map { example }
def hyperlink(url, name)
  name = name.gsub(/[“”"]+/, "'")
  "=HYPERLINK(\"#{url}\",\"#{name}\")"
end
def handle_hyperlinks(ent)
  links = ent.to_s.split(",")
  if(links.length > 1)
    links.join("\n")
  else
    link = links[0]
    name, url = link.to_s.split('|')
    hyperlink(url, name)  
  end
end
def write_records(service, spreadsheet_id, media, records)
  values = records.map { |entry|
    [
      hyperlink(entry[0],entry[1]),
      entry[0],
      entry[2],
      entry[3],
      handle_hyperlinks(entry[4]),
      handle_hyperlinks(entry[5]),
      entry[6].split(",").join("\n"),
      entry[7]
    ]
  }
  value_range = Google::Apis::SheetsV4::ValueRange.new(values: values)
  service.append_spreadsheet_value(spreadsheet_id, "#{media}!A1", value_range, value_input_option: "USER_ENTERED")
end 

media = "pc"
batch = []
rows.each_with_index do |row|
  if batch.count == 1000
    write_records(service, spreadsheet_id, media, batch)
    batch.clear
  end
  batch << row
end

write_records(service, spreadsheet_id, media, batch)
# values = [
#   "=HYPERLINK(\"#{row[0]}\",\"#{row[1]}\")"
# ].concat(row[2..-1])
# v = Google::Apis::SheetsV4::ValueRange.new(values: 10.times.map { |i| values })


# # values = [
# #   {
# #     "userEnteredValue": {
# #       "formulaValue": "=HYPERLINK(\"wwww.google.com\",\"google\")"
# #     }
# #   },
# # ]
# puts spreadsheet_id
# response = service.append_spreadsheet_value(spreadsheet_id, 'Sheet1!A1', v, value_input_option: "USER_ENTERED")

# def write(service, file_id, row)
#   values = [
#     {
#       "userEnteredValue": {"formulaValue" => "=HYPERLINK(\"#{row[0]}\",\"#{row[1]}\")" }
#     }
#   ].concat(row[2..-1].map{ |v| { "formattedValue" => v } })
#   service.append_spreadsheet_value(service, file_id, values)
# end




    # ]
      
    #   (publisher = entry[4].split(",")
    #     if (publisher.length > 1)
    #       publisher.join("\n")
    #     else 
    #       publisher = publisher[0]
    #       publ_name, link_pub = publisher.split("|")
    #       "=HYPERLINK(\"#{link_pub}\",\"#{publ_name}")
    #     end
    #     ),
    #   (developer = entry[5].split(",")
    #     if (developer.length > 1)
    #       developer.join("\n")
    #     else 
    #       developer = developer[0]
    #       dev_name, link_dev = developer.split("|")
    #       "=HYPERLINK(\"#{link_dev}\",\"#{dev_name}")
    #     end
    #     )