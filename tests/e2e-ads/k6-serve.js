import http from 'k6/http'
import { check, sleep } from 'k6'

export const options = {
  vus: 200,
  duration: '60s',
  thresholds: {
    http_req_failed: ['rate<0.01'],
    http_req_duration: ['p(95)<200']
  }
}

export default function () {
  const url = __ENV.ADS_BASE_URL || 'http://localhost:9093/ads/serve'
  const payload = JSON.stringify({ key: 'test_key', placement:'preroll', locale:'en-US', device:'ios', videoContext:{ tags:['gaming'], topic:'gaming' } })
  const res = http.post(url, payload, { headers: { 'content-type':'application/json' } })
  check(res, { '200': r => r.status === 200 })
  sleep(0.1)
}



