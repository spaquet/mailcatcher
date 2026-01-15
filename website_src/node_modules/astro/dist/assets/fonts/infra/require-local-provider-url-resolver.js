import { createRequire } from "node:module";
import { fileURLToPath, pathToFileURL } from "node:url";
class RequireLocalProviderUrlResolver {
  #root;
  // TODO: remove when stabilizing
  #intercept;
  constructor({
    root,
    intercept
  }) {
    this.#root = root;
    this.#intercept = intercept;
  }
  #resolveEntrypoint(root, entrypoint) {
    const require2 = createRequire(root);
    try {
      return pathToFileURL(require2.resolve(entrypoint));
    } catch {
      return new URL(entrypoint, root);
    }
  }
  resolve(input) {
    const path = fileURLToPath(this.#resolveEntrypoint(this.#root, input));
    this.#intercept?.(path);
    return path;
  }
}
export {
  RequireLocalProviderUrlResolver
};
