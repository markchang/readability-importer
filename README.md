# Readability Importer

Well, it really is just a ReadItLater to Readability importer. It only imports your unread articles!

This runs on Sinatra and requires a bunch of gems, as you can see in the source. Use it at your own risk, after putting your relevant keys into the environment. 

# Working demo

I have this deployed on Heroku here: http://readability-importer.heroku.com

# Known (or suspected) issues

  * The articles are not imported in order. This is because the article text is fetched by Readability asynchronously after we push the bookmark to them. Each article takes a different amount of time, and the order of articles is rendered reverse chronologically depending on when the article was fetched. **Not fixable.**
  * I am not spawning a background task to do the import. Thus, if it is long running, Heroku will kill the instance of the application, leaving you partially imported. Fix is to start a background job. Not going to do, since I'd have to pay for Delayed Jobs on Heroku. **Not fixed.**
  
  * I should make this obvious on how to use this locally so people can import from their own machines without the Heroku limitation.

# Development

This was an evening with Sinatra and OAuth. It could use a lot of cleaning up and beautification. If you want to help, you know the drill. Fork, change, pull request, enjoy.

# License

BSD