import type { Logger } from '../../core/logger/core.js';
import type { CssRenderer, FontFileReader, FontMetricsResolver, FontResolver, FontTypeExtractor, Hasher, LocalProviderUrlResolver, StringMatcher, SystemFallbacksProvider, UrlProxy } from './definitions.js';
import type { ConsumableMap, CreateUrlProxyParams, Defaults, FontFamily, FontFileDataMap, InternalConsumableMap, ResolvedFontFamily } from './types.js';
/**
 * Manages how fonts are resolved:
 *
 * - families are resolved
 * - font resolver is initialized
 *
 * For each family:
 * - We create a URL proxy
 * - We resolve the font and normalize the result
 *
 * For each resolved font:
 * - We generate the CSS font face
 * - We generate optimized fallbacks if applicable
 * - We generate CSS variables
 *
 * Once that's done, the collected data is returned
 */
export declare function orchestrate({ families, hasher, localProviderUrlResolver, cssRenderer, systemFallbacksProvider, fontMetricsResolver, fontTypeExtractor, fontFileReader, logger, createUrlProxy, defaults, bold, stringMatcher, createFontResolver, }: {
    families: Array<FontFamily>;
    hasher: Hasher;
    localProviderUrlResolver: LocalProviderUrlResolver;
    cssRenderer: CssRenderer;
    systemFallbacksProvider: SystemFallbacksProvider;
    fontMetricsResolver: FontMetricsResolver;
    fontTypeExtractor: FontTypeExtractor;
    fontFileReader: FontFileReader;
    logger: Logger;
    createUrlProxy: (params: CreateUrlProxyParams) => UrlProxy;
    defaults: Defaults;
    bold: (input: string) => string;
    stringMatcher: StringMatcher;
    createFontResolver: (params: {
        families: Array<ResolvedFontFamily>;
    }) => Promise<FontResolver>;
}): Promise<{
    fontFileDataMap: FontFileDataMap;
    internalConsumableMap: InternalConsumableMap;
    consumableMap: ConsumableMap;
}>;
