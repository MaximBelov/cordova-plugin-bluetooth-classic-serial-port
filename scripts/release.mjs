#!/usr/bin/env node
/* eslint-disable no-console */
// The git tag and the GitHub release of a version that is on npm. The publish job runs this after `npm publish`, and the same commands
// back-fill an older version by hand:
//
//   node scripts/release.mjs notes  <version>   the changelog's block for that version; fails when there is none, so no release is empty
//   node scripts/release.mjs commit <version>   the full sha of the first commit on the first-parent line of HEAD whose package.json
//                                               carries that version: the commit the version was published from, whichever run asks
import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');

/** The changelog of this repository: CHANGES.txt with `= 1.2.3 =` headings, or CHANGELOG.md with `## v1.2.3` headings. */
export function changelog(dir = root) {
  for (const name of ['CHANGES.txt', 'CHANGELOG.md']) {
    const path = join(dir, name);
    if (existsSync(path)) {
      return readFileSync(path, 'utf8');
    }
  }
  throw new Error('no CHANGES.txt or CHANGELOG.md');
}

const escape = (text) => text.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

/** The lines under the heading of `version`, up to the next heading, trimmed; null when the version has no heading. */
export function notesOf(text, version) {
  const lines = text.split('\n');
  const heading = new RegExp(`^(?:= ?v?${escape(version)} ?=|## v?${escape(version)})\\s*$`);
  const anyHeading = /^(?:= .+ =|## )/;
  const start = lines.findIndex((line) => heading.test(line));
  if (start === -1) {
    return null;
  }
  const rest = lines.slice(start + 1);
  const end = rest.findIndex((line) => anyHeading.test(line));
  const body = (end === -1 ? rest : rest.slice(0, end)).join('\n').trim();
  return body || null;
}

/** The first commit of HEAD's first-parent line, oldest first, whose package.json has `version`; null when none does. */
export function commitOf(version, dir = root) {
  const git = (...args) => execFileSync('git', args, { cwd: dir, encoding: 'utf8' }).trim();
  const commits = git('log', '--first-parent', '--reverse', '--format=%H', 'HEAD', '--', 'package.json').split('\n').filter(Boolean);
  for (const sha of commits) {
    try {
      if (JSON.parse(git('show', `${sha}:package.json`)).version === version) {
        return sha;
      }
    } catch {
      // a commit whose package.json does not parse carries no version
    }
  }
  return null;
}

if (import.meta.url === pathToFileURL(process.argv[1] ?? '').href) {
  const [command, version] = process.argv.slice(2);
  if (!['notes', 'commit'].includes(command) || !version) {
    console.error('usage: release.mjs notes <version> | release.mjs commit <version>');
    process.exit(2);
  }
  const answer = command === 'notes' ? notesOf(changelog(), version) : commitOf(version);
  if (!answer) {
    console.error(command === 'notes' ? `the changelog has no block for ${version}` : `no commit of HEAD carries ${version} in package.json`);
    process.exit(1);
  }
  console.log(answer);
}
