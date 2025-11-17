require 'net/http'
require 'uri'
require 'base64'
require 'openssl'
require 'time'

# Azure implementation of base storage service
class AzureStorageService < BaseStorageService

  def self.provider_name
    'azure'
  end

  def self.validate_configuration!
    raise StandardError, 'AZURE_STORAGE_CONNECTION_STRING not set' unless ENV['AZURE_STORAGE_CONNECTION_STRING']
  end

  def self.base_url
    account_name = parse_account_name
    "https://#{account_name}.blob.core.windows.net"
  end

  # Implement upload_blob (called by base class template method)
  def self.upload_blob(blob_path, content)
    account_name, account_key = parse_credentials
    upload_blob_rest(account_name, account_key, container_name, blob_path, content)
  end

  # Implement delete_blob
  def self.delete_blob(blob_name)
    account_name, account_key = parse_credentials
    delete_blob_rest(account_name, account_key, container_name, blob_name)
  end

  # Implement create_signed_url - Generate SAS token for temporary access
  def self.create_signed_url(blob_name, expires_in)
    account_name, account_key = parse_credentials
    expiry = (Time.now + expires_in).utc.iso8601

    # SAS token parameters
    permissions = 'r'  # Read only
    start = Time.now.utc.iso8601

    # Create signature
    string_to_sign = [
      permissions,
      start,
      expiry,
      "/blob/#{account_name}/#{container_name}/#{blob_name}",
      '',  # Identifier
      '',  # IP
      'https',  # Protocol
      '2023-01-03'  # API version
    ].join("\n")

    signature = Base64.strict_encode64(
      OpenSSL::HMAC.digest('sha256', Base64.decode64(account_key), string_to_sign)
    )

    sas_token = URI.encode_www_form({
      sp: permissions,
      st: start,
      se: expiry,
      sv: '2023-01-03',
      sr: 'b',
      sig: signature
    })

    "https://#{account_name}.blob.core.windows.net/#{container_name}/#{blob_name}?#{sas_token}"
  end

  private

  def self.parse_credentials
    conn_string = ENV['AZURE_STORAGE_CONNECTION_STRING']
    account_name = conn_string[/AccountName=([^;]+)/, 1]
    account_key = conn_string[/AccountKey=([^;]+)/, 1]
    [account_name, account_key]
  end

  def self.parse_account_name
    ENV['AZURE_STORAGE_CONNECTION_STRING'][/AccountName=([^;]+)/, 1]
  end

  def self.upload_blob_rest(account_name, account_key, container, blob_name, content)
    url = "https://#{account_name}.blob.core.windows.net/#{container}/#{blob_name}"
    uri = URI(url)

    # Use shared HTTP client from base class
    http = https_client(uri)

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

    # Use shared response validation from base class
    validate_response(response, [201])

    true
  rescue StandardError => e
    handle_upload_error(e)
  end

  def self.delete_blob_rest(account_name, account_key, container, blob_name)
    # Implement DELETE request for Azure Blob
    url = "https://#{account_name}.blob.core.windows.net/#{container}/#{blob_name}"
    uri = URI(url)

    # Use shared HTTP client from base class
    http = https_client(uri)

    request = Net::HTTP::Delete.new(uri.request_uri)
    request['x-ms-version'] = '2023-01-03'
    request['x-ms-date'] = Time.now.httpdate

    # Authorization signature for DELETE
    string_to_sign = "DELETE\n\n\n\n\n\n\n\n\n\n\n\nx-ms-date:#{request['x-ms-date']}\nx-ms-version:2023-01-03\n/#{account_name}/#{container}/#{blob_name}"

    signature = Base64.strict_encode64(
      OpenSSL::HMAC.digest('sha256', Base64.decode64(account_key), string_to_sign)
    )

    request['Authorization'] = "SharedKey #{account_name}:#{signature}"

    response = http.request(request)
    response.code.to_i == 202
  end
end
