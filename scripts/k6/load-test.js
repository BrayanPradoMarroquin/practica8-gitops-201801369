import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Métricas custom para mayor granularidad en los reportes
const errorRate = new Rate('errors');
const healthLatency = new Trend('health_latency_ms');
const loginLatency = new Trend('login_latency_ms');

// Umbrales JUSTIFICADOS:
// - 95% de requests exitosos (error rate < 5%): permite fallos transitorios
//   durante la promoción sin abortar por un solo timeout.
// - p95 latencia < 500ms: umbral aceptable para UX en un servicio de auth.
// - p99 latencia < 1000ms: cubre el 1% de cola larga sin dejar pasar
//   regresiones graves de performance.
export const options = {
  scenarios: {
    smoke: {
      executor: 'constant-vus',
      vus: 3,
      duration: '30s',
      gracefulStop: '10s',
    },
  },
  thresholds: {
    'http_req_failed': ['rate<0.05'],
    'http_req_duration': ['p(95)<500', 'p(99)<1000'],
    'errors': ['rate<0.05'],
    'health_latency_ms': ['p(95)<300'],
    'login_latency_ms': ['p(95)<800'],
  },
  summaryTrendStats: ['avg', 'min', 'med', 'max', 'p(90)', 'p(95)', 'p(99)'],
};

const BASE_URL = __ENV.BASE_URL || 'http://auth-service.microservices.svc.cluster.local:3001';

export default function () {
  // 1) Health check
  const healthRes = http.get(`${BASE_URL}/health`);
  healthLatency.add(healthRes.timings.duration);

  const healthOk = check(healthRes, {
    'health: status 200': (r) => r.status === 200,
    'health: body status OK': (r) => {
      try {
        return JSON.parse(r.body).status === 'OK';
      } catch (e) {
        return false;
      }
    },
  });
  errorRate.add(!healthOk);

  // 2) Login (con credenciales ficticias; solo validamos que no sea 5xx)
  const loginRes = http.post(
    `${BASE_URL}/login`,
    JSON.stringify({ email: 'k6@test.local', password: 'k6-test-1234' }),
    { headers: { 'Content-Type': 'application/json' }, timeout: '5s' }
  );
  loginLatency.add(loginRes.timings.duration);

  const loginOk = check(loginRes, {
    'login: no server error': (r) => r.status < 500,
  });
  errorRate.add(!loginOk);

  // 3) Register (crea un usuario ficticio; no afecta si falla por duplicado)
  const registerRes = http.post(
    `${BASE_URL}/register`,
    JSON.stringify({
      email: `k6-${__VU}-${__ITER}@test.local`,
      password: 'k6-test-1234',
      name: 'k6 User',
    }),
    { headers: { 'Content-Type': 'application/json' }, timeout: '5s' }
  );
  const registerOk = check(registerRes, {
    'register: no server error': (r) => r.status < 500,
  });
  errorRate.add(!registerOk);

  sleep(1);
}

export function handleSummary(data) {
  return {
    '/tmp/summary.json': JSON.stringify(data),
    stdout: textSummary(data, { indent: ' ', enableColors: true }),
  };
}

import { textSummary } from 'https://jslib.k6.io/k6-summary/0.0.2/index.js';