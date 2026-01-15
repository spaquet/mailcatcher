import { z } from "zod";
import { FONT_TYPES, LOCAL_PROVIDER_NAME } from "./constants.js";
const weightSchema = z.union([z.string(), z.number()]);
const styleSchema = z.enum(["normal", "italic", "oblique"]);
const displaySchema = z.enum(["auto", "block", "swap", "fallback", "optional"]);
const familyPropertiesSchema = z.object({
  weight: weightSchema.optional(),
  style: styleSchema.optional(),
  display: displaySchema.optional(),
  stretch: z.string().optional(),
  featureSettings: z.string().optional(),
  variationSettings: z.string().optional(),
  unicodeRange: z.array(z.string()).nonempty().optional()
});
const fallbacksSchema = z.object({
  fallbacks: z.array(z.string()).optional(),
  optimizedFallbacks: z.boolean().optional()
});
const requiredFamilyAttributesSchema = z.object({
  name: z.string(),
  cssVariable: z.string()
});
const entrypointSchema = z.union([z.string(), z.instanceof(URL)]);
const localFontFamilySchema = z.object({
  ...requiredFamilyAttributesSchema.shape,
  ...fallbacksSchema.shape,
  provider: z.literal(LOCAL_PROVIDER_NAME),
  variants: z.array(
    z.object({
      ...familyPropertiesSchema.shape,
      src: z.array(
        z.union([
          entrypointSchema,
          z.object({ url: entrypointSchema, tech: z.string().optional() }).strict()
        ])
      ).nonempty()
      // TODO: find a way to support subsets (through fontkit?)
    }).strict()
  ).nonempty()
}).strict();
const fontProviderSchema = z.object({
  name: z.string(),
  config: z.record(z.string(), z.any()).optional(),
  init: z.custom((v) => typeof v === "function").optional(),
  resolveFont: z.custom((v) => typeof v === "function"),
  listFonts: z.custom((v) => typeof v === "function").optional()
}).strict();
const remoteFontFamilySchema = z.object({
  ...requiredFamilyAttributesSchema.shape,
  ...fallbacksSchema.shape,
  ...familyPropertiesSchema.omit({
    weight: true,
    style: true
  }).shape,
  provider: fontProviderSchema,
  weights: z.array(weightSchema).nonempty().optional(),
  styles: z.array(styleSchema).nonempty().optional(),
  subsets: z.array(z.string()).nonempty().optional(),
  formats: z.array(z.enum(FONT_TYPES)).nonempty().optional()
}).strict();
export {
  displaySchema,
  fontProviderSchema,
  localFontFamilySchema,
  remoteFontFamilySchema,
  styleSchema,
  weightSchema
};
