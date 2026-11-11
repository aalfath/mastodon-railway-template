# First start only: create the Owner account with tootctl, set its password from
# ADMIN_PASSWORD and keep sign-ups closed. Later starts leave everything alone.
username = ENV.fetch('ADMIN_USERNAME')
if Account.find_local(username)
  puts "[railway] owner @#{username} already exists, nothing to do"
  return
end
email = ENV['ADMIN_EMAIL'].to_s.strip
password = ENV['ADMIN_PASSWORD'].to_s
abort '[railway] set ADMIN_EMAIL on the web service' if email.empty?
abort '[railway] ADMIN_PASSWORD must be 8 to 72 characters' unless (8..72).cover?(password.length)

require_relative '/opt/mastodon/lib/mastodon/cli/accounts'
out = StringIO.new
begin
  $stdout = out # tootctl prints a throwaway random password; it is replaced below
  Mastodon::CLI::Accounts.new([username], { email: email, confirmed: true, approve: true, role: 'Owner' }).create(username)
ensure
  $stdout = STDOUT
end
user = Account.find_local(username)&.user or abort "[railway] tootctl could not create @#{username}: #{out.string.lines.grep_v(/password/i).join.strip}"
user.skip_password_change_notification! if user.respond_to?(:skip_password_change_notification!)
user.update!(password: password)
Setting.registrations_mode = 'none'
puts "[railway] created owner @#{username} (#{email}); sign in with the ADMIN_PASSWORD variable. Registrations: closed"
