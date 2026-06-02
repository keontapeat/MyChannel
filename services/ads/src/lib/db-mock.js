/**
 * Mock Database Adapter
 * In-memory storage for development when Firestore credentials aren't available.
 * Data is lost on restart - use only for testing!
 */

const collections = new Map()

export const db = {
  collection: (name) => ({
    add: async (data) => {
      if (!collections.has(name)) collections.set(name, new Map())
      const id = Date.now().toString() + Math.random().toString(36).substr(2, 9)
      collections.get(name).set(id, { ...data, created_at: new Date() })
      return { id, get: async () => ({ id, data: () => collections.get(name).get(id) }) }
    },
    doc: (id) => ({
      get: async () => {
        const data = collections.get(name)?.get(id)
        return { id, exists: !!data, data: () => data }
      },
      set: async (data) => {
        if (!collections.has(name)) collections.set(name, new Map())
        collections.get(name).set(id, data)
      },
      update: async (data) => {
        if (!collections.has(name)) collections.set(name, new Map())
        const existing = collections.get(name).get(id) || {}
        collections.get(name).set(id, { ...existing, ...data })
      },
      delete: async () => {
        collections.get(name)?.delete(id)
      }
    }),
    where: (field, op, value) => ({
      get: async () => {
        const docs = []
        const coll = collections.get(name)
        if (coll) {
          for (const [id, data] of coll.entries()) {
            let match = false
            if (op === '==') match = data[field] === value
            if (op === '>') match = data[field] > value
            if (op === '<') match = data[field] < value
            if (op === '>=') match = data[field] >= value
            if (op === '<=') match = data[field] <= value
            if (match) {
              docs.push({
                id,
                ref: { update: async (u) => coll.set(id, { ...data, ...u }), delete: async () => coll.delete(id) },
                data: () => data
              })
            }
          }
        }
        return { docs, empty: docs.length === 0, size: docs.length }
      },
      limit: (n) => ({
        get: async () => {
          const result = await this.get()
          return { ...result, docs: result.docs.slice(0, n) }
        }
      }),
      orderBy: (field, dir) => ({
        get: async () => {
          const result = await this.get()
          result.docs.sort((a, b) => {
            const aVal = a.data()[field]
            const bVal = b.data()[field]
            return dir === 'desc' ? bVal - aVal : aVal - bVal
          })
          return result
        },
        limit: (n) => ({
          get: async () => {
            const result = await this.orderBy(field, dir).get()
            return { ...result, docs: result.docs.slice(0, n) }
          }
        })
      })
    }),
    orderBy: (field, dir = 'asc') => ({
      get: async () => {
        const docs = []
        const coll = collections.get(name)
        if (coll) {
          for (const [id, data] of coll.entries()) {
            docs.push({ id, data: () => data })
          }
          docs.sort((a, b) => {
            const aVal = a.data()[field]
            const bVal = b.data()[field]
            return dir === 'desc' ? bVal - aVal : aVal - bVal
          })
        }
        return { docs, empty: docs.length === 0 }
      },
      limit: (n) => ({
        get: async () => {
          const result = await this.orderBy(field, dir).get()
          return { ...result, docs: result.docs.slice(0, n) }
        }
      })
    }),
    limit: (n) => ({
      get: async () => {
        const docs = []
        const coll = collections.get(name)
        if (coll) {
          let count = 0
          for (const [id, data] of coll.entries()) {
            if (count++ >= n) break
            docs.push({ id, data: () => data })
          }
        }
        return { docs, empty: docs.length === 0 }
      }
    }),
    get: async () => {
      const docs = []
      const coll = collections.get(name)
      if (coll) {
        for (const [id, data] of coll.entries()) {
          docs.push({ id, data: () => data })
        }
      }
      return { docs, empty: docs.length === 0 }
    }
  }),
  batch: () => {
    const ops = []
    return {
      update: (ref, data) => ops.push({ type: 'update', ref, data }),
      delete: (ref) => ops.push({ type: 'delete', ref }),
      commit: async () => {
        for (const op of ops) {
          if (op.type === 'update') await op.ref.update(op.data)
          if (op.type === 'delete') await op.ref.delete()
        }
      }
    }
  }
}

export async function query(text, params = []) {
  const start = Date.now()
  const result = await executeQuery(text, params)
  const ms = Date.now() - start
  if (process.env.LOG_SQL === '1') console.log('[mock-db]', ms + 'ms', text)
  return result
}

async function executeQuery(sql, params) {
  // Simple mock - just return empty results for schema operations
  if (sql.toLowerCase().includes('create table') || sql.toLowerCase().includes('alter table')) {
    return { rows: [], rowCount: 0 }
  }
  
  // For other queries, return mock data
  return { rows: [], rowCount: 0 }
}

console.log('⚠️  Using MOCK database - data will not persist!')
