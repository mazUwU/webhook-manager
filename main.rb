# frozen_string_literal: true

require "bundler/setup"
require "sinatra"
require "sinatra/reloader"
require "json"
require "openssl"

set :port, 7000
GITHUB_WEBHOOK_SECRET = ENV["GITHUB_WEBHOOK_SECRET"]

get "/" do
  html_response = <<~HTML
    <html>
      <head>
        <title>Webhook Manager</title>
        <link rel="stylesheet" href="https://cdn.simplecss.org/simple.min.css">
      </head>
      <body>
        <h1>Oh hi!</h1>
        <h4>
          This project is responsible for automatically updating my live
          projects as I work on them, and doesn't have a user interface.
        </h4>
      </body>
    </html>
  HTML

  html_response
end

post "/" do
  # Check if the request is signed by Github
  signature = request.env["HTTP_X_HUB_SIGNATURE"]
  halt(400) unless signature

  raw_payload = request.body.read
  json_payload = JSON.parse(raw_payload)

  # Return if signature is bad
  verify_signature(raw_payload, signature)

  # Check if the request is a push event
  halt(400) unless request.env["HTTP_X_GITHUB_EVENT"] == "push"

  # Pull out what I need from the json
  branch = json_payload["ref"].split("/").last
  repo = json_payload["repository"]["name"]
  owner = json_payload["repository"]["owner"]["login"]

  # Check if the request is for a repo I own, on it's main branch
  halt(202) unless branch == "main" || branch == "master"
  halt(400) unless owner == "mazUwU"

  # TODO: Remove this
  puts body
  owner_id = body["repository"]["owner"]["id"]
  puts owner_id
  puts owner_id.class

  # Run deploy script
  case repo
  when "webhook-manager"
    Thread.new { system("sleep 5 && git pull -f") }
    status(202)
  when "maz.dev"
    status(202)
    system("./deploy_maz_dev.sh")
  else
    status(406)
  end
end

def verify_signature(payload, signature)
  expected_signature = "sha1=" + OpenSSL::HMAC.hexdigest(
    OpenSSL::Digest.new("sha1"),
    GITHUB_WEBHOOK_SECRET,
    payload,
  )

  halt(500, "Signatures didn't match!") unless Rack::Utils.secure_compare(expected_signature, signature)
end
