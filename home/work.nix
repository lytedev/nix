{ lib, ... }: let 
  username = "daniel.flanagan@divvypay.com";
in {
  home.username = username;
  home.homeDirectory = "/Users/${username}";
}
