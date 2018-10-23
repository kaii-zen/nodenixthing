const Module = require('module');
const {require: originalRequire, _compile: originalCompile} = Module.prototype;
const {existsSync: exists} = require('fs');
const {dirname, join: pathJoin, sep: pathSep} = require('path').posix;

const makeNixResolverFor = requirer => requiredPath => {
  const depMap = originalRequire(process.env.NIX_JSON);
  const scoped = path => path[0] == '@';
  const slicePath = path => a => b => path.split(pathSep).slice(a, b).join(pathSep);
  const moduleHead = path => slicePath(path)(0)(scoped(path) ? 2 : 1);
  const findUp = (path, file = pathJoin(path, "package.json")) => exists(file) ? file : findUp(dirname(path));

  // trimNixPath('/nix/store/abcdefghijklmnopqrstuvwxyz-something/lib/blah/blah') => 'abcdefghijklmnopqrstuvwxyz-something'
  const trimNixPath = storePath => storePath.match(/([a-z0-9]{32}-.+?)\//)[1];

  const findParent = requirer => {
    try {
      const requirerNixHash = trimNixPath(requirer.filename);
      const parentNixHash = trimNixPath(requirer.parent.filename);
      if (requirerNixHash !== parentNixHash) {
        return requirer.parent;
      }
      return findParent(requirer.parent);
    } catch (e) {
      return null;
    }
  }

  const getRequirerVersion = requirer => {
    const {name: requirerName, version: ownVersion} = originalRequire(findUp(requirer.filename));

    const findRequirerVersion = parent => {
      try {
        const versionFromParent = originalRequire(findUp(parent.filename))['dependencies'][requirerName];
        if (depMap[requirerName][versionFromParent]) {
          return versionFromParent;
        }
        throw 'SHADE';
      } catch (e) {
        if (depMap[requirerName][ownVersion]) {
          return ownVersion;
        }


        const nextParent = findParent(parent);

        if (nextParent) {
          return findRequirerVersion(findParent(nextParent));
        }

        return null
      }
    }
    return findRequirerVersion(findParent(requirer));
  };

  const mkVersionFinderFor = requirer => moduleName => {
    const packageJson = originalRequire(findUp(requirer.filename));
    const {name} = packageJson;
    const version = getRequirerVersion(requirer);
    const {requires = {}, packageJsonOverride = {}} = depMap[name][version];
    const {peerDependencies = {}} = Object.assign({}, packageJson, packageJsonOverride);

    const findPeerVersion = requirer => {
      const {name} = originalRequire(findUp(requirer.filename));
      const version = getRequirerVersion(requirer);
      const {requires = {}} = depMap[name][version];
      return (requires[moduleName] || findPeerVersion(findParent(requirer)));
    };

    const isPeer = !!peerDependencies[moduleName];

    if (isPeer) {
      return findPeerVersion(findParent(requirer));
    } else {
      return requires[moduleName];
    }
  };

  const requiredVersionOf = mkVersionFinderFor(requirer);
  const getNixPathFor = moduleName => depMap[moduleName] && depMap[moduleName][requiredVersionOf(moduleName)].path;
  const moduleName = moduleHead(requiredPath);
  const nixPath = getNixPathFor(moduleName)
  return pathJoin(nixPath, 'lib', 'node_modules');
}

Module.prototype.require = function(request) {
  const nixResolve = makeNixResolverFor(this);
  const resolveOpts = {};
  try {
    resolveOpts.paths = [nixResolve(request)];
    arguments[0] = require.resolve(request, resolveOpts);
  } catch (e) {
    if (process.env.NODE_NIX_REQUIRE_VERBOSE) {
      console.log(e)
    }
  } finally {
    return originalRequire.call(this, arguments[0]);
  }
}

function stripShebang(content) {
  // Remove shebang
  var contLen = content.length;
  if (contLen >= 2) {
    if (content.charCodeAt(0) === 35/*#*/ &&
        content.charCodeAt(1) === 33/*!*/) {
      if (contLen === 2) {
        // Exact match
        content = '';
      } else {
        // Find end of shebang line and slice it off
        var i = 2;
        for (; i < contLen; ++i) {
          var code = content.charCodeAt(i);
          if (code === 10/*\n*/ || code === 13/*\r*/)
            break;
        }
        if (i === contLen)
          content = '';
        else {
          // Note that this actually includes the newline character(s) in the
          // new output. This duplicates the behavior of the regular expression
          // that was previously used to replace the shebang line
          content = content.slice(i);
        }
      }
    }
  }
  return content;
}

Module.prototype._compile = function(content, filename) {
  originalCompile.call(this, `
  const originalRequire = require;
  const originalRequireResolve = require.resolve;

  const makeNixResolverFor = requiringFile => requiringFileParent => requiredPath => {
    const {existsSync: exists} = originalRequire('fs');
    const {dirname, join: pathJoin, sep: pathSep} = originalRequire('path').posix;
    const depMap = originalRequire(process.env.NIX_JSON);
    const scoped = path => path[0] == '@';
    const slicePath = path => a => b => path.split(pathSep).slice(a, b).join(pathSep);
    const moduleHead = path => slicePath(path)(0)(scoped(path) ? 2 : 1);
    const findUp = (path, file = pathJoin(path, "package.json")) => exists(file) ? file : findUp(dirname(path));
    const {name, version} = originalRequire(findUp(requiringFile));
    const requiredVersionOf = moduleName => {
      try {
        return depMap[name][version]['requires'][moduleName];
      } catch (e) {
        if (depMap[name][version]['peers'].includes(moduleName)) {
          const {name: parentName, version: parentVersion} = originalRequire(findUp(requiringFileParent));
          return depMap[parentName][parentVersion]['requires'][moduleName];
        } else {
          throw 'SHADE';
        }
      };
    };
    const nixPathFor = moduleName => depMap[moduleName] && depMap[moduleName][requiredVersionOf(moduleName)].path;
    const moduleName = moduleHead(requiredPath);
    // console.error('requiredPath ' + requiredPath + ' moduleName ' + moduleName);
    const nixPath = nixPathFor(moduleName)
    return pathJoin(nixPath, 'lib', 'node_modules');
  }
  // const makeNixResolverFor = requiringFile => requiredPath => {
  //   const {existsSync: exists} = originalRequire('fs');
  //   const {dirname, join: pathJoin, sep: pathSep} = originalRequire('path').posix;
  //   const depMap = originalRequire(process.env.NIX_JSON);
  //   const scoped = path => path[0] == '@';
  //   const slicePath = path => a => b => path.split(pathSep).slice(a, b).join(pathSep);
  //   const moduleHead = path => slicePath(path)(0)(scoped(path) ? 2 : 1);
  //   const findUp = (path, file = pathJoin(path, "package.json")) => exists(file) ? file : findUp(dirname(path));
  //   const {name, version} = originalRequire(findUp(requiringFile));
  //   const requiredVersionOf = moduleName => {
  //     try {
  //       return depMap[name][version]['requires'][moduleName];
  //     } catch (e) {
  //       throw 'SHADE';
  //     };
  //   };
  //   const nixPathFor = moduleName => depMap[moduleName] && depMap[moduleName][requiredVersionOf(moduleName)].path;
  //   const moduleName = moduleHead(requiredPath);
  //   const nixPath = nixPathFor(moduleName)
  //   return pathJoin(nixPath, 'lib', 'node_modules');
  // };

  require.resolve = function(requiredPath) {
    const nixResolve = makeNixResolverFor(module.filename)(module.parent ? module.parent.filename : null);
    const resolveOpts = {};
    try {
      resolveOpts.paths = [nixResolve(requiredPath)];
    } finally {
      return originalRequireResolve(requiredPath, resolveOpts);
    }
  };
  ` + stripShebang(content), filename)

}
