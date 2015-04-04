require 'net/http'
require 'uri'
require 'cgi'
require 'nokogiri'
require 'csv'

# The search page is a post request with form data:
#   intsearchby - This will be 4 for searching by business category.
#   BUSCODE - The code for the business category.  Those are in a file called 'business_category_codes.txt'
#   intSearchOpt - This will be 2 but don't know why...
COC_SEARCH_URL = "http://missouri.edu/directories/people-results.php"
NAME_FILE = "names.txt"
PEOPLE_CSV_FILENAME = "results.csv"

RESULT_CLASS = "results"
ITEM_CLASS = "item"
PERSON_NAME_CLASS = "name"


COOKIES = "_ga=GA1.2.14385190.1423014411; __utmt=1; __utma=262015377.14385190.1423014411.1428126619.1428128481.7; __utmb=262015377.1.10.1428128481; __utmc=262015377; __utmz=262015377.1428120911.5.4.utmcsr=google|utmccn=(organic)|utmcmd=organic|utmctr=(not%20provided)"

POST_HEADERS = {
  "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
  "Accept-Encoding" => "gzip,deflate",
  "Accept-Language" => "en-US,en;q=0.8",
  "Cache-Control" => "max-age=0",
  "Connection" => "keep-alive",
  "Content-Length" => "41",
  "Content-Type" => "application/x-www-form-urlencoded",
  "Cookie" => COOKIES,
  "User-Agent" => "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/38.0.2125.104 Safari/537.36"
}

GET_HEADERS = {

  "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
  "Accept-Encoding" => "gzip,deflate,sdch",
  "Accept-Language" => "en-US,en;q=0.8",
  "Cache-Control" => "max-age=0",
  "Cookie" => COOKIES,
  "Referrer" => "https://www.google.com/",
  "User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_1) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/41.0.2272.118 Safari/537.36"
}

def main
  people = people_from_file
  total_matches = 0

  people.each_with_index do |person, i|

    # p name.emails

    url = COC_SEARCH_URL
    url += "?firstName=" + person.fname
    url += "&lastname=" + person.lname
    url += "&department="
    url += "&phoneno="
    url += "&email="
    url += "&Search=Find+Person"
    puts url

    resp = get_GET_reponse(url)

    puts person_details = get_details_from_page(resp, person)
    total_matches += person_details.results.count

    puts "Found #{person_details.results.count} matches. Total matches: #{total_matches}"

  end

  CSV.open(File.join(File.dirname(__FILE__), PEOPLE_CSV_FILENAME), "wb", { force_quotes: true }) do |csv|
   csv << [
     "Name",
     "Email",
     "Department"
   ]

   people.each do |person|

     person.results.each do |result|
       csv << [
         result.name,
         result.email,
         result.department
       ]
     end
   end
 end

end

def get_details_from_page(resp_body, person)

  doc = Nokogiri::HTML(resp_body)
  doc.css(".#{ITEM_CLASS}").each do |item|
    begin
      name = CGI.unescapeHTML(item.css(".#{PERSON_NAME_CLASS}").first.text)
      email = item.css('strong a').first['href']
      email = email[email.index(':')+1, email.length]

      person.results << Result.new(name, email)

    rescue Exception => e
      puts e
      puts "An error occured when parsing a person."
    end
  end
  return person
end

def people_from_file
  people = []
  File.open(File.join(File.dirname(__FILE__), NAME_FILE), "r").each do |line|
    # line.strip
    names = line.strip.split

    people << Person.new(names[0], names[1]) if names.count > 1
  end

  return people
end

class Person
  attr_accessor :fname, :lname, :results

  def initialize(fname, lname)
    @fname = fname
    @lname = lname

    @results = []
  end
end

class Result
  attr_accessor :name, :department, :email
  def initialize(name, email, department = "")
    @name = name
    @email = email
    @department = department

  end
end

def get_POST_reponse(url, form_data)
  uri = URI.parse(url)
  http = Net::HTTP.new(uri.host, uri.port)

  req = Net::HTTP::Post.new(url, POST_HEADERS)
  req.set_form_data(form_data)

  res = nil
  http.start do
    res = http.request(req)
  end

  if res.nil?
    return nil
  else
    return res.body
  end
end

def get_GET_reponse(url)

  res = Net::HTTP.get(URI(url))

  if res.nil?
    return nil
  else

    return res
  end
end

if __FILE__ == $0
  main()
end
