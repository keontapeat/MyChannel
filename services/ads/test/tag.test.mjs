// Verifies the embeddable tag JS is syntactically valid JavaScript and
// contains the required AdSense-parity hooks.
import assert from 'assert'
import vm from 'vm'

// Pull the TAG_JS string out of the module without starting Fastify.
import { readFileSync } from 'fs'
const src = readFileSync(new URL('../src/routes/tag.js', import.meta.url), 'utf8')
const start = src.indexOf('const TAG_JS = `') + 'const TAG_JS = `'.length
const end = src.indexOf('`', start)
const tag = src.slice(start, end).replace('__API_BASE__', 'https://ads.example.com')

let pass = 0
function ok(n, c){ assert.ok(c, n); console.log('  ✓ ' + n); pass++ }

// Compile the tag in a fake browser-ish context to catch syntax errors.
const sandbox = { window: {}, document: { readyState: 'complete', addEventListener(){}, querySelectorAll(){ return [] }, currentScript: { src: 'https://ads.example.com/mca.js?client=pub-1' } }, URL, fetch: async()=>({json:async()=>({fill:false})}), Image: function(){}, IntersectionObserver: function(){ this.observe=()=>{}; this.disconnect=()=>{} }, location: { href:'https://site.test' }, setTimeout, encodeURIComponent }
vm.createContext(sandbox)
vm.runInContext(tag, sandbox)

ok('tag compiles and runs without throwing', true)
ok('exposes adsbymychannel push API', typeof sandbox.window.adsbymychannel.push === 'function')
ok('tag references the push pattern', tag.includes('adsbymychannel'))
ok('tag fires impression + viewability pings', tag.includes('impPing') && tag.includes('viewPing'))
ok('tag renders Ad badge for transparency', tag.includes('"Ad"'))

console.log('\\nALL TAG TESTS PASSED (' + pass + ')')
