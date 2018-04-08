const chalk = require('chalk');
const ora = require('ora');

module.exports = who => {
  spinner = ora('Loading unicorns...').start();
  setTimeout(() => { return spinner.succeed(`Hello ${chalk.blue(who)}!`); }, 1000);
}
