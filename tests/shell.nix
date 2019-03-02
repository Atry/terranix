# for development
{ pkgs ?  import <nixpkgs> {} }:

with pkgs.lib;
with builtins;

let

  terranix = import ../lib.nix { inherit (pkgs) writeShellScriptBin pandoc stdenv; };

  terraformCurrent = pkgs.terraform.overrideAttrs( old: rec {
    version = "0.11.10";
    name = "terraform-${version}";
    src = pkgs.fetchFromGitHub {
      owner  = "hashicorp";
      repo   = "terraform";
        rev    = "v${version}";
        sha256 = "08mapla89g106bvqr41zfd7l4ki55by6207qlxq9caiha54nx4nb";
      };
    });

  # todo : use builtins.readDir
  testFolder = folder: pkgs.writeScript "testFile" /* sh */ ''
    cd ${folder}
    OUTPUT_FILE=${folder}/.test-output
    if [ -f "$OUTPUT_FILE" ];then rm "$OUTPUT_FILE" ;fi

    for NIX_FILE in `ls | egrep nix`
    do
      echo "Testing : ${folder}/$NIX_FILE"
      ${terranix.terranix}/bin/terranix ${folder}/$NIX_FILE &> "$OUTPUT_FILE"
      diff -su "$OUTPUT_FILE" `basename $NIX_FILE .nix`.output
      if [ $? -ne 0 ]
      then
        exit 1
      fi
    done
  '';

  testScript =
    let
      testFolders = attrNames (filterAttrs (file: fileType: fileType == "directory") (readDir (toString ./.)));
      fullTestFolders = map (file: "${toString ./.}/${file}") testFolders;
    in
      pkgs.writeShellScriptBin "test-terranix" ''
        ${concatStringsSep "\n" (map testFolder fullTestFolders)}
      '';

in pkgs.mkShell {

  # needed pkgs
  # -----------
  buildInputs = with pkgs; [
    terranix.terranix
    terranix.terranixTrace
    (terranix.manpage "3.3.3")
    #terraformCurrent
    terraform
    pup
    pandoc
    testScript
  ];

  # run this on start
  # -----------------
  shellHook = ''
    HISTFILE=${toString ./.}/.history
  '';
}
