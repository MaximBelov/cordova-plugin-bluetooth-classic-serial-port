// scripts/release.mjs: the notes and the commit of a published version's tag and GitHub release, and the publish step that uses them.
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { changelog, commitOf, notesOf } from '../../scripts/release.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '..', '..');
const read = (path) => readFileSync(join(root, path), 'utf8');
const pkg = JSON.parse(read('package.json'));
const workflowText = read('.github/workflows/ci.yaml');

test('the changelog has a block for the version in package.json, so its release is never empty', () => {
  const notes = notesOf(changelog(root), pkg.version);
  assert.ok(notes, `no block for ${pkg.version}`);
});

test('notes are the lines under one heading, in either changelog form, and nothing for a version that has none', () => {
  const txt = '= next =\nlater\n\n= 1.1.0 =\na\nb\n\n= 1.0.0 =\nc\n';
  assert.equal(notesOf(txt, '1.1.0'), 'a\nb');
  assert.equal(notesOf(txt, '1.0.0'), 'c');
  const md = '# Changelog\n\n## v1.3.1\n\n- one\n\n## v1.3.0\n\n- two\n';
  assert.equal(notesOf(md, '1.3.1'), '- one');
  assert.equal(notesOf(md, '1.3.0'), '- two');
  assert.equal(notesOf(txt, '9.9.9'), null);
  assert.equal(notesOf('= 1.0.0 =\n\n= 0.9.0 =\nx\n', '1.0.0'), null, 'an empty block is no notes');
  assert.equal(notesOf('= 1.0.10 =\nx\n', '1.0.1'), null, 'a version is matched whole');
  assert.equal(notesOf('## v1.0.10\n\n- x\n', '1.0.1'), null, 'a version is matched whole in a markdown heading too');
});

test('the commit of a version is the first one on the first-parent line that carries it', () => {
  const dir = mkdtempSync(join(tmpdir(), 'release-'));
  try {
    const git = (...args) =>
      execFileSync('git', ['-c', 'user.name=test', '-c', 'user.email=test@example.com', '-c', 'commit.gpgsign=false', ...args], { cwd: dir, encoding: 'utf8' }).trim();
    git('init', '-q', '-b', 'main');
    const commit = (version, message) => {
      writeFileSync(join(dir, 'package.json'), JSON.stringify({ version }));
      writeFileSync(join(dir, 'note'), message);
      git('add', '-A');
      git('commit', '-q', '-m', message);
      return git('rev-parse', 'HEAD');
    };
    commit('1.0.0', 'first');
    const bump = commit('1.1.0', 'bump');
    // a later change to package.json that keeps the version: the bump stays the commit of 1.1.0
    writeFileSync(join(dir, 'package.json'), JSON.stringify({ version: '1.1.0', description: 'later' }));
    git('commit', '-q', '-am', 'later');
    assert.equal(commitOf('1.1.0', dir), bump);
    assert.equal(commitOf('2.0.0', dir), null);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('the publish job can tag and release: full history, write access, and the step that does it', () => {
  const publish = workflowText.slice(workflowText.indexOf('\n  publish:'));
  assert.match(publish, /contents: write/);
  assert.match(publish, /fetch-depth: 0/);
  assert.match(publish, /node scripts\/release\.mjs commit "\$version"/);
  assert.match(publish, /node scripts\/release\.mjs notes "\$version"/);
  assert.match(publish, /gh release create "\$tag" --verify-tag/);
});
