require 'rubygems'
require 'sinatra'
require 'hpricot'
require 'open-uri'  # to open the url of the videotron page
require 'openssl'
# auth-specific :
require 'dm-core'
require 'dm-timestamps'
require 'dm-validations'
require Pathname(__FILE__).dirname.expand_path + "models/user"
require 'pony'      # pour envoi de mail aux users

DataMapper.setup(:default, "sqlite3://#{Dir.pwd}/db/users.db")
DataMapper.auto_upgrade!

use Rack::Session::Cookie, :secret => 'A1 sauce 1s so good you should use 1t on a11 yr st34ksssss'
# /auth-specific

# because we crawl a https page :
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE

get '/' do
  erb :index, :locals => { :forfaits => $hashforfaits }
end

get '/getusage/:userid' do
  getdownload(params[:userid])    
end

get '/cronjob/:code' do
  # faire SEULEMENT si on recois ce parametre secret :
  if params[:code]=='fliptop777flipotap444supurtade'
    users = User.all(:issent=>0)
    users.each do |user|
      # aller chercher le upload et le download dans la page (scrapping) :
      @uploads = getupload(user.videotron)
      @downloads = getdownload(user.videotron)
      # si il est sur le point de depasser la limite :
      if (@uploads.to_f+user.margelimiteamont.to_f)>user.maxupload.to_f || (@downloads.to_f+user.margelimiteaval.to_f)>user.maxdownload.to_f
        Pony.mail(:to => user.email, :from => 'noreply@combienjetelecharge.com', :subject => 'Vous êtes sur le point de dépasser votre limite', :body => $surlepoint)
      end
    end
    
    # erb :cron, :locals=>{:users=>users}
    
    # on va chercher tout les users qui ont le flag issent a 0
    # for each user :
      # aller chercher le upload et le download dans la page (scrapping)
      # if (upload+margelimiteamont)>maxupload || (download+margelimiteaval)>maxdownload :
        # envoyer un email
        # setter issent a 1
  end
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
    @videotron = @user.videotron
    @email = @user.email
    @mdownload = @user.maxdownload
    @mupload = @user.maxupload
    @jourfin = @user.jourfin
    erb :profile, :locals => {:id=>@user.id, :videotron => @videotron, :email => @email, :mdownload=>@mdownload, :mupload=>@mupload, :jourfin=>@jourfin}
  else
    'You need to log in to see your profile.'
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
  erb :signup, :locals => {:forfaits => $hashforfaits }
end

post '/signup' do
  # usage starts the 30\n
  doc = open("https://www.videotron.com/services/secur/ConsommationInternet.do?compteInternet=#{params[:videotron]}") { |f| Hpricot(f) }
  match = doc.to_s[/usage starts the (\d{1,2})/]
  jourfin = match[$1].to_i
  margelimiteaval = ($hashforfaits[params[:forfait]]['aval']).to_f / 100 * 10
  margelimiteamont = ($hashforfaits[params[:forfait]]['amont']).to_f / 100 * 10
  @user = User.new(:email => params[:email], :videotron => params[:videotron], :jourfin => jourfin, :maxdownload=>$hashforfaits[params[:forfait]]['aval'], :maxupload=>$hashforfaits[params[:forfait]]['amont'], :password => params[:password], :password_confirmation => params[:password_confirmation], :margelimiteaval => margelimiteaval, :margelimiteamont => margelimiteamont, :issent=>0)
  if @user.save
    session[:user] = @user.id
    redirect '/'
  else
    session[:flash] = "failure!"
    redirect '/'
  end
end

# delete '/user/:id' do
#   user = User.first(params[:id])
#   user.delete
#   session[:flash] = "way to go, you deleted a user"
#   redirect '/'
# end

private

def getdocument(videotronid)
  doc = open("https://www.videotron.com/services/secur/ConsommationInternet.do?compteInternet=#{videotronid}") { |f| Hpricot(f) }
end

def getdownload(videotronid)
  doc = getdocument(videotronid)
# try...
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
    redirect '/'
  end
end
# /Auth actions 

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
$surlepoint = "Vous êtes sur le point de dépasser votre limite de téléchargement.\nPour plus d'informations, veuillez consulter votre profil sur http://combienjetelecharge.com .\n\nVeuillez SVP ne pas répondre à ce courriel"