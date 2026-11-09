import { readFile, writeFile, mkdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';

const packages = [
  'react',
  'react-dom',
  '@tanstack/react-start',
  '@tanstack/react-router',
  'tailwindcss',
  'vite',
  'nitro',
  'node-appwrite',
];
const notices = [];
for (const name of packages) {
  let dir = dirname(fileURLToPath(import.meta.resolve(name)));
  while (dir !== '/') {
    try {
      const pkg = JSON.parse(await readFile(join(dir, 'package.json'), 'utf8'));
      if (pkg.name === name) {
        let text;
        for (const file of ['LICENSE', 'LICENSE.md', 'LICENSE.txt']) {
          try {
            text = await readFile(join(dir, file), 'utf8');
            break;
          } catch {
            /* Try the next conventional license filename. */
          }
        }
        if (!text) throw new Error(`License missing for ${name}`);
        notices.push(
          `=== ${name} ${pkg.version} (${pkg.license}) ===\n${text}`
        );
        break;
      }
    } catch (error) {
      if (error.message.startsWith('License missing')) throw error;
    }
    dir = dirname(dir);
  }
}
await mkdir('public/licenses', { recursive: true });
await writeFile(
  'public/licenses/software-notices.txt',
  notices
    .join('\n\n')
    .split('\n')
    .map((line) => line.trimEnd())
    .join('\n')
);
