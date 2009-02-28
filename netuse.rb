=begin
###############################################################################################
  *TODO* :                                                                                     
-----------------------------------------------------------------------------------------------
  # -Faire un modele Forfait pour stocker les donnees sur les forfaits                         
  -Faire la validation des champs pour signup et login                                       
    -valider que le nom d'utilisateur Videotron est fonctionnel                              
  -dans /cronjob/xxxx, faire que ca reset les issent a 0 si on est dans le debut de leur mois
  # -Pour le modele User,                                                                      
    # -Ajouter un champ forfait_id                                                             
    # -Faire des champs:                                                                       
    #   issent_neardownload,                                                                   
    #   issent_busteddownload,                                                                 
    #   issent_nearupload,                                                                     
    #   issent_busteddownload                                                                  
  -faire un cron-job pour appeller l'action /cronjob/:code (en dev et en prod) a chaque 6 am
  -pour les liens dans les fichiers erb, faire qu'ils soient independants du nom de domaine
  
  Phase 2:
  -faire un video pour expliquer le but de l'affaire, mettre ca dans l'accueil
  -fil RSS
  -Widget Netvibes
  -Widget Dashboard
  -Application web pour iPhone (version alternative des vues)
###############################################################################################
=end

require 'rubygems'
require 'sinatra'
require 'hpricot'
require 'open-uri'  # to open the url of the videotron page
require 'openssl'
require 'pony'      # pour envoi de mail aux users
# auth-specific :
require 'dm-core'
require 'dm-timestamps'
require 'dm-validations'
require Pathname(__FILE__).dirname.expand_path + "models/user" # model user
require Pathname(__FILE__).dirname.expand_path + "models/forfait" # model forfait
DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/db/users.db")
DataMapper.auto_upgrade!
use Rack::Session::Cookie, :secret => 't0Uche ce d0Ux p0Ulet'
# /auth-specific

# because we crawl an https page :
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

get '/' do
  erb :index, :locals => { :forfaits => getforfaits(), :user => session[:user]}
end

get '/getusage/:userid' do
  getdownload(params[:userid].strip)
end

get '/cronjob/:code' do
  # faire SEULEMENT si on recois ce parametre secret :
  if params[:code]=='fliptop777flipotap444supurtade'
    users = User.all(:issent=>0) # on va chercher tout les users qui ont le flag issent a 0
    users.each do |user|
      # aller chercher le upload et le download dans la page (scrapping) :
      @uploads = getupload(user.videotron)
      @downloads = getdownload(user.videotron)
      # si il est sur le point de depasser la limite :
      if (@uploads.to_f+user.margelimiteamont.to_f)>user.maxupload.to_f || (@downloads.to_f+user.margelimiteaval.to_f)>user.maxdownload.to_f
        Pony.mail(:to => user.email, :from => 'CombienJeTelecharge.com <noreply@combienjetelecharge.com>', :subject => 'Vous êtes sur le point de dépasser votre limite', :body => $surlepointaval) # envoyer un email
        # setter issent a 1 :
        user.issent = 1
        user.save!
      end
    end
    erb :cron, :locals=>{:users=>users}
  end
end

get '/test' do
  erb :test, :locals=>{:forfaits=>Forfait.all()}
end

post '/getusage' do
  doc = open("https://www.videotron.com/services/secur/ConsommationInternet.do?compteInternet=#{params[:userid]}") { |f| Hpricot(f) }
# try...
  tableau = doc.search("//table[@class='data']")
  tbody = tableau.at("tbody")
  firsttr = tbody.at("tr:nth(0)")
  recu_go = firsttr.at("td:nth(3)")
  erb :result, :locals => {:download => recu_go.inner_html, :forfait => getforfaits()[params[:forfait]]['name'], :maxaval =>getforfaits()[params[:forfait]]['aval']}
end

# Auth actions :
get '/logged_in' do
  if session[:user]
    "true"
  else
    "false"
  end
end

get '/profile' do
  if session[:user]
    @user = User.first(:id=>session[:user])
    @forfait = Forfait.first(:id=>@user.forfait_id)
    @videotron = @user.videotron
    @email = @user.email
    # @mdownload = @user.maxdownload
    # @mupload = @user.maxupload
    @jourfin = @user.jourfin
    @downloads = getdownload(@user.videotron)
    @uploads = getupload(@user.videotron)
    erb :profile, :locals => {
        :id=>@user.id, 
        :downloads => @downloads,
        :uploads => @uploads, 
        :videotron => @videotron, 
        :email => @email, 
        :mdownload=>@forfait.aval, 
        :mupload=>@forfait.amont, 
        :jourfin=>@jourfin
    }
  else
    redirect '/login'
  end
end

get '/login' do
  erb :login
end

post '/login' do
    if user = User.authenticate(params[:email], params[:password])
      session[:user] = user.id
      redirect_to_stored
    else
      redirect '/login'
    end
end

get '/logout' do
  session[:user] = nil
  @message = "in case it weren't obvious, you've logged out"
  redirect '/'
end

get '/signup' do
  erb :signup, :locals => {:forfaits => getforfaits() }
end

post '/signup' do
  # usage starts the 30\n
  forfaits = getforfaits()
  doc = open("https://www.videotron.com/services/secur/ConsommationInternet.do?compteInternet=#{params[:videotron]}") { |f| Hpricot(f) }
  match = doc.to_s[/usage starts the (\d{1,2})/]
  jourfin = match[$1].to_i
  margelimiteaval = (forfaits[params[:forfait]]['aval']).to_f / 100 * 20
  margelimiteamont = (forfaits[params[:forfait]]['amont']).to_f / 100 * 20
  @user = User.new(:email => params[:email].strip, 
                  :videotron => params[:videotron].strip.upcase, 
                  :jourfin => jourfin, 
                  :forfait_id => params[:forfait].to_i,
                  :password => params[:password].strip, 
                  :password_confirmation => params[:password_confirmation].strip, 
                  :margelimiteaval => margelimiteaval, 
                  :margelimiteamont => margelimiteamont, 
                  :issent_neardownload => 0,
                  :issent_busteddownload => 0,
                  :issent_nearupload => 0,
                  :issent_busteddownload => 0)
  if @user.save
    session[:user] = @user.id
    redirect '/profile'
  else
    session[:flash] = "failure!"
    redirect '/'
  end
end

# pour les users qui veulent en finir avec leur compte :
delete '/user/:id' do
  if session[:user] == params[:id].to_i
    session[:user] = nil
    @user = User.first(:id=>params[:id].to_s)
    @user.destroy
    session[:flash] = "Vous avez supprim&eacute; votre compte!<br/>&Agrave; la prochaine!"
    redirect '/'
  end
end

# function to include files in erb templates :
def include(filename)
  all_doc = []
  File.open(filename) do |file|
    while line = file.gets
      all_doc.push(line)
    end
  end
  all_doc.join("")
end

private

def getforfaits
  forfaits = Hash.new
  Forfait.all.each do |forfait|
    forfaits[forfait.id.to_s] = {
      'id'=>forfait.id,
      'name'=>forfait.name,
      'aval'=>forfait.aval,
      'amont'=>forfait.amont
    }
  end
  forfaits.sort.to_hash
end

def getdocument(videotronid)
  now = Time.now()
  document=''
  # le fichier existe?
  if File.exist?('cache/'+videotronid)
    lastwrite = File.ctime('cache/'+videotronid)
    # le fichier est plus ancien qu'aujourd'hui?
    if lastwrite.day >= now.day
      document = readfile('cache/'+videotronid)
    else
      document = writetofile(videotronid)
    end
  else
    # le fichier n'existe pas ?
    document = writetofile(videotronid)
  end
  return document
end

def readfile(filename)
  all_doc = []
  File.open(filename) do |file|
    while line = file.gets
      all_doc.push(line)
    end
  end
  doc = all_doc.join("")
  Hpricot(doc)
end

def writetofile(videotronid)
  url = "https://www.videotron.com/services/secur/ConsommationInternet.do?compteInternet=#{videotronid}"
  doc = open(url) { |f| Hpricot(f) }
  outputfile = 'cache/'+videotronid # nom du fichier a generer 
  fout = File.open(outputfile, "w")
  fout.puts doc
  fout.close
  return doc
end

def getdownload(videotronid)
  doc = getdocument(videotronid)
  tableau = doc.search("//table[@class='data']")
  tbody = tableau.at("tbody")
  firsttr = tbody.at("tr:nth(0)")
  recu_go = firsttr.at("td:nth(3)")
  recu_go.inner_html
end

def getupload(videotronid)
  doc = getdocument(videotronid)
  tableau = doc.search("//table[@class='data']")
  tbody = tableau.at("tbody")
  firsttr = tbody.at("tr:nth(0)")
  recu_go = firsttr.at("td:nth(5)")
  recu_go.inner_html
end

def login_required
  if session[:user]
    return true
  else
    session[:return_to] = request.fullpath
    redirect '/login'
    return false 
  end
end

def current_user
  User.first(session[:user])
end

def redirect_to_stored
  if return_to = session[:return_to]
    session[:return_to] = nil
    redirect return_to
  else
    redirect '/profile'
  end
end


# forfaits :
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
# /forfaits 

# copy :
$surlepointaval = "Vous êtes sur le point de dépasser votre limite de téléchargement (aval).\nPour plus d'informations, veuillez consulter votre profil sur http://combienjetelecharge.com .\n\nSVP ne pas répondre à ce courriel."
$depassementaval = "Vous avez dépassé votre limite de téléchargement (aval).\nPour plus d'informations, veuillez consulter votre profil sur http://combienjetelecharge.com .\n\nSVP ne pas répondre à ce courriel."
$surlepointamont = "Vous êtes sur le point de dépasser votre limite de téléversement (amont).\nPour plus d'informations, veuillez consulter votre profil sur http://combienjetelecharge.com .\n\nSVP ne pas répondre à ce courriel."
$depassementamont = "Vous avez dépassé votre limite de téléversement (amont).\nPour plus d'informations, veuillez consulter votre profil sur http://combienjetelecharge.com .\n\nSVP ne pas répondre à ce courriel."

# "Vous êtes sur le point de dépasser votre limite de téléchargement (aval) et il vous reste #{jours} jours avant la fin de votre mois de facturation.\nPour plus d'informations, veuillez consulter votre profil sur http://combienjetelecharge.com .\n\nSVP ne pas répondre à ce courriel."

