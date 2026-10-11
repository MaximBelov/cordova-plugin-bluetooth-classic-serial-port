#!/usr/bin/env node
/**
 * Prints the name of an iPhone simulator to run the tests on, so no script has to know which one a machine has:
 *
 *   node test/ios/simulator.mjs              # iPhone 17 Pro       (the form xcodebuild takes)
 *   node test/ios/simulator.mjs --paramedic  # iPhone-17-Pro       (the form cordova-paramedic takes)
 *
 * IOS_SIMULATOR=<name> picks one by hand. Otherwise: an iPhone on the newest iOS runtime installed (never below iOS 16, the
 * minimum the plugin is tested on), a "Pro" one when there is one.
 */
import { execFileSync } from 'node:child_process';

const { devices } = JSON.parse(execFileSync('xcrun', ['simctl', 'list', 'devices', 'available', '-j'], { encoding: 'utf8' }));

const version = (runtime) => (/iOS-([\d-]+)$/.exec(runtime)?.[1] ?? '').split('-').map(Number);
const newestFirst = (a, b) => {
  for (let i = 0; i < Math.max(a.length, b.length); i++) {
    if ((b[i] ?? 0) !== (a[i] ?? 0)) return (b[i] ?? 0) - (a[i] ?? 0);
  }
  return 0;
};

const iphones = Object.entries(devices)
  .filter(([runtime]) => /SimRuntime\.iOS-/.test(runtime) && (version(runtime)[0] ?? 0) >= 16)
  .sort(([a], [b]) => newestFirst(version(a), version(b)))
  .flatMap(([, list]) => list.filter((device) => device.isAvailable && /^iPhone /.test(device.name)));

const name = process.env.IOS_SIMULATOR ?? (iphones.find((device) => /Pro$/.test(device.name)) ?? iphones[0])?.name;
if (!name) {
  console.error('no iPhone simulator is installed (Xcode > Settings > Components)');
  process.exit(1);
}
console.log(process.argv.includes('--paramedic') ? name.replaceAll(' ', '-') : name);
