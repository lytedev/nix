{...}: let
  username = "daniel.flanagan@hq.bill.com";
in {
  home.username = username;
  home.homeDirectory = "/Users/${username}";
}
