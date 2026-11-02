# SSH server for remote fixes and inspection. A host imports it only while it
# needs one. The account logs in with the installer's authorized keys or its
# password; root cannot log in.
_:

{
  services.openssh = {
    enable = true;
    openFirewall = true;
    settings = {
      PasswordAuthentication = true;
      PubkeyAuthentication = true;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };
}
