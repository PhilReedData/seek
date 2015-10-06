module Seek
  module ContentBlobCommon
    include Seek::UploadHandling::ContentInspection

    def redirect_on_error asset,msg=nil
      flash[:error]=msg if !msg.nil?
      if (asset.class.name.include?("::Version"))
        redirect_to asset.parent,:version=>asset.version
      else
        redirect_to asset
      end
    end

    def handle_download disposition='attachment', image_size=nil
      if @content_blob.url.blank?
        if @content_blob.file_exists?
          if image_size && @content_blob.is_image?
            @content_blob.copy_image
            @content_blob.resize_image(image_size)
            filepath = @content_blob.full_cache_path(image_size)
            headers["Content-Length"]=File.size(filepath).to_s
          else
            filepath = @content_blob.filepath
            #added for the benefit of the tests after rails3 upgrade - but doubt it is required
            headers["Content-Length"]=@content_blob.filesize.to_s
          end
          send_file filepath, :filename => @content_blob.original_filename, :type => @content_blob.content_type || "application/octet-stream", :disposition => disposition
        else
          redirect_on_error @asset_version,"Unable to find a copy of the file for download, or an alternative location. Please contact an administrator of #{Seek::Config.application_name}."
        end
      else
        begin
          if @asset_version.contributor.nil? #A jerm generated resource
            download_jerm_asset
          else
            stream_from_url
          end
        rescue Seek::DownloadException=>de
          redirect_on_error @asset_version,"There was an error accessing the remote resource, and a local copy was not available. Please try again later when the remote resource may be available again."
        rescue Jerm::JermException=>de
          redirect_on_error @asset_version,de.message
        end

      end
    end

    def return_file_or_redirect_to redirected_url=nil, error_message = nil
      if @content_blob.file_exists?
        send_file @content_blob.filepath, :filename => @content_blob.original_filename, :type => @content_blob.content_type, :disposition => 'attachment'
      else
        flash[:error]= error_message if error_message
        redirect_to redirected_url
      end
    end

    def download_jerm_asset
      project = @asset_version.projects.first
      project.decrypt_credentials
      downloader=Jerm::DownloaderFactory.create project.title
      resource_type = @asset_version.class.name.split("::")[0] #need to handle versions, e.g. Sop::Version
      begin
        data_hash = downloader.get_remote_data @content_blob.url,project.site_username,project.site_password, resource_type
        send_file data_hash[:data_tmp_path], :filename => data_hash[:filename] || @content_blob.original_filename, :type => data_hash[:content_type] || @content_blob.content_type, :disposition => 'attachment'
      rescue Seek::DownloadException,Jerm::JermException=>de

        puts "Unable to fetch from remote: #{de.message}"
        if @content_blob.file_exists?
          send_file @content_blob.filepath, :filename => @content_blob.original_filename, :type => @content_blob.content_type, :disposition => 'attachment'
        else
          raise de
        end
      end
    end

    def stream_from_url
      code = url_response_code(@content_blob.url).to_i
      case code
      when 200
        self.response.headers["Content-Type"] ||= @content_blob.content_type
        self.response.headers["Content-Disposition"] = "attachment; filename=#{@content_blob.original_filename}"
        self.response.headers['Last-Modified'] = Time.now.ctime.to_s
        uri = URI(@content_blob.url)

        begin
          self.response_body = Enumerator.new do |yielder|
            Net::HTTP.start(uri.host, uri.port) do |http|
              http.request(Net::HTTP::Get.new(uri)) do |res|
                res.read_body do |chunk|
                  yielder << chunk # yield chunk
                end
              end
            end
          end
        rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, EOFError,
            Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
          error_message = "There is a problem downloading this file. #{e}"
          redirected_url = polymorphic_path(@asset_version.parent,{:version=>@asset_version.version})
          return_file_or_redirect_to redirected_url, error_message
        end
      when 301, 302, 401, 403
        return_file_or_redirect_to @content_blob.url
      when 404
        error_message = "This item is referenced at a remote location, which is currently unavailable"
        redirected_url = polymorphic_path(@asset_version.parent,{:version=>@asset_version.version})
        return_file_or_redirect_to redirected_url, error_message
      else
        error_message = "There is a problem downloading this file."
        redirected_url = polymorphic_path(@asset_version.parent,{:version=>@asset_version.version})
        return_file_or_redirect_to redirected_url, error_message
      end
    end
  end
end
