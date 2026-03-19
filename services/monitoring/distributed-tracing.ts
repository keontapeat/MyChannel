/**
 * Distributed Tracing Service
 * Track requests across all services
 */

import { trace, context, SpanStatusCode } from '@opentelemetry/api';
import { NodeTracerProvider } from '@opentelemetry/sdk-trace-node';
import { registerInstrumentations } from '@opentelemetry/instrumentation';
import { HttpInstrumentation } from '@opentelemetry/instrumentation-http';
import { ExpressInstrumentation } from '@opentelemetry/instrumentation-express';
import { Resource } from '@opentelemetry/resources';
import { SemanticResourceAttributes } from '@opentelemetry/semantic-conventions';

const tracer = trace.getTracer('mychannel-service');

export class DistributedTracingService {
  private provider: NodeTracerProvider;

  constructor() {
    this.provider = new NodeTracerProvider({
      resource: new Resource({
        [SemanticResourceAttributes.SERVICE_NAME]: 'mychannel',
        [SemanticResourceAttributes.SERVICE_VERSION]: '1.0.0',
      }),
    });

    this.setupInstrumentations();
    this.provider.register();

    console.log('🔍 [Tracing] Distributed tracing initialized');
  }

  private setupInstrumentations() {
    registerInstrumentations({
      instrumentations: [
        new HttpInstrumentation(),
        new ExpressInstrumentation(),
      ],
    });
  }

  /**
   * Create a new span for tracking operation
   */
  async trace<T>(
    name: string,
    operation: () => Promise<T>,
    attributes?: Record<string, any>
  ): Promise<T> {
    const span = tracer.startSpan(name, {
      attributes: attributes || {},
    });

    const startTime = Date.now();

    try {
      const result = await context.with(trace.setSpan(context.active(), span), operation);
      
      const duration = Date.now() - startTime;
      span.setAttribute('duration_ms', duration);
      span.setStatus({ code: SpanStatusCode.OK });
      
      console.log(`✅ [Trace] ${name} completed in ${duration}ms`);
      
      return result;
    } catch (error) {
      span.setStatus({
        code: SpanStatusCode.ERROR,
        message: error instanceof Error ? error.message : 'Unknown error',
      });
      
      span.recordException(error as Error);
      throw error;
    } finally {
      span.end();
    }
  }

  /**
   * Add custom attributes to current span
   */
  addAttributes(attributes: Record<string, any>): void {
    const span = trace.getActiveSpan();
    if (span) {
      Object.entries(attributes).forEach(([key, value]) => {
        span.setAttribute(key, value);
      });
    }
  }

  /**
   * Record an event in the current span
   */
  recordEvent(name: string, attributes?: Record<string, any>): void {
    const span = trace.getActiveSpan();
    if (span) {
      span.addEvent(name, attributes);
    }
  }
}

export const tracingService = new DistributedTracingService();
export default tracingService;
