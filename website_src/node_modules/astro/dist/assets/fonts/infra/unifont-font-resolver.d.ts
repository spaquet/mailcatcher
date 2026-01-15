import type { FontFaceData, Provider } from 'unifont';
import type { FontResolver, Hasher, Storage } from '../definitions.js';
import type { FontProvider, ResolvedFontFamily, ResolveFontOptions } from '../types.js';
type NonEmptyProviders = [Provider, ...Array<Provider>];
export declare class UnifontFontResolver implements FontResolver {
    #private;
    private constructor();
    static astroToUnifontProvider(astroProvider: FontProvider): Provider;
    static extractUnifontProviders({ families, hasher, }: {
        families: Array<ResolvedFontFamily>;
        hasher: Hasher;
    }): NonEmptyProviders;
    static create({ families, hasher, storage, }: {
        families: Array<ResolvedFontFamily>;
        hasher: Hasher;
        storage: Storage;
    }): Promise<UnifontFontResolver>;
    resolveFont({ familyName, provider, ...rest }: ResolveFontOptions & {
        provider: string;
    }): Promise<Array<FontFaceData>>;
    listFonts({ provider }: {
        provider: string;
    }): Promise<string[] | undefined>;
}
export {};
