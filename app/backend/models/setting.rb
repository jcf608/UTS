require 'active_record'

class Setting < ActiveRecord::Base
  validates :key, presence: true, uniqueness: true
  validates :category, presence: true

  # Get a setting value
  def self.get(key, default = nil)
    setting = find_by(key: key)
    setting ? setting.value : default
  end

  # Set a setting value
  def self.set(key, value, description: nil, category: 'general')
    setting = find_or_initialize_by(key: key)
    setting.value = value
    setting.description = description if description
    setting.category = category
    setting.save!
    setting
  end

  # Get all settings by category
  def self.by_category(category)
    where(category: category).order(:key)
  end

  # Get all settings as a hash
  def self.all_as_hash
    all.each_with_object({}) do |setting, hash|
      hash[setting.key] = setting.value
    end
  end

  # Initialize default settings
  def self.initialize_defaults
    defaults = [
      {
        key: 'openai_chat_model',
        value: 'gpt-4-turbo',
        description: 'OpenAI chat model to use (gpt-4, gpt-4-turbo, gpt-4o, gpt-4o-mini)',
        category: 'ai'
      },
      {
        key: 'openai_max_output_tokens',
        value: '2000',
        description: 'Maximum tokens for AI response generation',
        category: 'ai'
      },
      {
        key: 'openai_context_budget',
        value: '6000',
        description: 'Maximum tokens allocated for context chunks',
        category: 'ai'
      },
      {
        key: 'log_level',
        value: 'info',
        description: 'Application logging level (debug, info, warn, error)',
        category: 'system'
      }
    ]

    defaults.each do |default|
      next if exists?(key: default[:key])
      create!(default)
    end
  end
end
