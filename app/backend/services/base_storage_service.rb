# Base class for cloud storage services
# Template Method Pattern - defines upload/download workflow
class BaseStorageService
  # Template method - defines the algorithm
  def self.upload_document(filename, content)
    validate_configuration!

    safe_filename = sanitize_filename(filename)
    blob_path = generate_blob_path(safe_filename)

    # Subclass implements actual upload
    upload_blob(blob_path, content)

    {
      blob_url: build_url(blob_path),
      blob_name: blob_path,
      container: container_name,
      provider: provider_name
    }
  end

  def self.delete_document(blob_name)
    validate_configuration!
    delete_blob(blob_name)
  end

  # Generate temporary access URL (SAS token)
  def self.generate_download_url(blob_name, expires_in: 3600)
    validate_configuration!
    create_signed_url(blob_name, expires_in)
  end

  # Abstract methods - must be implemented by subclasses
  def self.upload_blob(blob_path, content)
    raise NotImplementedError, "#{name} must implement upload_blob"
  end

  def self.delete_blob(blob_name)
    raise NotImplementedError, "#{name} must implement delete_blob"
  end

  def self.create_signed_url(blob_name, expires_in)
    raise NotImplementedError, "#{name} must implement create_signed_url"
  end

  def self.provider_name
    raise NotImplementedError, "#{name} must implement provider_name"
  end

  def self.validate_configuration!
    raise NotImplementedError, "#{name} must implement validate_configuration!"
  end

  # Shared helper methods available to all subclasses
  def self.sanitize_filename(filename)
    filename.gsub(/[^a-zA-Z0-9._-]/, '_')
  end

  def self.generate_blob_path(filename)
    "#{Time.now.strftime('%Y/%m/%d')}/#{SecureRandom.uuid}_#{filename}"
  end

  def self.container_name
    ENV['AZURE_STORAGE_CONTAINER'] || ENV['AWS_S3_BUCKET'] || ENV['GCP_BUCKET'] || 'documents'
  end

  def self.build_url(blob_path)
    # Subclasses can override if needed
    "#{base_url}/#{container_name}/#{blob_path}"
  end

  def self.base_url
    raise NotImplementedError, "#{name} must implement base_url"
  end

  # Shared HTTP client setup - all subclasses can use
  def self.https_client(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE if ENV['RACK_ENV'] == 'development'
    http
  end

  # Shared error handling - delegate to subclass for specifics
  def self.handle_upload_error(error)
    raise StandardError, "#{provider_name.upcase} upload failed: #{error.message}"
  end

  # Shared response validation
  def self.validate_response(response, expected_codes)
    code = response.code.to_i
    return true if expected_codes.include?(code)

    raise StandardError, "Upload failed: HTTP #{code} - #{response.body}"
  end
end
