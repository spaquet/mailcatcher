import { createUnifont, defineFontProvider } from "unifont";
import { LOCAL_PROVIDER_NAME } from "../constants.js";
class UnifontFontResolver {
  #unifont;
  constructor({ unifont }) {
    this.#unifont = unifont;
  }
  static astroToUnifontProvider(astroProvider) {
    return defineFontProvider(astroProvider.name, async (_options, ctx) => {
      await astroProvider?.init?.(ctx);
      return {
        async resolveFont(familyName, options) {
          return await astroProvider.resolveFont({ familyName, ...options });
        },
        async listFonts() {
          return astroProvider.listFonts?.();
        }
      };
    })(astroProvider.config);
  }
  static extractUnifontProviders({
    families,
    hasher
  }) {
    const hashes = /* @__PURE__ */ new Set();
    const providers = [];
    for (const { provider } of families) {
      if (provider === LOCAL_PROVIDER_NAME) {
        continue;
      }
      const unifontProvider = this.astroToUnifontProvider(provider);
      const hash = hasher.hashObject({
        name: unifontProvider._name,
        ...provider.config
      });
      unifontProvider._name += `-${hash}`;
      provider.name = unifontProvider._name;
      if (!hashes.has(hash)) {
        hashes.add(hash);
        providers.push(unifontProvider);
      }
    }
    return providers;
  }
  static async create({
    families,
    hasher,
    storage
  }) {
    return new UnifontFontResolver({
      unifont: await createUnifont(this.extractUnifontProviders({ families, hasher }), {
        storage,
        // TODO: consider enabling, would require new astro errors
        throwOnError: false
      })
    });
  }
  async resolveFont({
    familyName,
    provider,
    ...rest
  }) {
    const { fonts } = await this.#unifont.resolveFont(familyName, rest, [provider]);
    return fonts;
  }
  async listFonts({ provider }) {
    return await this.#unifont.listFonts([provider]);
  }
}
export {
  UnifontFontResolver
};
