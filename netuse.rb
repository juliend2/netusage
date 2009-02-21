require 'rubygems'
require 'sinatra'
require 'hpricot'
require 'open-uri' # to open the url of the videotron page
require 'openssl'
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

get '/' do

  erb :index, :locals => { :forfaits => $hashforfaits }
end

get '/getusage/:userid' do
  
  doc = open("https://www.videotron.com/services/secur/ConsommationInternet.do?compteInternet=#{params[:userid]}") { |f| Hpricot(f) }
# try...
  tableau = doc.search("//table[@class='data']")
  tbody = tableau.at("tbody")
  firsttr = tbody.at("tr:nth(0)")
  recu_go = firsttr.at("td:nth(3)")
  recu_go.inner_html
end

post '/getusage' do
  doc = open("https://www.videotron.com/services/secur/ConsommationInternet.do?compteInternet=#{params[:userid]}") { |f| Hpricot(f) }
# try...
  tableau = doc.search("//table[@class='data']")
  tbody = tableau.at("tbody")
  firsttr = tbody.at("tr:nth(0)")
  recu_go = firsttr.at("td:nth(3)")
  erb :result, :locals => {:download => recu_go.inner_html, :forfait => $hashforfaits[params[:forfait]]['name'], :maxaval =>$hashforfaits[params[:forfait]]['aval']}
end

$hashforfaits = {
  "intermediaire" => {
    "name" => 'Internet Intermédiaire',
    "aval" => 2,
    "amont" => 2
  },
  "hautevitesse" => {
    "name" => 'Internet haute vitesse',
    "aval" => 20,
    "amont" => 10
  },
  "hautevitesseextreme" => {
    "name" => 'Internet haute vitesse Extrême',
    "aval" => 100,
    "amont" => 100
  },
  "hautevitesseextremeplus" => {
    "name" => 'Internet haute vitesse Extrême Plus',
    "aval" => 20,
    "amont" => 10
  },
  "tgv30" => {
    "name" => 'Internet TGV 30',
    "aval" => 70,
    "amont" => 70
  },
  "tgv50" => {
    "name" => 'Internet TGV 50',
    "aval" => 100,
    "amont" => 100
  },
  "intermediaireaffaire" => {
    "name" => 'Internet Intermédiaire Affaires',
    "aval" => 0,
    "amont" => 0
  },
  "hautevitesseaffaire" => {
    "name" => 'Internet haute vitesse Affaires',
    "aval" => 0,
    "amont" => 0
  },
  "hautevitesseextremeaffaire" => {
    "name" => 'Internet haute vitesse Extrême Affaires',
    "aval" => 0,
    "amont" => 0
  },
  "tgv30affaire" => {
    "name" => 'Internet TGV 30 Affaires',
    "aval" => 100,
    "amont" => 100
  },
  "tgv50affaire" => {
    "name" => 'Internet TGV 50 Affaires',
    "aval" => 100,
    "amont" => 100
  }
}