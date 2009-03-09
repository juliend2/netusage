=begin
###############################################################################################
  *TODO* :
-----------------------------------------------------------------------------------------------
  -Faire la validation des champs pour signup et login
  
  Phase 2:
  -mettre un widget Feedback pour que les gens laissent du feedback 
  -mettre un widget ShareThis
  -mettre des termes d'utilisation et une politique de confidentialite
  -enregistrer toutes les donnees dans la db pour avoir un historique complet pour chaque utilisateur
  -faire un video pour expliquer le but de l'affaire, mettre ca dans l'accueil
  -fil RSS
  -Widget Netvibes
  -Widget Dashboard
  -Application web pour iPhone (version alternative des vues)
  -Rendre la methode cron discrete pour ne pas abuser du serveur si ya beaucoup d'utilisateurs
  -"Vous êtes sur le point de dépasser votre limite de téléchargement (aval) et il vous reste #{jours} jours avant la fin de votre mois de facturation.\nPour plus d'informations, veuillez consulter votre profil sur http://combienjetelecharge.com .\n\nSVP ne pas répondre à ce courriel."
  -mettre graphique dans le profil et afficher les downloads pour chaque jours
###############################################################################################
=end

# Include gems :
require 'rubygems'
require 'sinatra'
require 'activesupport' # pour la gestion des dates avancees
require 'hpricot'       # pour scrapper les infos dans le html
require 'open-uri'      # to open the url of the videotron page
require 'openssl'       # parce quon scrap les infos sur une page https
require 'pony'          # pour envoi de mail aux users
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

configure :development do
  set :public, File.dirname(__FILE__) + '/public'
end

configure :development do
  set :base, ''
end
configure :production do
  set :base, Pathname(__FILE__).dirname.expand_path.to_s+'/../cache/'
end
# access through : options.base

# ---------------Actions : -----------------
get '/' do
  erb :index, :locals => { :forfaits => getforfaits(), :user => session[:user], :errors=>[]}
end

get '/getusage/:userid' do
  getdownload(params[:userid].strip)
end

get '/cronjob/:code' do
  # faire SEULEMENT si on recois ce parametre secret :
  if params[:code]=='fliptop777flipotap444supurtade'
    users = User.all() # on va chercher tout les users qui ont le flag issent a 0
    users.each do |user|
      @forfait = Forfait.first(:id=>user.forfait_id)
      # aller chercher le upload et le download dans la page (scrapping) :
      @uploads = getupload(user.videotron, true)
      @downloads = getdownload(user.videotron, true)
      
      # Si le user a pas un download ILLIMITE :
      if user.margelimiteaval.to_i > 0
        # NOTIFICATION :
        # download :
        if (@downloads.to_f+user.margelimiteaval.to_f)>@forfait.aval.to_f
          Pony.mail(:to => user.email, :from => 'CombienJeTelecharge.com <noreply@combienjetelecharge.com>', :subject => 'Vous êtes sur le point de dépasser votre limite de téléchargement', :body => $surlepointaval) # envoyer un email
          user.issent_neardownload = 1
          user.save!
        end
        if (@downloads.to_f)>@forfait.aval.to_f
          Pony.mail(:to => user.email, :from => 'CombienJeTelecharge.com <noreply@combienjetelecharge.com>', :subject => 'Attention, Vous avez dépassé votre limite de téléchargement', :body => $depassementaval) # envoyer un email
          user.issent_busteddownload = 1
          user.save!
        end
      end

      # Si le user a pas un upload ILLIMITE :
      if user.margelimiteamont.to_i > 0
        # upload :
        if (@uploads.to_f+user.margelimiteamont.to_f)>@forfait.amont.to_f
          Pony.mail(:to => user.email, :from => 'CombienJeTelecharge.com <noreply@combienjetelecharge.com>', :subject => 'Vous êtes sur le point de dépasser votre limite de téléversement', :body => $surlepointamont) # envoyer un email
          user.issent_nearupload = 1
          user.save!
        end
        if (@uploads.to_f)>@forfait.amont.to_f
          Pony.mail(:to => user.email, :from => 'CombienJeTelecharge.com <noreply@combienjetelecharge.com>', :subject => 'Attention, Vous avez dépassé votre limite de téléversement', :body => $depassementamont) # envoyer un email
          user.issent_bustedupload = 1
          user.save!
        end
      end

      # RESET FLAG DE NOTIFICATION :
      if is_day_after_end_of_month(user.jourdebut.to_i)
        user.issent_bustedupload = 0
        user.issent_nearupload = 0
        user.issent_busteddownload = 0
        user.issent_neardownload = 0
        user.save!
      end
      
    end
    erb :cron, :locals=>{:users=>users}
  end
end

get '/test' do
  # test case
  # retour= writetofile('VLISKLCE')
  erb :test, :locals=>{:valeur=>Pathname(__FILE__).dirname.expand_path.to_s+'/../cache'}
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
    @jourdebut = @user.jourdebut
    @downloads = getdownload(@user.videotron)
    @uploads = getupload(@user.videotron)
    erb :profile, :locals => {
        :id=>@user.id, 
        :downloads => @downloads,
        :uploads => @uploads, 
        :videotron => @videotron, 
        :email => @email, 
        :mdownload=> @forfait.aval, 
        :mupload=>@forfait.amont, 
        :jourdebut=>@jourdebut,
        :isdayafterendofmonth => is_day_after_end_of_month(@jourdebut.to_i)
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

post '/signup' do
  # usage starts the 30\n
  forfaits = getforfaits()
  doc = open("https://www.videotron.com/services/secur/ConsommationInternet.do?compteInternet=#{params[:videotron]}") { |f| Hpricot(f) }
  match = doc.to_s[/usage starts the (\d{1,2})/]
  begin
    jourdebut = match[$1].to_i
  rescue
    errors = ["Le num&eacute;ro d'utilisateur Videotron que vous avez entr&eacute; n'est pas valide. Veuillez v&eacute;rifier qu'il est bien &eacute;crit."]
  end
  margelimiteaval = (forfaits[params[:forfait]]['aval']).to_f / 100 * 20
  margelimiteamont = (forfaits[params[:forfait]]['amont']).to_f / 100 * 20
  @user = User.new(:email => params[:email].strip, 
                  :videotron => params[:videotron].strip.upcase, 
                  :jourdebut => jourdebut, 
                  :forfait_id => params[:forfait].to_i,
                  :password => params[:password].strip, 
                  # :password_confirmation => params[:password_confirmation].strip, 
                  :margelimiteaval => margelimiteaval, 
                  :margelimiteamont => margelimiteamont, 
                  :issent_neardownload => 0,
                  :issent_busteddownload => 0,
                  :issent_nearupload => 0,
                  :issent_bustedupload => 0)
  if errors 
    erb :index, :locals => {:forfaits => getforfaits(), :errors=> errors, :user => session[:user]}
  else
    if @user.save
      session[:user] = @user.id
      redirect '/profile'
    else
      session[:flash] = "failure!"
      redirect '/'
    end
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

# ---------------File managing : -----------------
def getdocument(videotronid, refreshfile=false)
  now = Time.now()
  document=''
  # Si on ne rafraichis pas le fichier par defaut, on le lis ou on le cree :
  if not refreshfile
    # le fichier existe?
    if File.exist?(options.base.to_s+'cache/'+videotronid)
      lastwrite = File.ctime(options.base.to_s+'cache/'+videotronid)
      # le fichier est plus ancien qu'aujourd'hui?
      if lastwrite.day >= now.day
        document = readfile(options.base.to_s+'cache/'+videotronid)
      else
        document = writetofile(videotronid)
      end
    else
      # le fichier n'existe pas ?
      document = writetofile(videotronid)
    end
  else
    # IF refreshfile is set to true... Refresh it!
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
  outputfile = options.base.to_s+'cache/'+videotronid # nom du fichier a generer 
  fout = File.open(outputfile, "w")
  fout.puts doc
  fout.close
  return doc
end

def getdownload(videotronid, refreshfile=false)
  doc = getdocument(videotronid, refreshfile)
  tableau = doc.search("//table[@class='data']")
  tbody = tableau.at("tbody")
  firsttr = tbody.at("tr:nth(0)")
  recu_go = firsttr.at("td:nth(3)")
  recu_go.inner_html
end

def getupload(videotronid, refreshfile=false)
  doc = getdocument(videotronid, refreshfile)
  tableau = doc.search("//table[@class='data']")
  tbody = tableau.at("tbody")
  firsttr = tbody.at("tr:nth(0)")
  recu_go = firsttr.at("td:nth(5)")
  recu_go.inner_html
end

# ---------------Time managing : -----------------
def days_in(yearnum,monthnum)
 Date.civil(yearnum,monthnum,-1).day
end

def is_day_after_end_of_month(end_of_month_day)
  hier = 1.days.ago.day.to_i  
  nbjoursdansmois = days_in(1.days.ago.year,1.days.ago.month)
  
  if end_of_month_day > nbjoursdansmois
    if hier == nbjoursdansmois
      true
    else
      false
    end
  else
    if hier == end_of_month_day
      true
    else
      false
    end
  end
end

# ---------------Auth : -----------------
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



# ---------------Copy : -----------------
$surlepointaval = "Vous êtes sur le point de dépasser votre limite de téléchargement (aval).\nPour plus d'informations, veuillez consulter votre profil sur http://combienjetelecharge.com .\n\nSVP ne pas répondre à ce courriel."
$depassementaval = "Vous avez dépassé votre limite de téléchargement (aval).\nPour plus d'informations, veuillez consulter votre profil sur http://combienjetelecharge.com .\n\nSVP ne pas répondre à ce courriel."
$surlepointamont = "Vous êtes sur le point de dépasser votre limite de téléversement (amont).\nPour plus d'informations, veuillez consulter votre profil sur http://combienjetelecharge.com .\n\nSVP ne pas répondre à ce courriel."
$depassementamont = "Vous avez dépassé votre limite de téléversement (amont).\nPour plus d'informations, veuillez consulter votre profil sur http://combienjetelecharge.com .\n\nSVP ne pas répondre à ce courriel."

# "Vous êtes sur le point de dépasser votre limite de téléchargement (aval) et il vous reste #{jours} jours avant la fin de votre mois de facturation.\nPour plus d'informations, veuillez consulter votre profil sur http://combienjetelecharge.com .\n\nSVP ne pas répondre à ce courriel."

