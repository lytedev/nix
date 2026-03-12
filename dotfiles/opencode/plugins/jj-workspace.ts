import type { Plugin } from "@opencode-ai/plugin";
import { existsSync } from "fs";
import { join, resolve, basename } from "path";
import { execSync } from "child_process";

// Resolve jj path at plugin load time
const JJ = (() => {
  try {
    return execSync("which jj", { encoding: "utf-8" }).trim();
  } catch {
    return "jj";
  }
})();

const JjWorkspace: Plugin = async ({ $, directory, workspaceFetch }) => {
  // Only activate in jj repositories
  if (!existsSync(join(directory, ".jj"))) return {};

  return {
    "workspace.adaptor": {
      jj: {
        detect(dir) {
          return existsSync(join(dir, ".jj"));
        },

        configure(info) {
          const root = info.projectDirectory ?? directory;
          const name = info.name || `sandbox-${info.id.slice(0, 8)}`;
          const wsDir = resolve(root, "..", `${basename(root)}-${name}`);
          return {
            ...info,
            name,
            branch: info.branch || name,
            directory: wsDir,
          };
        },

        async create(info) {
          const root = info.projectDirectory ?? directory;
          const name = info.name!;
          const wsDir = info.directory!;
          const trunk = "trunk()";
          const atWorkspace = `${name}@${name}`;

          // Clean up any leftover workspace with the same name
          await $`${JJ} workspace forget ${name}`.cwd(root).quiet().nothrow();

          // Remove leftover directory if it exists
          if (existsSync(wsDir)) {
            await $`rm -rf ${wsDir}`.quiet().nothrow();
          }

          // Create a jj workspace rooted at the sibling directory
          const result =
            await $`${JJ} workspace add ${wsDir} --name ${name} -r ${trunk}`
              .cwd(root)
              .nothrow();
          if (result.exitCode !== 0) {
            throw new Error(
              `jj workspace add failed (exit ${result.exitCode}): ${result.stderr.toString()}`,
            );
          }

          // Create a bookmark so the workspace is addressable
          await $`${JJ} bookmark create ${name} -r ${atWorkspace}`
            .cwd(wsDir)
            .nothrow();
        },

        async remove(info) {
          const root = info.projectDirectory ?? directory;
          const name = info.name!;
          const wsDir = info.directory!;

          // Clean up the bookmark
          await $`${JJ} bookmark delete ${name}`.cwd(root).quiet().nothrow();

          // Forget the workspace from jj's tracking
          await $`${JJ} workspace forget ${name}`.cwd(root).quiet().nothrow();

          // Remove the directory
          await $`rm -rf ${wsDir}`.quiet().nothrow();
        },

        async reset(info) {
          const wsDir = info.directory!;
          const trunk = "trunk()";

          // Reset the workspace to trunk
          await $`${JJ} new ${trunk}`.cwd(wsDir).quiet();
        },

        fetch(info, input, init) {
          return workspaceFetch(info.directory!, input, init);
        },
      },
    },

    async "vcs.branch"(input, output) {
      // Only act on directories that are jj repos
      if (!existsSync(join(input.directory, ".jj"))) return;

      const bookmarksTpl = 'separate(", ", bookmarks)';
      const changeIdTpl = "change_id.short()";

      // Try bookmarks first
      const bookmarks = (
        await $`${JJ} log -r @ --no-graph -T ${bookmarksTpl}`
          .cwd(input.directory)
          .quiet()
          .nothrow()
          .text()
      ).trim();

      if (bookmarks) {
        output.branch = bookmarks;
        return;
      }

      // Fall back to short change ID
      const changeId = (
        await $`${JJ} log -r @ --no-graph -T ${changeIdTpl}`
          .cwd(input.directory)
          .quiet()
          .nothrow()
          .text()
      ).trim();

      if (changeId) {
        output.branch = changeId;
      }
    },
  };
};

export default JjWorkspace;
