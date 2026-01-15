import {
  providers
} from "unifont";
function adobe(config) {
  const provider = providers.adobe(config);
  let initializedProvider;
  return {
    name: provider._name,
    config,
    async init(context) {
      initializedProvider = await provider(context);
    },
    async resolveFont({ familyName, ...rest }) {
      return await initializedProvider?.resolveFont(familyName, rest);
    },
    async listFonts() {
      return await initializedProvider?.listFonts?.();
    }
  };
}
function bunny() {
  const provider = providers.bunny();
  let initializedProvider;
  return {
    name: provider._name,
    async init(context) {
      initializedProvider = await provider(context);
    },
    async resolveFont({ familyName, ...rest }) {
      return await initializedProvider?.resolveFont(familyName, rest);
    },
    async listFonts() {
      return await initializedProvider?.listFonts?.();
    }
  };
}
function fontshare() {
  const provider = providers.fontshare();
  let initializedProvider;
  return {
    name: provider._name,
    async init(context) {
      initializedProvider = await provider(context);
    },
    async resolveFont({ familyName, ...rest }) {
      return await initializedProvider?.resolveFont(familyName, rest);
    },
    async listFonts() {
      return await initializedProvider?.listFonts?.();
    }
  };
}
function fontsource() {
  const provider = providers.fontsource();
  let initializedProvider;
  return {
    name: provider._name,
    async init(context) {
      initializedProvider = await provider(context);
    },
    async resolveFont({ familyName, ...rest }) {
      return await initializedProvider?.resolveFont(familyName, rest);
    },
    async listFonts() {
      return await initializedProvider?.listFonts?.();
    }
  };
}
function google(config) {
  const provider = providers.google(config);
  let initializedProvider;
  return {
    name: provider._name,
    config,
    async init(context) {
      initializedProvider = await provider(context);
    },
    async resolveFont({ familyName, ...rest }) {
      return await initializedProvider?.resolveFont(familyName, rest);
    },
    async listFonts() {
      return await initializedProvider?.listFonts?.();
    }
  };
}
function googleicons(config) {
  const provider = providers.googleicons(config);
  let initializedProvider;
  return {
    name: provider._name,
    config,
    async init(context) {
      initializedProvider = await provider(context);
    },
    async resolveFont({ familyName, ...rest }) {
      return await initializedProvider?.resolveFont(familyName, rest);
    },
    async listFonts() {
      return await initializedProvider?.listFonts?.();
    }
  };
}
const fontProviders = {
  adobe,
  bunny,
  fontshare,
  fontsource,
  google,
  googleicons
};
export {
  fontProviders
};
