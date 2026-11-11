# Read-only media server for a private S3 bucket (Railway buckets can't be public).
# Serves GET/HEAD by object key; no listing, no writes. Mastodon's S3_ALIAS_HOST points here.
require 'aws-sdk-s3'
require 'net/http'

class MediaProxy
  PASS = %w[content-type content-length content-range accept-ranges etag last-modified cache-control].freeze
  FWD = { 'HTTP_RANGE' => 'Range', 'HTTP_IF_NONE_MATCH' => 'If-None-Match', 'HTTP_IF_MODIFIED_SINCE' => 'If-Modified-Since' }.freeze

  def initialize
    client = Aws::S3::Client.new(
      endpoint: ENV.fetch('S3_ENDPOINT'), region: ENV.fetch('S3_REGION', 'auto'),
      access_key_id: ENV.fetch('AWS_ACCESS_KEY_ID'), secret_access_key: ENV.fetch('AWS_SECRET_ACCESS_KEY'),
      force_path_style: ENV['S3_OVERRIDE_PATH_STYLE'] != 'true'
    )
    @presigner = Aws::S3::Presigner.new(client: client)
    @bucket = ENV.fetch('S3_BUCKET')
  end

  def call(env)
    path = env['PATH_INFO'].to_s
    return [200, { 'content-type' => 'text/plain' }, ['ok']] if path == '/health'
    return [405, { 'allow' => 'GET, HEAD' }, []] unless %w[GET HEAD].include?(env['REQUEST_METHOD'])

    key = Rack::Utils.unescape_path(path.sub(%r{\A/+}, ''))
    return not_found if key.empty? || key.end_with?('/') || key.split('/').include?('..')

    head = env['REQUEST_METHOD'] == 'HEAD'
    uri = URI(@presigner.presigned_url(head ? :head_object : :get_object, bucket: @bucket, key: key, expires_in: 300))
    req = (head ? Net::HTTP::Head : Net::HTTP::Get).new(uri)
    FWD.each { |k, h| req[h] = env[k] if env[k] }

    queue = SizedQueue.new(8)
    worker = Thread.new do
      Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', open_timeout: 5, read_timeout: 30) do |http|
        http.request(req) do |res|
          queue << res
          res.read_body { |chunk| queue << chunk } if !head && res.code.to_i < 300
        end
      end
      queue << :done
    rescue StandardError => e
      queue << e
    end

    res = queue.pop
    if res.is_a?(Exception) || res == :done
      worker.kill
      warn "[media] #{key}: #{res.inspect}"
      return [502, { 'content-type' => 'text/plain' }, ['upstream error']]
    end
    code = res.code.to_i
    unless [200, 206, 304].include?(code)
      worker.kill
      return code == 416 ? [416, {}, []] : not_found
    end

    headers = PASS.each_with_object({}) { |h, out| out[h] = res[h] if res[h] }
    headers['access-control-allow-origin'] = '*'
    headers['x-content-type-options'] = 'nosniff'
    headers['content-security-policy'] = "default-src 'none'; form-action 'none'"
    body = head || code == 304 ? [] : Body.new(queue, worker)
    [code, headers, body]
  end

  def not_found
    [404, { 'content-type' => 'text/plain' }, ['not found']]
  end

  class Body
    def initialize(queue, worker)
      @queue = queue
      @worker = worker
    end

    def each
      while (item = @queue.pop) != :done
        raise item if item.is_a?(Exception)
        yield item
      end
    end

    def close
      @worker.kill
    end
  end
end

run MediaProxy.new
