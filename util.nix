{ pkgs }:

with builtins;
with pkgs;
with pkgs.lib;
rec {
  countAttrs = attrs: length (attrNames attrs);
  not = notxy;
  notxy = f: x: y: !(f x y);
  notxyz = f: x: y: z: !(f x y z);
  notx = f: x: !(f x);
  equal = x: y: x == y;
  equals = equal;
  isNonEmptyList = xs: isList xs && xs != [];
  pair = a: b: [ a b ];
  discardz = f: x: y: _: assert isFunction f; f x y;
  discardy = f: x: _: assert isFunction f; f x;
  discardxy = f: _: _: z: assert isFunction f; f z;
  hasntAttr = not (flip hasAttr);
  hasntAttrs = attrs: attrSet: foldl and true (map (hasntAttr attrSet) attrs);
  hasAttrs = attrs: attrSet: foldl and true (map ((flip hasAttr) attrSet) attrs);
  mkStack = {
    __functor = self: x: self // {
      empty = false;
      size = self.size + 1;
      top = x;
      pop = self;
      toList = [x] ++ self.toList;
    };
    empty = true;
    size = 0;
    top = null;
    pop = null;
    toList = [];
  };
  discard = n: if n == 0 then false else (_: discard (n - 1));
  compareArgsToList = xs: x:
  let
    t = tail xs;
  in
    if x == (head xs) then (if t == []  then true
                                        else compareArgsToList t)
                      else discard (length t);
  removeAttrRecursive = attr: filterAttrsRecursive (name: _: name != attr);
  tailIfHead = pred: assert isFunction pred; xs: assert isNonEmptyList xs; if (pred (head xs)) then (tail xs) else false;
  # "attr" -> { attr = "something"; anotherAttr = "something else"; ... } -> { something = { anotherAttr = "somethingElse"; }; }
  hoistAttr = attr: attrSet: { ${attrSet.${attr}} = attrSet; };
  hoistAttrs = attr: mapAttrs (_: hoistAttr attr);
  hoistAttr' = attr: attrSet: { ${attrSet.${attr}} = (removeAttrs attrSet [ attr ]); };
  hoistAttrs' = attr: mapAttrs (_: hoistAttr' attr);
  # This is what I thought builtins.hasAttr was for. Unfortunately it differs from the behaviour of the ? operator
  # in that builtins.hasAttr would abort when given anything but a set while the ? operator would just return false. Which is what we want 😌
  # "attr" -> ({}) -> bool
  isAttrsAndHasAttr = attr: attrs: attrs ? ${attr};
  collectAttrsByName = name: collect (isAttrsAndHasAttr name);
  collectValuesByName = name: attrs: map (getAttr name) (collectAttrsByName name attrs);
  collectValuesByNameRecursive = name: attrs: foldl (result: as: result ++ (collectValuesByNameRecursive name as)) [ attrs ] (collectValuesByName name attrs);
  composeTwoFunctions = f: g: x: g (f x);
  composeManyFunctions = foldr composeTwoFunctions id;
  composeMultipleExtensions = extensions: foldl composeExtensions (head extensions) (tail extensions);

  makeUnextensible = flip builtins.removeAttrs [ "__unfix__" "extend" ];

  applyExtension = extension: attrs: let
    extensible = makeExtensible (const attrs);
    extended = extensible.extend extension;
  in makeUnextensible extended;

}
