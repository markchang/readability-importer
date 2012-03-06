# Readability Importer

Well, it really is just a ReadItLater to Readability importer. It only imports your unread articles!

This runs on Sinatra and requires a bunch of gems, as you can see in the source. Use it at your own risk, after putting your relevant keys into the environment. 

# Working demo

I have this deployed on Heroku here: http://readability-importer.heroku.com

# Known (or suspected) issues

  * The readitlater API documentation suggests that the records are returned ordered by time_updated descending. This is not the case. Importing should be forwards because it means I'm importing the oldest article first. If it gets fixed, it'll all be backwards.
  * I am not spawning a background task to do the import. Thus, if it is long running (say, >100 articles and 30s), Heroku will kill the instance of the application, leaving you partially imported. Fix is to start a background job. Not going to do, since I'd have to manage queues and such under the free limitation.
    * I should make this obvious on how to use locally so people can import from their own machines without the Heroku limitation.

# Development

This was an evening with Sinatra and OAuth. It could use a lot of cleaning up and beautification. If you want to help, you know the drill. Fork, change, pull request, enjoy.

# License

BSD