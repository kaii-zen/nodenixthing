chalk = require 'chalk'
ora = require 'ora'

module.exports = (who) ->
  spinner = ora('Loading unicorns...').start()
  setTimeout(() =>
    spinner.succeed "Hello #{chalk.blue who}!"
  , 1000)
