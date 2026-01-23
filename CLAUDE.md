format code with something like `fish -c 'nix fmt -- (jj file list)'`

if asked, setup jj workspaces for separate features somewhere in the following format:
- $CODE/workspaces/$REPO_NAME/$WORKSPACE_NAME
  - $CODE is the related code directory, usually ~/../code (since $HOME is /home/daniel/.home for clutter reasons and the code directory is usually /home/daniel/code)
  - $REPO_NAME would be nix in this case, so going from code/nix to code/workspaces/nix should be obvious
  - $WORKSPACE_NAME should probably just be the branch or bookmark name
