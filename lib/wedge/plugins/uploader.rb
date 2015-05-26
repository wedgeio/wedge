class Wedge
  module Plugins
    class Uploader < Component
      name :uploader, :uploader_plugin

      on :compile do
        settings = Wedge.config.settings[:uploader]
        store[:settings] = settings.select do |k, v|
          client? ? %w(aws_access_key_id bucket).include?(k) : true
        end if settings
      end

      class S3Signature < Struct.new(:policy_data, :settings)
        def policy
          Base64.encode64(policy_data.to_json).gsub("\n", "")
        end

        def signature
          # The presence of the “headers” property in the JSON request alerts your server to the fact that this is a request to sign a REST/multipart request and not a policy document.
          # Your server only needs to return the following in the body of an “application/json” response:
          encode_string = policy_data["headers"].present? ? policy_data["headers"] : policy

          Base64.encode64(
            OpenSSL::HMAC.digest(
              OpenSSL::Digest.new('sha1'),
              settings[:aws_secret_access_key], encode_string
            )
          ).gsub("\n", "")
        end
      end

      def signature policy_data
        s3 = S3Signature.new policy_data, settings

        {
          policy: s3.policy,
          signature: s3.signature
        }.to_json
      end

      def success options = {}
        options      = options.indifferent
        wedge_name   = options.delete :wedge_name
        wedge_method = options.delete :wedge_method

        if wedge_name
          response.headers["Content-Type"] = 'application/json; charset=UTF-8'
          {
            success: true,
            wedge_name: wedge_name,
            wedge_method: wedge_method,
            wedge_response: wedge(wedge_name).to_js(wedge_method, options),
            dom_file_id: options[:dom_file_id]
          }.to_json
        end
      end

      def delete options = {}
        options     = options.indifferent
        wedge_name   = options.delete :wedge_name
        wedge_method = options.delete :delete_method

        if wedge_name
          response.headers["Content-Type"] = 'application/json; charset=UTF-8'
          {
            success: true,
            wedge_name: wedge_name,
            wedge_method: wedge_method,
            wedge_response: wedge(wedge_name).to_js(wedge_method, options)
          }.to_json
        end
      end

      def resume options = {}
        options     = options.indifferent
        wedge_name   = options.delete :wedge_name
        wedge_method = options.delete :resume_method

        if wedge_name
          response.headers["Content-Type"] = 'application/json; charset=UTF-8'
          wedge(wedge_name).send(wedge_method, options)
        end
      end

      def button el, options = {}
        options = { multiple: false }.merge options
        drag_n_drop el, options
      end

      def drag_n_drop el, options = {}
        id            = el.attr 'id'
        container_id  = "#{id}-container"
        template_id   = "#{id}-tmpl"
        key           = options.delete(:aws_name) || '{name}-{uuid}'

        # add s3 container
        el.after drag_n_drop_tmpl template_id, options
        el.after "<div id='#{container_id}'></div>"

        container = dom.find("##{container_id}")

        uploader = el.fine_uploader_dnd({
          classes: {
            dropActive: "cssClassToAddToDropZoneOnEnter"
          }
        })

        uploader.on('processingDroppedFiles') do |event|
          # todo: display some sort of a "processing" or spinner graphic
        end

        uploader.on('processingDroppedFilesComplete') do |event, files, dropTarget|
          # todo: hide spinner/processing graphic
          container.fine_uploader_s3('addFiles', files)
        end

        uploader_settings = {
            objectProperties: {
              key: function { |key_id|
                promise = Native(`new qq.Promise()`)
                @this.setName(key_id, @this.getName(key_id).gsub(/[^0-9A-Za-z_\.\s-]/, '').gsub(/\s{1,}/,'_'));
                uuid = @this.getUuid(key_id).split('-').last
                ext = @this.getName(key_id).split('.').last
                promise.success(key.gsub('{uuid}', uuid).gsub('{name}', @this.getName(key_id)).gsub('{ext}',ext));
                promise.to_n
              }
            },
            request: {
              # // REQUIRED: We are using a custom domain
              # // for our S3 bucket, in this case.  You can
              # // use any valid URL that points to your bucket.
              endpoint: "https://#{settings[:bucket]}.s3.amazonaws.com",
              # // REQUIRED: The AWS public key for the client-side user
              # // we provisioned.
              accessKey: settings[:aws_access_key_id]
            },

            template: template_id,

            # // REQUIRED: Path to our local server where requests
            # // can be signed.
            signature: {
              endpoint: "#{Wedge.assets_url}/wedge/plugins/uploader.call?__wedge_method__=signature&__wedge_args__=__wedge_data__&__wedge_name__=uploader_plugin",
              customHeaders: {'X-CSRF-Token' => Element.find('head > meta[name="_csrf"]').attr('content') }
            },

            # // OPTIONAL: An endopint for Fine Uploader to POST to
            # // after the file has been successfully uploaded.
            # // Server-side, we can declare this upload a failure
            # // if something is wrong with the file.
            uploadSuccess: {
              endpoint: "#{Wedge.assets_url}/wedge/plugins/uploader.call?__wedge_method__=success&__wedge_args__=__wedge_data__&__wedge_name__=uploader_plugin",
              customHeaders: {'X-CSRF-Token' => Element.find('head > meta[name="_csrf"]').attr('content') }
            },

            # // optional feature
            chunking: {
                enabled: true
            },

            # // optional feature
            resume: {
                enabled: true
            },

            # thumbnails: {
            #     placeholders: {
            #         # notAvailablePath: "assets/not_available-generic.png",
            #         # waitingPath: "assets/waiting-generic.png"
            #     }
            # },

            callbacks: {
              onSubmitted: function { |fu_id|
                params             = options
                button             = Native(@this._buttons[0])
                el                 = Element.find(button.getInput).closest('.s3-uploader');
                params[:dom_id]      = el.attr('id')
                params[:dom_file_id] = fu_id

                if `qq.supportedFeatures.canDetermineSize`
                  size = @this.getSize(fu_id)
                  params[:size] = size
                end

                @this.setUploadSuccessParams(params, fu_id)
              }
            }
        }

        if resize = options[:resize]
          uploader_settings[:scaling] = {
            sendOriginal: false,
            sizes: [
              { name: "#{resize}", maxSize: resize }
            ]
          }
        end

        if options[:delete_method]
          uploader_settings[:deleteFile] = {
            enabled: true,
            forceConfirm: true,
            endpoint: "#{Wedge.assets_url}/wedge/plugins/uploader.call?__wedge_method__=delete&__wedge_args__=__wedge_data__&__wedge_name__=uploader_plugin",
            params: options,
            customHeaders: {
              'X-CSRF-Token' => Element.find('head > meta[name="_csrf"]').attr('content'),
              'Accept' => '*/*;q=0.5, text/javascript, application/javascript, application/ecmascript, application/x-ecmascript'
            }
          }
        end

        if options[:accept_files]
          uploader_settings[:validation] = {
            acceptFiles: options[:accept_files]
          }
        end

        if options[:resume_method]
          uploader_settings[:session] = {
            endpoint: "#{Wedge.assets_url}/wedge/plugins/uploader.call?__wedge_method__=resume&__wedge_args__=__wedge_data__&__wedge_name__=uploader_plugin",
            # endpoint: "#{Wedge.assets_url}/app/components/#{options[:wedge_name]}.call?wedge_method=#{options[:resume_method]}&wedge_method_args=wedge_data&wedge_name=registration",
            params: options
          }
        end
        if !options[:multiple].nil?
          uploader_settings[:multiple] = options.delete(:multiple)
        end
        fine_uploader = container.fine_uploader_s3(uploader_settings)

        fine_uploader.on('complete') do |event, _, name, response|
          return unless response

          name          = `response.wedge_name`
          dom_file_id   = `response.dom_file_id`
          method_called = `response.wedge_method`
          # fix: we should be able to get the object better than this
          data          = JSON.parse(`JSON.stringify(response.wedge_response)`)

          wedge(name).send(method_called, data)

          dom.find(".qq-file-id-#{dom_file_id}").remove unless options[:preserve_upload]
        end
      end

      def drag_n_drop_tmpl id, options = {}
        <<-EOF
        <script type="text/template" id="#{id}">
          <div class="qq-uploader-selector qq-uploader">
            <div class="qq-upload-button-selector qq-upload-button">
              <div>#{options.delete(:button_name) || 'Upload a file'}</div>
            </div>
            <div class="qq-upload-drop-area-selector qq-upload-drop-area" qq-hide-dropzone>
                <span>Drop file here to upload</span> </div>
            <span class="qq-drop-processing-selector qq-drop-processing">
              <span>Processing dropped files...</span>
              <span class="qq-drop-processing-spinner-selector qq-drop-processing-spinner"></span>
            </span>
              <ul class="qq-upload-list-selector qq-upload-list">
                  <li>
                      <div class="qq-progress-bar-container-selector">
                          <div class="qq-progress-bar-selector qq-progress-bar"></div>
                      </div>
                      <span class="qq-upload-spinner-selector qq-upload-spinner"></span>
                      <img class="qq-thumbnail-selector" qq-max-size="100" qq-server-scale>
                      <span class="qq-edit-filename-icon-selector qq-edit-filename-icon"></span>
                      <span class="qq-upload-file-selector qq-upload-file"></span>
                      <input class="qq-edit-filename-selector qq-edit-filename" tabindex="0" type="text">
                      <span class="qq-upload-size-selector qq-upload-size"></span>
                      <a class="qq-upload-cancel-selector btn-small btn-warning" href="#">Cancel</a>
                      <a class="qq-upload-retry-selector btn-small btn-info" href="#">Retry</a>
                      <a class="qq-upload-delete-selector btn-small btn-warning" href="#">Delete</a>
                      <a class="qq-upload-pause-selector btn-small btn-info" href="#">Pause</a>
                      <a class="qq-upload-continue-selector btn-small btn-info" href="#">Continue</a>
                      <span class="qq-upload-status-text-selector qq-upload-status-text"></span>
                      <a class="view-btn btn-small btn-info hide" target="_blank">View</a>
                  </li>
              </ul>
          </div>
        </script>
        EOF
      end

      def settings
        @settings ||= store[:settings]
      end
    end
  end
end

if RUBY_ENGINE == 'opal'
  class Element
    alias_native :fine_uploader, :fineUploader

    def fine_uploader_dnd options = {}
      options = options.to_n
      `self.fineUploaderDnd(options)`
    end

    def fine_uploader_s3 type, options = false
      if !options
        options = type.to_n
        `self.fineUploaderS3(options)`
      else
        `self.fineUploaderS3(type, options)`
      end
    end
  end
end
