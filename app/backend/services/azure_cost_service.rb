require 'net/http'
require 'json'
require 'uri'

class AzureCostService
  # Azure Management API for consumption/budgets
  MANAGEMENT_API_VERSION = '2023-11-01'
  CONSUMPTION_API_VERSION = '2023-05-01'

  def initialize
    @subscription_id = ENV['AZURE_SUBSCRIPTION_ID']
    @tenant_id = ENV['AZURE_TENANT_ID']
    @client_id = ENV['AZURE_CLIENT_ID']
    @client_secret = ENV['AZURE_CLIENT_SECRET']

    validate_credentials!
  end

  # Get current month spending and budget information
  def get_budget_info
    token = get_access_token

    # Try to get budget from Azure Cost Management
    budget_data = fetch_budget_data(token)

    # Get current month usage
    usage_data = fetch_current_usage(token)

    {
      subscription_id: @subscription_id,
      current_spend: usage_data[:current_spend],
      budget_limit: budget_data[:budget_limit],
      remaining: budget_data[:budget_limit] - usage_data[:current_spend],
      percentage_used: calculate_percentage(usage_data[:current_spend], budget_data[:budget_limit]),
      period: usage_data[:period],
      currency: usage_data[:currency] || 'USD',
      last_updated: Time.now.iso8601
    }
  rescue => e
    puts "⚠️  Azure Cost Service Error: #{e.message}"
    puts e.backtrace.first(3).join("\n")

    # Return default/fallback data
    {
      subscription_id: @subscription_id,
      current_spend: 0,
      budget_limit: 100, # Default for student accounts
      remaining: 100,
      percentage_used: 0,
      period: "#{Date.today.strftime('%B %Y')}",
      currency: 'USD',
      last_updated: Time.now.iso8601,
      error: e.message
    }
  end

  private

  def validate_credentials!
    missing = []
    missing << 'AZURE_SUBSCRIPTION_ID' unless @subscription_id
    missing << 'AZURE_TENANT_ID' unless @tenant_id
    missing << 'AZURE_CLIENT_ID' unless @client_id
    missing << 'AZURE_CLIENT_SECRET' unless @client_secret

    if missing.any?
      raise "Missing Azure credentials: #{missing.join(', ')}"
    end
  end

  # Get OAuth token from Azure AD
  def get_access_token
    uri = URI("https://login.microsoftonline.com/#{@tenant_id}/oauth2/v2.0/token")

    response = Net::HTTP.post_form(uri, {
      'grant_type' => 'client_credentials',
      'client_id' => @client_id,
      'client_secret' => @client_secret,
      'scope' => 'https://management.azure.com/.default'
    })

    result = JSON.parse(response.body)

    unless response.is_a?(Net::HTTPSuccess)
      raise "Failed to get access token: #{result['error_description']}"
    end

    result['access_token']
  end

  # Fetch budget configuration from Azure
  def fetch_budget_data(token)
    # Try to get budgets at subscription level
    uri = URI("https://management.azure.com/subscriptions/#{@subscription_id}/providers/Microsoft.Consumption/budgets?api-version=#{CONSUMPTION_API_VERSION}")

    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{token}"
    request['Content-Type'] = 'application/json'

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      result = JSON.parse(response.body)
      budgets = result['value'] || []

      if budgets.any?
        # Use the first active budget
        budget = budgets.first
        limit = budget.dig('properties', 'amount') || 100

        return {
          budget_limit: limit.to_f,
          budget_name: budget['name']
        }
      end
    end

    # Fallback: no budget configured, assume $100 (student account default)
    {
      budget_limit: 100.0,
      budget_name: 'default'
    }
  rescue => e
    puts "⚠️  Could not fetch budget: #{e.message}"
    { budget_limit: 100.0, budget_name: 'default' }
  end

  # Fetch current month usage from Azure Cost Management
  def fetch_current_usage(token)
    # Get first and last day of current month
    today = Date.today
    start_date = Date.new(today.year, today.month, 1)
    end_date = Date.new(today.year, today.month, -1)

    uri = URI("https://management.azure.com/subscriptions/#{@subscription_id}/providers/Microsoft.CostManagement/query?api-version=2023-03-01")

    request = Net::HTTP::Post.new(uri)
    request['Authorization'] = "Bearer #{token}"
    request['Content-Type'] = 'application/json'

    # Query for current month costs
    request.body = {
      type: 'ActualCost',
      timeframe: 'Custom',
      timePeriod: {
        from: start_date.iso8601,
        to: end_date.iso8601
      },
      dataset: {
        granularity: 'None',
        aggregation: {
          totalCost: {
            name: 'Cost',
            function: 'Sum'
          }
        }
      }
    }.to_json

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
      http.request(request)
    end

    if response.is_a?(Net::HTTPSuccess)
      result = JSON.parse(response.body)

      # Parse cost from response
      rows = result.dig('properties', 'rows') || []
      total_cost = rows.sum { |row| row[0].to_f }
      currency = result.dig('properties', 'columns', 0, 'name') || 'USD'

      return {
        current_spend: total_cost.round(2),
        period: start_date.strftime('%B %Y'),
        currency: currency
      }
    end

    # Fallback
    {
      current_spend: 0.0,
      period: start_date.strftime('%B %Y'),
      currency: 'USD'
    }
  rescue => e
    puts "⚠️  Could not fetch usage: #{e.message}"
    {
      current_spend: 0.0,
      period: Date.today.strftime('%B %Y'),
      currency: 'USD'
    }
  end

  def calculate_percentage(spent, budget)
    return 0 if budget.zero?
    ((spent / budget) * 100).round(1)
  end
end
