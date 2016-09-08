request = require('request')
fs = require('fs')
config = 'config.json'

config_file = ->
   fs.readFileSync config, 'utf8'

config_data=JSON.parse(config_file())
standard_req = {
    json: true,
    method:"POST",
    auth: {
      user: config_data.git.user,
      pass: config_data.git.password
    },
    headers: {
      'User-Agent': 'hubot-watch'
    }
  }

module.exports = (robot) ->
 
  # If I want to take in env variables instead  process.env.HUBOT_WATCH_USERNAME
 # if not process.env.HUBOT_WATCH_USERNAME or not process.env.HUBOT_WATCH_PASSWORD
 #   robot.send '','Please provide your Github credentials'
 #   return
  watched = []
  req_options = standard_req
  req_options.method="GET"
  req_options.url = "https://api.github.com/repos/#{repo}/events"

  repo=config_data.repo
  
  request req_options, (err,response,obj) ->
    throw err if err
    if obj.message
     # res.send obj.message
    else
     watched[repo] = obj[0].id
     console.log(obj[0].id)
  
  setInterval ->
    for repo of watched
      req_options.url = "https://api.github.com/repos/#{repo}/events"
      request req_options, (err, response, obj) ->
        if obj[0].id != watched[repo]
          robot.send '',repo + ": " + handleEvent obj[0] unless process.env.HUBOT_WATCH_IGNORED and process.env.HUBOT_WATCH_IGNORED.indexOf(obj[0].type) isnt -1
          watched[repo] = obj[0].id
  ,5000

handleEvent = (event) ->
  switch event.type
    when "IssuesEvent"
      return "#{event.actor.login} #{event.payload.action} issue ##{event.payload.issue.number}: #{event.payload.issue.title}"
    when "IssueCommentEvent"
      event_text=event.payload.comment.body
      pr=event.payload.issue.number
      bot_check(event_text,pr) 
    when "PullRequestEvent"
      pr=event.payload.pull_request.number
      handle_pr(pr)
      return "#{event.actor.login} #{event.payload.action} pull request ##{event.payload.pull_request.number}: #{event.payload.pull_request}"
    when "PushEvent"
      return "#{event.actor.login} pushed to #{event.payload.ref.replace('refs/heads/','')}"
    when "CreateEvent"
      return "#{event.actor.login} created #{event.payload.ref_type} #{event.payload.ref}"
    when "DeleteEvent"
      return "#{event.actor.login} deleted #{event.payload.ref_type} #{event.payload.ref}"
    when "GollumEvent"
      return "#{event.actor.login} #{event.payload.pages[0].action} the wiki page: #{event.payload.pages[0].title}"
    when "MemberEvent"
      return "#{event.actor.login} #{event.payload.action} #{event.payload.member.login} to the collaborators"
    when "WatchEvent"
      return "#{event.actor.login} gave a star"
    when "ForkEvent"
      return "#{event.actor.login} forked to #{event.payload.forkee.full-name}"
    else
      return "Cannot handle event type: #{event.type}"

bot_check = (comment,pr) ->
  bot_regex=/(@miq-bot)\s(\w*)\s(.*)/
  bot_matches=comment.match(bot_regex)
  if bot_matches=comment.match(bot_regex)
    bot_action=bot_matches[2]
    bot_arguments=bot_matches[3]
    console.log("action is "+bot_action)
    console.log("arguments are "+bot_arguments)
    #switch based on action
    switch bot_action
      when "add_label" then label_action(bot_arguments,pr)
      when "assign" then assign_action(bot_arguments,pr)
  else
    console.log("No bot found")

label_action = (label_text, pr) ->
  trimmed_labels=label_text.replace /\s/g, ""
  labels=trimmed_labels.split ","

  req_options = standard_req
  req_options.body = labels
  req_options.url = "https://api.github.com/repos/"+repo+"/issues/"+pr+"/labels"

  request req_options, (err,response,obj) ->
    throw err if err
    if obj.message
      console.log obj.message
    else
     console.log("labels were added successfully")
  #test case if only one is submitted
assign_action= (assignee) ->
  console.log(assignee)

handle_pr=(pr) ->
  creds=config_data.git.user+":"+config_data.git.password
  #at this point load the git pull functionality
  s = spawn './git_pull.sh', [creds,repo,pr]                        
  s.stdout.on 'data', ( data ) -> 
    
    rubocop_file = ->
      fs.readFileSync '/tmp/hubot_pull_requests/rubocop.json', 'utf8'
    comment_message=""
    rubocop_data=JSON.parse(rubocop_file())
    console.log rubocop_data
    if (rubocop_data.summary.offense_count > 0)
      comment_message="Fix yo code foo"

    req_options = standard_req
    req_options.body = {"body":comment_message}
    req_options.url = "https://api.github.com/repos/"+repo+"/issues/"+pr+"/comments"

    request req_options, (err,response,obj) ->
      throw err if err
      if obj.message
        console.log obj.message
      else
      console.log("Comment on ticket was successful")  