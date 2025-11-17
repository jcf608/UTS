require 'securerandom'
require 'net/http'
require 'uri'
require 'base64'
require 'openssl'
require 'time'
require 'cgi'

class AzureStorageService
  def self.upload_document(filename, content)
    # Parse connection string manually
    conn_string = ENV['AZURE_STORAGE_CONNECTION_STRING']
    account_name = conn_string[/AccountName=([^;]+)/, 1]
    account_key = conn_string[/AccountKey=([^;]+)/, 1]

    container_name = ENV['AZURE_STORAGE_CONTAINER'] || 'documents'
    # URL-encode filename to handle spaces and special characters
    safe_filename = filename.gsub(/[^a-zA-Z0-9._-]/, '_')
    blob_name = "#{Time.now.strftime('%Y/%m/%d')}/#{SecureRandom.uuid}_#{safe_filename}"

    # Upload using REST API
    upload_blob_rest(account_name, account_key, container_name, blob_name, content)

    blob_url = "https://#{account_name}.blob.core.windows.net/#{container_name}/#{blob_name}"

    {
      blob_url: blob_url,
      blob_name: blob_name,
      container: container_name
    }
  rescue StandardError => e
    raise StandardError, "Azure upload failed: #{e.message}"
  end

  def self.upload_blob_rest(account_name, account_key, container, blob_name, content)
    url = "https://#{account_name}.blob.core.windows.net/#{container}/#{blob_name}"
    uri = URI(url)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    # Development: disable SSL verification (production should use proper certs)
    http.verify_mode = OpenSSL::SSL::VERIFY_NONE

    request = Net::HTTP::Put.new(uri.request_uri)
    request['x-ms-blob-type'] = 'BlockBlob'
    request['x-ms-version'] = '2023-01-03'
    request['Content-Length'] = content.bytesize.to_s
    request['Content-Type'] = 'application/octet-stream'
    request['x-ms-date'] = Time.now.httpdate

    # Create authorization signature following Azure spec
    string_to_sign = [
      'PUT',                          # HTTP Verb
      '',                             # Content-Encoding
      '',                             # Content-Language
      content.bytesize.to_s,          # Content-Length
      '',                             # Content-MD5
      'application/octet-stream',     # Content-Type
      '',                             # Date
      '',                             # If-Modified-Since
      '',                             # If-Match
      '',                             # If-None-Match
      '',                             # If-Unmodified-Since
      '',                             # Range
      "x-ms-blob-type:BlockBlob\nx-ms-date:#{request['x-ms-date']}\nx-ms-version:2023-01-03",  # Canonicalized headers
      "/#{account_name}/#{container}/#{blob_name}"  # Canonicalized resource
    ].join("\n")

    signature = Base64.strict_encode64(
      OpenSSL::HMAC.digest('sha256', Base64.decode64(account_key), string_to_sign)
    )

    request['Authorization'] = "SharedKey #{account_name}:#{signature}"
    request.body = content

    response = http.request(request)

    unless response.code.to_i == 201
      raise "Upload failed: #{response.code} - #{response.body}"
    end

    true
  end

  def self.delete_document(blob_name)
    blob_client = Azure::Storage::Blob::BlobService.create_from_connection_string(
      ENV['AZURE_STORAGE_CONNECTION_STRING']
    )

    container_name = ENV['AZURE_STORAGE_CONTAINER'] || 'documents'
    blob_client.delete_blob(container_name, blob_name)

    true
  rescue Azure::Core::Http::HTTPError => e
    raise StandardError, "Azure delete failed: #{e.message}"
  end
end
