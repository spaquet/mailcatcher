import { z } from 'zod';
export declare const weightSchema: z.ZodUnion<[z.ZodString, z.ZodNumber]>;
export declare const styleSchema: z.ZodEnum<["normal", "italic", "oblique"]>;
export declare const displaySchema: z.ZodEnum<["auto", "block", "swap", "fallback", "optional"]>;
export declare const localFontFamilySchema: z.ZodObject<{
    provider: z.ZodLiteral<"local">;
    variants: z.ZodArray<z.ZodObject<{
        src: z.ZodArray<z.ZodUnion<[z.ZodUnion<[z.ZodString, z.ZodType<URL, z.ZodTypeDef, URL>]>, z.ZodObject<{
            url: z.ZodUnion<[z.ZodString, z.ZodType<URL, z.ZodTypeDef, URL>]>;
            tech: z.ZodOptional<z.ZodString>;
        }, "strict", z.ZodTypeAny, {
            url: string | URL;
            tech?: string | undefined;
        }, {
            url: string | URL;
            tech?: string | undefined;
        }>]>, "atleastone">;
        weight: z.ZodOptional<z.ZodUnion<[z.ZodString, z.ZodNumber]>>;
        style: z.ZodOptional<z.ZodEnum<["normal", "italic", "oblique"]>>;
        display: z.ZodOptional<z.ZodEnum<["auto", "block", "swap", "fallback", "optional"]>>;
        stretch: z.ZodOptional<z.ZodString>;
        featureSettings: z.ZodOptional<z.ZodString>;
        variationSettings: z.ZodOptional<z.ZodString>;
        unicodeRange: z.ZodOptional<z.ZodArray<z.ZodString, "atleastone">>;
    }, "strict", z.ZodTypeAny, {
        src: [string | URL | {
            url: string | URL;
            tech?: string | undefined;
        }, ...(string | URL | {
            url: string | URL;
            tech?: string | undefined;
        })[]];
        weight?: string | number | undefined;
        style?: "normal" | "italic" | "oblique" | undefined;
        display?: "auto" | "block" | "swap" | "fallback" | "optional" | undefined;
        stretch?: string | undefined;
        featureSettings?: string | undefined;
        variationSettings?: string | undefined;
        unicodeRange?: [string, ...string[]] | undefined;
    }, {
        src: [string | URL | {
            url: string | URL;
            tech?: string | undefined;
        }, ...(string | URL | {
            url: string | URL;
            tech?: string | undefined;
        })[]];
        weight?: string | number | undefined;
        style?: "normal" | "italic" | "oblique" | undefined;
        display?: "auto" | "block" | "swap" | "fallback" | "optional" | undefined;
        stretch?: string | undefined;
        featureSettings?: string | undefined;
        variationSettings?: string | undefined;
        unicodeRange?: [string, ...string[]] | undefined;
    }>, "atleastone">;
    fallbacks: z.ZodOptional<z.ZodArray<z.ZodString, "many">>;
    optimizedFallbacks: z.ZodOptional<z.ZodBoolean>;
    name: z.ZodString;
    cssVariable: z.ZodString;
}, "strict", z.ZodTypeAny, {
    provider: "local";
    name: string;
    cssVariable: string;
    variants: [{
        src: [string | URL | {
            url: string | URL;
            tech?: string | undefined;
        }, ...(string | URL | {
            url: string | URL;
            tech?: string | undefined;
        })[]];
        weight?: string | number | undefined;
        style?: "normal" | "italic" | "oblique" | undefined;
        display?: "auto" | "block" | "swap" | "fallback" | "optional" | undefined;
        stretch?: string | undefined;
        featureSettings?: string | undefined;
        variationSettings?: string | undefined;
        unicodeRange?: [string, ...string[]] | undefined;
    }, ...{
        src: [string | URL | {
            url: string | URL;
            tech?: string | undefined;
        }, ...(string | URL | {
            url: string | URL;
            tech?: string | undefined;
        })[]];
        weight?: string | number | undefined;
        style?: "normal" | "italic" | "oblique" | undefined;
        display?: "auto" | "block" | "swap" | "fallback" | "optional" | undefined;
        stretch?: string | undefined;
        featureSettings?: string | undefined;
        variationSettings?: string | undefined;
        unicodeRange?: [string, ...string[]] | undefined;
    }[]];
    fallbacks?: string[] | undefined;
    optimizedFallbacks?: boolean | undefined;
}, {
    provider: "local";
    name: string;
    cssVariable: string;
    variants: [{
        src: [string | URL | {
            url: string | URL;
            tech?: string | undefined;
        }, ...(string | URL | {
            url: string | URL;
            tech?: string | undefined;
        })[]];
        weight?: string | number | undefined;
        style?: "normal" | "italic" | "oblique" | undefined;
        display?: "auto" | "block" | "swap" | "fallback" | "optional" | undefined;
        stretch?: string | undefined;
        featureSettings?: string | undefined;
        variationSettings?: string | undefined;
        unicodeRange?: [string, ...string[]] | undefined;
    }, ...{
        src: [string | URL | {
            url: string | URL;
            tech?: string | undefined;
        }, ...(string | URL | {
            url: string | URL;
            tech?: string | undefined;
        })[]];
        weight?: string | number | undefined;
        style?: "normal" | "italic" | "oblique" | undefined;
        display?: "auto" | "block" | "swap" | "fallback" | "optional" | undefined;
        stretch?: string | undefined;
        featureSettings?: string | undefined;
        variationSettings?: string | undefined;
        unicodeRange?: [string, ...string[]] | undefined;
    }[]];
    fallbacks?: string[] | undefined;
    optimizedFallbacks?: boolean | undefined;
}>;
export declare const fontProviderSchema: z.ZodObject<{
    name: z.ZodString;
    config: z.ZodOptional<z.ZodRecord<z.ZodString, z.ZodAny>>;
    init: z.ZodOptional<z.ZodType<((context: import("./types.js").FontProviderInitContext) => void | Promise<void>) | undefined, z.ZodTypeDef, ((context: import("./types.js").FontProviderInitContext) => void | Promise<void>) | undefined>>;
    resolveFont: z.ZodType<(options: import("./types.js").ResolveFontOptions) => {
        fonts: Array<import("unifont").FontFaceData>;
    } | Promise<{
        fonts: Array<import("unifont").FontFaceData>;
    } | undefined> | undefined, z.ZodTypeDef, (options: import("./types.js").ResolveFontOptions) => {
        fonts: Array<import("unifont").FontFaceData>;
    } | Promise<{
        fonts: Array<import("unifont").FontFaceData>;
    } | undefined> | undefined>;
    listFonts: z.ZodOptional<z.ZodType<(() => string[] | Promise<string[] | undefined> | undefined) | undefined, z.ZodTypeDef, (() => string[] | Promise<string[] | undefined> | undefined) | undefined>>;
}, "strict", z.ZodTypeAny, {
    name: string;
    resolveFont: (options: import("./types.js").ResolveFontOptions) => {
        fonts: Array<import("unifont").FontFaceData>;
    } | Promise<{
        fonts: Array<import("unifont").FontFaceData>;
    } | undefined> | undefined;
    config?: Record<string, any> | undefined;
    init?: ((context: import("./types.js").FontProviderInitContext) => void | Promise<void>) | undefined;
    listFonts?: (() => string[] | Promise<string[] | undefined> | undefined) | undefined;
}, {
    name: string;
    resolveFont: (options: import("./types.js").ResolveFontOptions) => {
        fonts: Array<import("unifont").FontFaceData>;
    } | Promise<{
        fonts: Array<import("unifont").FontFaceData>;
    } | undefined> | undefined;
    config?: Record<string, any> | undefined;
    init?: ((context: import("./types.js").FontProviderInitContext) => void | Promise<void>) | undefined;
    listFonts?: (() => string[] | Promise<string[] | undefined> | undefined) | undefined;
}>;
export declare const remoteFontFamilySchema: z.ZodObject<{
    provider: z.ZodObject<{
        name: z.ZodString;
        config: z.ZodOptional<z.ZodRecord<z.ZodString, z.ZodAny>>;
        init: z.ZodOptional<z.ZodType<((context: import("./types.js").FontProviderInitContext) => void | Promise<void>) | undefined, z.ZodTypeDef, ((context: import("./types.js").FontProviderInitContext) => void | Promise<void>) | undefined>>;
        resolveFont: z.ZodType<(options: import("./types.js").ResolveFontOptions) => {
            fonts: Array<import("unifont").FontFaceData>;
        } | Promise<{
            fonts: Array<import("unifont").FontFaceData>;
        } | undefined> | undefined, z.ZodTypeDef, (options: import("./types.js").ResolveFontOptions) => {
            fonts: Array<import("unifont").FontFaceData>;
        } | Promise<{
            fonts: Array<import("unifont").FontFaceData>;
        } | undefined> | undefined>;
        listFonts: z.ZodOptional<z.ZodType<(() => string[] | Promise<string[] | undefined> | undefined) | undefined, z.ZodTypeDef, (() => string[] | Promise<string[] | undefined> | undefined) | undefined>>;
    }, "strict", z.ZodTypeAny, {
        name: string;
        resolveFont: (options: import("./types.js").ResolveFontOptions) => {
            fonts: Array<import("unifont").FontFaceData>;
        } | Promise<{
            fonts: Array<import("unifont").FontFaceData>;
        } | undefined> | undefined;
        config?: Record<string, any> | undefined;
        init?: ((context: import("./types.js").FontProviderInitContext) => void | Promise<void>) | undefined;
        listFonts?: (() => string[] | Promise<string[] | undefined> | undefined) | undefined;
    }, {
        name: string;
        resolveFont: (options: import("./types.js").ResolveFontOptions) => {
            fonts: Array<import("unifont").FontFaceData>;
        } | Promise<{
            fonts: Array<import("unifont").FontFaceData>;
        } | undefined> | undefined;
        config?: Record<string, any> | undefined;
        init?: ((context: import("./types.js").FontProviderInitContext) => void | Promise<void>) | undefined;
        listFonts?: (() => string[] | Promise<string[] | undefined> | undefined) | undefined;
    }>;
    weights: z.ZodOptional<z.ZodArray<z.ZodUnion<[z.ZodString, z.ZodNumber]>, "atleastone">>;
    styles: z.ZodOptional<z.ZodArray<z.ZodEnum<["normal", "italic", "oblique"]>, "atleastone">>;
    subsets: z.ZodOptional<z.ZodArray<z.ZodString, "atleastone">>;
    formats: z.ZodOptional<z.ZodArray<z.ZodEnum<["woff2", "woff", "otf", "ttf", "eot"]>, "atleastone">>;
    display: z.ZodOptional<z.ZodEnum<["auto", "block", "swap", "fallback", "optional"]>>;
    stretch: z.ZodOptional<z.ZodString>;
    featureSettings: z.ZodOptional<z.ZodString>;
    variationSettings: z.ZodOptional<z.ZodString>;
    unicodeRange: z.ZodOptional<z.ZodArray<z.ZodString, "atleastone">>;
    fallbacks: z.ZodOptional<z.ZodArray<z.ZodString, "many">>;
    optimizedFallbacks: z.ZodOptional<z.ZodBoolean>;
    name: z.ZodString;
    cssVariable: z.ZodString;
}, "strict", z.ZodTypeAny, {
    provider: {
        name: string;
        resolveFont: (options: import("./types.js").ResolveFontOptions) => {
            fonts: Array<import("unifont").FontFaceData>;
        } | Promise<{
            fonts: Array<import("unifont").FontFaceData>;
        } | undefined> | undefined;
        config?: Record<string, any> | undefined;
        init?: ((context: import("./types.js").FontProviderInitContext) => void | Promise<void>) | undefined;
        listFonts?: (() => string[] | Promise<string[] | undefined> | undefined) | undefined;
    };
    name: string;
    cssVariable: string;
    weights?: [string | number, ...(string | number)[]] | undefined;
    styles?: ["normal" | "italic" | "oblique", ...("normal" | "italic" | "oblique")[]] | undefined;
    subsets?: [string, ...string[]] | undefined;
    fallbacks?: string[] | undefined;
    optimizedFallbacks?: boolean | undefined;
    formats?: ["woff2" | "woff" | "otf" | "ttf" | "eot", ...("woff2" | "woff" | "otf" | "ttf" | "eot")[]] | undefined;
    display?: "auto" | "block" | "swap" | "fallback" | "optional" | undefined;
    stretch?: string | undefined;
    featureSettings?: string | undefined;
    variationSettings?: string | undefined;
    unicodeRange?: [string, ...string[]] | undefined;
}, {
    provider: {
        name: string;
        resolveFont: (options: import("./types.js").ResolveFontOptions) => {
            fonts: Array<import("unifont").FontFaceData>;
        } | Promise<{
            fonts: Array<import("unifont").FontFaceData>;
        } | undefined> | undefined;
        config?: Record<string, any> | undefined;
        init?: ((context: import("./types.js").FontProviderInitContext) => void | Promise<void>) | undefined;
        listFonts?: (() => string[] | Promise<string[] | undefined> | undefined) | undefined;
    };
    name: string;
    cssVariable: string;
    weights?: [string | number, ...(string | number)[]] | undefined;
    styles?: ["normal" | "italic" | "oblique", ...("normal" | "italic" | "oblique")[]] | undefined;
    subsets?: [string, ...string[]] | undefined;
    fallbacks?: string[] | undefined;
    optimizedFallbacks?: boolean | undefined;
    formats?: ["woff2" | "woff" | "otf" | "ttf" | "eot", ...("woff2" | "woff" | "otf" | "ttf" | "eot")[]] | undefined;
    display?: "auto" | "block" | "swap" | "fallback" | "optional" | undefined;
    stretch?: string | undefined;
    featureSettings?: string | undefined;
    variationSettings?: string | undefined;
    unicodeRange?: [string, ...string[]] | undefined;
}>;
