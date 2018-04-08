#!/usr/bin/env node

let greet = require('./lib/greeter')

greet('World')
greet(process.env.PWD)
