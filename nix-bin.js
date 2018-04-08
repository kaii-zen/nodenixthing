const assert = require('assert');

let {name: pkgName, bin} = require(process.argv[2]);
let binObj = (typeof bin === 'string' ? { [pkgName]: bin } : bin) || {};

for (const [name, path] of Object.entries(binObj)) {
  console.log(`${pkgName} ${name} ${path}`);
}
