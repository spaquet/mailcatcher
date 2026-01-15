import { type AdobeProviderOptions, type GoogleiconsOptions, type GoogleOptions } from 'unifont';
import type { FontProvider } from '../types.js';
/** [Adobe](https://fonts.adobe.com/) */
declare function adobe(config: AdobeProviderOptions): FontProvider;
/** [Bunny](https://fonts.bunny.net/) */
declare function bunny(): FontProvider;
/** [Fontshare](https://www.fontshare.com/) */
declare function fontshare(): FontProvider;
/** [Fontsource](https://fontsource.org/) */
declare function fontsource(): FontProvider;
/** [Google](https://fonts.google.com/) */
declare function google(config?: GoogleOptions): FontProvider;
/** [Google Icons](https://fonts.google.com/icons) */
declare function googleicons(config?: GoogleiconsOptions): FontProvider;
/**
 * Astro re-exports most [unifont](https://github.com/unjs/unifont/) providers:
 * - [Adobe](https://fonts.adobe.com/)
 * - [Bunny](https://fonts.bunny.net/)
 * - [Fontshare](https://www.fontshare.com/)
 * - [Fontsource](https://fontsource.org/)
 * - [Google](https://fonts.google.com/)
 * - [Google Icons](https://fonts.google.com/icons)
 */
export declare const fontProviders: {
    adobe: typeof adobe;
    bunny: typeof bunny;
    fontshare: typeof fontshare;
    fontsource: typeof fontsource;
    google: typeof google;
    googleicons: typeof googleicons;
};
export {};
