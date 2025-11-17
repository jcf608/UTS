class Document < ActiveRecord::Base
  validates :title, presence: true
  validates :content, presence: true

  # Scopes
  scope :recent, -> { order(created_at: :desc).limit(10) }
  scope :by_status, ->(status) { where(status: status) }

  # Status enum (ActiveRecord 7.x syntax)
  enum :status, {
    pending: 0,
    processing: 1,
    indexed: 2,
    failed: 3
  }, default: :pending

  # Methods
  def to_json_api
    # Handle encoding issues - force UTF-8 and remove invalid bytes
    safe_content = content.force_encoding('UTF-8').encode('UTF-8', invalid: :replace, undef: :replace, replace: '')

    {
      id: id,
      title: title,
      content_preview: safe_content[0...200],
      status: status,
      metadata: metadata || {},
      blob_url: blob_url,
      created_at: created_at.iso8601,
      updated_at: updated_at.iso8601
    }
  end
end
