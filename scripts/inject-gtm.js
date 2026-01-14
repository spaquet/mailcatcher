#!/usr/bin/env node

/**
 * Injects Google Tag Manager code into all HTML files in the docs directory.
 * This script:
 * 1. Adds the GTM script tag as high as possible in the <head> tag
 * 2. Adds the GTM noscript tag immediately after the opening <body> tag
 *
 * The GTM code remains identical across all pages.
 */

const fs = require('fs');
const path = require('path');

const GTM_ID = 'GTM-NN95GJ8G';

const GTM_HEAD_SCRIPT = `<!-- Google Tag Manager -->
<script>(function(w,d,s,l,i){w[l]=w[l]||[];w[l].push({'gtm.start':
new Date().getTime(),event:'gtm.js'});var f=d.getElementsByTagName(s)[0],
j=d.createElement(s),dl=l!='dataLayer'?'&l='+l:'';j.async=true;j.src=
'https://www.googletagmanager.com/gtm.js?id='+i+dl;f.parentNode.insertBefore(j,f);
})(window,document,'script','dataLayer','${GTM_ID}');</script>
<!-- End Google Tag Manager -->`;

const GTM_NOSCRIPT = `<!-- Google Tag Manager (noscript) -->
<noscript><iframe src="https://www.googletagmanager.com/ns.html?id=${GTM_ID}"
height="0" width="0" style="display:none;visibility:hidden"></iframe></noscript>
<!-- End Google Tag Manager (noscript) -->`;

/**
 * Recursively finds all HTML files in a directory
 * @param {string} dir - Directory path
 * @returns {string[]} Array of file paths
 */
function findHtmlFiles(dir) {
  const files = [];

  function traverse(currentPath) {
    const entries = fs.readdirSync(currentPath, { withFileTypes: true });

    entries.forEach(entry => {
      const fullPath = path.join(currentPath, entry.name);

      if (entry.isDirectory() && entry.name !== 'node_modules') {
        traverse(fullPath);
      } else if (entry.isFile() && entry.name.endsWith('.html')) {
        files.push(fullPath);
      }
    });
  }

  traverse(dir);
  return files;
}

/**
 * Injects GTM code into an HTML file
 * @param {string} filePath - Path to the HTML file
 */
function injectGTM(filePath) {
  let content = fs.readFileSync(filePath, 'utf8');

  // Skip if GTM is already present
  if (content.includes(`GTM-${GTM_ID}`)) {
    console.log(`✓ Skipped ${path.relative(process.cwd(), filePath)} (GTM already present)`);
    return;
  }

  // Inject in <head> - insert after opening <head> tag, before other content
  const headRegex = /<head[^>]*>/i;
  const headMatch = content.match(headRegex);

  if (headMatch) {
    const headTag = headMatch[0];
    const insertionPoint = content.indexOf(headTag) + headTag.length;
    content = content.slice(0, insertionPoint) + '\n    ' + GTM_HEAD_SCRIPT + '\n' + content.slice(insertionPoint);
  } else {
    console.warn(`⚠ Warning: Could not find <head> tag in ${filePath}`);
    return;
  }

  // Inject in <body> - insert after opening <body> tag
  const bodyRegex = /<body[^>]*>/i;
  const bodyMatch = content.match(bodyRegex);

  if (bodyMatch) {
    const bodyTag = bodyMatch[0];
    const insertionPoint = content.indexOf(bodyTag) + bodyTag.length;
    content = content.slice(0, insertionPoint) + '\n    ' + GTM_NOSCRIPT + '\n' + content.slice(insertionPoint);
  } else {
    console.warn(`⚠ Warning: Could not find <body> tag in ${filePath}`);
    return;
  }

  fs.writeFileSync(filePath, content, 'utf8');
  console.log(`✓ Injected GTM into ${path.relative(process.cwd(), filePath)}`);
}

/**
 * Main function
 */
function main() {
  const docsDir = path.join(__dirname, '..', 'docs');

  // Check if docs directory exists
  if (!fs.existsSync(docsDir)) {
    console.error(`✗ Error: docs directory not found at ${docsDir}`);
    process.exit(1);
  }

  // Find all HTML files in the docs directory
  const htmlFiles = findHtmlFiles(docsDir);

  if (htmlFiles.length === 0) {
    console.warn('⚠ Warning: No HTML files found in docs directory');
    process.exit(0);
  }

  console.log(`Found ${htmlFiles.length} HTML file(s) to process\n`);

  htmlFiles.forEach(file => {
    injectGTM(file);
  });

  console.log(`\n✓ GTM injection completed for all ${htmlFiles.length} file(s)`);
}

main();
