require 'uri'

class SessionController < ApplicationController

  @@openid_url_base  = "http://publiclab.org/people/"
  @@openid_url_suffix = "/identity"


  def show_login
    @referer = params[:back_to]  
  end

  def login_openid
    back_to = params[:back_to]
    open_id = params[:open_id]
    if not open_id or open_id == ""
      failed_login "Open ID not provided!"
      return
    end  
    openid_url = URI.decode(open_id)
    #possibly user is providing the whole URL
    if openid_url.include? "publiclab"
      if openid_url.include? "http"
        url = openid_url
      end
    else 
      url = @@openid_url_base + openid_url + @@openid_url_suffix
    end
    openid_authentication(url, back_to)
  end

#  protected

  def openid_authentication(openid_url, back_to)
    #puts openid_url
    authenticate_with_open_id(openid_url, :required => [:nickname, :email]) do |result, identity_url, registration|
      if result.successful?
        @user = User.find_by_identity_url(identity_url)
        if not @user
          @user = User.new
          @user.username = registration['nickname']
          @user.email = registration['email']
          @user.identity_url = identity_url
          begin 
            @user.save!
          rescue ActiveRecord::RecordInvalid => invalid
            puts invalid
            failed_login "User can not be associated to local account. Probably the account already exists with different case!" 
            return
          end
        end
        nonce = params[:n]
        if nonce 
          tmp = Sitetmp.find_by nonce: nonce
          if tmp 
            data = tmp.attributes
            data.delete("nonce")
            data.delete("id")
            site = Site.new(data)
            site.save
            tmp.destroy
          end
        end
        @current_user = @user
        if site
          if back_to
            successful_login back_to, site.id
          else
            successful_login nil, site.id
          end
        else
          successful_login back_to, nil 
        end
      else
        failed_login result.message
        return false
      end
    end
  end

  def failed_login(message = "Authentication failed.")
    session[:user_id] = nil 
    flash[:danger] = message
    redirect_to '/'
  end

  def successful_login(back_to, id)
    session[:user_id] = @current_user.id
    flash[:success] = "You have successfully logged in."
    if id
      redirect_to '/sites/' + id.to_s + '/upload'
    else
      if back_to 
        redirect_to back_to 
      else
        redirect_to '/sites'
      end
    end
  end

  def logout
    session[:user_id] = nil 
    flash[:success] = "You have successfully logged out."
    redirect_to '/'
  end

end

