import type { Hasher, LocalProviderUrlResolver } from '../definitions.js';
import type { FontFamily, ResolvedFontFamily } from '../types.js';
/**
 * Dedupes properties if applicable and resolves entrypoints.
 */
export declare function resolveFamily({ family, hasher, localProviderUrlResolver, }: {
    family: FontFamily;
    hasher: Hasher;
    localProviderUrlResolver: LocalProviderUrlResolver;
}): ResolvedFontFamily;
/**
 * A function for convenience. The actual logic lives in resolveFamily
 */
export declare function resolveFamilies({ families, ...dependencies }: {
    families: Array<FontFamily>;
} & Omit<Parameters<typeof resolveFamily>[0], 'family'>): Array<ResolvedFontFamily>;
